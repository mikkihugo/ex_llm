defmodule Singularity.LuaRunner do
  @moduledoc """
  Lua script executor using ergonomic Lua wrapper over Luerl.

  Execute Lua scripts with sandboxed APIs for file reading, git operations,
  LLM sub-prompts, and prompt building.

  Uses the `lua` package (v0.3.0) which provides an ergonomic interface over
  raw luerl. When luerl 2.0 releases, these features will merge directly into luerl.

  ## Use Cases

  **Prompt Building** (original):
  - Dynamic prompt assembly
  - Context-aware template generation

  **Rule Engine** (NEW - hot-reload business logic!):
  - Store business rules in database as Lua scripts
  - Update rules without recompiling Elixir
  - Confidence-based autonomous decisions

  ## Usage

  ### Prompt Building

      lua_code = ~LUA[
        local prompt = Prompt.new()
        local readme = workspace.read_file("README.md")
        prompt:section("Context", readme)
        return prompt
      ]

      {:ok, messages} = LuaRunner.execute(lua_code, %{project_root: "/"})

  ### Rule Engine

      lua_rule = ~LUA[
        function validate_epic(context)
          local wsjf = context.metrics.wsjf_score or 0
          local business_value = context.metrics.business_value or 0

          if wsjf > 50 and business_value > 70 then
            return {
              decision = "autonomous",
              confidence = 0.95,
              reasoning = "High WSJF and business value"
            }
          else
            return {
              decision = "escalated",
              confidence = 0.5,
              reasoning = "Low WSJF, human decision required"
            }
          end
        end

        return validate_epic(context)
      ]

      {:ok, result} = LuaRunner.execute_rule(lua_rule, %{metrics: %{wsjf_score: 60}})
      # => %{"decision" => "autonomous", "confidence" => 0.95, ...}

  ## Features

  - Compile-time syntax checking with ~LUA sigil
  - Better error messages
  - Cleaner API using `deflua` macro
  - Automatic type conversions
  - Sandboxed execution
  - Hot-reload from database

  ## Security

  - Sandboxed execution
  - No file writes
  - No arbitrary system commands
  - Scoped to project_root

  See `Singularity.LuaAPI` for available APIs.
  """

  require Logger

  @type context :: %{required(:project_root) => String.t(), optional(atom()) => any()}
  @type message :: %{role: String.t(), content: String.t()}

  @doc """
  Execute Lua script and return assembled prompt messages.

  ## Parameters

  - `lua_script` - Lua code as string
  - `context` - Context map with `:project_root` and optional vars

  ## Returns

  - `{:ok, messages}` - List of LLM message maps
  - `{:error, reason}` - Execution error

  ## Examples

      iex> lua = ~S[
      ...>   local prompt = Prompt.new()
      ...>   prompt:section("Task", "Build feature")
      ...>   return prompt
      ...> ]
      iex> LuaRunner.execute(lua, %{project_root: "."})
      {:ok, [%{role: "user", content: "=== Task ===\\nBuild feature"}]}
  """
  @spec execute(String.t(), context()) :: {:ok, [message()]} | {:error, term()}
  def execute(lua_script, context) do
    try do
      project_root = Map.get(context, :project_root, File.cwd!())

      # 1. Create Lua state with APIs and inject context
      lua =
        Lua.new()
        # Store context in Lua global _CONTEXT table
        |> Lua.set!([:_CONTEXT], %{"project_root" => project_root})
        |> Lua.load_api(Singularity.LuaAPI)
        |> Lua.load_api(Singularity.LuaAPI.Git)
        |> Lua.load_api(Singularity.LuaAPI.LLM)
        |> Lua.load_api(Singularity.LuaAPI.Prompt)

      # 2. Execute script
      {result, _new_state} = Lua.eval!(lua, lua_script)

      # 3. Convert result to messages
      messages = lua_result_to_messages(result)
      {:ok, messages}
    rescue
      error ->
        Logger.error("Lua execution failed: #{inspect(error)}")
        {:error, {:execution_error, error}}
    end
  end

  # ============================================================================
  # CONVERSION
  # ============================================================================

  @doc false
  def lua_result_to_messages([result]) when is_map(result) do
    sections = Map.get(result, "sections", [])
    instructions = Map.get(result, "instructions", [])

    # Build content from sections
    section_content =
      Enum.map(sections, fn section ->
        name = Map.get(section, "name", "")
        content = Map.get(section, "content", "")
        "=== #{name} ===\n#{content}"
      end)

    # Combine sections + instructions
    full_content =
      (section_content ++ instructions)
      |> Enum.reject(&(&1 == "" or is_nil(&1)))
      |> Enum.join("\n\n")

    [%{role: "user", content: full_content}]
  end

  def lua_result_to_messages(_), do: []

  # ============================================================================
  # RULE ENGINE EXECUTION
  # ============================================================================

  @doc """
  Execute Lua rule and return decision result.

  Lua script must return a table with:
  - `decision`: "autonomous" | "collaborative" | "escalated"
  - `confidence`: 0.0-1.0
  - `reasoning`: Human-readable explanation

  ## Parameters

  - `lua_script` - Lua code as string
  - `context` - Rule execution context (epic metrics, feature data, etc.)

  ## Returns

  - `{:ok, result}` - Map with decision, confidence, reasoning
  - `{:error, reason}` - Execution error

  ## Examples

      iex> lua = ~S[
      ...>   local wsjf = context.metrics.wsjf_score or 0
      ...>   if wsjf > 50 then
      ...>     return {decision = "autonomous", confidence = 0.95, reasoning = "High WSJF"}
      ...>   else
      ...>     return {decision = "escalated", confidence = 0.5, reasoning = "Low WSJF"}
      ...>   end
      ...> ]
      iex> LuaRunner.execute_rule(lua, %{metrics: %{wsjf_score: 60}})
      {:ok, %{"decision" => "autonomous", "confidence" => 0.95, "reasoning" => "High WSJF"}}
  """
  @spec execute_rule(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def execute_rule(lua_script, context) do
    try do
      # 1. Create Lua state and inject context
      lua =
        Lua.new()
        # Inject entire context as global `context` variable
        |> Lua.set!([:context], elixir_to_lua_map(context))

      # 2. Execute script
      {result, _new_state} = Lua.eval!(lua, lua_script)

      # 3. Extract decision result
      case result do
        [lua_table] when is_map(lua_table) ->
          {:ok, lua_table}

        other ->
          Logger.warning("Lua rule returned unexpected result: #{inspect(other)}")
          {:error, {:invalid_result, other}}
      end
    rescue
      error ->
        Logger.error("Lua rule execution failed: #{inspect(error)}")
        {:error, {:execution_error, error}}
    end
  end

  # Convert Elixir map to Lua-compatible nested structure
  defp elixir_to_lua_map(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      lua_key = if is_atom(key), do: Atom.to_string(key), else: key
      lua_value = elixir_to_lua_value(value)
      {lua_key, lua_value}
    end)
  end

  defp elixir_to_lua_value(map) when is_map(map), do: elixir_to_lua_map(map)
  defp elixir_to_lua_value(list) when is_list(list), do: Enum.map(list, &elixir_to_lua_value/1)
  defp elixir_to_lua_value(value), do: value
end
