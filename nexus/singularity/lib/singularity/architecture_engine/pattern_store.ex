defmodule Singularity.Architecture.PatternStore do
  @moduledoc """
  Unified Pattern Store - Consolidates Framework and Technology Pattern Storage.

  **CONSOLIDATION NOTE:** This module replaces both:
  - `Singularity.Architecture.FrameworkPatternStore` (DEPRECATED)
  - `Singularity.Architecture.TechnologyPatternStore` (DEPRECATED)

  See them as references but use this module for all new pattern storage.

  ## Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Architecture.PatternStore",
    "purpose": "Unified framework and technology pattern storage",
    "layer": "domain_service",
    "replaces": ["FrameworkPatternStore", "TechnologyPatternStore"],
    "status": "production",
    "deprecates": ["FrameworkPatternStore", "TechnologyPatternStore"]
  }
  ```

  ## Architecture Diagram
  ```mermaid
  graph TD
      Query["Detector / Analyzer"]
      Store["PatternStore"]
      DB["PostgreSQL<br/>(framework_patterns + technology_patterns)"]
      Search["SemanticSearch"]
      Embed["EmbeddingGenerator"]

      Query -->|store/2| Store
      Query -->|search/3| Store
      Store -->|SQL queries| DB
      Store -->|semantic search| Search
      Search -->|embedding| Embed
  ```

  ## Usage Examples

  ```elixir
  # Store a framework pattern
  {:ok, pattern} = PatternStore.store_pattern(
    :framework,
    "React",
    "web_ui_framework",
    "A JavaScript library for building UIs with components",
    0.95
  )

  # Store a technology pattern
  {:ok, pattern} = PatternStore.store_pattern(
    :technology,
    "TypeScript",
    "language",
    "JavaScript with static type checking",
    0.88
  )

  # Get a pattern
  {:ok, pattern} = PatternStore.get_pattern(:framework, "React")

  # Search similar patterns
  {:ok, patterns} = PatternStore.search_similar_patterns(
    :framework,
    "component-based UI library",
    top_k: 5
  )

  # Discover new patterns
  {:ok, unknown} = PatternStore.discover_new_patterns(:framework, "/path/to/repo")

  # Update pattern confidence (learning)
  {:ok, new_confidence} = PatternStore.update_confidence(:framework, "React", success: true)

  # Export patterns to JSON
  {:ok, count} = PatternStore.export_to_json(:framework, "/tmp/frameworks.json")
  ```

  ## Pattern Types

  - `:framework` - Frameworks (React, Django, Rails, etc.)
  - `:technology` - Technologies (TypeScript, PostgreSQL, etc.)

  ## Call Graph (Machine-Readable)

  ```yaml
  calls_out:
    - module: Singularity.Shared.SemanticSearch
      function: search_by_embedding/2
      purpose: Semantic similarity search
      critical: true

    - module: Singularity.EmbeddingGenerator
      function: embed/2
      purpose: Generate vector embeddings
      critical: true

    - module: Singularity.Repo
      function: query/2
      purpose: Execute PostgreSQL queries
      critical: true

    - module: Logger
      function: "[info|error]/2"
      purpose: Logging operations
      critical: false

  called_by:
    - module: Singularity.ArchitectureEngine.Detector
      count: "5+"
      purpose: Store detected patterns

    - module: Singularity.ArchitectureEngine.Analyzer
      count: "3+"
      purpose: Query patterns for analysis

    - module: Singularity.Knowledge.TemplateService
      count: "2+"
      purpose: Pattern enrichment
  ```

  ## Anti-Patterns (Prevents Duplicates)

  - ❌ **DO NOT** use FrameworkPatternStore directly (DEPRECATED)
  - ❌ **DO NOT** use TechnologyPatternStore directly (DEPRECATED)
  - ❌ **DO NOT** duplicate pattern storage logic in new modules
  - ✅ **DO** use `PatternStore.store_pattern/5` for all pattern storage
  - ✅ **DO** use `PatternStore.search_similar_patterns/3` for searches
  - ✅ **DO** reference this module in new code
  """

  require Logger
  alias Singularity.{Repo, EmbeddingGenerator}
  alias Singularity.Shared.SemanticSearch
  alias Singularity.Knowledge.Requests, as: KnowledgeRequests

  @type pattern_type :: :framework | :technology
  @type result :: {:ok, map()} | {:error, atom()}

  # Table mapping
  defp table_for(:framework), do: "framework_patterns"
  defp table_for(:technology), do: "technology_patterns"

  defp name_column(:framework), do: "framework_name"
  defp name_column(:technology), do: "technology_name"

  @doc """
  Store a new pattern or update existing one.

  ## Parameters

  - `pattern_type` - `:framework` or `:technology`
  - `name` - Pattern name (e.g., "React", "TypeScript")
  - `category` - Category (e.g., "web_ui_framework", "language")
  - `description` - Human-readable description
  - `confidence` - Initial confidence score (0.0-1.0)

  ## Returns

  `{:ok, pattern_map}` with stored pattern, or `{:error, reason}`
  """
  def store_pattern(pattern_type, name, category, description, confidence \\ 0.7)
      when pattern_type in [:framework, :technology] and is_binary(name) do
    with {:ok, embedding} <- EmbeddingGenerator.embed(description) do
      table = table_for(pattern_type)
      name_col = name_column(pattern_type)

      query = """
      INSERT INTO #{table} (#{name_col}, category, description, pattern_embedding, confidence, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
      ON CONFLICT (#{name_col}) DO UPDATE
      SET category = $2, description = $3, pattern_embedding = $4, updated_at = NOW()
      RETURNING *
      """

      case Repo.query(query, [name, category, description, embedding, confidence]) do
        {:ok, %{rows: [row | _]}} ->
          {:ok, build_pattern_map(row)}

        {:error, reason} ->
          Logger.error("Failed to store #{pattern_type} pattern: #{name}",
            reason: inspect(reason)
          )

          {:error, :storage_failed}
      end
    end
  end

  @doc """
  Get a specific pattern by name.
  """
  def get_pattern(pattern_type, name)
      when pattern_type in [:framework, :technology] and is_binary(name) do
    table = table_for(pattern_type)
    name_col = name_column(pattern_type)

    query = "SELECT * FROM #{table} WHERE #{name_col} = $1"

    case Repo.query(query, [name]) do
      {:ok, %{rows: [row | _]}} ->
        {:ok, build_pattern_map(row)}

      {:ok, %{rows: []}} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to get #{pattern_type} pattern: #{name}", reason: inspect(reason))
        {:error, :query_failed}
    end
  end

  @doc """
  Search for patterns similar to a query string.
  """
  def search_similar_patterns(pattern_type, query_text, opts \\ [])
      when pattern_type in [:framework, :technology] and is_binary(query_text) do
    table = table_for(pattern_type)
    top_k = Keyword.get(opts, :top_k, 5)
    min_similarity = Keyword.get(opts, :min_similarity, 0.7)

    SemanticSearch.search(query_text,
      table: table,
      top_k: top_k,
      min_similarity: min_similarity,
      text_column: "description"
    )
  end

  @doc """
  Update pattern confidence using exponential moving average.

  Implements adaptive learning: successful patterns become more trusted.
  """
  def update_confidence(pattern_type, name, success: success?)
      when pattern_type in [:framework, :technology] do
    table = table_for(pattern_type)
    name_col = name_column(pattern_type)

    success_value = if success?, do: 1.0, else: 0.0

    query = """
    UPDATE #{table}
    SET
      confidence = confidence * 0.9 + $2 * 0.1,
      usage_count = COALESCE(usage_count, 0) + 1,
      updated_at = NOW()
    WHERE #{name_col} = $1
    RETURNING confidence, usage_count
    """

    case Repo.query(query, [name, success_value]) do
      {:ok, %{rows: [[confidence, usage_count]]}} ->
        maybe_enqueue_false_positive(pattern_type, name, success?, confidence, usage_count)
        {:ok, confidence}

      {:ok, %{rows: []}} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to update confidence for #{pattern_type}: #{name}",
          reason: inspect(reason)
        )

        {:error, :update_failed}
    end
  end

  @doc """
  Discover new patterns by analyzing file extensions in a repository.

  Returns patterns not yet in the knowledge base.
  """
  def discover_new_patterns(pattern_type, repo_path)
      when pattern_type in [:framework, :technology] and is_binary(repo_path) do
    query = """
    SELECT DISTINCT
      SUBSTRING(file_path FROM '\\.([^.]+)$') AS extension,
      COUNT(*) AS file_count
    FROM codebase_chunks
    WHERE repo_name = $1
    GROUP BY extension
    HAVING COUNT(*) > 5
    ORDER BY file_count DESC
    LIMIT 20
    """

    case Repo.query(query, [repo_path]) do
      {:ok, %{rows: rows}} ->
        patterns = Enum.map(rows, fn [ext, count] -> %{extension: ext, file_count: count} end)
        unknown = Enum.reject(patterns, fn p -> known_extension?(p.extension, pattern_type) end)

        if Enum.any?(unknown) do
          Logger.info("Discovered #{length(unknown)} potential new #{pattern_type} patterns")
          enqueue_pattern_requests(pattern_type, repo_path, unknown)
          {:ok, unknown}
        else
          {:ok, []}
        end

      {:error, reason} ->
        Logger.error("Failed to discover patterns", reason: inspect(reason))
        {:error, :discovery_failed}
    end
  end

  defp enqueue_pattern_requests(pattern_type, repo_path, patterns) do
    Enum.each(patterns, fn
      %{extension: nil} ->
        :ok

      %{extension: extension, file_count: count} ->
        external_key = "pattern:#{pattern_type}:#{extension}"

        payload = %{
          "pattern_type" => Atom.to_string(pattern_type),
          "extension" => extension,
          "file_count" => count,
          "repo_path" => repo_path,
          "ecosystem" => infer_ecosystem(pattern_type, extension)
        }

        case KnowledgeRequests.enqueue(%{
               request_type: :pattern,
               external_key: external_key,
               payload: payload,
               source: "Singularity.Architecture.PatternStore",
               source_reference: repo_path,
               metadata: %{"pattern_type" => Atom.to_string(pattern_type)}
             }) do
          {:ok, _request} ->
            :ok

          {:error, changeset} ->
            Logger.error("Failed to enqueue knowledge request for pattern",
              external_key: external_key,
              errors: changeset.errors
            )
        end
    end)
  end

  defp maybe_enqueue_false_positive(_pattern_type, _name, true, _confidence, _usage_count),
    do: :ok

  defp maybe_enqueue_false_positive(pattern_type, name, false, confidence, usage_count) do
    threshold =
      Application.get_env(:singularity, :pattern_store, %{})[:false_positive_threshold] || 0.35

    min_failures =
      Application.get_env(:singularity, :pattern_store, %{})[:false_positive_min_failures] || 3

    if confidence < threshold and usage_count >= min_failures do
      external_key = "anti_pattern:" <> Atom.to_string(pattern_type) <> ":" <> slugify_name(name)

      payload = %{
        "pattern_type" => Atom.to_string(pattern_type),
        "pattern_name" => name,
        "confidence" => confidence,
        "usage_count" => usage_count,
        "trigger" => "low_confidence"
      }

      attrs = %{
        request_type: :anti_pattern,
        external_key: external_key,
        payload: payload,
        source: Atom.to_string(__MODULE__),
        source_reference: name,
        metadata: %{
          "pattern_type" => Atom.to_string(pattern_type),
          "confidence" => confidence,
          "usage_count" => usage_count,
          "reason" => "low_confidence"
        }
      }

      case KnowledgeRequests.enqueue(attrs) do
        {:ok, _req} ->
          Logger.warning("Enqueued anti-pattern review",
            pattern_type: pattern_type,
            pattern_name: name,
            confidence: confidence,
            usage_count: usage_count
          )

        {:error, changeset} ->
          Logger.error("Failed to enqueue anti-pattern request",
            pattern_type: pattern_type,
            pattern_name: name,
            errors: changeset.errors
          )
      end
    end
  end

  defp maybe_enqueue_false_positive(_pattern_type, _name, _success, _confidence, _usage_count),
    do: :ok

  defp slugify_name(nil), do: "unknown"

  defp slugify_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  defp infer_ecosystem(:technology, extension), do: infer_language(extension)
  defp infer_ecosystem(:framework, extension), do: infer_language(extension)

  defp infer_language(nil), do: nil

  defp infer_language(extension) do
    case String.trim_leading(extension, ".") |> String.downcase() do
      "ex" -> "elixir"
      "exs" -> "elixir"
      "py" -> "python"
      "rb" -> "ruby"
      "ts" -> "typescript"
      "tsx" -> "typescript"
      "js" -> "javascript"
      "jsx" -> "javascript"
      "rs" -> "rust"
      "go" -> "go"
      "java" -> "java"
      "kt" -> "kotlin"
      "cs" -> "csharp"
      "c" -> "c"
      "h" -> "c"
      "hpp" -> "cpp"
      "hh" -> "cpp"
      "cc" -> "cpp"
      "cpp" -> "cpp"
      "cxx" -> "cpp"
      "m" -> "objective-c"
      "swift" -> "swift"
      "php" -> "php"
      "scala" -> "scala"
      "hs" -> "haskell"
      "lua" -> "lua"
      "groovy" -> "groovy"
      "dart" -> "dart"
      _ -> nil
    end
  end

  @doc """
  Export all patterns to JSON file.

  Useful for backup, sharing, or version control integration.
  """
  def export_to_json(pattern_type, output_path)
      when pattern_type in [:framework, :technology] and is_binary(output_path) do
    table = table_for(pattern_type)
    name_col = name_column(pattern_type)

    query = """
    SELECT #{name_col}, category, description, confidence, usage_count, created_at, updated_at
    FROM #{table}
    ORDER BY #{name_col}
    """

    case Repo.query(query, []) do
      {:ok, %{rows: rows}} ->
        patterns = Enum.map(rows, fn row -> build_export_map(row, pattern_type) end)
        json = Jason.encode!(patterns, pretty: true)
        File.write!(output_path, json)
        Logger.info("Exported #{length(patterns)} #{pattern_type} patterns to #{output_path}")
        {:ok, length(patterns)}

      {:error, reason} ->
        Logger.error("Failed to export patterns", reason: inspect(reason))
        {:error, :export_failed}
    end
  rescue
    e ->
      Logger.error("Exception during pattern export", error: inspect(e))
      {:error, :export_exception}
  end

  @doc """
  List all patterns of a given type.
  """
  def list_patterns(pattern_type, opts \\ []) when pattern_type in [:framework, :technology] do
    table = table_for(pattern_type)
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    query = """
    SELECT * FROM #{table}
    ORDER BY confidence DESC, created_at DESC
    LIMIT $1 OFFSET $2
    """

    case Repo.query(query, [limit, offset]) do
      {:ok, %{rows: rows}} ->
        patterns = Enum.map(rows, &build_pattern_map/1)
        {:ok, patterns}

      {:error, reason} ->
        Logger.error("Failed to list patterns", reason: inspect(reason))
        {:error, :query_failed}
    end
  end

  # Private helpers

  defp build_pattern_map([
         id,
         name,
         type,
         category,
         description,
         embedding,
         confidence,
         usage,
         created,
         updated | _
       ]) do
    %{
      id: id,
      name: name,
      type: type,
      category: category,
      description: description,
      embedding_size: byte_size(inspect(embedding)),
      confidence: confidence,
      usage_count: usage || 0,
      created_at: created,
      updated_at: updated
    }
  end

  defp build_pattern_map(_), do: %{}

  defp build_export_map(
         [name, category, description, confidence, usage, created, updated | _],
         _type
       ) do
    %{
      name: name,
      category: category,
      description: description,
      confidence: confidence,
      usage_count: usage || 0,
      created_at: created,
      updated_at: updated
    }
  end

  defp known_extension?(ext, :framework) do
    # Frameworks typically don't have universal file extensions
    # This is a heuristic check
    not String.starts_with?(ext, ".")
  end

  defp known_extension?(ext, :technology) do
    # Known technology extensions
    known = [
      "js",
      "ts",
      "tsx",
      "jsx",
      "py",
      "rb",
      "go",
      "rs",
      "java",
      "kt",
      "scala",
      "php",
      "c",
      "cpp",
      "h",
      "cs",
      "swift",
      "m"
    ]

    String.downcase(String.trim_leading(ext, ".")) in known
  end
end
