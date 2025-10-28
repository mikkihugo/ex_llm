defmodule Singularity.Knowledge.ArtifactSemanticSearch do
  @moduledoc """
  Semantic search for knowledge artifacts using vector embeddings.

  Integrates with:
  - **Embedding**: Nx-based Jina v3 (1024-dim, optimized for both code and general text)
  - **Storage**: pgvector in PostgreSQL with ivfflat index (fast similarity search)
  - **Graph**: Combines semantic + graph relationships for knowledge discovery

  ## Semantic Search

  Find similar artifacts by meaning, not just text matching:

  ```elixir
  # Search by query string
  {:ok, results} = ArtifactSemanticSearch.search("async web framework for Elixir")

  # Returns: [
  #   %{artifact_id: "phoenix", similarity: 0.94, relevance: "exact match"},
  #   %{artifact_id: "elixir", similarity: 0.89, relevance: "language"},
  #   %{artifact_id: "async_pattern", similarity: 0.85, relevance: "pattern"}
  # ]
  ```

  ## Semantic + Graph Combined

  Find similar artifacts AND their relationships:

  ```elixir
  # Get semantic matches + their graph relationships
  {:ok, knowledge} = ArtifactSemanticSearch.search_with_graph(
    "authenticated REST API",
    depth: 2
  )

  # Returns: [
  #   %{
  #     artifact: %{artifact_id: "authenticated_json_api", similarity: 0.96},
  #     related: [
  #       %{target: "phoenix", relationship: "has_pattern", confidence: 0.95},
  #       %{target: "elixir_quality", relationship: "governs", confidence: 0.9}
  #     ]
  #   }
  # ]
  ```

  ## Embedding Generation

  All artifacts are automatically embedded:

  ```elixir
  # Generate embeddings for all artifacts (async)
  ArtifactSemanticSearch.generate_embeddings_all()

  # Check embedding status
  {:ok, stats} = ArtifactSemanticSearch.embedding_stats()
  # => %{
  #   total: 123,
  #   with_embeddings: 118,
  #   missing: 5,
  #   model: "qodo+jina_v3",
  #   dimensions: 2560
  # }
  ```

  ## Queries

  ### SQL: Simple Vector Similarity (top 10)

  ```sql
  SELECT
    artifact_id,
    artifact_type,
    (1 - (embedding <=> $1::vector)) as similarity
  FROM curated_knowledge_artifacts
  WHERE embedding IS NOT NULL
  ORDER BY embedding <=> $1::vector
  LIMIT 10;
  ```

  ### SQL: Semantic + Graph Combined

  ```sql
  WITH semantic_matches AS (
    SELECT
      id,
      artifact_id,
      artifact_type,
      (1 - (embedding <=> $1::vector)) as similarity
    FROM curated_knowledge_artifacts
    WHERE embedding IS NOT NULL
    ORDER BY embedding <=> $1::vector
    LIMIT 20
  ),
  with_relationships AS (
    SELECT
      sm.*,
      edge.relationship_type,
      edge.confidence,
      tgt.artifact_id as related_artifact_id
    FROM semantic_matches sm
    LEFT JOIN artifact_graph_edges edge ON edge.source_id = sm.id
    LEFT JOIN artifact_graph_nodes tgt ON edge.target_id = tgt.id
  )
  SELECT
    artifact_id,
    artifact_type,
    similarity,
    json_agg(
      json_build_object(
        'related', related_artifact_id,
        'relationship', relationship_type,
        'confidence', confidence
      )
    ) FILTER (WHERE related_artifact_id IS NOT NULL) as relationships
  FROM with_relationships
  GROUP BY artifact_id, artifact_type, similarity
  ORDER BY similarity DESC;
  ```

  ## Model Architecture

  **Embedding Pipeline:**
  ```
  Input Text
    ↓
  Qodo Embeddings (1536-dim, code-focused)
    ↓
  Jina v3 Embeddings (1024-dim, general text)
    ↓
  Concatenate → 2560-dim vector
    ↓
  pgvector storage
    ↓
  Similarity search (<-> operator)
  ```

  **Distance Metric:** Cosine distance (0.0 = identical, 2.0 = opposite)

  **Similarity Score:** `1 - distance` (0.0 = opposite, 1.0 = identical)
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Schemas.KnowledgeArtifact
  alias Singularity.CodeGeneration.Implementations.EmbeddingGenerator

  require Logger

  @doc """
  Search for artifacts semantically similar to a query string.

  Returns artifacts ranked by cosine similarity, with similarity scores.
  Uses vector embeddings for meaning-based search.

  Options:
  - `:limit` - Number of results (default: 10)
  - `:artifact_types` - Filter by type (default: all)
  - `:min_similarity` - Minimum similarity threshold (default: 0.5)
  """
  def search(query_text, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_similarity = Keyword.get(opts, :min_similarity, 0.5)
    artifact_types = Keyword.get(opts, :artifact_types, nil)

    case generate_embedding(query_text) do
      {:ok, embedding} ->
        embedding_vector = embedding_to_pgvector(embedding)

        query =
          from a in KnowledgeArtifact,
            where: not is_nil(a.embedding),
            select: %{
              artifact_id: a.artifact_id,
              artifact_type: a.artifact_type,
              version: a.version,
              similarity: fragment("1 - (? <=> ?)", a.embedding, ^embedding_vector)
            },
            order_by: [desc: fragment("1 - (? <=> ?)", a.embedding, ^embedding_vector)],
            limit: ^limit

        query =
          if artifact_types do
            where(query, [a], a.artifact_type in ^artifact_types)
          else
            query
          end

        results =
          query
          |> Repo.all()
          |> Enum.filter(fn r -> r.similarity >= min_similarity end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _ -> {:error, "Search failed"}
  end

  @doc """
  Search semantically and include graph relationships.

  Combines vector similarity with artifact graph to show not just
  what's similar, but what those similar artifacts connect to.

  Options:
  - `:limit` - Number of semantic matches (default: 10)
  - `:depth` - Graph traversal depth (default: 2)
  - `:min_similarity` - Minimum similarity threshold (default: 0.5)
  """
  def search_with_graph(query_text, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    depth = Keyword.get(opts, :depth, 2)
    min_similarity = Keyword.get(opts, :min_similarity, 0.5)

    with {:ok, semantic_results} <-
           search(query_text, limit: limit, min_similarity: min_similarity) do
      # Enrich with graph relationships
      enriched =
        Enum.map(semantic_results, fn result ->
          related = get_related_from_graph(result.artifact_id, depth)

          %{
            artifact: result,
            related_count: length(related),
            relationships: related
          }
        end)

      {:ok, enriched}
    else
      error -> error
    end
  end

  @doc """
  Generate embeddings for all artifacts without embeddings.

  Async operation - returns immediately, processes in background.
  Uses EmbeddingGenerator (Nx with Qodo + Jina v3).
  """
  def generate_embeddings_all do
    Task.start(fn ->
      artifacts = Repo.all(from a in KnowledgeArtifact, where: is_nil(a.embedding))

      Enum.each(artifacts, fn artifact ->
        case generate_embedding(artifact.content_raw) do
          {:ok, embedding} ->
            update_embedding(artifact, embedding)
            Logger.info("Generated embedding for #{artifact.artifact_id}")

          {:error, reason} ->
            Logger.warning("Failed to embed #{artifact.artifact_id}: #{reason}")
        end
      end)

      Logger.info("Embedding generation complete")
    end)

    {:ok, "Embedding generation started in background"}
  end

  @doc """
  Get embedding statistics.

  Returns count of artifacts with/without embeddings and model info.
  """
  def embedding_stats do
    total = Repo.aggregate(KnowledgeArtifact, :count)

    with_embeddings =
      Repo.aggregate(from(a in KnowledgeArtifact, where: not is_nil(a.embedding)), :count)

    {:ok,
     %{
       total: total,
       with_embeddings: with_embeddings,
       missing: total - with_embeddings,
       model: "jina_v3",
       dimensions: 1024,
       percentage: if(total > 0, do: Float.round(with_embeddings / total * 100, 1), else: 0)
     }}
  end

  @doc """
  Generate embedding for text using Jina v3.

  Returns 1024-dimensional vector optimized for both code patterns and general text.
  Uses local Nx-based inference (no API calls).
  """
  def generate_embedding(text) when is_binary(text) do
    # Use EmbeddingGenerator with Jina v3 only (1024-dim)
    # Jina v3 balances code-specific patterns with general text understanding
    case EmbeddingGenerator.generate_embedding(text, model: :jina_v3) do
      {:ok, embedding} when is_list(embedding) ->
        # Verify dimension is 1024
        if length(embedding) == 1024 do
          {:ok, embedding}
        else
          {:error, "Expected 1024-dim embedding, got #{length(embedding)}"}
        end

      {:ok, embedding} when is_binary(embedding) ->
        # Parse if returned as string
        case Jason.decode(embedding) do
          {:ok, parsed} when is_list(parsed) and length(parsed) == 1024 ->
            {:ok, parsed}

          {:ok, parsed} ->
            {:error, "Expected 1024-dim, got #{length(parsed)}-dim"}

          {:error, _} ->
            {:error, "Invalid embedding format"}
        end

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Embedding generation failed"}
    end
  rescue
    _ -> {:error, "Embedding generation crashed"}
  end

  # Private Functions

  defp embedding_to_pgvector(embedding) when is_list(embedding) do
    # Convert list to pgvector format
    "[" <> Enum.join(embedding, ",") <> "]"
  end

  defp embedding_to_pgvector(_), do: nil

  defp update_embedding(artifact, embedding) do
    vector_str = embedding_to_pgvector(embedding)

    case Repo.query(
           """
           UPDATE curated_knowledge_artifacts
           SET embedding = $1::vector,
               embedding_model = $2,
               embedding_generated_at = $3
           WHERE id = $4
           """,
           [vector_str, "jina_v3", DateTime.utc_now(), artifact.id]
         ) do
      {:ok, _} -> {:ok, "Embedding updated"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_related_from_graph(artifact_id, depth) do
    query = """
    WITH RECURSIVE artifact_graph AS (
      SELECT
        src.artifact_id as source,
        tgt.artifact_id as target,
        edge.relationship_type,
        edge.confidence,
        1 as d
      FROM artifact_graph_edges edge
      JOIN artifact_graph_nodes src ON edge.source_id = src.id
      JOIN artifact_graph_nodes tgt ON edge.target_id = tgt.id
      WHERE src.artifact_id = $1

      UNION ALL

      SELECT
        ag.source,
        tgt.artifact_id,
        edge.relationship_type,
        edge.confidence,
        ag.d + 1
      FROM artifact_graph ag
      JOIN artifact_graph_edges edge ON edge.source_id =
        (SELECT id FROM artifact_graph_nodes WHERE artifact_id = ag.target)
      JOIN artifact_graph_nodes tgt ON edge.target_id = tgt.id
      WHERE ag.d < $2
    )
    SELECT DISTINCT target, relationship_type, confidence
    FROM artifact_graph
    WHERE target != $1
    ORDER BY confidence DESC
    """

    case Repo.query(query, [artifact_id, depth]) do
      {:ok, result} ->
        Enum.map(result.rows, fn [target, rel_type, confidence] ->
          %{
            target: target,
            relationship: rel_type,
            confidence: confidence
          }
        end)

      {:error, _} ->
        []
    end
  rescue
    _ -> []
  end
end
