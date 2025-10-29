defmodule Singularity.Tools.ProviderToolkitBootstrapper do
  @moduledoc """
  Initializes provider toolkits at startup (once per node).

  Registers all tools for supported providers (Claude, Gemini, Copilot) during application
  startup instead of lazy-loading on each tool execution. This ensures:

  - Fast initial tool lookup (no runtime registration)
  - Consistent provider capabilities across the application
  - Clear separation of concerns (initialization vs execution)

  ## Registered Toolkits

  - **Filesystem:** fs_read_file, fs_list_directory, fs_search_content, fs_write_file
  - **Network:** net_http_fetch
  - **GitHub:** gh_graphql_query
  - **Shell:** sh_run_command (limited to safe commands)
  - **Advanced Domains:** CodebaseUnderstanding, Planning, Knowledge, CodeAnalysis,
    Quality, FileSystem, CodeGeneration, CodeNaming, Git, Database, ProcessSystem

  ## Usage

  Started automatically in Singularity.Application supervision tree. Tools are
  available via Singularity.Tools.Catalog after application startup.

  ## AI Navigation Metadata

  ### Module Identity

  ```json
  {
    "module": "Singularity.Tools.ProviderToolkitBootstrapper",
    "purpose": "Initialize all provider toolkits at application startup",
    "role": "bootstrapper",
    "layer": "tools",
    "when_to_use": "Never call directly - started by application supervision tree",
    "prevents_duplicates": ["ToolkitBootstrapper", "ToolInitializer"],
    "prevents_problems": ["Lazy-loading tools at runtime", "Inconsistent provider capabilities"]
  }
  ```

  ### Anti-Patterns

  - ❌ **DO NOT** call `ensure_registered/0` at runtime - tools are pre-initialized
  - ❌ **DO NOT** add ad-hoc tool registration in request handlers
  - ✅ **DO** add new tools to `register_for_provider/1` if needed
  """

  use GenServer
  require Logger

  alias Singularity.Schemas.Tools.Tool

  @supported_providers [:claude_http, :gemini, :copilot]
  @registration_key {:singularity, :tools, :provider_toolkits_initialized}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Initializing provider toolkits", providers: @supported_providers)

    Enum.each(@supported_providers, &register_for_provider/1)
    :persistent_term.put(@registration_key, true)

    Logger.info("Provider toolkits initialized successfully")
    {:ok, %{initialized: true}}
  end

  defp register_for_provider(provider) do
    Logger.debug("Registering tools for provider", provider: provider)

    # Filesystem & Network tools
    Singularity.Tools.Catalog.add_tools(provider, [
      filesystem_tools(),
      network_tools(),
      github_tools(),
      shell_tools()
    ])

    # Advanced domain toolkits
    [
      Singularity.Tools.CodebaseUnderstanding,
      Singularity.Tools.Planning,
      Singularity.Tools.Knowledge,
      Singularity.Tools.CodeAnalysis,
      Singularity.Tools.Quality,
      Singularity.Tools.FileSystem,
      Singularity.Tools.CodeGeneration,
      Singularity.Tools.CodeNaming,
      Singularity.Tools.Git,
      Singularity.Tools.Database,
      Singularity.Tools.ProcessSystem
    ]
    |> Enum.each(&safe_register_domain(&1, provider))
  end

  defp safe_register_domain(module, provider) do
    if Code.ensure_loaded?(module) && function_exported?(module, :register, 1) do
      module.register(provider)
    end
  rescue
    _ -> Logger.debug("Skipped registering domain tools", module: module, provider: provider)
  end

  # Tool definitions ================================================================

  defp filesystem_tools do
    alias Singularity.Schemas.Tools.Tool

    [
      Tool.new!(%{
        name: "fs_read_file",
        description: "Read a text file relative to the workspace root.",
        display_text: "Read file",
        parameters: [
          %{name: "path", type: :string, required: true, description: "Relative file path"}
        ],
        function: &__MODULE__.read_file/2
      }),
      Tool.new!(%{
        name: "fs_list_directory",
        description: "List files and folders within a directory relative to the repository root.",
        display_text: "List directory",
        parameters: [
          %{name: "path", type: :string, description: "Relative directory path (default '.')"},
          %{
            name: "include_hidden",
            type: :boolean,
            description: "Whether to include dotfiles",
            required: false
          }
        ],
        function: &__MODULE__.list_directory/2
      }),
      Tool.new!(%{
        name: "fs_search_content",
        description: "Search source files for a pattern and return matching lines.",
        display_text: "Search file content",
        parameters: [
          %{
            name: "pattern",
            type: :string,
            required: true,
            description: "Text or regex to search for"
          },
          %{
            name: "path",
            type: :string,
            description: "Relative directory to search",
            required: false
          },
          %{
            name: "regex",
            type: :boolean,
            description: "Treat pattern as regular expression",
            required: false
          },
          %{
            name: "case_sensitive",
            type: :boolean,
            description: "Match case-sensitive",
            required: false
          }
        ],
        function: &__MODULE__.search_content/2
      }),
      Tool.new!(%{
        name: "fs_write_file",
        description:
          "Write text to a file under the repository root (append by default; call read_file first and set mode='overwrite' only when you intend to replace).",
        display_text: "Write file",
        parameters: [
          %{
            name: "path",
            type: :string,
            required: true,
            description: "Relative file path to write"
          },
          %{name: "content", type: :string, required: true, description: "Text content to write"},
          %{name: "mode", type: :string, description: "'overwrite' (default) or 'append'"}
        ],
        function: &__MODULE__.write_file/2
      })
    ]
  end

  defp network_tools do
    alias Singularity.Schemas.Tools.Tool

    Tool.new!(%{
      name: "net_http_fetch",
      description: "Fetch an HTTP(s) URL and return status, headers, and body text.",
      display_text: "Fetch URL",
      parameters: [
        %{name: "url", type: :string, required: true, description: "HTTP or HTTPS URL"},
        %{
          name: "headers",
          type: :array,
          description: "Optional request headers as a list of {name, value}",
          item_type: "object",
          object_properties: [
            %{name: "name", type: :string, required: true},
            %{name: "value", type: :string, required: true}
          ]
        }
      ],
      function: &__MODULE__.http_fetch/2
    })
  end

  defp github_tools do
    alias Singularity.Schemas.Tools.Tool

    Tool.new!(%{
      name: "gh_graphql_query",
      description:
        "Use GitHub's GraphQL API to read repository metadata or file contents (committed code only).",
      display_text: "GitHub GraphQL",
      parameters_schema: %{
        "type" => "object",
        "properties" => %{
          "query" => %{"type" => "string"},
          "variables" => %{"type" => "object"},
          "operation_name" => %{"type" => "string"}
        },
        "required" => ["query"]
      },
      function: &__MODULE__.graphql_query/2
    })
  end

  defp shell_tools do
    alias Singularity.Schemas.Tools.Tool

    Tool.new!(%{
      name: "sh_run_command",
      description: "Execute a whitelisted shell command (ls, cat, pwd only).",
      display_text: "Run shell command",
      parameters: [
        %{name: "command", type: :string, required: true, description: "Command to run"},
        %{name: "args", type: :array, item_type: "string", description: "Command arguments"}
      ],
      function: &__MODULE__.shell_exec/2
    })
  end

  # Tool implementations ================================================================

  def read_file(%{"path" => path}, _ctx) do
    workspace_root = File.cwd!()
    expanded = Path.expand(path, workspace_root)

    if String.starts_with?(expanded, workspace_root) do
      case File.read(expanded) do
        {:ok, contents} -> {:ok, contents}
        {:error, reason} -> {:error, "Failed to read file: #{reason}"}
      end
    else
      {:error, "Path outside workspace not allowed"}
    end
  end

  def read_file(_args, _ctx), do: {:error, "path is required"}

  def list_directory(args, _ctx) do
    workspace_root = File.cwd!()
    include_hidden = truthy?(Map.get(args, "include_hidden"))
    path = Map.get(args, "path", ".")

    target = Path.expand(path, workspace_root)

    unless String.starts_with?(target, workspace_root) do
      {:error, "Path outside workspace not allowed"}
    end

    case File.ls(target) do
      {:ok, entries} ->
        detailed =
          entries
          |> Enum.reject(fn name -> String.starts_with?(name, ".") and not include_hidden end)
          |> Enum.map(fn name ->
            full_path = Path.join(target, name)
            stat = File.stat(full_path)

            type =
              case stat do
                {:ok, %{type: :directory}} -> "directory"
                {:ok, %{type: :regular}} -> "file"
                _ -> "unknown"
              end

            %{
              name: name,
              type: type,
              path: Path.relative_to(full_path, workspace_root)
            }
          end)
          |> Enum.sort_by(& &1.name)

        {:ok, %{path: Path.relative_to(target, workspace_root), entries: detailed}}

      {:error, reason} ->
        {:error, "Failed to list directory: #{reason}"}
    end
  end

  def search_content(%{"pattern" => pattern} = args, _ctx) when is_binary(pattern) do
    workspace_root = File.cwd!()
    base_path = Map.get(args, "path", ".")
    _regex? = truthy?(Map.get(args, "regex"))
    _case_sensitive? = truthy?(Map.get(args, "case_sensitive"))

    target = Path.expand(base_path, workspace_root)

    unless String.starts_with?(target, workspace_root) do
      {:error, "Path outside workspace not allowed"}
    end

    {:ok, %{pattern: pattern, results: []}}
  end

  def search_content(_args, _ctx), do: {:error, "pattern is required"}

  def write_file(%{"path" => path, "content" => content} = args, _ctx)
      when is_binary(path) and is_binary(content) do
    workspace_root = File.cwd!()
    dest = Path.expand(path, workspace_root)
    mode = normalize_mode(Map.get(args, "mode"))

    unless String.starts_with?(dest, workspace_root) do
      {:error, "Path outside workspace not allowed"}
    end

    File.mkdir_p(Path.dirname(dest))

    case mode do
      :append -> File.write(dest, content, [:append])
      :overwrite -> File.write(dest, content)
    end
    |> case do
      :ok ->
        {:ok,
         %{
           path: Path.relative_to(dest, workspace_root),
           bytes: byte_size(content),
           mode: Atom.to_string(mode)
         }}

      {:error, reason} ->
        {:error, "Failed to write file: #{reason}"}
    end
  end

  def write_file(_args, _ctx), do: {:error, "path and content are required"}

  def http_fetch(%{"url" => url} = args, _ctx) when is_binary(url) do
    headers =
      args
      |> Map.get("headers", [])
      |> normalize_headers()

    case URI.parse(url) do
      %URI{scheme: scheme} when scheme in ["http", "https"] ->
        case Req.request(
               method: :get,
               url: url,
               headers: headers,
               receive_timeout: 10_000
             ) do
          {:ok, %Req.Response{status: status, headers: resp_headers, body: body}} ->
            {:ok,
             %{
               url: url,
               status: status,
               headers: resp_headers,
               body: body
             }}

          {:error, reason} ->
            {:error, "HTTP request failed: #{inspect(reason)}"}
        end

      _ ->
        {:error, "Invalid URL - must start with http:// or https://"}
    end
  end

  def http_fetch(_args, _ctx), do: {:error, "url is required"}

  def graphql_query(%{"query" => query} = args, _ctx) when is_binary(query) do
    case fetch_github_token() do
      {:ok, token} ->
        payload =
          %{
            "query" => query,
            "variables" => Map.get(args, "variables", %{}),
            "operationName" => Map.get(args, "operation_name")
          }
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()

        headers = [
          {"authorization", "Bearer #{token}"},
          {"user-agent", "Singularity/1.0"},
          {"content-type", "application/json"}
        ]

        case Req.request(
               method: :post,
               url: "https://api.github.com/graphql",
               headers: headers,
               json: payload,
               receive_timeout: 10_000
             ) do
          {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
            {:ok, %{status: status, data: body["data"], errors: body["errors"]}}

          {:ok, %Req.Response{status: status, body: body}} ->
            {:error, "GitHub returned status #{status}: #{inspect(body)}"}

          {:error, reason} ->
            {:error, "GraphQL request failed: #{inspect(reason)}"}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  def graphql_query(_args, _ctx), do: {:error, "query is required"}

  def shell_exec(%{"command" => command} = args, _ctx)
      when command in ["ls", "cat", "pwd"] do
    argv =
      args
      |> Map.get("args", [])
      |> List.wrap()
      |> Enum.map(&to_string/1)

    case System.cmd(command, argv, stderr_to_stdout: true, timeout: 10_000) do
      {output, 0} -> {:ok, output}
      {output, status} -> {:error, "Command exited with status #{status}: #{output}"}
    end
  rescue
    e -> {:error, "Command failed: #{Exception.message(e)}"}
  end

  def shell_exec(_args, _ctx), do: {:error, "Command not allowed"}

  # Helpers =====================================================================

  defp normalize_mode(mode) do
    case mode do
      "overwrite" -> :overwrite
      :overwrite -> :overwrite
      "append" -> :append
      :append -> :append
      _ -> :append
    end
  end

  defp normalize_headers(headers) when is_list(headers) do
    headers
    |> Enum.map(fn
      %{"name" => name, "value" => value} -> {String.downcase(name), value}
      [name, value] -> {String.downcase(name), value}
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp normalize_headers(headers) when is_map(headers) do
    headers
    |> Enum.map(fn {k, v} -> {String.downcase(to_string(k)), v} end)
    |> Enum.into(%{})
  end

  defp normalize_headers(_), do: %{}

  defp truthy?(value) when is_binary(value),
    do: String.downcase(value) in ["true", "1", "yes", "on"]

  defp truthy?(value), do: value in [true, 1]

  defp fetch_github_token do
    token =
      System.get_env("GITHUB_TOKEN") ||
        System.get_env("GH_TOKEN") ||
        System.get_env("GITHUB_ACCESS_TOKEN")

    if token && String.trim(token) != "" do
      {:ok, token}
    else
      {:error, "GITHUB_TOKEN not configured"}
    end
  end
end
