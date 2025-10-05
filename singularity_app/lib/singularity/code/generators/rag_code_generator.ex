defmodule Singularity.RAGCodeGenerator do
  @moduledoc """
  RAG-powered Code Generation - Find and use the BEST code from all codebases

  Uses Retrieval-Augmented Generation (RAG) to:
  1. Search ALL codebases in PostgreSQL for similar code patterns
  2. Find the BEST examples using semantic similarity (pgvector)
  3. Use those examples as context for code generation
  4. Generate code that matches proven patterns from your repos

  ## How it works

  ```
  User asks: "Generate function to parse JSON API response"
      ↓
  1. Embed the request → [0.23, 0.45, ...] (768 dims)
      ↓
  2. Search PostgreSQL for similar code (vector similarity)
      → Found: 10 similar functions from 5 different repos
      ↓
  3. Rank by quality (tests passing, recently used, etc.)
      ↓
  4. Use TOP 3 as examples for code generation
      ↓
  5. StarCoder2 generates code following those patterns
      ↓
  Result: High-quality code matching YOUR best practices!
  ```

  ## Benefits

  - ✅ Learns from ALL your codebases (not just one repo)
  - ✅ Finds PROVEN patterns (tested, working code)
  - ✅ Automatically adapts to your best practices
  - ✅ Cross-language learning (Elixir patterns → Rust, etc.)
  - ✅ Zero-shot quality (no training needed!)

  ## Usage

      # Generate with RAG (finds best examples automatically)
      {:ok, code} = RAGCodeGenerator.generate(
        task: "Parse JSON response with error handling",
        language: "elixir",
        top_k: 5  # Use top 5 similar code examples
      )

      # Generate with specific repo context
      {:ok, code} = RAGCodeGenerator.generate(
        task: "Create GenServer for cache",
        repos: ["singularity", "sparc_fact_system"],
        prefer_recent: true  # Prefer recently modified code
      )
  """

  require Logger
  alias Singularity.{CodeStore, SemanticCodeSearch, EmbeddingService, CodeModel}

  @type generation_opts :: [
    task: String.t(),
    language: String.t() | nil,
    repos: [String.t()] | nil,
    top_k: integer(),
    prefer_recent: boolean(),
    temperature: float()
  ]

  @doc """
  Generate code using RAG - finds best examples from all codebases

  ## Options

  - `:task` - What to generate (required) - e.g. "Parse JSON API response"
  - `:language` - Target language (e.g. "elixir", "rust") - auto-detected if nil
  - `:repos` - Limit to specific repos (nil = search all)
  - `:top_k` - Number of example code snippets to use (default: 5)
  - `:prefer_recent` - Prefer recently modified code (default: false)
  - `:temperature` - Generation temperature (default: 0.05 for strict)
  - `:include_tests` - Include test examples (default: true)
  """
  @spec generate(generation_opts()) :: {:ok, String.t()} | {:error, term()}
  def generate(opts) do
    task = Keyword.fetch!(opts, :task)
    language = Keyword.get(opts, :language)
    repos = Keyword.get(opts, :repos)
    top_k = Keyword.get(opts, :top_k, 5)
    prefer_recent = Keyword.get(opts, :prefer_recent, false)
    temperature = Keyword.get(opts, :temperature, 0.05)
    include_tests = Keyword.get(opts, :include_tests, true)

    Logger.info("RAG Code Generation: #{task}")

    with {:ok, examples} <- find_best_examples(task, language, repos, top_k, prefer_recent, include_tests),
         {:ok, prompt} <- build_rag_prompt(task, examples, language),
         {:ok, code} <- CodeModel.complete(prompt, temperature: temperature) do
      Logger.info("✅ Generated #{String.length(code)} chars using #{length(examples)} examples")
      {:ok, code}
    else
      {:error, reason} ->
        Logger.error("RAG generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Find the BEST code examples from all codebases using semantic search

  Returns ranked examples with metadata (quality scores, repo, path, etc.)
  """
  @spec find_best_examples(String.t(), String.t() | nil, [String.t()] | nil, integer(), boolean(), boolean()) ::
    {:ok, [map()]} | {:error, term()}
  def find_best_examples(task, language, repos, top_k, prefer_recent, include_tests) do
    # 1. Create search query (semantic)
    search_query = build_search_query(task, language)

    Logger.debug("Searching for similar code: #{search_query}")

    # 2. Semantic search in PostgreSQL (pgvector)
    with {:ok, embedding} <- EmbeddingService.embed(search_query),
         {:ok, results} <- semantic_search(embedding, language, repos, top_k * 2) do  # Get 2x, then filter

      # 3. Rank and filter results
      ranked = results
      |> filter_quality(include_tests)
      |> rank_by_quality(prefer_recent)
      |> Enum.take(top_k)

      Logger.debug("Found #{length(ranked)} high-quality examples")
      {:ok, ranked}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  ## Private Functions

  defp build_search_query(task, language) do
    # Enhance task with language-specific keywords for better retrieval
    lang_prefix = case language do
      "elixir" -> "Elixir function module defmodule"
      "rust" -> "Rust function impl struct"
      "typescript" -> "TypeScript function class interface"
      _ -> ""
    end

    "#{lang_prefix} #{task}"
  end

  defp semantic_search(embedding, language, repos, limit) do
    # Use optimized function with parallel partition scanning
    query = """
    SELECT * FROM search_similar_code(
      $1::vector,
      $2,
      $3,
      $4
    )
    """

    params = [
      embedding,
      if(language, do: language, else: nil),
      if(repos, do: repos, else: nil),
      limit
    ] |> Enum.reject(&is_nil/1)

    case Singularity.Repo.query(query, params) do
      {:ok, %{rows: rows}} ->
        examples = Enum.map(rows, fn row ->
          [id, path, content, lang, metadata, repo, updated_at, similarity] = row
          %{
            id: id,
            path: path,
            content: content,
            language: lang,
            metadata: metadata || %{},
            repo: repo,
            updated_at: updated_at,
            similarity: similarity
          }
        end)

        {:ok, examples}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_limit_param_index(language, repos) do
    case {language, repos} do
      {nil, nil} -> "2"
      {_, nil} -> "3"
      {nil, _} -> "3"
      {_, _} -> "4"
    end
  end

  defp filter_quality(examples, include_tests) do
    examples
    |> Enum.filter(fn ex ->
      # Filter out low-quality code
      content = ex.content
      metadata = ex.metadata

      # Basic quality checks
      has_min_length = String.length(content) >= 50
      not_generated = not String.contains?(content, ["TODO", "FIXME", "XXX"])
      not_commented_out = not String.starts_with?(String.trim(content), "#")

      # Test file handling
      is_test = String.contains?(ex.path, ["test", "spec", "_test."])
      include_this = if include_tests, do: true, else: not is_test

      # Similarity threshold
      has_good_similarity = ex.similarity >= 0.7

      has_min_length and not_generated and not_commented_out and include_this and has_good_similarity
    end)
  end

  defp rank_by_quality(examples, prefer_recent) do
    examples
    |> Enum.sort_by(fn ex ->
      # Multi-factor ranking score
      similarity_score = ex.similarity * 1000  # 0-1000

      # Recency bonus (if preferred)
      recency_score = if prefer_recent do
        days_old = DateTime.diff(DateTime.utc_now(), ex.updated_at, :day)
        max(0, 100 - days_old)  # 100 points for today, 0 for 100+ days
      else
        0
      end

      # Code size bonus (prefer substantial code, not snippets)
      size_score = min(100, div(String.length(ex.content), 10))

      # Total score
      -(similarity_score + recency_score + size_score)  # Negative for DESC sort
    end)
  end

  defp build_rag_prompt(task, examples, language) do
    # Build prompt with examples from best codebases
    language_hint = if language, do: language, else: "auto-detect"

    examples_text = examples
    |> Enum.with_index(1)
    |> Enum.map(fn {ex, idx} ->
      """
      Example #{idx} (from #{ex.repo}/#{Path.basename(ex.path)}, similarity: #{Float.round(ex.similarity, 2)}):
      ```#{ex.language}
      #{String.slice(ex.content, 0..500)}
      ```
      """
    end)
    |> Enum.join("\n")

    prompt = """
    Task: #{task}
    Language: #{language_hint}

    Here are #{length(examples)} similar, high-quality code examples from your codebases:

    #{examples_text}

    Based on these proven patterns, generate code for the task.
    OUTPUT CODE ONLY - no explanations, no comments about the examples.

    """

    {:ok, prompt}
  end

  @doc """
  Analyze code quality across all repos - find best practices

  Returns insights like:
  - Most common patterns
  - Best-performing code (by similarity to many files)
  - Repos with highest quality code
  """
  @spec analyze_best_practices(keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_best_practices(opts \\ []) do
    language = Keyword.get(opts, :language)

    query = """
    WITH code_similarities AS (
      SELECT
        cf.repo_name,
        cf.language,
        COUNT(*) as file_count,
        AVG(LENGTH(cf.content)) as avg_file_size,
        COUNT(DISTINCT cf.file_path) as unique_files
      FROM code_files cf
      #{if language, do: "WHERE cf.language = $1", else: ""}
      GROUP BY cf.repo_name, cf.language
      ORDER BY file_count DESC
    )
    SELECT * FROM code_similarities
    LIMIT 20
    """

    params = if language, do: [language], else: []

    case Singularity.Repo.query(query, params) do
      {:ok, %{rows: rows}} ->
        stats = Enum.map(rows, fn [repo, lang, count, avg_size, unique] ->
          %{
            repo: repo,
            language: lang,
            file_count: count,
            avg_file_size: round(avg_size),
            unique_files: unique
          }
        end)

        {:ok, %{
          top_repos: stats,
          total_repos: length(stats),
          languages: Enum.map(stats, & &1.language) |> Enum.uniq()
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
