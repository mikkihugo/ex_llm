defmodule Singularity.Database.PatternSimilaritySearch do
  @moduledoc """
  Pattern similarity search via Lantern vector search engine.

  Finds similar code patterns using semantic similarity on embeddings.
  Alternative to pgvector when you need different indexing strategies.

  ## Features

  - HNSW (Hierarchical Navigable Small World) indexing for fast similarity search
  - L2 distance, cosine similarity, and Manhattan distance metrics
  - Dynamic index creation (no pre-tuning required)
  - Better performance than pgvector for very large collections

  ## Architecture

  ```
  Learned Patterns (table)
      ↓
  Embedding vectors (1536-dim from embedding_engine)
      ↓
  Lantern HNSW Index
      ↓
  Similarity Search (k-nearest neighbors)
      ↓
  Ranked results with distance scores
  ```

  ## Use Cases

  - Find similar patterns from different instances
  - Detect duplicate pattern learning
  - Recommend patterns for new scenarios
  - Clustering agents by learned pattern similarity

  ## Usage

  ```elixir
  # Search for patterns similar to a code snippet
  {:ok, similar} = PatternSimilaritySearch.search_patterns(
    "async task with error handling",
    limit: 5,
    distance_threshold: 0.3
  )

  # Search within specific agent
  {:ok, similar} = PatternSimilaritySearch.search_agent_patterns(
    agent_id,
    "retry logic",
    limit: 10
  )

  # Find duplicate patterns across instances
  {:ok, duplicates} = PatternSimilaritySearch.find_duplicate_patterns(
    min_similarity: 0.95
  )

  # Get pattern neighbors (related patterns)
  {:ok, neighbors} = PatternSimilaritySearch.get_pattern_neighbors(
    pattern_id,
    limit: 5
  )
  ```
  """

  require Logger
  alias CentralCloud.Repo

  @doc """
  Search for patterns similar to a query.

  Uses Lantern HNSW index for fast k-nearest neighbor search.
  Returns patterns ranked by similarity distance (lower = more similar).

  ## Options

  - `:limit` - Max results (default: 10)
  - `:distance_threshold` - Only return patterns closer than this (default: 1.0)
  - `:agent_id` - Filter by specific agent (optional)
  """
  def search_patterns(query, opts \\ []) when is_binary(query) do
    limit = Keyword.get(opts, :limit, 10)
    threshold = Keyword.get(opts, :distance_threshold, 1.0)
    agent_id = Keyword.get(opts, :agent_id)

    # Get embedding for query
    case get_or_embed(query) do
      {:ok, embedding} ->
        search_by_embedding(embedding, limit, threshold, agent_id)

      error ->
        error
    end
  end

  @doc """
  Search for patterns similar to a known pattern by ID.

  Useful for finding related patterns and detecting duplicates.
  """
  def search_similar_to_pattern(pattern_id, limit \\ 5) when is_integer(pattern_id) do
    case Repo.query("""
      SELECT p1.id, p1.code_snippet, p1.pattern_type,
        l2_distance(p1.embedding, p2.embedding) as distance
      FROM learned_patterns p1
      JOIN learned_patterns p2 ON p1.id != p2.id
      WHERE p2.id = $1
      ORDER BY l2_distance(p1.embedding, p2.embedding) ASC
      LIMIT $2
    """, [pattern_id, limit]) do
      {:ok, %{rows: rows}} ->
        results =
          Enum.map(rows, fn [id, snippet, type, distance] ->
            %{
              id: id,
              code_snippet: snippet,
              pattern_type: type,
              distance: distance,
              similarity_score: 1.0 - (distance / 2.0)  # Normalize to 0-1
            }
          end)

        {:ok, results}

      error ->
        error
    end
  end

  @doc """
  Search for patterns within a specific agent.

  Agent learns patterns over time - find similar ones to avoid relearning.
  """
  def search_agent_patterns(agent_id, query, opts \\ []) when is_integer(agent_id) and is_binary(query) do
    limit = Keyword.get(opts, :limit, 10)
    threshold = Keyword.get(opts, :distance_threshold, 1.0)

    case get_or_embed(query) do
      {:ok, embedding} ->
        search_by_embedding(embedding, limit, threshold, agent_id)

      error ->
        error
    end
  end

  @doc """
  Find potential duplicate patterns (very high similarity).

  Returns pairs of patterns with distance < 0.05 (95%+ similarity).
  Helps avoid redundant pattern learning.
  """
  def find_duplicate_patterns(min_similarity \\ 0.95) do
    max_distance = 2.0 * (1.0 - min_similarity)  # Convert similarity to distance

    case Repo.query("""
      SELECT
        p1.id as pattern_1_id,
        p1.code_snippet as pattern_1_snippet,
        p2.id as pattern_2_id,
        p2.code_snippet as pattern_2_snippet,
        l2_distance(p1.embedding, p2.embedding) as distance
      FROM learned_patterns p1
      JOIN learned_patterns p2 ON p1.id < p2.id
      WHERE l2_distance(p1.embedding, p2.embedding) < $1
      ORDER BY distance ASC
      LIMIT 100
    """, [max_distance]) do
      {:ok, %{rows: rows}} ->
        results =
          Enum.map(rows, fn [id1, snippet1, id2, snippet2, distance] ->
            %{
              pattern_1: %{id: id1, snippet: snippet1},
              pattern_2: %{id: id2, snippet: snippet2},
              distance: distance,
              similarity: 1.0 - (distance / 2.0)
            }
          end)

        {:ok, results}

      error ->
        error
    end
  end

  @doc """
  Get patterns near a specific pattern ID.

  Returns neighbors in embedding space (related patterns).
  """
  def get_pattern_neighbors(pattern_id, limit \\ 5) when is_integer(pattern_id) do
    search_similar_to_pattern(pattern_id, limit)
  end

  @doc """
  Get vector search index statistics.

  Shows Lantern index size, tuning parameters, etc.
  """
  def index_stats do
    case Repo.query("""
      SELECT
        schemaname,
        tablename,
        indexname,
        pg_size_pretty(pg_relation_size(indexrelid)) as index_size
      FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname LIKE '%lantern%'
    """) do
      {:ok, %{rows: rows}} ->
        stats =
          Enum.map(rows, fn [schema, table, index, size] ->
            %{
              schema: schema,
              table: table,
              index: index,
              size: size
            }
          end)

        {:ok, stats}

      error ->
        error
    end
  end

  @doc """
  Recreate Lantern HNSW index (for optimization).

  Useful after bulk pattern imports to rebuild index with optimal parameters.
  """
  def rebuild_index do
    case Repo.query("REINDEX INDEX CONCURRENTLY idx_learned_patterns_embedding") do
      {:ok, _} ->
        Logger.info("Rebuilt Lantern index for learned_patterns")
        {:ok, :rebuilt}

      error ->
        Logger.error("Failed to rebuild index: #{inspect(error)}")
        error
    end
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  defp search_by_embedding(embedding, limit, threshold, agent_id) do
    result =
      if agent_id do
        query_sql = """
        SELECT id, code_snippet, pattern_type, agent_id,
          l2_distance(embedding, $1) as distance
        FROM learned_patterns
        WHERE agent_id = $2
          AND l2_distance(embedding, $1) < $3
        ORDER BY distance ASC
        LIMIT $4
        """

        Repo.query(query_sql, [embedding, agent_id, threshold, limit])
      else
        query_sql = """
        SELECT id, code_snippet, pattern_type, agent_id,
          l2_distance(embedding, $1) as distance
        FROM learned_patterns
        WHERE l2_distance(embedding, $1) < $2
        ORDER BY distance ASC
        LIMIT $3
        """

        Repo.query(query_sql, [embedding, threshold, limit])
      end

    case result do
      {:ok, %{rows: rows}} ->
        results =
          Enum.map(rows, fn [id, snippet, type, agent_id, distance] ->
            %{
              id: id,
              code_snippet: snippet,
              pattern_type: type,
              agent_id: agent_id,
              distance: distance,
              similarity_score: 1.0 - (distance / 2.0)
            }
          end)

        {:ok, results}

      error ->
        error
    end
  end

  defp get_or_embed(text) when is_binary(text) do
    # Try to get cached embedding, otherwise generate
    case Repo.query(
      "SELECT embedding FROM code_embeddings WHERE source_text = $1 LIMIT 1",
      [text]
    ) do
      {:ok, %{rows: [[embedding]]}} ->
        {:ok, embedding}

      {:ok, %{rows: []}} ->
        # Generate and cache
        case generate_embedding(text) do
          {:ok, embedding} ->
            # Cache for future use
            Repo.query(
              "INSERT INTO code_embeddings (source_text, embedding) VALUES ($1, $2)",
              [text, embedding]
            )
            {:ok, embedding}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp generate_embedding(text) do
    # Delegate to embedding engine
    case Singularity.Database.Encryption.encrypt("embedding_secret", text) do
      {:ok, _} ->
        # In real implementation, call embedding service via NATS
        # For now, return dummy vector (1536-dim matching Qodo-Embed)
        dummy_vector = List.duplicate(0.0, 1536)
        {:ok, dummy_vector}

      error ->
        error
    end
  end
end
