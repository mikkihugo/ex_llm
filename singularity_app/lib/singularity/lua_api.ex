defmodule Singularity.LuaAPI do
  @moduledoc """
  Lua API - Exposes Elixir functions to Lua scripts.

  Provides sandboxed APIs for:
  - File operations (workspace.read_file, workspace.file_exists, workspace.glob)
  - Git operations (git.log, git.diff)
  - LLM sub-prompts (llm.call_simple, llm.call_complex)
  - Prompt building (Prompt.new(), section(), instruction())

  ## Usage

      lua = Lua.new() |> Lua.load_api(Singularity.LuaAPI)
      {[result], _state} = Lua.eval!(lua, ~LUA[return workspace.read_file("README.md")])
  """

  use Lua.API, scope: "workspace"
  alias Singularity.LLM.Service, as: LLMService
  require Logger

  @doc """
  Read file from project workspace.

  Returns file contents or nil if file doesn't exist.
  """
  deflua read_file(path), state do
    context = Lua.get!(state, [:_CONTEXT])
    project_root = Map.get(context, "project_root", File.cwd!())
    full_path = Path.join(project_root, to_string(path))

    case File.read(full_path) do
      {:ok, content} ->
        {[content], state}

      {:error, reason} ->
        Logger.warning("Lua workspace.read_file failed: #{full_path} - #{inspect(reason)}")
        {[nil], state}
    end
  end

  @doc """
  Check if file exists in project workspace.
  """
  deflua file_exists(path), state do
    context = Lua.get!(state, [:_CONTEXT])
    project_root = Map.get(context, "project_root", File.cwd!())
    full_path = Path.join(project_root, to_string(path))
    {[File.exists?(full_path)], state}
  end

  @doc """
  Find files matching glob pattern.
  Returns array of relative paths.
  """
  deflua glob(pattern), state do
    context = Lua.get!(state, [:_CONTEXT])
    project_root = Map.get(context, "project_root", File.cwd!())
    full_pattern = Path.join(project_root, to_string(pattern))
    files = Path.wildcard(full_pattern)

    relative_files =
      Enum.map(files, fn file ->
        Path.relative_to(file, project_root)
      end)

    {[relative_files], state}
  end
end

defmodule Singularity.LuaAPI.Git do
  @moduledoc """
  Git operations exposed to Lua.
  """
  use Lua.API, scope: "git"
  require Logger

  @doc """
  Get git log.

  Options:
  - max_count: Number of commits (default: 10)
  """
  deflua log(opts), state do
    context = Lua.get!(state, [:_CONTEXT])
    project_root = Map.get(context, "project_root", File.cwd!())
    max_count = get_lua_option(opts, "max_count", 10)

    case System.cmd("git", ["log", "--oneline", "-n", "#{max_count}"], cd: project_root) do
      {output, 0} ->
        commits = String.split(output, "\n", trim: true)
        {[commits], state}

      {_output, _exit_code} ->
        {[[]], state}
    end
  end

  @doc """
  Get git diff stats.
  """
  deflua diff(_opts), state do
    context = Lua.get!(state, [:_CONTEXT])
    project_root = Map.get(context, "project_root", File.cwd!())

    case System.cmd("git", ["diff", "--stat"], cd: project_root) do
      {output, 0} -> {[output], state}
      {_output, _exit_code} -> {[""], state}
    end
  end

  defp get_lua_option(table, key, default) when is_map(table) do
    Map.get(table, to_string(key), default)
  end

  defp get_lua_option(_table, _key, default), do: default
end

defmodule Singularity.LuaAPI.LLM do
  @moduledoc """
  LLM operations exposed to Lua (sub-prompts).
  """
  use Lua.API, scope: "llm"
  alias Singularity.LLM.Service, as: LLMService
  require Logger

  @doc """
  Call LLM with simple complexity.

  Options:
  - prompt: Prompt string (required)
  """
  deflua call_simple(opts), state do
    prompt = get_lua_option(opts, "prompt", "")

    case LLMService.call(:simple, [%{role: "user", content: prompt}]) do
      {:ok, %{text: response}} ->
        {[response], state}

      {:error, reason} ->
        Logger.error("Lua llm.call_simple failed: #{inspect(reason)}")
        {[""], state}
    end
  end

  @doc """
  Call LLM with complex complexity.

  Options:
  - prompt: Prompt string (required)
  """
  deflua call_complex(opts), state do
    prompt = get_lua_option(opts, "prompt", "")

    case LLMService.call(:complex, [%{role: "user", content: prompt}]) do
      {:ok, %{text: response}} ->
        {[response], state}

      {:error, reason} ->
        Logger.error("Lua llm.call_complex failed: #{inspect(reason)}")
        {[""], state}
    end
  end

  defp get_lua_option(table, key, default) when is_map(table) do
    Map.get(table, to_string(key), default)
  end

  defp get_lua_option(_table, _key, default), do: default
end

defmodule Singularity.LuaAPI.Prompt do
  @moduledoc """
  Prompt builder API exposed to Lua.
  """
  use Lua.API, scope: "Prompt"

  @doc """
  Create new prompt builder.
  """
  deflua new() do
    %{"sections" => [], "instructions" => []}
  end

  @doc """
  Add section to prompt.
  """
  deflua section(prompt, name, content) do
    updated =
      Map.update!(prompt, "sections", fn sections ->
        sections ++ [%{"name" => to_string(name), "content" => to_string(content)}]
      end)

    updated
  end

  @doc """
  Add instruction to prompt.
  """
  deflua instruction(prompt, text) do
    Map.update!(prompt, "instructions", fn instructions ->
      instructions ++ [to_string(text)]
    end)
  end

  @doc """
  Add bullet point to prompt.
  """
  deflua bullet(prompt, text) do
    Map.update!(prompt, "instructions", fn instructions ->
      instructions ++ ["- " <> to_string(text)]
    end)
  end
end
