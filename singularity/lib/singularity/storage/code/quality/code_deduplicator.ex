defmodule Singularity.CodeDeduplicator do
  @moduledoc """
  Prevent duplicate code generation across 750M+ lines

  Uses semantic fingerprinting and vector similarity to detect:
  - Exact duplicates (same code)
  - Semantic duplicates (same logic, different syntax)
  - Near-duplicates (>90% similar)
  - Structural clones (same pattern, different data)

  ## Strategies

  1. **Hash-based** - Fast exact match (MD5/SHA256)
  2. **AST-based** - Structural similarity (ignore whitespace/comments)
  3. **Vector-based** - Semantic similarity (embeddings)
  4. **Pattern-based** - Extract core logic pattern

  ## Usage

      # Before generating code, check for duplicates
      {:ok, similar} = CodeDeduplicator.find_similar(
        proposed_code,
        language: "elixir",
        threshold: 0.9  # 90% similarity = likely duplicate
      )

      case similar do
        [] ->
          # No duplicates, safe to generate
          generate_code()

        [%{similarity: sim, path: path} | _] ->
          # Found duplicate! Reuse existing code
          {:error, {:duplicate_found, path, sim}}
      end

      # Index new code after generation
      CodeDeduplicator.index_code(code, metadata)
  """

  require Logger
  alias Singularity.{EmbeddingEngine, Repo, ParserEngine}

  @doc """
  Find similar code in the entire codebase (750M lines)

  Returns matches ranked by similarity.
  """
  @spec find_similar(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def find_similar(code, opts \\ []) do
    language = Keyword.get(opts, :language)
    # 90% = likely duplicate
    threshold = Keyword.get(opts, :threshold, 0.9)
    search_limit = Keyword.get(opts, :limit, 10)

    Logger.debug("Searching for code duplicates (threshold: #{threshold})")

    with {:ok, fingerprints} <- extract_fingerprints(code, language),
         {:ok, candidates} <- multi_level_search(fingerprints, language, search_limit),
         {:ok, ranked} <- rank_by_similarity(code, candidates, threshold) do
      duplicates = Enum.filter(ranked, fn m -> m.similarity >= threshold end)

      if duplicates != [] do
        Logger.warning("Found #{length(duplicates)} potential duplicates")
      end

      {:ok, ranked}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Index code with multiple fingerprints for fast duplicate detection
  """
  @spec index_code(String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  def index_code(code, metadata) do
    language = metadata[:language]

    with {:ok, fingerprints} <- extract_fingerprints(code, language),
         {:ok, code_id} <- store_fingerprints(code, fingerprints, metadata) do
      Logger.debug("Indexed code: #{code_id}")
      {:ok, code_id}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extract semantic keywords that prevent duplicate logic

  These are high-level concepts, not variable names:
  - "http_request" not "req"
  - "validate_email" not "validate"
  - "cache_with_ttl" not "cache"
  """
  @spec extract_semantic_keywords(String.t(), String.t()) :: [String.t()]
  def extract_semantic_keywords(code, language) do
    # Extract based on language
    case language do
      "elixir" -> extract_elixir_keywords(code)
      "rust" -> extract_rust_keywords(code)
      "go" -> extract_go_keywords(code)
      "typescript" -> extract_ts_keywords(code)
      "python" -> extract_python_keywords(code)
      "java" -> extract_java_keywords(code)
      _ -> extract_generic_keywords(code)
    end
    |> Enum.uniq()
    |> Enum.sort()
  end

  ## Private Functions

  defp extract_fingerprints(code, language) do
    # Multiple fingerprinting strategies
    exact_hash = hash_exact(code)
    normalized_hash = hash_normalized(code)
    ast_hash = hash_ast(code, language)
    pattern_sig = extract_pattern_signature(code, language)

    # Semantic embedding (most expensive, but catches renamed variables)
    {:ok, embedding} = EmbeddingEngine.embed(code, provider: :google)

    # Semantic keywords (compact representation)
    keywords = extract_semantic_keywords(code, language)

    {:ok,
     %{
       exact_hash: exact_hash,
       normalized_hash: normalized_hash,
       ast_hash: ast_hash,
       pattern_signature: pattern_sig,
       embedding: embedding,
       keywords: keywords,
       length: String.length(code),
       lines: length(String.split(code, "\n"))
     }}
  end

  defp hash_exact(code) do
    :crypto.hash(:sha256, code) |> Base.encode16(case: :lower)
  end

  defp hash_normalized(code) do
    # Remove whitespace, comments, normalize formatting
    normalized =
      code
      # Collapse whitespace
      |> String.replace(~r/\s+/, " ")
      # Remove comments
      |> String.replace(~r/#.*$/, "", m: :multiline)
      |> String.replace(~r/\/\/.*$/, "", m: :multiline)
      |> String.downcase()

    :crypto.hash(:sha256, normalized) |> Base.encode16(case: :lower)
  end

  defp hash_ast(code, language) do
    # Parse AST and hash structure for better duplicate detection
    case parse_code_to_ast(code, language) do
      {:ok, ast} ->
        ast_string = ast_to_string(ast)
        :crypto.hash(:sha256, ast_string) |> Base.encode16(case: :lower)

      {:error, _reason} ->
        # Fallback to normalized hash if AST parsing fails
        Logger.warning("AST parsing failed, using normalized hash", language: language)
        hash_normalized(code)
    end
  end

  defp parse_code_to_ast(code, language) do
    case language do
      "elixir" ->
        parse_elixir_ast(code)

      "rust" ->
        parse_rust_ast(code)

      "javascript" ->
        parse_javascript_ast(code)

      "python" ->
        parse_python_ast(code)

      _ ->
        # For unsupported languages, use normalized hash
        {:error, :unsupported_language}
    end
  end

  defp parse_elixir_ast(code) do
    # Use Code.string_to_quoted for Elixir AST parsing
    case Code.string_to_quoted(code) do
      {:ok, ast} -> {:ok, ast}
      {:error, _reason} -> {:error, :parse_failed}
    end
  end

  defp parse_rust_ast(code) do
    # For Rust, we would use a Rust parser via NIF or external service
    # For now, create a simple structure-based representation
    {:ok,
     %{
       type: "rust_file",
       functions: extract_rust_functions(code),
       structs: extract_rust_structs(code),
       impls: extract_rust_impls(code)
     }}
  end

  defp parse_javascript_ast(code) do
    # For JavaScript, we would use a JS parser
    # For now, create a simple structure-based representation
    {:ok,
     %{
       type: "javascript_file",
       functions: extract_js_functions(code),
       classes: extract_js_classes(code),
       variables: extract_js_variables(code)
     }}
  end

  defp parse_python_ast(code) do
    # For Python, we would use a Python parser
    # For now, create a simple structure-based representation
    {:ok,
     %{
       type: "python_file",
       functions: extract_python_functions(code),
       classes: extract_python_classes(code),
       imports: extract_python_imports(code)
     }}
  end

  defp ast_to_string(ast) when is_list(ast) do
    ast
    |> Enum.map(&ast_to_string/1)
    |> Enum.join("")
  end

  defp ast_to_string(ast) when is_tuple(ast) do
    ast
    |> Tuple.to_list()
    |> Enum.map(&ast_to_string/1)
    |> Enum.join("")
  end

  defp ast_to_string(ast) when is_atom(ast) do
    Atom.to_string(ast)
  end

  defp ast_to_string(ast) when is_binary(ast) do
    ast
  end

  defp ast_to_string(ast) when is_map(ast) do
    ast
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(fn key ->
      "#{key}:#{ast_to_string(Map.get(ast, key))}"
    end)
    |> Enum.join("|")
  end

  defp ast_to_string(ast) do
    inspect(ast)
  end

  # Helper functions for extracting language-specific structures
  defp extract_rust_functions(code) do
    # Extract Rust function signatures
    Regex.scan(~r/fn\s+(\w+)\s*\([^)]*\)\s*->\s*[^{]+/, code)
    |> Enum.map(fn [_, name] -> name end)
  end

  defp extract_rust_structs(code) do
    # Extract Rust struct definitions
    Regex.scan(~r/struct\s+(\w+)\s*\{[^}]*\}/, code)
    |> Enum.map(fn [_, name] -> name end)
  end

  defp extract_rust_impls(code) do
    # Extract Rust impl blocks
    Regex.scan(~r/impl\s+(\w+)\s*for\s+(\w+)/, code)
    |> Enum.map(fn [_, trait, struct] -> "#{trait} for #{struct}" end)
  end

  defp extract_js_functions(code) do
    # Extract JavaScript function names
    Regex.scan(~r/function\s+(\w+)\s*\(/, code)
    |> Enum.map(fn [_, name] -> name end)
  end

  defp extract_js_classes(code) do
    # Extract JavaScript class names
    Regex.scan(~r/class\s+(\w+)/, code)
    |> Enum.map(fn [_, name] -> name end)
  end

  defp extract_js_variables(code) do
    # Extract JavaScript variable declarations
    Regex.scan(~r/(?:let|const|var)\s+(\w+)/, code)
    |> Enum.map(fn [_, name] -> name end)
  end

  defp extract_python_functions(code) do
    # Extract Python function names
    Regex.scan(~r/def\s+(\w+)\s*\(/, code)
    |> Enum.map(fn [_, name] -> name end)
  end

  defp extract_python_classes(code) do
    # Extract Python class names
    Regex.scan(~r/class\s+(\w+)/, code)
    |> Enum.map(fn [_, name] -> name end)
  end

  defp extract_python_imports(code) do
    # Extract Python imports
    Regex.scan(~r/(?:from\s+(\w+)\s+)?import\s+(\w+)/, code)
    |> Enum.map(fn [_, module, name] ->
      if module != "", do: "#{module}.#{name}", else: name
    end)
  end

  defp extract_pattern_signature(code, language) do
    # Extract high-level pattern (e.g., "GenServer with state + get/put")
    # This is simplified - real implementation would analyze AST

    keywords = extract_semantic_keywords(code, language)

    # Combine top keywords into signature
    keywords
    |> Enum.take(5)
    |> Enum.join("_")
  end

  defp multi_level_search(fingerprints, language, limit) do
    # Level 1: Exact hash (instant)
    exact = search_by_exact_hash(fingerprints.exact_hash)

    if exact != [] do
      {:ok, exact}
    else
      # Level 2: Normalized hash (near-instant)
      normalized = search_by_normalized_hash(fingerprints.normalized_hash)

      if normalized != [] do
        {:ok, normalized}
      else
        # Level 3: Pattern signature (fast)
        pattern = search_by_pattern(fingerprints.pattern_signature, language)

        # Level 4: Vector similarity (slower but thorough)
        vector = search_by_embedding(fingerprints.embedding, language, limit)

        {:ok, pattern ++ vector}
      end
    end
  end

  defp search_by_exact_hash(hash) do
    query = "SELECT id, file_path, content FROM code_fingerprints WHERE exact_hash = $1 LIMIT 10"

    case Repo.query(query, [hash]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, path, content] ->
          %{id: id, path: path, content: content, similarity: 1.0, match_type: :exact}
        end)

      _ ->
        []
    end
  end

  defp search_by_normalized_hash(hash) do
    query =
      "SELECT id, file_path, content FROM code_fingerprints WHERE normalized_hash = $1 LIMIT 10"

    case Repo.query(query, [hash]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, path, content] ->
          %{id: id, path: path, content: content, similarity: 0.95, match_type: :normalized}
        end)

      _ ->
        []
    end
  end

  defp search_by_pattern(pattern, language) do
    query = """
    SELECT id, file_path, content
    FROM code_fingerprints
    WHERE pattern_signature = $1
    AND language = $2
    LIMIT 20
    """

    case Repo.query(query, [pattern, language]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, path, content] ->
          %{id: id, path: path, content: content, similarity: 0.85, match_type: :pattern}
        end)

      _ ->
        []
    end
  end

  defp search_by_embedding(embedding, language, limit) do
    query = """
    SELECT
      id,
      file_path,
      content,
      1 - (embedding <=> $1::vector) AS similarity
    FROM code_fingerprints
    WHERE language = $2
    ORDER BY embedding <=> $1::vector
    LIMIT $3
    """

    case Repo.query(query, [embedding, language, limit]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, path, content, sim] ->
          %{id: id, path: path, content: content, similarity: sim, match_type: :semantic}
        end)

      _ ->
        []
    end
  end

  defp rank_by_similarity(_code, candidates, _threshold) do
    # Candidates already have similarity scores
    ranked = Enum.sort_by(candidates, & &1.similarity, :desc)
    {:ok, ranked}
  end

  defp store_fingerprints(code, fingerprints, metadata) do
    code_id = generate_code_id(code, metadata)

    query = """
    INSERT INTO code_fingerprints (
      id, file_path, language, content,
      exact_hash, normalized_hash, ast_hash, pattern_signature,
      embedding, keywords, length, lines,
      created_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW())
    ON CONFLICT (id) DO UPDATE SET
      exact_hash = $5,
      normalized_hash = $6,
      embedding = $9,
      keywords = $10,
      updated_at = NOW()
    """

    params = [
      code_id,
      metadata[:path] || "generated",
      metadata[:language],
      code,
      fingerprints.exact_hash,
      fingerprints.normalized_hash,
      fingerprints.ast_hash,
      fingerprints.pattern_signature,
      fingerprints.embedding,
      fingerprints.keywords,
      fingerprints.length,
      fingerprints.lines
    ]

    case Repo.query(query, params) do
      {:ok, _} -> {:ok, code_id}
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_code_id(code, metadata) do
    hash = :crypto.hash(:sha256, code) |> Base.encode16(case: :lower) |> String.slice(0..15)
    language = metadata[:language] || "unknown"
    "code_#{language}_#{hash}"
  end

  # Language-specific keyword extraction

  defp extract_elixir_keywords(code) do
    # Use CodeAnalyzer for accurate AST-based extraction with multi-language support
    case Singularity.CodeAnalyzer.extract_functions(code, "elixir") do
      {:ok, functions} ->
        function_names = Enum.map(functions, & &1.name)
        module_names = extract_module_names_from_code(code)

        framework_patterns =
          extract_patterns(code, [
            "GenServer",
            "Supervisor",
            "Agent",
            "Task",
            "Broadway",
            "Ecto.Schema"
          ])

        domain_patterns =
          extract_patterns(code, [
            "http",
            "api",
            "request",
            "cache",
            "pubsub",
            "nats",
            "database"
          ])

        (function_names ++ module_names ++ framework_patterns ++ domain_patterns)
        |> Enum.map(&String.downcase/1)

      {:error, _} ->
        # Fallback to basic extraction
        extract_generic_keywords(code)
    end
  end

  defp extract_rust_keywords(code) do
    # Use CodeAnalyzer for accurate AST-based extraction with multi-language support
    case Singularity.CodeAnalyzer.extract_functions(code, "rust") do
      {:ok, functions} ->
        function_names = Enum.map(functions, & &1.name)
        class_names = extract_class_names_from_code(code)

        framework_patterns =
          extract_patterns(code, [
            "Result",
            "Option",
            "Vec",
            "HashMap",
            "async",
            "tokio",
            "serde"
          ])

        (function_names ++ class_names ++ framework_patterns)
        |> Enum.map(&String.downcase/1)

      {:error, _} ->
        # Fallback to basic extraction
        extract_generic_keywords(code)
    end
  end

  defp extract_go_keywords(code) do
    # Use CodeAnalyzer for accurate AST-based extraction with multi-language support
    case Singularity.CodeAnalyzer.extract_functions(code, "go") do
      {:ok, functions} ->
        function_names = Enum.map(functions, & &1.name)
        class_names = extract_class_names_from_code(code)

        framework_patterns =
          extract_patterns(code, [
            "http",
            "context",
            "goroutine",
            "channel",
            "error",
            "interface"
          ])

        (function_names ++ class_names ++ framework_patterns)
        |> Enum.map(&String.downcase/1)

      {:error, _} ->
        # Fallback to basic extraction
        extract_generic_keywords(code)
    end
  end

  defp extract_ts_keywords(code) do
    # Use CodeAnalyzer for accurate AST-based extraction with multi-language support
    case Singularity.CodeAnalyzer.extract_functions(code, "typescript") do
      {:ok, functions} ->
        function_names = Enum.map(functions, & &1.name)
        class_names = extract_class_names_from_code(code)

        framework_patterns =
          extract_patterns(code, [
            "async",
            "await",
            "Promise",
            "Observable",
            "http",
            "api"
          ])

        (function_names ++ class_names ++ framework_patterns)
        |> Enum.map(&String.downcase/1)

      {:error, _} ->
        # Fallback to basic extraction
        extract_generic_keywords(code)
    end
  end

  defp extract_python_keywords(code) do
    # Use CodeAnalyzer for accurate AST-based extraction with multi-language support
    case Singularity.CodeAnalyzer.extract_functions(code, "python") do
      {:ok, functions} ->
        function_names = Enum.map(functions, & &1.name)
        class_names = extract_class_names_from_code(code)

        framework_patterns =
          extract_patterns(code, [
            "async",
            "await",
            "dataclass",
            "pydantic",
            "fastapi",
            "django"
          ])

        (function_names ++ class_names ++ framework_patterns)
        |> Enum.map(&String.downcase/1)

      {:error, _} ->
        # Fallback to basic extraction
        extract_generic_keywords(code)
    end
  end

  defp extract_java_keywords(code) do
    # Use CodeAnalyzer for accurate AST-based extraction with multi-language support
    case Singularity.CodeAnalyzer.extract_functions(code, "java") do
      {:ok, functions} ->
        function_names = Enum.map(functions, & &1.name)
        class_names = extract_class_names_from_code(code)

        framework_patterns =
          extract_patterns(code, [
            "Spring",
            "Repository",
            "Service",
            "Controller",
            "Entity",
            "Optional"
          ])

        (function_names ++ class_names ++ framework_patterns)
        |> Enum.map(&String.downcase/1)

      {:error, _} ->
        # Fallback to basic extraction
        extract_generic_keywords(code)
    end
  end

  defp extract_generic_keywords(code) do
    code
    |> String.split(~r/[^a-zA-Z0-9_]+/)
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.map(&String.downcase/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.take(20)
    |> Enum.map(fn {word, _} -> word end)
  end

  defp extract_module_names_from_code(code) do
    # Try ParserEngine first, fallback to regex
    case ParserEngine.detect_language(code) do
      {:ok, "elixir"} ->
        case ParserEngine.parse_file(code) do
          {:ok, document} ->
            # Extract module names from AST
            extract_module_from_ast(document.ast)

          {:error, _} ->
            extract_by_regex(code, ~r/defmodule\s+([A-Z][A-Za-z0-9_.]+)/)
        end

      _ ->
        extract_by_regex(code, ~r/defmodule\s+([A-Z][A-Za-z0-9_.]+)/)
    end
  end

  defp extract_class_names_from_code(code) do
    # Try ParserEngine first, fallback to regex
    case ParserEngine.extract_classes(code) do
      {:ok, classes} ->
        Enum.map(classes, & &1.name)

      {:error, _} ->
        extract_by_regex(code, ~r/(?:class|struct)\s+([A-Z][A-Za-z0-9_]+)/)
    end
  end

  defp extract_module_from_ast(ast) do
    # Extract module names from Elixir AST
    case ast do
      %{"type" => "Program", "body" => body} when is_list(body) ->
        body
        |> Enum.filter(&(&1["type"] == "ModuleDeclaration"))
        |> Enum.map(& &1["name"])

      _ ->
        []
    end
  end

  defp extract_by_regex(code, regex) do
    Regex.scan(regex, code)
    |> Enum.map(fn [_, match] -> match end)
  end

  defp extract_patterns(code, patterns) do
    Enum.filter(patterns, &String.contains?(code, &1))
  end
end
