defmodule Singularity.Tools.Basic do
  @moduledoc """
  Registers a lightweight set of helper tools (directory listing, code search, file write)
  so providers have a LangChain-style baseline toolkit.

  Naming conventions:
  • Use short snake_case names with a helpful prefix when it clarifies scope (e.g. `fs_list_directory`, `net_http_fetch`, `gh_graphql_query`).
  • Keep names snake_case, unique, and terse—mirroring Gemini CLI’s built-ins makes it easier to reason about them.
  • Descriptions should tell the model *when* to use the tool and note any safety steps (e.g. “call read_file first, overwrite requires explicit opt-in”).
  """

  alias Singularity.Tools.{Registry, Tool}

  @providers [:claude_cli, :claude_http, :gemini_cli, :gemini_http]
  @workspace_root File.cwd!()
  @registration_key {:singularity, :tools, :basic_loaded}
  @max_matches 20
  @max_files 500
  @text_extensions ~w(
    ex exs eex heex leex
    md txt json jsonl yaml yml toml
    js jsx ts tsx css scss html erb
    py rb go rs java kt swift c cpp h hpp cs lua sh zsh bash fish
  )

  @doc """
  Ensure basic tools are registered once per node.
  """
  def ensure_registered do
    case :persistent_term.get(@registration_key, false) do
      true ->
        :ok

      _ ->
        Enum.each(@providers, &register_tools_for/1)
        :persistent_term.put(@registration_key, true)
        :ok
    end
  end

  defp register_tools_for(provider) do
    Registry.register_tools(provider, [
      fs_list_directory_tool(),
      fs_search_content_tool(),
      fs_write_file_tool(),
      net_http_fetch_tool(),
      gh_graphql_tool()
    ])
  end

  defp fs_list_directory_tool do
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
      function: &__MODULE__.fs_list_directory/2
    })
  end

  defp fs_search_content_tool do
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
      function: &__MODULE__.fs_search_content/2
    })
  end

  defp fs_write_file_tool do
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
      function: &__MODULE__.fs_write_file/2
    })
  end

  defp net_http_fetch_tool do
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
      function: &__MODULE__.net_http_fetch/2
    })
  end

  defp gh_graphql_tool do
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
      function: &__MODULE__.gh_graphql_query/2
    })
  end

  # Tool implementations ----------------------------------------------------

  def fs_list_directory(args, _ctx) do
    include_hidden = truthy?(Map.get(args, "include_hidden"))

    with {:ok, target} <- resolve_path(Map.get(args, "path", ".")),
         {:ok, entries} <- File.ls(target) do
      detailed =
        entries
        |> Enum.reject(fn name -> hidden?(name) and not include_hidden end)
        |> Enum.map(&build_entry(Path.join(target, &1)))
        |> Enum.sort_by(& &1.name)

      {:ok, %{path: relative_path(target), entries: detailed}}
    else
      {:error, reason} -> {:error, message(reason)}
    end
  end

  def fs_search_content(%{"pattern" => pattern} = args, _ctx) do
    cond do
      not is_binary(pattern) ->
        {:error, "pattern must be a string"}

      byte_size(String.trim(pattern)) == 0 ->
        {:error, "pattern must not be blank"}

      byte_size(pattern) > 256 ->
        {:error, "pattern is too long"}

      true ->
        do_search(pattern, args)
    end
  end

  def fs_search_content(_args, _ctx), do: {:error, "pattern must be a string"}

  defp do_search(pattern, args) do
    base_path = Map.get(args, "path", ".")
    regex? = truthy?(Map.get(args, "regex"))
    case_sensitive? = truthy?(Map.get(args, "case_sensitive"))

    with {:ok, root} <- resolve_path(base_path),
         {:ok, matcher} <- build_matcher(pattern, regex?, case_sensitive?) do
      files = collect_files(root)

      matches =
        files
        |> Enum.reduce_while([], fn file, acc ->
          case scan_file(file, matcher) do
            [] ->
              {:cont, acc}

            file_matches ->
              updated = [%{file: relative_path(file), matches: file_matches} | acc]

              if length(updated) >= @max_matches do
                {:halt, updated}
              else
                {:cont, updated}
              end
          end
        end)
        |> Enum.take(@max_matches)
        |> Enum.reverse()

      {:ok, %{pattern: pattern, results: matches}}
    else
      {:error, reason} -> {:error, message(reason)}
    end
  end

  def fs_write_file(%{"path" => path, "content" => content} = args, _ctx)
      when is_binary(path) and is_binary(content) do
    mode = normalize_mode(Map.get(args, "mode"))

    with {:ok, dest} <- resolve_path(path),
         :ok <- File.mkdir_p(Path.dirname(dest)) do
      case mode do
        :append -> File.write(dest, content, [:append])
        :overwrite -> File.write(dest, content)
      end
      |> case do
        :ok ->
          info = %{
            path: relative_path(dest),
            bytes: byte_size(content),
            mode: Atom.to_string(mode)
          }

          {:ok, info}

        {:error, reason} ->
          {:error, message(reason)}
      end
    else
      {:error, reason} -> {:error, message(reason)}
    end
  end

  def fs_write_file(_args, _ctx), do: {:error, "path and content are required"}

  def net_http_fetch(%{"url" => url} = args, _ctx) when is_binary(url) do
    headers =
      args
      |> Map.get("headers", %{})
      |> normalize_headers()

    with {:ok, uri} <- validate_http_url(url),
         {:ok, response} <-
           Req.request(
             method: :get,
             url: URI.to_string(uri),
             headers: headers,
             receive_timeout: 10_000
           ) do
      %Req.Response{status: status, headers: resp_headers, body: body} = response

      {:ok,
       %{
         url: URI.to_string(uri),
         status: status,
         headers: normalize_response_headers(resp_headers),
         body: body
       }}
    else
      {:error, %Req.TransportError{reason: reason}} -> {:error, message(reason)}
      {:error, reason} -> {:error, message(reason)}
    end
  end

  def net_http_fetch(_args, _ctx), do: {:error, "url must be a string"}

  def gh_graphql_query(%{"query" => query} = args, _ctx) when is_binary(query) do
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

        headers =
          [
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
            {:error, "GitHub GraphQL returned status #{status}: #{inspect(body)}"}

          {:error, %Req.TransportError{reason: reason}} ->
            {:error, message(reason)}

          {:error, reason} ->
            {:error, message(reason)}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  def gh_graphql_query(_args, _ctx), do: {:error, "query must be a string"}

  # Helpers -----------------------------------------------------------------

  defp resolve_path(path) when is_binary(path) do
    expanded = Path.expand(path, @workspace_root)

    if String.starts_with?(expanded, @workspace_root) do
      {:ok, expanded}
    else
      {:error, "path outside repository root is not allowed"}
    end
  end

  defp resolve_path(_), do: {:error, "path must be a string"}

  defp build_entry(full_path) do
    stat = File.stat(full_path)

    type =
      case stat do
        {:ok, %{type: :directory}} -> "directory"
        {:ok, %{type: :regular}} -> "file"
        {:ok, %{type: other}} -> to_string(other)
        _ -> "unknown"
      end

    size =
      case stat do
        {:ok, %{size: bytes}} -> bytes
        _ -> nil
      end

    %{
      name: Path.basename(full_path),
      type: type,
      size: size,
      path: relative_path(full_path)
    }
  end

  defp collect_files(root) do
    cond do
      File.regular?(root) ->
        if text_extension?(root), do: [root], else: []

      true ->
        root
        |> Path.join("**/*")
        |> Path.wildcard(match_dot: false)
        |> Enum.sort()
        |> Stream.filter(&File.regular?/1)
        |> Stream.filter(&text_extension?/1)
        |> Enum.take(@max_files)
    end
  end

  defp text_extension?(path) do
    case Path.extname(path) do
      "." <> ext -> String.downcase(ext) in @text_extensions
      _ -> true
    end
  end

  defp build_matcher(pattern, true, case_sensitive?) do
    opts = if case_sensitive?, do: "", else: "i"

    case Regex.compile(pattern, opts) do
      {:ok, regex} -> {:ok, {:regex, regex}}
      {:error, {reason, _}} -> {:error, "invalid regex: #{reason}"}
    end
  end

  defp build_matcher(pattern, false, case_sensitive?) do
    text = if case_sensitive?, do: pattern, else: String.downcase(pattern)
    {:ok, {:text, text, case_sensitive?}}
  end

  defp scan_file(path, {:regex, regex}) do
    stream_file(path, fn line -> Regex.match?(regex, line) end)
  end

  defp scan_file(path, {:text, text, true}) do
    stream_file(path, fn line -> String.contains?(line, text) end)
  end

  defp scan_file(path, {:text, text, false}) do
    stream_file(path, fn line -> String.contains?(String.downcase(line), text) end)
  end

  defp stream_file(path, matcher_fun) do
    path
    |> File.stream!(:line)
    |> Stream.with_index(1)
    |> Stream.filter(fn {line, _} -> matcher_fun.(line) end)
    |> Enum.map(fn {line, number} -> %{line: number, text: String.trim_trailing(line)} end)
    |> Enum.take(@max_matches)
  rescue
    _ -> []
  end

  defp hidden?(name), do: String.starts_with?(name, ".")

  defp relative_path(path) do
    Path.relative_to(path, @workspace_root)
  rescue
    _ -> path
  end

  defp normalize_mode(mode) do
    case mode do
      "overwrite" -> :overwrite
      :overwrite -> :overwrite
      "append" -> :append
      :append -> :append
      _ -> :append
    end
  end

  defp truthy?(value) when is_binary(value),
    do: String.downcase(value) in ["true", "1", "yes", "on"]

  defp truthy?(value), do: value in [true, 1]

  defp normalize_headers(list) when is_list(list) do
    list
    |> Enum.reduce([], fn
      %{"name" => name, "value" => value}, acc when is_binary(name) ->
        [{name, to_string(value)} | acc]

      %{name: name, value: value}, acc when is_binary(name) or is_atom(name) ->
        key = if is_atom(name), do: Atom.to_string(name), else: name
        [{key, to_string(value)} | acc]

      _other, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  defp normalize_headers(map) when is_map(map) do
    map
    |> Enum.reduce([], fn
      {key, value}, acc when is_binary(key) and (is_binary(value) or is_number(value)) ->
        [{key, to_string(value)} | acc]

      {key, value}, acc when is_atom(key) and (is_binary(value) or is_number(value)) ->
        [{Atom.to_string(key), to_string(value)} | acc]

      _, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  defp normalize_headers(_), do: []

  defp validate_http_url(url) do
    case URI.parse(url) do
      %URI{scheme: scheme} = uri when scheme in ["http", "https"] -> {:ok, uri}
      _ -> {:error, "url must start with http:// or https://"}
    end
  end

  defp normalize_response_headers(headers) when is_list(headers) do
    Enum.map(headers, fn
      {k, v} -> %{name: k, value: v}
      other -> %{value: to_string(other)}
    end)
  end

  defp normalize_response_headers(_), do: []

  defp fetch_github_token do
    token =
      System.get_env("GITHUB_TOKEN") ||
        System.get_env("GH_TOKEN") ||
        System.get_env("GITHUB_ACCESS_TOKEN")

    if token && String.trim(token) != "" do
      {:ok, token}
    else
      {:error, "GITHUB_TOKEN is not configured"}
    end
  end

  defp message(%File.Error{reason: reason}), do: message(reason)
  defp message(reason) when is_atom(reason), do: :file.format_error(reason) |> to_string()
  defp message(reason) when is_binary(reason), do: reason
  defp message(other), do: inspect(other)
end
