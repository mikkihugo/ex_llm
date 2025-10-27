defmodule Singularity.Search.PostgresVectorSearch do
  @moduledoc """
  PostgreSQL Native Vector Search - High-performance vector operations using pgvector

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.Search.PostgresVectorSearch",
    "purpose": "Native PostgreSQL vector search using pgvector extension",
    "type": "Search service (PostgreSQL-native)",
    "operates_on": "code_embeddings, todos, knowledge_artifacts tables",
    "storage": "PostgreSQL with pgvector extension",
    "dependencies": ["Repo", "pgvector extension"]
  }
  ```

  ## Architecture (Mermaid)

  ```mermaid
  graph TD
      A[PostgresVectorSearch] -->|SQL functions| B[PostgreSQL]
      B -->|pgvector ops| C[(Vector Indexes)]
      A -->|Fallback| D[EmbeddingService]
      D -->|HTTP| E[Google AI Studio]
  ```

  ## Call Graph (YAML)

  ```yaml
  PostgresVectorSearch:
    calls:
      - Repo.query/1  # Execute vector search functions
      - EmbeddingGenerator.embed/1  # Generate embeddings
    called_by:
      - CodeSearch  # When vector search is needed
      - TodoStore  # For todo similarity
      - Knowledge.ArtifactStore  # For knowledge search
    alternative:
      - EmbeddingService  # Fallback to HTTP-based search
  ```

  ## Anti-Patterns

  **DO NOT create these duplicates:**
  - ❌ `VectorSearch` - This IS the vector search module
  - ❌ `PgVectorSearch` - Redundant naming
  - ❌ `CodeVectorSearch` - This handles all vector types

  **Use this module when:**
  - ✅ Need high-performance vector search
  - ✅ Have embeddings already generated
  - ✅ Want to leverage pgvector indexes

  **Use EmbeddingService when:**
  - ✅ Need to generate embeddings first
  - ✅ Simple similarity without advanced features

  ## Search Keywords

  pgvector, vector-search, similarity-search, cosine-similarity, ivfflat-index,
  hnsw-index, embedding-search, semantic-search, postgresql-vector, performance-optimized
  """

  alias Singularity.Repo
  alias Singularity.Search.EmbeddingService
  alias Singularity.Embedding.NxService

  @doc """
  Find similar code using PostgreSQL vector functions.

  ## Examples

      iex> PostgresVectorSearch.find_similar_code("async worker implementation")
      {:ok, [
        %{code_id: "...", content: "...", similarity: 0.94, file_path: "lib/worker.ex"},
        %{code_id: "...", content: "...", similarity: 0.87, file_path: "lib/async.ex"}
      ]}

      iex> PostgresVectorSearch.find_similar_code("database query", threshold: 0.9, limit: 5)
      {:ok, [...]}
  """
  def find_similar_code(query, _opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.8)
    limit = Keyword.get(opts, :limit, 10)

    with {:ok, embedding} <- generate_embedding(query) do
      query_sql = """
      SELECT * FROM find_similar_code_vectors($1, $2, $3)
      """

      case Repo.query(query_sql, [embedding, threshold, limit]) do
        {:ok, result} ->
          results =
            Enum.map(result.rows, fn row ->
              [code_id, content, similarity, file_path, language] = row

              %{
                code_id: code_id,
                content: content,
                similarity: similarity,
                file_path: file_path,
                language: language
              }
            end)

          {:ok, results}

        {:error, reason} ->
          {:error, "Vector search failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Find similar todos using PostgreSQL vector functions.

  ## Examples

      iex> PostgresVectorSearch.find_similar_todos("implement user authentication")
      {:ok, [
        %{todo_id: "...", title: "Add login system", similarity: 0.92},
        %{todo_id: "...", title: "Setup JWT tokens", similarity: 0.88}
      ]}
  """
  def find_similar_todos(query, _opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.8)
    limit = Keyword.get(opts, :limit, 10)

    with {:ok, embedding} <- generate_embedding(query) do
      query_sql = """
      SELECT * FROM find_similar_todos($1, $2, $3)
      """

      case Repo.query(query_sql, [embedding, threshold, limit]) do
        {:ok, result} ->
          results =
            Enum.map(result.rows, fn row ->
              [todo_id, title, description, similarity, status, priority] = row

              %{
                todo_id: todo_id,
                title: title,
                description: description,
                similarity: similarity,
                status: status,
                priority: priority
              }
            end)

          {:ok, results}

        {:error, reason} ->
          {:error, "Todo vector search failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Find similar knowledge artifacts using PostgreSQL vector functions.

  ## Examples

      iex> PostgresVectorSearch.find_similar_knowledge("elixir best practices")
      {:ok, [
        %{artifact_id: "...", name: "elixir_production.json", similarity: 0.95},
        %{artifact_id: "...", name: "phoenix_patterns.json", similarity: 0.89}
      ]}

      iex> PostgresVectorSearch.find_similar_knowledge("testing", artifact_type: "quality_template")
      {:ok, [...]}
  """
  def find_similar_knowledge(query, _opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.8)
    limit = Keyword.get(opts, :limit, 10)
    artifact_type = Keyword.get(opts, :artifact_type)

    with {:ok, embedding} <- generate_embedding(query) do
      query_sql = """
      SELECT * FROM find_similar_knowledge($1, $2, $3, $4)
      """

      case Repo.query(query_sql, [embedding, artifact_type, threshold, limit]) do
        {:ok, result} ->
          results =
            Enum.map(result.rows, fn row ->
              [artifact_id, name, content, similarity, artifact_type, language] = row

              %{
                artifact_id: artifact_id,
                name: name,
                content: content,
                similarity: similarity,
                artifact_type: artifact_type,
                language: language
              }
            end)

          {:ok, results}

        {:error, reason} ->
          {:error, "Knowledge vector search failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Perform hybrid search combining vector similarity and text search.

  ## Examples

      iex> PostgresVectorSearch.hybrid_search("async worker with error handling")
      {:ok, [
        %{code_id: "...", content: "...", combined_score: 0.92, vector_score: 0.89, text_score: 0.95},
        %{code_id: "...", content: "...", combined_score: 0.87, vector_score: 0.85, text_score: 0.89}
      ]}
  """
  def hybrid_search(query, _opts \\ []) do
    vector_weight = Keyword.get(opts, :vector_weight, 0.7)
    text_weight = Keyword.get(opts, :text_weight, 0.3)
    threshold = Keyword.get(opts, :threshold, 0.6)
    limit = Keyword.get(opts, :limit, 20)

    with {:ok, embedding} <- generate_embedding(query) do
      query_sql = """
      SELECT * FROM hybrid_search($1, $2, $3, $4, $5, $6)
      """

      case Repo.query(query_sql, [query, embedding, vector_weight, text_weight, threshold, limit]) do
        {:ok, result} ->
          results =
            Enum.map(result.rows, fn row ->
              [code_id, content, file_path, language, vector_score, text_score, combined_score] =
                row

              %{
                code_id: code_id,
                content: content,
                file_path: file_path,
                language: language,
                vector_score: vector_score,
                text_score: text_score,
                combined_score: combined_score
              }
            end)

          {:ok, results}

        {:error, reason} ->
          {:error, "Hybrid search failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Cluster code vectors using PostgreSQL functions.

  ## Examples

      iex> PostgresVectorSearch.cluster_code_vectors()
      {:ok, [
        %{cluster_id: 1, code_id: "...", content: "...", distance_to_centroid: 0.23},
        %{cluster_id: 2, code_id: "...", content: "...", distance_to_centroid: 0.31}
      ]}
  """
  def cluster_code_vectors(_opts \\ []) do
    cluster_count = Keyword.get(opts, :cluster_count, 10)
    min_cluster_size = Keyword.get(opts, :min_cluster_size, 5)

    query_sql = """
    SELECT * FROM cluster_code_vectors($1, $2)
    """

    case Repo.query(query_sql, [cluster_count, min_cluster_size]) do
      {:ok, result} ->
        results =
          Enum.map(result.rows, fn row ->
            [cluster_id, code_id, content, file_path, distance_to_centroid] = row

            %{
              cluster_id: cluster_id,
              code_id: code_id,
              content: content,
              file_path: file_path,
              distance_to_centroid: distance_to_centroid
            }
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, "Vector clustering failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Get vector search performance metrics.

  ## Examples

      iex> PostgresVectorSearch.get_performance_metrics()
      {:ok, %{
        total_embeddings: 15420,
        index_size: "2.3 GB",
        avg_query_time: "12.5 ms",
        cache_hit_ratio: 0.87
      }}
  """
  def get_performance_metrics do
    query_sql = """
    SELECT 
      (SELECT count(*) FROM code_embeddings) as total_embeddings,
      pg_size_pretty(pg_total_relation_size('code_embeddings')) as index_size,
      (SELECT avg(mean_exec_time) FROM pg_stat_statements WHERE query LIKE '%find_similar_code_vectors%') as avg_query_time,
      (SELECT round(blks_hit::float / (blks_hit + blks_read), 2) FROM pg_stat_database WHERE datname = current_database()) as cache_hit_ratio
    """

    case Repo.query(query_sql) do
      {:ok, result} ->
        case result.rows do
          [[total_embeddings, index_size, avg_query_time, cache_hit_ratio] | _] ->
            {:ok,
             %{
               total_embeddings: total_embeddings,
               index_size: index_size,
               avg_query_time: avg_query_time,
               cache_hit_ratio: cache_hit_ratio
             }}

          [] ->
            {:ok,
             %{
               total_embeddings: 0,
               index_size: "0 bytes",
               avg_query_time: "0 ms",
               cache_hit_ratio: 0.0
             }}
        end

      {:error, reason} ->
        {:error, "Performance metrics failed: #{inspect(reason)}"}
    end
  end

  # Private functions

  defp generate_embedding(text) do
    case NxService.embed(text) do
      {:ok, embedding} -> {:ok, embedding}
      {:error, reason} -> {:error, "Multi-vector embedding generation failed: #{inspect(reason)}"}
    end
  end
end
