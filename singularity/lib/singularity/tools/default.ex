defmodule Singularity.Tools.Default do
  @moduledoc """
  Registers baseline unsafe tooling (shell + file read) using the shared Tool registry.
  """

  @compile {:no_warn_undefined, {Singularity.Tools.Catalog, :add_tools, 2}}
  @compile {:no_warn_undefined, {Singularity.Tools.Tool, :new!, 1}}

  alias Singularity.Schemas.Tools.Tool

  @providers [:claude_cli, :claude_http, :gemini_code_cli, :gemini_code_api]
  @defaults_key {:singularity, :tools, :defaults_loaded}
  @allowed_commands ["ls", "cat", "pwd"]
  @shell_timeout 10_000
  @workspace_root File.cwd!()

  @doc """
  Ensure default tools are registered once per node.
  """
  def ensure_registered do
    case :persistent_term.get(@defaults_key, false) do
      true ->
        :ok

      _ ->
        Enum.each(@providers, &register_defaults/1)
        :persistent_term.put(@defaults_key, true)
        :ok
    end
  end

  defp register_defaults(provider) do
    Singularity.Tools.Catalog.add_tools(provider, [shell_tool(), read_file_tool()])
    Singularity.Tools.Quality.register(provider)
    Singularity.Tools.CodebaseUnderstanding.register(provider)
    Singularity.Tools.Planning.register(provider)
    Singularity.Tools.Knowledge.register(provider)
    Singularity.Tools.CodeAnalysis.register(provider)
    Singularity.Tools.FileSystem.register(provider)
    Singularity.Tools.CodeGeneration.register(provider)
    Singularity.Tools.CodeNaming.register(provider)
    Singularity.Tools.Git.register(provider)
    Singularity.Tools.Database.register(provider)
    Singularity.Tools.Testing.register(provider)
    Singularity.Tools.ProcessSystem.register(provider)
    Singularity.Tools.Documentation.register(provider)
    Singularity.Tools.Monitoring.register(provider)
    Singularity.Tools.Security.register(provider)
    Singularity.Tools.Performance.register(provider)
    Singularity.Tools.Deployment.register(provider)
    Singularity.Tools.Communication.register(provider)
    Singularity.Tools.Analytics.register(provider)
    Singularity.Tools.Integration.register(provider)
    Singularity.Tools.QualityAssurance.register(provider)
    Singularity.Tools.Development.register(provider)
  end

  defp shell_tool do
    Tool.new!(%{
      name: "sh_run_command",
      description: "Execute a whitelisted shell command (ls, cat, pwd).",
      display_text: "Run shell command",
      parameters: [
        %{name: "command", type: :string, required: true, description: "Command to run"},
        %{name: "args", type: :array, item_type: "string", description: "Command arguments"}
      ],
      function: &__MODULE__.shell_exec/2
    })
  end

  defp read_file_tool do
    Tool.new!(%{
      name: "fs_read_file",
      description: "Read a text file relative to the workspace root.",
      display_text: "Read file",
      parameters: [
        %{name: "path", type: :string, required: true, description: "Relative file path"}
      ],
      function: &__MODULE__.read_file/2
    })
  end

  # Tool implementations ---------------------------------------------------

  def shell_exec(%{"command" => command} = args, _ctx) when command in @allowed_commands do
    argv =
      args
      |> Map.get("args", [])
      |> List.wrap()
      |> Enum.map(&to_string/1)

    case System.cmd(command, argv, stderr_to_stdout: true, timeout: @shell_timeout) do
      {output, 0} -> {:ok, output}
      {output, status} -> {:error, "command exited with status #{status}: #{output}"}
    end
  rescue
    e -> {:error, "command failed: #{Exception.message(e)}"}
  end

  def shell_exec(_args, _ctx), do: {:error, "command not allowed"}

  def read_file(%{"path" => path}, _ctx) do
    path
    |> Path.expand(@workspace_root)
    |> allow_path()
    |> case do
      {:ok, safe_path} ->
        case File.read(safe_path) do
          {:ok, contents} -> {:ok, contents}
          {:error, reason} -> {:error, "failed to read file: #{reason}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_file(_args, _ctx), do: {:error, "path is required"}

  defp allow_path(expanded) do
    if String.starts_with?(expanded, @workspace_root) do
      {:ok, expanded}
    else
      {:error, "path outside workspace not allowed"}
    end
  end
end
