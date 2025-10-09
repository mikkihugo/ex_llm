defmodule Singularity.ParserEngine do
  @moduledoc """
  Parser Engine - Consolidated parsing and database streaming

  Provides a unified interface for parsing code files and streaming AST data
  directly into PostgreSQL.
  """

  require Logger

  alias Singularity.Repo
  alias Singularity.Schemas.CodeFile

  @nif_module :parsing_engine
  @default_codebase_id "default"
  @default_hash_algorithm :sha256
  @default_concurrency 8

  # Public API ----------------------------------------------------------------

  @doc """
  Parse a single file and persist the result to the database.
  """
  def parse_and_store_file(file_path, opts \\ []) do
    opts = normalize_options(opts)
    do_parse_and_store_file(file_path, opts)
  end

  @doc """
  Parse all files below a root path and persist them to the database.
  """
  def parse_and_store_tree(root_path, opts \\ []) do
    opts = normalize_options(opts)

    with {:ok, files} <- discover_files(root_path) do
      results =
        files
        |> Task.async_stream(&do_parse_and_store_file(&1, opts),
          max_concurrency: opts.max_concurrency,
          timeout: :infinity
        )
        |> Enum.map(&unwrap_stream_result/1)

      {:ok, results}
    else
      {:error, reason} = error ->
        Logger.error("Failed to parse/store #{root_path}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Parse a single file and return the normalized document.
  """
  def parse_file(file_path) do
    expanded_path = Path.expand(file_path)

    with :ok <- validate_regular_file(expanded_path),
         {:ok, content} <- File.read(expanded_path),
         {:ok, raw_document} <- call_nif(:parse_file, [expanded_path]),
         ast_map <- convert_ast_to_map(raw_document),
         language <- resolve_language(expanded_path, ast_map),
         document <- build_document(expanded_path, language, content, ast_map) do
      {:ok, document}
    else
      {:error, reason} = error ->
        Logger.error("Failed to parse file #{file_path}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Parse all files under a root path and return the documents.
  """
  def parse_tree(root_path) do
    with {:ok, files} <- discover_files(root_path) do
      {documents, errors} =
        files
        |> Task.async_stream(&parse_file/1,
          max_concurrency: @default_concurrency,
          timeout: :infinity
        )
        |> Enum.reduce({[], []}, fn
          {:ok, {:ok, document}}, {docs, errs} -> {[document | docs], errs}
          {:ok, {:error, reason}}, {docs, errs} -> {docs, [reason | errs]}
          {:exit, reason}, {docs, errs} -> {docs, [reason | errs]}
        end)

      Enum.each(errors, fn reason ->
        Logger.warning("ParserEngine.parse_tree skipped file: #{inspect(reason)}")
      end)

      {:ok, Enum.reverse(documents)}
    else
      {:error, reason} = error ->
        Logger.error("Failed to parse tree #{root_path}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Parse a list of files (best-effort).
  """
  def parse_files(file_paths) when is_list(file_paths) do
    file_paths
    |> Task.async_stream(&parse_file/1,
      max_concurrency: @default_concurrency,
      timeout: :infinity
    )
    |> Enum.map(&unwrap_stream_result/1)
  end

  @doc """
  Parse files below a root path filtered by language.
  """
  def parse_tree_by_language(root_path, language_filter) do
    with {:ok, files} <- discover_files(root_path) do
      files
      |> Enum.filter(fn path ->
        case detect_language(path) do
          {:ok, language} -> language == language_filter
          _ -> false
        end
      end)
      |> parse_files()
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Extract function symbols from a file.
  """
  def extract_functions(file_path) do
    with {:ok, document} <- parse_file(file_path) do
      {:ok, document.functions}
    end
  end

  @doc """
  Extract class symbols from a file.
  """
  def extract_classes(file_path) do
    with {:ok, document} <- parse_file(file_path) do
      {:ok, document.classes}
    end
  end

  @doc """
  Extract import symbols from a file.
  """
  def extract_imports(file_path) do
    with {:ok, document} <- parse_file(file_path) do
      {:ok, document.imports}
    end
  end

  @doc """
  Extract export symbols from a file.
  """
  def extract_exports(file_path) do
    with {:ok, document} <- parse_file(file_path) do
      {:ok, document.exports}
    end
  end

  @doc """
  Extract all symbols from a file.
  """
  def extract_symbols(file_path) do
    with {:ok, document} <- parse_file(file_path) do
      {:ok, document.symbols}
    end
  end

  @doc """
  Retrieve the normalized AST for a file.
  """
  def extract_ast(file_path) do
    with {:ok, document} <- parse_file(file_path) do
      {:ok, document.ast}
    end
  end

  @doc """
  Find dependencies for a file using the parsed AST.
  """
  def find_dependencies(file_path) do
    with {:ok, document} <- parse_file(file_path) do
      dependencies =
        document.ast
        |> Map.get("dependencies", [])
        |> listify()

      {:ok, dependencies}
    end
  end

  @doc """
  Extract functions from multiple files concurrently.
  """
  def extract_all_functions(file_paths) when is_list(file_paths) do
    file_paths
    |> Task.async_stream(
      fn path ->
        with {:ok, document} <- parse_file(path) do
          {:ok, document.functions}
        end
      end,
      max_concurrency: @default_concurrency,
      timeout: :infinity
    )
    |> Enum.map(&unwrap_stream_result/1)
  end

  @doc """
  Extract classes from multiple files concurrently.
  """
  def extract_all_classes(file_paths) when is_list(file_paths) do
    file_paths
    |> Task.async_stream(
      fn path ->
        with {:ok, document} <- parse_file(path) do
          {:ok, document.classes}
        end
      end,
      max_concurrency: @default_concurrency,
      timeout: :infinity
    )
    |> Enum.map(&unwrap_stream_result/1)
  end

  @doc """
  Detect the language of a file based on extension.
  """
  def detect_language(file_path) do
    extension = Path.extname(file_path) |> String.downcase()

    language =
      case extension do
        ".ex" -> "elixir"
        ".exs" -> "elixir"
        ".gleam" -> "gleam"
        ".rs" -> "rust"
        ".js" -> "javascript"
        ".ts" -> "typescript"
        ".tsx" -> "typescript"
        ".jsx" -> "javascript"
        ".py" -> "python"
        ".go" -> "go"
        ".java" -> "java"
        ".c" -> "c"
        ".cpp" -> "cpp"
        ".h" -> "c"
        ".hpp" -> "cpp"
        ".cs" -> "csharp"
        ".php" -> "php"
        ".rb" -> "ruby"
        ".swift" -> "swift"
        ".kt" -> "kotlin"
        ".scala" -> "scala"
        ".clj" -> "clojure"
        ".hs" -> "haskell"
        ".ml" -> "ocaml"
        ".fs" -> "fsharp"
        ".dart" -> "dart"
        ".lua" -> "lua"
        ".r" -> "r"
        ".m" -> "matlab"
        ".jl" -> "julia"
        ".sh" -> "bash"
        ".zsh" -> "zsh"
        ".fish" -> "fish"
        ".ps1" -> "powershell"
        ".bat" -> "batch"
        ".cmd" -> "batch"
        ".sql" -> "sql"
        ".html" -> "html"
        ".css" -> "css"
        ".scss" -> "scss"
        ".sass" -> "sass"
        ".less" -> "less"
        ".xml" -> "xml"
        ".yaml" -> "yaml"
        ".yml" -> "yaml"
        ".json" -> "json"
        ".toml" -> "toml"
        ".ini" -> "ini"
        ".cfg" -> "config"
        ".conf" -> "config"
        ".env" -> "env"
        ".dockerfile" -> "dockerfile"
        ".md" -> "markdown"
        ".rst" -> "restructuredtext"
        ".tex" -> "latex"
        ".txt" -> "text"
        _ -> "unknown"
      end

    {:ok, language}
  end

  # Private helpers -----------------------------------------------------------

  defp do_parse_and_store_file(file_path, opts) do
    with {:ok, document} <- parse_file(file_path),
         {:ok, record} <- store_document(opts.codebase_id, document, opts.hash_algorithm) do
      {:ok, %{document: document, record: record}}
    else
      {:error, reason} = error ->
        Logger.error("Failed to parse/store #{file_path}: #{inspect(reason)}")
        error
    end
  end

  defp store_document(codebase_id, document, hash_algorithm) do
    attrs = %{
      codebase_id: codebase_id,
      file_path: document.path,
      language: document.language,
      content: document.content,
      file_size: byte_size(document.content),
      line_count: line_count(document.content),
      hash: compute_hash(document.content, hash_algorithm),
      ast_json: document.ast,
      functions: document.functions,
      classes: document.classes,
      imports: document.imports,
      exports: document.exports,
      symbols: document.symbols,
      metadata: document.metadata,
      parsed_at: DateTime.utc_now()
    }

    changeset = CodeFile.changeset(%CodeFile{}, attrs)

    case Repo.insert(
           changeset,
           on_conflict: {:replace_all_except, [:id, :inserted_at]},
           conflict_target: [:codebase_id, :file_path]
         ) do
      {:ok, record} -> {:ok, record}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp build_document(expanded_path, language, content, ast_map) do
    descriptor =
      ast_map
      |> Map.get("descriptor", %{})
      |> ensure_map()

    path =
      descriptor
      |> Map.get("path")
      |> case do
        path when is_binary(path) and path != "" -> Path.expand(path)
        _ -> expanded_path
      end

    %{
      path: path,
      language: language,
      content: content,
      ast: ast_map,
      functions: extract_functions_from_ast(ast_map),
      classes: extract_classes_from_ast(ast_map),
      imports: extract_imports_from_ast(ast_map),
      exports: extract_exports_from_ast(ast_map),
      symbols: extract_symbols_from_ast(ast_map),
      metadata: ast_map |> Map.get("metadata", %{}) |> ensure_map(),
      stats: ast_map |> Map.get("stats", %{}) |> ensure_map()
    }
  end

  defp extract_functions_from_ast(ast_map) do
    ast_map
    |> Map.get("symbols", [])
    |> listify()
    |> Enum.filter(&(Map.get(&1, "kind") == "function"))
    |> Enum.map(&normalize_symbol/1)
  end

  defp extract_classes_from_ast(ast_map) do
    ast_map
    |> Map.get("classes", [])
    |> listify()
    |> Enum.map(fn class ->
      %{
        name: Map.get(class, "name"),
        bases: Map.get(class, "bases", []),
        decorators: Map.get(class, "decorators", []),
        docstring: Map.get(class, "docstring"),
        range: Map.get(class, "range")
      }
    end)
  end

  defp extract_imports_from_ast(ast_map) do
    ast_map
    |> Map.get("symbols", [])
    |> listify()
    |> Enum.filter(&(Map.get(&1, "kind") == "import"))
    |> Enum.map(&normalize_symbol/1)
  end

  defp extract_exports_from_ast(ast_map) do
    ast_map
    |> Map.get("symbols", [])
    |> listify()
    |> Enum.filter(&(Map.get(&1, "kind") == "export"))
    |> Enum.map(&normalize_symbol/1)
  end

  defp extract_symbols_from_ast(ast_map) do
    ast_map
    |> Map.get("symbols", [])
    |> listify()
    |> Enum.map(&normalize_symbol/1)
  end

  defp normalize_symbol(symbol) do
    %{
      name: Map.get(symbol, "name"),
      kind: Map.get(symbol, "kind"),
      range: Map.get(symbol, "range"),
      signature: Map.get(symbol, "signature")
    }
  end

  defp discover_files(path) do
    expanded_path = Path.expand(path)

    cond do
      File.regular?(expanded_path) ->
        {:ok, [expanded_path]}

      File.dir?(expanded_path) ->
        files =
          expanded_path
          |> Path.join("**/*")
          |> Path.wildcard(match_dot: true)
          |> Enum.filter(&File.regular?/1)

        {:ok, files}

      File.exists?(expanded_path) ->
        {:error, :unsupported_file_type}

      true ->
        {:error, :enoent}
    end
  end

  defp validate_regular_file(path) do
    cond do
      File.regular?(path) -> :ok
      File.dir?(path) -> {:error, :is_directory}
      File.exists?(path) -> {:error, :unsupported_file_type}
      true -> {:error, :enoent}
    end
  end

  defp convert_ast_to_map(ast_document) when is_map(ast_document) do
    deep_stringify_keys(ast_document)
  end

  defp deep_stringify_keys(%{} = map) do
    map
    |> Enum.map(fn {key, value} -> {stringify_key(key), deep_stringify_keys(value)} end)
    |> Enum.into(%{})
  end

  defp deep_stringify_keys(list) when is_list(list), do: Enum.map(list, &deep_stringify_keys/1)
  defp deep_stringify_keys(value), do: value

  defp stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  defp stringify_key(key) when is_binary(key), do: key
  defp stringify_key(key), do: to_string(key)

  defp resolve_language(path, ast_map) do
    descriptor_language =
      ast_map
      |> Map.get("descriptor", %{})
      |> ensure_map()
      |> Map.get("language")

    cond do
      is_binary(descriptor_language) and descriptor_language != "" and
          descriptor_language != "unknown" ->
        descriptor_language

      true ->
        case detect_language(path) do
          {:ok, language} -> language
          {:error, _} -> "unknown"
        end
    end
  end

  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(_), do: %{}

  defp listify(nil), do: []
  defp listify(list) when is_list(list), do: list
  defp listify(value), do: [value]

  defp compute_hash(content, :sha256), do: digest(:sha256, content)
  defp compute_hash(content, :sha1), do: digest(:sha, content)
  defp compute_hash(content, :md5), do: digest(:md5, content)
  defp compute_hash(content, _), do: compute_hash(content, :sha256)

  defp digest(type, content) do
    :crypto.hash(type, content) |> Base.encode16(case: :lower)
  end

  defp line_count(content) do
    content
    |> String.split("\n", trim: false)
    |> length()
  end

  defp call_nif(function, args) do
    apply(@nif_module, function, args)
  rescue
    error -> {:error, {:nif_error, error}}
  end

  defp unwrap_stream_result({:ok, result}), do: result
  defp unwrap_stream_result({:exit, reason}), do: {:error, reason}

  defp normalize_options(opts) when is_list(opts) do
    opts
    |> Enum.into(%{})
    |> normalize_options()
  end

  defp normalize_options(%{} = opts) do
    %{
      codebase_id: Map.get(opts, :codebase_id, @default_codebase_id),
      hash_algorithm: Map.get(opts, :hash_algorithm, @default_hash_algorithm),
      max_concurrency: Map.get(opts, :max_concurrency, @default_concurrency)
    }
  end
end
