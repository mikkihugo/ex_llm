defmodule CentralCloud.TemplateLoader do
  @moduledoc """
  Loads and renders Lua prompt templates from templates_data/.

  Supports:
  - Dynamic variable injection
  - Workspace integration (glob, grep, read_file) via Lua
  - Template caching for performance

  ## Examples

      iex> TemplateLoader.load("architecture/llm_team/analyst-discover-pattern.lua", %{
        pattern_type: "architecture",
        code_samples: samples,
        codebase_id: "mikkihugo/singularity"
      })
      {:ok, "rendered prompt string"}
  """

  use GenServer
  require Logger

  @templates_root Path.join([
                    File.cwd!(),
                    "..",
                    "templates_data",
                    "prompt_library"
                  ])

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Load and render a Lua template with variables.

  Returns the rendered prompt string ready for LLM consumption.
  """
  def load(template_path, variables \\ %{}) do
    GenServer.call(__MODULE__, {:load, template_path, variables}, 30_000)
  end

  @doc """
  Test a template by rendering with default variables.
  """
  def test_template(template_path) do
    test_vars = %{
      codebase_id: "test/codebase",
      project_root: "/test/path",
      code_samples: [
        %{path: "lib/test.ex", content: "defmodule Test do\nend", language: "elixir"}
      ]
    }

    load(template_path, test_vars)
  end

  @doc """
  Clear template cache (useful after template updates).
  """
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("TemplateLoader starting with templates_root: #{@templates_root}")

    state = %{
      cache: %{},
      cache_hits: 0,
      cache_misses: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:load, template_path, variables}, _from, state) do
    case get_or_load_template(template_path, state) do
      {:ok, lua_content, new_state} ->
        case render_template(lua_content, variables) do
          {:ok, rendered} ->
            {:reply, {:ok, rendered}, new_state}

          {:error, reason} ->
            Logger.error("Template render failed for #{template_path}: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        Logger.error("Template load failed for #{template_path}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    Logger.info("Clearing template cache (#{map_size(state.cache)} entries)")
    new_state = %{state | cache: %{}}
    {:reply, :ok, new_state}
  end

  ## Private Functions

  defp get_or_load_template(template_path, state) do
    full_path = Path.join(@templates_root, template_path)

    case Map.get(state.cache, template_path) do
      nil ->
        # Cache miss - load from file
        Logger.debug("Template cache miss: #{template_path}")

        case File.read(full_path) do
          {:ok, content} ->
            new_cache = Map.put(state.cache, template_path, content)

            new_state = %{
              state
              | cache: new_cache,
                cache_misses: state.cache_misses + 1
            }

            {:ok, content, new_state}

          {:error, reason} ->
            {:error, {:file_read_failed, full_path, reason}}
        end

      cached_content ->
        # Cache hit
        Logger.debug("Template cache hit: #{template_path}")

        new_state = %{state | cache_hits: state.cache_hits + 1}
        {:ok, cached_content, new_state}
    end
  end

  defp render_template(lua_content, variables) do
    # TODO: Full Lua rendering with luerl
    # For now, do simple variable substitution as placeholder

    # Extract template metadata (comments at top)
    {metadata, _body} = extract_metadata(lua_content)

    # Simple placeholder rendering
    # In production, this will use luerl to execute Lua and call workspace functions
    rendered = """
    # LLM Prompt Template Rendered

    Template Version: #{Map.get(metadata, :version, "unknown")}
    Model: #{Map.get(metadata, :model, "unknown")}

    Variables Injected:
    #{inspect(variables, pretty: true)}

    ---

    TODO: Full Lua rendering with luerl integration
    This placeholder shows that template loading works.
    Next step: Integrate luerl for full Lua execution with workspace functions.

    Template Content Preview:
    #{String.slice(lua_content, 0, 500)}...
    """

    {:ok, rendered}
  end

  defp extract_metadata(lua_content) do
    # Extract version, model, etc. from Lua comments
    version =
      case Regex.run(~r/-- Version: (.+)/, lua_content) do
        [_, v] -> String.trim(v)
        _ -> "1.0.0"
      end

    model =
      case Regex.run(~r/-- Model: (.+)/, lua_content) do
        [_, m] -> String.trim(m)
        _ -> "unknown"
      end

    agent =
      case Regex.run(~r/-- Agent: (.+)/, lua_content) do
        [_, a] -> String.trim(a)
        _ -> "unknown"
      end

    metadata = %{
      version: version,
      model: model,
      agent: agent
    }

    {metadata, lua_content}
  end
end
