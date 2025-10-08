defmodule Singularity.ParserEngine do
  @moduledoc """
  High-level interface for the native parser-engine.

  Parses source files or directory trees via the Rust NIF and normalizes the
  returned JSON into Elixir-friendly maps so that downstream code can work with
  consistent keys (`:descriptor`, `:symbols`, `:functions`, etc.).
  """

  alias Singularity.ParserEngine.Native

  @doc """
  Parse a single file and return a normalized document map.
  """
  def parse_file(path) when is_binary(path) do
    with {:ok, json} <- call_native(:parse_file, path),
         {:ok, decoded} <- decode_json(json) do
      {:ok, normalize_document(decoded)}
    else
      {:error, _} = error -> error
      other -> {:error, other}
    end
  end

  @doc """
  Parse a directory tree and return normalized documents for each file.
  """
  def parse_tree(root) when is_binary(root) do
    with {:ok, json} <- call_native(:parse_tree, root),
         {:ok, decoded} <- decode_json(json) do
      documents = Enum.map(decoded, &normalize_document/1)
      {:ok, documents}
    else
      {:error, _} = error -> error
      other -> {:error, other}
    end
  end

  @doc """
  Extract the normalized AST payload (if the capsule emitted one).
  """
  def extract_ast(path) do
    case parse_file(path) do
      {:ok, %{ast: ast}} -> {:ok, ast}
      error -> error
    end
  end

  @doc """
  Extract function-like symbols from a single file.
  """
  def extract_functions(path) do
    case parse_file(path) do
      {:ok, %{functions: functions}} -> {:ok, functions}
      error -> error
    end
  end

  @doc """
  Extract parsed classes from a single file.
  """
  def extract_classes(path) do
    case parse_file(path) do
      {:ok, %{classes: classes}} -> {:ok, classes}
      error -> error
    end
  end

  @doc """
  Extract parsed imports from a single file.
  """
  def extract_imports(path) do
    case parse_file(path) do
      {:ok, %{imports: imports}} -> {:ok, imports}
      error -> error
    end
  end

  @doc """
  Extract parsed exports from a single file.
  """
  def extract_exports(path) do
    case parse_file(path) do
      {:ok, %{exports: exports}} -> {:ok, exports}
      error -> error
    end
  end

  @doc """
  Detect language for a file using capsule metadata.
  """
  def detect_language(path) do
    case parse_file(path) do
      {:ok, %{language: language}} -> {:ok, language}
      error -> error
    end
  end

  @doc """
  Extract dependency-like entries (usually imports) from a file.
  """
  def find_dependencies(path) do
    case parse_file(path) do
      {:ok, %{imports: imports}} -> {:ok, imports}
      error -> error
    end
  end

  @doc """
  Parse many files concurrently, short-circuiting on the first error.
  """
  def parse_files(paths) when is_list(paths) do
    paths
    |> Task.async_stream(&parse_file/1, max_concurrency: 10, timeout: :infinity)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, doc}}, {:ok, acc} -> {:cont, {:ok, [doc | acc]}}
      {:ok, {:error, reason}}, _ -> {:halt, {:error, reason}}
      {:exit, reason}, _ -> {:halt, {:error, reason}}
      {:error, reason}, _ -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, docs} -> {:ok, Enum.reverse(docs)}
      error -> error
    end
  end

  @doc """
  Filter a parsed tree by language.
  """
  def parse_tree_by_language(root, language) when is_binary(language) do
    case parse_tree(root) do
      {:ok, documents} -> {:ok, Enum.filter(documents, &(document_language(&1) == language))}
      error -> error
    end
  end

  @doc """
  Gather all functions across every file in a directory tree.
  """
  def extract_all_functions(root) do
    case parse_tree(root) do
      {:ok, documents} ->
        functions =
          documents
          |> Enum.flat_map(fn doc ->
            Enum.map(doc.functions || [], &Map.put(&1, :file, doc.path))
          end)

        {:ok, functions}

      error -> error
    end
  end

  @doc """
  Gather all classes across every file in a directory tree.
  """
  def extract_all_classes(root) do
    case parse_tree(root) do
      {:ok, documents} ->
        classes =
          documents
          |> Enum.flat_map(fn doc ->
            Enum.map(doc.classes || [], &Map.put(&1, :file, doc.path))
          end)

        {:ok, classes}

      error -> error
    end
  end

  @doc """
  Filter a document's symbols by a given kind (e.g. "function").
  """
  def symbols_by_kind(%{symbols: symbols}, kind) when is_binary(kind) do
    Enum.filter(symbols, fn symbol -> match_kind?(symbol[:kind], kind) end)
  end

  def symbols_by_kind(_, _), do: []

  # --------------------------------------------------------------------------
  # Normalization helpers
  # --------------------------------------------------------------------------

  defp call_native(fun, arg) do
    apply(Native, fun, [arg])
  rescue
    error -> {:error, error}
  catch
    :exit, reason -> {:error, reason}
  end

  defp decode_json(json) when is_binary(json), do: Jason.decode(json)
  defp decode_json(other), do: {:error, {:invalid_payload, other}}

  defp normalize_document(%{} = raw) do
    descriptor = normalize_descriptor(Map.get(raw, "descriptor", %{}))
    metadata = normalize_metadata(Map.get(raw, "metadata", %{}))
    symbols = normalize_symbols(Map.get(raw, "symbols", []))
    classes = normalize_classes(Map.get(raw, "classes", []))
    enums = normalize_enums(Map.get(raw, "enums", []))
    docstrings = normalize_docstrings(Map.get(raw, "docstrings", []))
    stats = normalize_stats(Map.get(raw, "stats", %{}))
    diagnostics = List.wrap(Map.get(raw, "diagnostics", []))
    imports = normalize_generic_list(Map.get(raw, "imports", []))
    exports = normalize_generic_list(Map.get(raw, "exports", []))
    ast = Map.get(raw, "ast")

    functions =
      raw
      |> Map.get("functions")
      |> normalize_functions()
      |> default_functions(symbols)

    %{
      descriptor: descriptor,
      metadata: metadata,
      symbols: symbols,
      classes: classes,
      enums: enums,
      docstrings: docstrings,
      stats: stats,
      diagnostics: diagnostics,
      imports: imports,
      exports: exports,
      functions: functions,
      ast: ast,
      language: Map.get(raw, "language") || descriptor[:language],
      path: descriptor[:path]
    }
  end

  defp normalize_document(other), do: other

  defp normalize_descriptor(map) do
    map
    |> take_known(%{path: nil, language: nil, kind: nil, size_bytes: nil, last_modified: nil})
    |> update_in([:path], &normalize_path/1)
  end

  defp normalize_metadata(map) do
    take_known(map, %{parser_version: nil, analyzed_at: nil, additional: %{}})
  end

  defp normalize_symbols(list) when is_list(list) do
    Enum.map(list, fn symbol ->
      symbol
      |> take_known(%{name: nil, kind: nil, signature: nil, range: nil, namespace: nil, visibility: nil, language: nil})
      |> update_in([:range], &normalize_range/1)
    end)
  end

  defp normalize_symbols(_), do: []

  defp normalize_classes(list) when is_list(list) do
    Enum.map(list, fn class ->
      class
      |> take_known(%{name: nil, bases: [], decorators: [], docstring: nil, range: nil})
      |> update_in([:decorators], &normalize_decorators/1)
      |> update_in([:range], &normalize_range/1)
    end)
  end

  defp normalize_classes(_), do: []

  defp normalize_enums(list) when is_list(list) do
    Enum.map(list, fn enum ->
      enum
      |> take_known(%{name: nil, variants: [], decorators: [], docstring: nil, range: nil})
      |> update_in([:decorators], &normalize_decorators/1)
      |> update_in([:variants], &normalize_enum_variants/1)
      |> update_in([:range], &normalize_range/1)
    end)
  end

  defp normalize_enums(_), do: []

  defp normalize_docstrings(list) when is_list(list) do
    Enum.map(list, fn docstring ->
      docstring
      |> take_known(%{owner: nil, kind: nil, value: nil, range: nil})
      |> update_in([:range], &normalize_range/1)
    end)
  end

  defp normalize_docstrings(_), do: []

  defp normalize_stats(map) do
    take_known(map, %{byte_length: 0, total_nodes: 0, total_tokens: 0, duration_ms: 0})
  end

  defp normalize_enum_variants(list) when is_list(list) do
    Enum.map(list, fn variant ->
      variant
      |> take_known(%{name: nil, value: nil, range: nil})
      |> update_in([:range], &normalize_range/1)
    end)
  end

  defp normalize_enum_variants(_), do: []

  defp normalize_decorators(list) when is_list(list) do
    Enum.map(list, &take_known(&1, %{name: nil, arguments: []}))
  end

  defp normalize_decorators(_), do: []

  defp normalize_functions(nil), do: []

  defp normalize_functions(list) when is_list(list) do
    Enum.map(list, fn function ->
      function
      |> take_known(%{name: nil, kind: nil, signature: nil, range: nil, namespace: nil, visibility: nil, language: nil})
      |> update_in([:range], &normalize_range/1)
    end)
  end

  defp normalize_functions(_), do: []

  defp normalize_generic_list(list) when is_list(list), do: list
  defp normalize_generic_list(_), do: []

  defp take_known(source, template) do
    Enum.reduce(template, %{}, fn {key, default}, acc ->
      value = Map.get(source, key) || Map.get(source, Atom.to_string(key)) || default
      Map.put(acc, key, value)
    end)
  end

  defp normalize_range([start_line, end_line]) when is_integer(start_line) and is_integer(end_line),
    do: {start_line, end_line}

  defp normalize_range(_), do: nil

  defp normalize_path(path) when is_binary(path), do: path
  defp normalize_path(_), do: nil

  defp default_functions([], symbols), do: derive_functions(symbols)
  defp default_functions(functions, _symbols), do: functions

  defp derive_functions(symbols) do
    symbols
    |> Enum.filter(fn symbol -> match_kind?(symbol[:kind], "function") end)
    |> Enum.map(&Map.take(&1, [:name, :kind, :signature, :range, :namespace, :visibility, :language]))
  end

  defp match_kind?(kind, target) when is_binary(kind), do: String.downcase(kind) == String.downcase(target)
  defp match_kind?(kind, target) when is_atom(kind), do: match_kind?(Atom.to_string(kind), target)
  defp match_kind?(_, _), do: false

  defp document_language(%{language: language}), do: language
  defp document_language(_), do: nil
