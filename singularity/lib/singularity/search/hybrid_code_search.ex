defmodule Singularity.Search.HybridCodeSearch do
  @moduledoc """
  Hybrid Code Search - Combines PostgreSQL FTS + Semantic Vector Search.

  ## Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Search.HybridCodeSearch",
    "purpose": "Unified search combining keyword (FTS) + semantic (pgvector)",
    "layer": "search",
    "status": "production"
  }
  ```

  ## Search Strategy

  **Three search modes:**

  1. **Keyword Search** (PostgreSQL FTS) - Fast exact/phrase matches
  2. **Semantic Search** (pgvector) - Conceptual similarity
  3. **Hybrid Search** (Combined) - Best of both worlds

  ## Architecture Diagram
  ```mermaid
  graph TD
      A[Search Query] --> B{Mode}
      B -->|:keyword| C[PostgreSQL FTS]
      B -->|:semantic| D[pgvector Search]
      B -->|:hybrid| E[Combined Scoring]

      C --> F[ts_rank score]
      D --> G[cosine similarity]
      E --> H[weighted average]

      F --> I[Results]
      G --> I
      H --> I

      I --> J[Ranked by relevance]
  ```

  ## Call Graph (YAML)
  ```yaml
  calls:
    - Singularity.Repo (database queries)
    - Singularity.Search.EmbeddingService (embeddings)
    - PostgreSQL FTS functions (ts_rank, plainto_tsquery)
    - pgvector operators (<=> distance)

  called_by:
    - Singularity.Tools.CodeSearch (MCP interface)
    - Singularity.Jobs.PgmqClient.CodeSearchSubscriber (pgmq interface)
    - User-facing search APIs
  ```

  ## Anti-Patterns

  ❌ **DO NOT** use FTS for conceptual searches - use semantic
  ❌ **DO NOT** use semantic for exact matches - use FTS
  ❌ **DO NOT** skip fuzzy search (pg_trgm) for typo tolerance
  ❌ **DO NOT** forget to generate embeddings before semantic search

  ## Search Keywords

  hybrid search, full-text search, semantic search, code search, pgvector,
  postgresql fts, fuzzy search, pg_trgm, keyword search, vector similarity,
  cosine distance, weighted ranking, search relevance

  ## Note on Tables

  Uses `code_files` table (not `code_chunks`) for code search.
  Uses `store_knowledge_artifacts` and `curated_knowledge_artifacts` for templates/patterns.

  ## Usage

      # Keyword search (exact matches)
      {:ok, results} = HybridCodeSearch.search(
        "async worker pattern",
        mode: :keyword
      )

      # Semantic search (conceptual similarity)
      {:ok, results} = HybridCodeSearch.search(
        "background job processing",
        mode: :semantic
      )

      # Hybrid search (best of both)
      {:ok, results} = HybridCodeSearch.search(
        "async worker",
        mode: :hybrid,
        weights: %{keyword: 0.4, semantic: 0.6}
      )

      # Fuzzy search (typo-tolerant)
      {:ok, results} = HybridCodeSearch.fuzzy_search(
        "asynch wrker",  # Note the typos!
        threshold: 0.3
      )
  """

  import Ecto.Query
  require Logger
  alias Singularity.Repo
  alias Singularity.Search.EmbeddingService

  @type search_mode :: :keyword | :semantic | :hybrid
  @type search_result :: %{
          id: integer(),
          content: String.t(),
          file_path: String.t(),
          score: float(),
          match_type: atom()
        }
  @type _opts :: [
          mode: search_mode(),
          limit: pos_integer(),
          weights: map(),
          threshold: float(),
          language: String.t()
        ]

  @default_limit 20
  @default_weights %{keyword: 0.4, semantic: 0.6}
  @default_threshold 0.5

  @doc """
  Search code chunks using keyword, semantic, or hybrid mode.

  ## Options

  - `:mode` - Search mode (`:keyword`, `:semantic`, `:hybrid`, default: `:hybrid`)
  - `:limit` - Maximum results (default: 20)
  - `:weights` - Score weights for hybrid mode (default: %{keyword: 0.4, semantic: 0.6})
  - `:threshold` - Minimum similarity threshold (default: 0.5)
  - `:language` - Filter by language (optional)

  ## Examples

      # Hybrid search (default)
      {:ok, results} = HybridCodeSearch.search("async worker")

      # Keyword only (exact matches)
      {:ok, results} = HybridCodeSearch.search(
        "GenServer.handle_call",
        mode: :keyword
      )

      # Semantic only (conceptual)
      {:ok, results} = HybridCodeSearch.search(
        "background job processing",
        mode: :semantic
      )

      # Hybrid with custom weights
      {:ok, results} = HybridCodeSearch.search(
        "async worker",
        mode: :hybrid,
        weights: %{keyword: 0.3, semantic: 0.7}
      )

      # Filter by language
      {:ok, results} = HybridCodeSearch.search(
        "async worker",
        language: "elixir"
      )
  """
  @spec search(String.t(), _opts()) :: {:ok, [search_result()]} | {:error, term()}
  def search(query, _opts \\ []) do
    mode = Keyword.get(opts, :mode, :hybrid)

    case mode do
      :keyword -> keyword_search(query, _opts)
      :semantic -> semantic_search(query, _opts)
      :hybrid -> hybrid_search(query, _opts)
      _ -> {:error, "Unknown search mode: #{mode}"}
    end
  end

  @doc """
  Fuzzy search using PostgreSQL pg_trgm (typo-tolerant).

  Finds results even with typos, missing characters, etc.

  ## Options

  - `:threshold` - Minimum similarity (0.0-1.0, default: 0.3)
  - `:limit` - Maximum results (default: 20)

  ## Examples

      # Tolerates typos
      {:ok, results} = HybridCodeSearch.fuzzy_search(
        "asynch wrker",  # Typos!
        threshold: 0.3
      )

      # Stricter matching
      {:ok, results} = HybridCodeSearch.fuzzy_search(
        "GenServer",
        threshold: 0.7
      )
  """
  @spec fuzzy_search(String.t(), _opts()) :: {:ok, [search_result()]} | {:error, term()}
  def fuzzy_search(query, _opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.3)
    limit = Keyword.get(opts, :limit, @default_limit)
    language = Keyword.get(opts, :language)

    base_query =
      from c in "code_files",
        where: fragment("similarity(content, ?) > ?", ^query, ^threshold),
        order_by: [desc: fragment("similarity(content, ?)", ^query)],
        limit: ^limit,
        select: %{
          id: c.id,
          content: c.content,
          file_path: c.file_path,
          language: c.language,
          score: fragment("similarity(content, ?)", ^query),
          match_type: "fuzzy"
        }

    query_with_language =
      if language do
        from c in base_query, where: c.language == ^language
      else
        base_query
      end

    results = Repo.all(query_with_language)
    Logger.debug("Fuzzy search: #{length(results)} results (threshold: #{threshold})")
    {:ok, results}
  rescue
    error ->
      Logger.error("Fuzzy search error: #{inspect(error)}")
      {:error, error}
  end

  ## Private - Keyword Search (PostgreSQL FTS)

  defp keyword_search(query, _opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    language = Keyword.get(opts, :language)

    base_query =
      from c in "code_files",
        where:
          fragment(
            "search_vector @@ plainto_tsquery('english', ?)",
            ^query
          ),
        order_by: [
          desc:
            fragment(
              "ts_rank(search_vector, plainto_tsquery('english', ?))",
              ^query
            )
        ],
        limit: ^limit,
        select: %{
          id: c.id,
          content: c.content,
          file_path: c.file_path,
          language: c.language,
          score:
            fragment(
              "ts_rank(search_vector, plainto_tsquery('english', ?))",
              ^query
            ),
          match_type: "keyword"
        }

    query_with_language =
      if language do
        from c in base_query, where: c.language == ^language
      else
        base_query
      end

    results = Repo.all(query_with_language)
    Logger.debug("Keyword search: #{length(results)} results")
    {:ok, results}
  rescue
    error ->
      Logger.error("Keyword search error: #{inspect(error)}")
      {:error, error}
  end

  ## Private - Semantic Search (pgvector)

  defp semantic_search(query, _opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    language = Keyword.get(opts, :language)

    # Generate embedding for query
    with {:ok, embedding} <- EmbeddingService.embed(query) do
      embedding_list = embedding_to_list(embedding)

      base_query =
        from c in "code_files",
          where: fragment("1 - (embedding <=> ?) > ?", ^embedding_list, ^threshold),
          order_by: fragment("embedding <=> ?", ^embedding_list),
          limit: ^limit,
          select: %{
            id: c.id,
            content: c.content,
            file_path: c.file_path,
            language: c.language,
            score: fragment("1 - (embedding <=> ?)", ^embedding_list),
            match_type: "semantic"
          }

      query_with_language =
        if language do
          from c in base_query, where: c.language == ^language
        else
          base_query
        end

      results = Repo.all(query_with_language)
      Logger.debug("Semantic search: #{length(results)} results")
      {:ok, results}
    else
      {:error, reason} ->
        Logger.error("Embedding generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Semantic search error: #{inspect(error)}")
      {:error, error}
  end

  ## Private - Hybrid Search (FTS + pgvector)

  defp hybrid_search(query, _opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    weights = Keyword.get(opts, :weights, @default_weights)
    language = Keyword.get(opts, :language)

    keyword_weight = Map.get(weights, :keyword, 0.4)
    semantic_weight = Map.get(weights, :semantic, 0.6)

    # Generate embedding for query
    with {:ok, embedding} <- EmbeddingService.embed(query) do
      embedding_list = embedding_to_list(embedding)

      base_query =
        from c in "code_files",
          where:
            fragment(
              "search_vector @@ plainto_tsquery('english', ?)",
              ^query
            ),
          order_by: [
            desc:
              fragment(
                """
                ts_rank(search_vector, plainto_tsquery('english', ?)) * ? +
                (1 - (embedding <=> ?)) * ?
                """,
                ^query,
                ^keyword_weight,
                ^embedding_list,
                ^semantic_weight
              )
          ],
          limit: ^limit,
          select: %{
            id: c.id,
            content: c.content,
            file_path: c.file_path,
            language: c.language,
            keyword_score:
              fragment(
                "ts_rank(search_vector, plainto_tsquery('english', ?))",
                ^query
              ),
            semantic_score: fragment("1 - (embedding <=> ?)", ^embedding_list),
            score:
              fragment(
                """
                ts_rank(search_vector, plainto_tsquery('english', ?)) * ? +
                (1 - (embedding <=> ?)) * ?
                """,
                ^query,
                ^keyword_weight,
                ^embedding_list,
                ^semantic_weight
              ),
            match_type: "hybrid"
          }

      query_with_language =
        if language do
          from c in base_query, where: c.language == ^language
        else
          base_query
        end

      results = Repo.all(query_with_language)
      Logger.debug("Hybrid search: #{length(results)} results (weights: #{inspect(weights)})")
      {:ok, results}
    else
      {:error, reason} ->
        Logger.error("Hybrid search failed: #{inspect(reason)}, falling back to keyword")
        keyword_search(query, _opts)
    end
  rescue
    error ->
      Logger.error("Hybrid search error: #{inspect(error)}, falling back to keyword")
      keyword_search(query, _opts)
  end

  ## Private - Helpers

  defp embedding_to_list(%Pgvector{} = pgvector) do
    # Convert Pgvector struct to list
    Pgvector.to_list(pgvector)
  end

  defp embedding_to_list(list) when is_list(list), do: list
end
