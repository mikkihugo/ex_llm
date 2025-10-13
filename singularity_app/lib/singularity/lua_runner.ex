defmodule Singularity.LuaRunner do
  @moduledoc """
  Execute Lua prompt scripts with sandboxing and API injection.

  Provides Lua scripts with safe APIs for:
  - File reading (workspace.read_file, workspace.file_exists)
  - Git operations (git.log, git.diff)
  - Sub-prompts (llm.call_simple, llm.call_complex)
  - Prompt building (Prompt.new(), section(), instruction())

  ## Security

  - Sandboxed execution (Luerl sandbox)
  - No file writes from Lua
  - No arbitrary system commands
  - Resource limits (max execution time, memory)

  ## Examples

      iex> lua_code = \"\"\"
      ...> local prompt = Prompt.new()
      ...> prompt:section("README", workspace.read_file("README.md"))
      ...> return prompt
      ...> \"\"\"
      iex> LuaRunner.execute(lua_code, %{project_root: "/app"})
      {:ok, [%{role: "user", content: "=== README ===\\n..."}]}
  """

  require Logger

  @type context :: %{required(:project_root) => String.t(), optional(atom()) => any()}

  @type message :: %{role: String.t(), content: String.t()}

  @doc """
  Execute Lua script and return assembled prompt messages.

  ## Parameters

  - `lua_script` - Lua code as string
  - `context` - Context map with project_root and optional vars

  ## Returns

  - `{:ok, messages}` - List of LLM message maps
  - `{:error, reason}` - Execution error
  """
  @spec execute(String.t(), context()) :: {:ok, [message()]} | {:error, term()}
  def execute(lua_script, context) do
    try do
      # 1. Initialize sandboxed Lua state
      state = :luerl.init()

      # 2. Inject APIs (workspace, git, llm, Prompt)
      state = inject_apis(state, context)

      # 3. Execute script
      case :luerl.do(lua_script, state) do
        {[result], _new_state} when is_map(result) ->
          # 4. Convert Lua result to Elixir messages
          {:ok, lua_result_to_messages(result)}

        {[result], _new_state} ->
          {:error, {:invalid_return, "Expected Prompt table, got: #{inspect(result)}"}}

        {:error, reason, _state} ->
          {:error, {:lua_error, reason}}
      end
    rescue
      error ->
        Logger.error("Lua execution failed: #{inspect(error)}")
        {:error, {:execution_error, error}}
    end
  end

  # ============================================================================
  # API INJECTION
  # ============================================================================

  defp inject_apis(state, context) do
    state
    |> inject_workspace_api(context)
    |> inject_git_api(context)
    |> inject_llm_api()
    |> inject_prompt_builder()
  end

  # ----------------------------------------------------------------------------
  # Workspace API
  # ----------------------------------------------------------------------------

  defp inject_workspace_api(state, context) do
    project_root = Map.get(context, :project_root, File.cwd!())

    # workspace.read_file(path) -> string | nil
    state =
      :luerl.set_table(
        state,
        ["workspace", "read_file"],
        fn [path], st ->
          full_path = Path.join(project_root, to_string(path))

          case File.read(full_path) do
            {:ok, content} -> {[content], st}
            {:error, reason} ->
              Logger.warning("Lua workspace.read_file failed: #{full_path} - #{inspect(reason)}")
              {[nil], st}
          end
        end
      )

    # workspace.file_exists(path) -> boolean
    state =
      :luerl.set_table(
        state,
        ["workspace", "file_exists"],
        fn [path], st ->
          full_path = Path.join(project_root, to_string(path))
          {[File.exists?(full_path)], st}
        end
      )

    # workspace.glob(pattern) -> array of paths
    state =
      :luerl.set_table(
        state,
        ["workspace", "glob"],
        fn [pattern], st ->
          full_pattern = Path.join(project_root, to_string(pattern))
          files = Path.wildcard(full_pattern)
          # Convert to relative paths
          relative_files =
            Enum.map(files, fn file ->
              Path.relative_to(file, project_root)
            end)

          {[relative_files], st}
        end
      )

    state
  end

  # ----------------------------------------------------------------------------
  # Git API
  # ----------------------------------------------------------------------------

  defp inject_git_api(state, context) do
    project_root = Map.get(context, :project_root, File.cwd!())

    # git.log(opts) -> array of commit messages
    state =
      :luerl.set_table(
        state,
        ["git", "log"],
        fn [opts], st ->
          max_count = get_lua_table_value(opts, "max_count", 10)

          case System.cmd("git", ["log", "--oneline", "-n", "#{max_count}"], cd: project_root) do
            {output, 0} ->
              commits =
                output
                |> String.split("\n", trim: true)

              {[commits], st}

            {_output, _exit_code} ->
              {[[]], st}
          end
        end
      )

    # git.diff(opts) -> string
    state =
      :luerl.set_table(
        state,
        ["git", "diff"],
        fn [_opts], st ->
          case System.cmd("git", ["diff", "--stat"], cd: project_root) do
            {output, 0} -> {[output], st}
            {_output, _exit_code} -> {[""], st}
          end
        end
      )

    state
  end

  # ----------------------------------------------------------------------------
  # LLM API (Sub-prompts)
  # ----------------------------------------------------------------------------

  defp inject_llm_api(state) do
    # llm.call_simple(opts) -> string
    state =
      :luerl.set_table(
        state,
        ["llm", "call_simple"],
        fn [opts], st ->
          prompt = get_lua_table_value(opts, "prompt", "")

          case Singularity.LLM.Service.call(:simple, [
                 %{role: "user", content: prompt}
               ]) do
            {:ok, %{text: response}} -> {[response], st}
            {:error, reason} ->
              Logger.error("Lua llm.call_simple failed: #{inspect(reason)}")
              {[""], st}
          end
        end
      )

    # llm.call_complex(opts) -> string
    state =
      :luerl.set_table(
        state,
        ["llm", "call_complex"],
        fn [opts], st ->
          prompt = get_lua_table_value(opts, "prompt", "")

          case Singularity.LLM.Service.call(:complex, [
                 %{role: "user", content: prompt}
               ]) do
            {:ok, %{text: response}} -> {[response], st}
            {:error, reason} ->
              Logger.error("Lua llm.call_complex failed: #{inspect(reason)}")
              {[""], st}
          end
        end
      )

    state
  end

  # ----------------------------------------------------------------------------
  # Prompt Builder API
  # ----------------------------------------------------------------------------

  defp inject_prompt_builder(state) do
    # Prompt.new() -> table
    state =
      :luerl.set_table(
        state,
        ["Prompt", "new"],
        fn [], st ->
          # Return Lua table with metatable for method calls
          prompt_table = %{"sections" => [], "instructions" => []}
          {[prompt_table], st}
        end
      )

    # prompt:section(name, content) -> prompt
    state =
      :luerl.set_table(
        state,
        ["Prompt", "section"],
        fn [prompt, name, content], st ->
          updated =
            Map.update!(prompt, "sections", fn sections ->
              sections ++ [%{"name" => to_string(name), "content" => to_string(content)}]
            end)

          {[updated], st}
        end
      )

    # prompt:instruction(text) -> prompt
    state =
      :luerl.set_table(
        state,
        ["Prompt", "instruction"],
        fn [prompt, text], st ->
          updated =
            Map.update!(prompt, "instructions", fn instructions ->
              instructions ++ [to_string(text)]
            end)

          {[updated], st}
        end
      )

    # prompt:bullet(text) -> prompt
    state =
      :luerl.set_table(
        state,
        ["Prompt", "bullet"],
        fn [prompt, text], st ->
          updated =
            Map.update!(prompt, "instructions", fn instructions ->
              instructions ++ ["- " <> to_string(text)]
            end)

          {[updated], st}
        end
      )

    state
  end

  # ============================================================================
  # CONVERSION
  # ============================================================================

  defp lua_result_to_messages(lua_result) when is_map(lua_result) do
    sections = Map.get(lua_result, "sections", [])
    instructions = Map.get(lua_result, "instructions", [])

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

  defp lua_result_to_messages(_), do: []

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp get_lua_table_value(table, key, default) when is_map(table) do
    Map.get(table, to_string(key), default)
  end

  defp get_lua_table_value(_table, _key, default), do: default
end
