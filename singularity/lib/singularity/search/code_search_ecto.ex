defmodule Singularity.CodeSearch.Ecto do
  @moduledoc """
  CodeSearch Ecto Operations - Type-safe database operations for CodeSearch.

  This module provides Ecto-based replacements for Postgrex.query!() calls,
  enabling proper connection pooling, type safety, and error handling.

  ## Migration Path

  Gradually replace calls in code_search.ex like:
  ```elixir
  # OLD: Direct Postgrex (no pooling)
  Postgrex.query!(db_conn, sql, params)

  # NEW: Use Ecto (automatic pooling, type-safe)
  CodeSearch.Ecto.register_codebase(attrs)
  CodeSearch.Ecto.get_codebase_registry(codebase_id)
  ```

  ## Benefits

  - ✅ Automatic connection pooling (fixes >25 concurrent request crashes)
  - ✅ Type-safe changeset validation
  - ✅ Better error handling (returns {:ok, result} | {:error, reason})
  - ✅ Query performance (uses indexes defined in migrations)
  - ✅ Consistency with rest of application
  """

  require Logger
  alias Singularity.Repo
  alias Singularity.Schemas.{
    CodebaseMetadata,
    CodebaseRegistry,
    GraphNode,
    GraphEdge,
    GraphType,
    VectorSearch,
    VectorSimilarityCache
  }

  import Ecto.Query

  # ============================================================================
  # CODEBASE REGISTRY OPERATIONS
  # ============================================================================

  @doc """
  Register a new codebase with metadata.

  Uses upsert (ON CONFLICT) to update existing codebases.
  """
  @spec register_codebase(map(), keyword()) :: {:ok, CodebaseRegistry.t()} | {:error, term()}
  def register_codebase(attrs, opts \\ []) do
    attrs_with_defaults =
      Map.merge(
        %{
          analysis_status: "pending",
          metadata: %{}
        },
        attrs
      )

    %CodebaseRegistry{}
    |> CodebaseRegistry.changeset(attrs_with_defaults)
    |> Repo.insert(
      on_conflict: {:replace, [:codebase_path, :codebase_name, :description, :language, :framework, :metadata, :updated_at]},
      conflict_target: [:codebase_id]
    )
  end

  @doc """
  Get codebase registry entry by codebase_id.
  """
  @spec get_codebase_registry(String.t()) :: CodebaseRegistry.t() | nil
  def get_codebase_registry(codebase_id) do
    Repo.get_by(CodebaseRegistry, codebase_id: codebase_id)
  end

  @doc """
  List all registered codebases, ordered by creation time (newest first).
  """
  @spec list_codebases() :: [CodebaseRegistry.t()]
  def list_codebases do
    CodebaseRegistry
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  List codebases by analysis status.
  """
  @spec list_codebases_by_status(String.t()) :: [CodebaseRegistry.t()]
  def list_codebases_by_status(status) do
    CodebaseRegistry
    |> where(analysis_status: ^status)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Update codebase analysis status.
  """
  @spec update_codebase_status(String.t(), String.t(), DateTime.t() | nil) :: {:ok, CodebaseRegistry.t()} | {:error, term()}
  def update_codebase_status(codebase_id, status, last_analyzed \\ nil) do
    case get_codebase_registry(codebase_id) do
      nil ->
        {:error, :not_found}

      registry ->
        attrs = %{
          analysis_status: status,
          last_analyzed: last_analyzed || DateTime.utc_now()
        }

        registry
        |> CodebaseRegistry.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Delete a codebase registry entry.
  """
  @spec delete_codebase_registry(String.t()) :: {:ok, CodebaseRegistry.t()} | {:error, term()}
  def delete_codebase_registry(codebase_id) do
    case get_codebase_registry(codebase_id) do
      nil ->
        {:error, :not_found}

      registry ->
        Repo.delete(registry)
    end
  end

  # ============================================================================
  # CODEBASE METADATA OPERATIONS
  # ============================================================================

  @doc """
  Create or update codebase metadata for a file.

  Uses upsert to handle updates.
  """
  @spec upsert_metadata(map()) :: {:ok, CodebaseMetadata.t()} | {:error, term()}
  def upsert_metadata(attrs) do
    %CodebaseMetadata{}
    |> CodebaseMetadata.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [
        :size, :lines, :language, :last_modified, :file_type,
        :cyclomatic_complexity, :cognitive_complexity, :maintainability_index,
        :nesting_depth, :function_count, :class_count, :struct_count,
        :enum_count, :trait_count, :interface_count, :total_lines,
        :code_lines, :comment_lines, :blank_lines, :halstead_vocabulary,
        :halstead_length, :halstead_volume, :halstead_difficulty,
        :halstead_effort, :pagerank_score, :centrality_score,
        :dependency_count, :dependent_count, :technical_debt_ratio,
        :code_smells_count, :duplication_percentage, :security_score,
        :vulnerability_count, :quality_score, :test_coverage,
        :documentation_coverage, :domains, :patterns, :features,
        :business_context, :performance_characteristics,
        :security_characteristics, :dependencies, :related_files,
        :imports, :exports, :functions, :classes, :structs, :enums,
        :traits, :vector_embedding, :updated_at
      ]},
      conflict_target: [:codebase_id, :path]
    )
  end

  @doc """
  Get metadata for a specific file.
  """
  @spec get_metadata(String.t(), String.t()) :: CodebaseMetadata.t() | nil
  def get_metadata(codebase_id, path) do
    Repo.get_by(CodebaseMetadata, codebase_id: codebase_id, path: path)
  end

  @doc """
  List metadata for all files in a codebase.
  """
  @spec list_metadata(String.t()) :: [CodebaseMetadata.t()]
  def list_metadata(codebase_id) do
    CodebaseMetadata
    |> where(codebase_id: ^codebase_id)
    |> order_by(:path)
    |> Repo.all()
  end

  @doc """
  List metadata for files with minimum quality score.
  """
  @spec list_metadata_by_quality(String.t(), float()) :: [CodebaseMetadata.t()]
  def list_metadata_by_quality(codebase_id, min_quality) do
    CodebaseMetadata
    |> where(codebase_id: ^codebase_id)
    |> where([m], m.quality_score >= ^min_quality)
    |> order_by(desc: :quality_score)
    |> Repo.all()
  end

  @doc """
  List metadata for files with language filter.
  """
  @spec list_metadata_by_language(String.t(), String.t()) :: [CodebaseMetadata.t()]
  def list_metadata_by_language(codebase_id, language) do
    CodebaseMetadata
    |> where(codebase_id: ^codebase_id)
    |> where(language: ^language)
    |> order_by(:path)
    |> Repo.all()
  end

  @doc """
  Delete metadata for a file.
  """
  @spec delete_metadata(String.t(), String.t()) :: {:ok, CodebaseMetadata.t()} | {:error, term()}
  def delete_metadata(codebase_id, path) do
    case get_metadata(codebase_id, path) do
      nil ->
        {:error, :not_found}

      metadata ->
        Repo.delete(metadata)
    end
  end

  # ============================================================================
  # VECTOR SEARCH OPERATIONS
  # ============================================================================

  @doc """
  Create or update vector search entry.

  Uses upsert to handle updates.
  """
  @spec upsert_vector_search(map()) :: {:ok, VectorSearch.t()} | {:error, term()}
  def upsert_vector_search(attrs) do
    %VectorSearch{}
    |> VectorSearch.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:content, :vector_embedding, :metadata, :updated_at]},
      conflict_target: [:codebase_id, :file_path, :content_type]
    )
  end

  @doc """
  Get vector search entry by codebase_id, file_path, and content_type.
  """
  @spec get_vector_search(String.t(), String.t(), String.t()) :: VectorSearch.t() | nil
  def get_vector_search(codebase_id, file_path, content_type) do
    Repo.get_by(VectorSearch, codebase_id: codebase_id, file_path: file_path, content_type: content_type)
  end

  @doc """
  List vector searches for a codebase.
  """
  @spec list_vector_searches(String.t()) :: [VectorSearch.t()]
  def list_vector_searches(codebase_id) do
    VectorSearch
    |> where(codebase_id: ^codebase_id)
    |> Repo.all()
  end

  @doc """
  Search for similar vectors using cosine distance.

  Note: This is a basic implementation. For production, use pgvector operators
  directly via Ecto.Adapters.SQL if needed for performance.
  """
  @spec search_similar_vectors(String.t(), Pgvector.t(), non_neg_integer()) :: [VectorSearch.t()]
  def search_similar_vectors(codebase_id, query_vector, limit \\ 10) do
    VectorSearch
    |> where(codebase_id: ^codebase_id)
    |> order_by([v], fragment("? <-> ?", v.vector_embedding, ^query_vector))
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Delete vector search entry.
  """
  @spec delete_vector_search(String.t(), String.t(), String.t()) :: {:ok, VectorSearch.t()} | {:error, term()}
  def delete_vector_search(codebase_id, file_path, content_type) do
    case get_vector_search(codebase_id, file_path, content_type) do
      nil ->
        {:error, :not_found}

      vector_search ->
        Repo.delete(vector_search)
    end
  end

  # ============================================================================
  # VECTOR SIMILARITY CACHE OPERATIONS
  # ============================================================================

  @doc """
  Cache a similarity score.

  Uses upsert to handle updates.
  """
  @spec cache_similarity(String.t(), String.t(), String.t(), float()) :: {:ok, VectorSimilarityCache.t()} | {:error, term()}
  def cache_similarity(codebase_id, query_vector_hash, target_file_path, similarity_score) do
    attrs = %{
      codebase_id: codebase_id,
      query_vector_hash: query_vector_hash,
      target_file_path: target_file_path,
      similarity_score: similarity_score
    }

    %VectorSimilarityCache{}
    |> VectorSimilarityCache.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:similarity_score, :updated_at]},
      conflict_target: [:codebase_id, :query_vector_hash, :target_file_path]
    )
  end

  @doc """
  Get cached similarity score.
  """
  @spec get_cached_similarity(String.t(), String.t(), String.t()) :: VectorSimilarityCache.t() | nil
  def get_cached_similarity(codebase_id, query_vector_hash, target_file_path) do
    Repo.get_by(VectorSimilarityCache,
      codebase_id: codebase_id,
      query_vector_hash: query_vector_hash,
      target_file_path: target_file_path
    )
  end

  @doc """
  List cached similarities for a query vector.
  """
  @spec list_cached_similarities(String.t(), String.t()) :: [VectorSimilarityCache.t()]
  def list_cached_similarities(codebase_id, query_vector_hash) do
    VectorSimilarityCache
    |> where(codebase_id: ^codebase_id)
    |> where(query_vector_hash: ^query_vector_hash)
    |> order_by(desc: :similarity_score)
    |> Repo.all()
  end

  @doc """
  Clear cache entries older than specified age (in seconds).
  """
  @spec clear_old_cache(non_neg_integer()) :: {non_neg_integer(), nil}
  def clear_old_cache(age_seconds \\ 86_400) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -age_seconds)

    VectorSimilarityCache
    |> where([c], c.inserted_at < ^cutoff_time)
    |> Repo.delete_all()
  end

  # ============================================================================
  # GRAPH OPERATIONS
  # ============================================================================

  @doc """
  Create or update a graph node.

  Uses upsert to handle updates.
  """
  @spec upsert_graph_node(map()) :: {:ok, GraphNode.t()} | {:error, term()}
  def upsert_graph_node(attrs) do
    %GraphNode{}
    |> GraphNode.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:node_type, :name, :file_path, :line_number, :vector_embedding, :vector_magnitude, :metadata, :updated_at]},
      conflict_target: [:codebase_id, :node_id]
    )
  end

  @doc """
  Get graph node by codebase_id and node_id.
  """
  @spec get_graph_node(String.t(), String.t()) :: GraphNode.t() | nil
  def get_graph_node(codebase_id, node_id) do
    Repo.get_by(GraphNode, codebase_id: codebase_id, node_id: node_id)
  end

  @doc """
  List graph nodes for a codebase.
  """
  @spec list_graph_nodes(String.t()) :: [GraphNode.t()]
  def list_graph_nodes(codebase_id) do
    GraphNode
    |> where(codebase_id: ^codebase_id)
    |> Repo.all()
  end

  @doc """
  List graph nodes by type.
  """
  @spec list_graph_nodes_by_type(String.t(), String.t()) :: [GraphNode.t()]
  def list_graph_nodes_by_type(codebase_id, node_type) do
    GraphNode
    |> where(codebase_id: ^codebase_id)
    |> where(node_type: ^node_type)
    |> Repo.all()
  end

  @doc """
  Create or update a graph edge.

  Uses upsert to handle updates.
  """
  @spec upsert_graph_edge(map()) :: {:ok, GraphEdge.t()} | {:error, term()}
  def upsert_graph_edge(attrs) do
    %GraphEdge{}
    |> GraphEdge.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:from_node_id, :to_node_id, :edge_type, :weight, :metadata, :updated_at]},
      conflict_target: [:codebase_id, :edge_id]
    )
  end

  @doc """
  Get graph edge by codebase_id and edge_id.
  """
  @spec get_graph_edge(String.t(), String.t()) :: GraphEdge.t() | nil
  def get_graph_edge(codebase_id, edge_id) do
    Repo.get_by(GraphEdge, codebase_id: codebase_id, edge_id: edge_id)
  end

  @doc """
  List graph edges for a codebase.
  """
  @spec list_graph_edges(String.t()) :: [GraphEdge.t()]
  def list_graph_edges(codebase_id) do
    GraphEdge
    |> where(codebase_id: ^codebase_id)
    |> Repo.all()
  end

  @doc """
  List edges from a source node.
  """
  @spec list_edges_from_node(String.t(), String.t()) :: [GraphEdge.t()]
  def list_edges_from_node(codebase_id, from_node_id) do
    GraphEdge
    |> where(codebase_id: ^codebase_id)
    |> where(from_node_id: ^from_node_id)
    |> Repo.all()
  end

  @doc """
  List edges to a target node.
  """
  @spec list_edges_to_node(String.t(), String.t()) :: [GraphEdge.t()]
  def list_edges_to_node(codebase_id, to_node_id) do
    GraphEdge
    |> where(codebase_id: ^codebase_id)
    |> where(to_node_id: ^to_node_id)
    |> Repo.all()
  end

  @doc """
  Get or create a graph type.
  """
  @spec ensure_graph_type(String.t(), String.t() | nil) :: {:ok, GraphType.t()} | {:error, term()}
  def ensure_graph_type(graph_type, description \\ nil) do
    case Repo.get_by(GraphType, graph_type: graph_type) do
      nil ->
        %GraphType{}
        |> GraphType.changeset(%{graph_type: graph_type, description: description})
        |> Repo.insert()

      existing ->
        {:ok, existing}
    end
  end

  @doc """
  List all graph types.
  """
  @spec list_graph_types() :: [GraphType.t()]
  def list_graph_types do
    Repo.all(GraphType)
  end

  # ============================================================================
  # QUERY HELPERS
  # ============================================================================

  @doc """
  Get dependencies of a node (outgoing edges).

  Returns list of nodes that this node points to, ordered by edge weight.
  """
  @spec get_dependencies(String.t()) :: [map()]
  def get_dependencies(from_node_id) do
    GraphEdge
    |> where(from_node_id: ^from_node_id)
    |> join(:inner, [ge], gn in GraphNode, on: ge.to_node_id == gn.node_id)
    |> select([ge, gn], %{
      node_id: gn.node_id,
      name: gn.name,
      file_path: gn.file_path,
      node_type: gn.node_type,
      edge_type: ge.edge_type,
      weight: ge.weight
    })
    |> order_by([ge], desc: ge.weight)
    |> Repo.all()
  end

  @doc """
  Get dependents of a node (incoming edges).

  Returns list of nodes that point to this node, ordered by edge weight.
  """
  @spec get_dependents(String.t()) :: [map()]
  def get_dependents(to_node_id) do
    GraphEdge
    |> where(to_node_id: ^to_node_id)
    |> join(:inner, [ge], gn in GraphNode, on: ge.from_node_id == gn.node_id)
    |> select([ge, gn], %{
      node_id: gn.node_id,
      name: gn.name,
      file_path: gn.file_path,
      node_type: gn.node_type,
      edge_type: ge.edge_type,
      weight: ge.weight
    })
    |> order_by([ge], desc: ge.weight)
    |> Repo.all()
  end

  @doc """
  Count files in a codebase.
  """
  @spec count_files(String.t()) :: non_neg_integer()
  def count_files(codebase_id) do
    CodebaseMetadata
    |> where(codebase_id: ^codebase_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Get statistics for a codebase.
  """
  @spec get_codebase_stats(String.t()) :: map()
  def get_codebase_stats(codebase_id) do
    metadata_list = list_metadata(codebase_id)

    %{
      total_files: length(metadata_list),
      total_lines: Enum.sum(Enum.map(metadata_list, & &1.total_lines)),
      total_functions: Enum.sum(Enum.map(metadata_list, & &1.function_count)),
      avg_quality_score: if(length(metadata_list) > 0, do: Enum.sum(Enum.map(metadata_list, & &1.quality_score)) / length(metadata_list), else: 0.0),
      avg_complexity: if(length(metadata_list) > 0, do: Enum.sum(Enum.map(metadata_list, & &1.cyclomatic_complexity)) / length(metadata_list), else: 0.0)
    }
  end

  @doc """
  Find similar nodes using vector similarity.

  Finds nodes with similar embeddings to the query node, ordered by cosine similarity.
  Uses pgvector distance operator (<->) for fast approximate nearest neighbor search.
  """
  @spec find_similar_nodes(String.t(), String.t(), non_neg_integer()) :: [map()]
  def find_similar_nodes(codebase_id, query_node_id, top_k \\ 10) do
    # Get the query node's embedding
    query_node =
      GraphNode
      |> where(codebase_id: ^codebase_id, node_id: ^query_node_id)
      |> select([gn], gn.vector_embedding)
      |> Repo.one()

    case query_node do
      nil ->
        []

      query_vector ->
        # Find similar nodes using vector distance
        GraphNode
        |> where(codebase_id: ^codebase_id)
        |> where([gn], gn.node_id != ^query_node_id)
        |> where([gn], not is_nil(gn.vector_embedding))
        |> select([gn], %{
          node_id: gn.node_id,
          name: gn.name,
          file_path: gn.file_path,
          node_type: gn.node_type,
          cosine_similarity: fragment("1 - (? <-> ?)", gn.vector_embedding, ^query_vector),
          combined_similarity: fragment("1 - (? <-> ?)", gn.vector_embedding, ^query_vector)
        })
        |> order_by([gn], desc: fragment("1 - (? <-> ?)", gn.vector_embedding, ^query_vector))
        |> limit(^top_k)
        |> Repo.all()
    end
  end

  @doc """
  Perform semantic search using vector similarity.

  Searches for files with similar embeddings to the query vector.
  Uses pgvector distance operator (<->) for fast approximate nearest neighbor search.
  """
  @spec semantic_search(String.t(), binary(), non_neg_integer()) :: [map()]
  def semantic_search(codebase_id, query_vector, limit \\ 10) do
    CodebaseMetadata
    |> where(codebase_id: ^codebase_id)
    |> where([cm], not is_nil(cm.vector_embedding))
    |> select([cm], %{
      path: cm.path,
      language: cm.language,
      file_type: cm.file_type,
      quality_score: cm.quality_score,
      maintainability_index: cm.maintainability_index,
      distance: fragment("? <-> ?", cm.vector_embedding, ^query_vector),
      similarity_score: fragment("1 - (? <-> ?)", cm.vector_embedding, ^query_vector)
    })
    |> order_by([cm], fragment("? <-> ?", cm.vector_embedding, ^query_vector))
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Search across multiple codebases using vector similarity.

  Searches for similar files across multiple codebases efficiently.
  Uses Ecto.Adapters.SQL for raw SQL support while maintaining connection pooling.
  """
  @spec multi_codebase_search([String.t()], binary(), non_neg_integer()) :: [map()]
  def multi_codebase_search(codebase_ids, query_vector, limit \\ 10) when is_list(codebase_ids) do
    placeholders = Enum.map(1..length(codebase_ids), fn i -> "$#{i}" end) |> Enum.join(",")

    query = """
    SELECT
      codebase_id,
      path,
      language,
      file_type,
      quality_score,
      maintainability_index,
      vector_embedding <-> $#{length(codebase_ids) + 1} as distance,
      1 - (vector_embedding <-> $#{length(codebase_ids) + 1}) as similarity_score
    FROM codebase_metadata
    WHERE codebase_id IN (#{placeholders}) AND vector_embedding IS NOT NULL
    ORDER BY vector_embedding <-> $#{length(codebase_ids) + 1}
    LIMIT $#{length(codebase_ids) + 2}
    """

    params = codebase_ids ++ [query_vector, limit]

    case Ecto.Adapters.SQL.query(Repo, query, params) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [
                            codebase_id,
                            path,
                            language,
                            file_type,
                            quality_score,
                            maintainability_index,
                            _distance,
                            similarity_score
                          ] ->
          %{
            codebase_id: codebase_id,
            path: path,
            language: language,
            file_type: file_type,
            quality_score: quality_score,
            maintainability_index: maintainability_index,
            similarity_score: similarity_score
          }
        end)

      {:error, reason} ->
        raise "multi_codebase_search failed: #{inspect(reason)}"
    end
  end

  @doc """
  Detect circular dependencies using recursive graph traversal.

  Uses PostgreSQL recursive CTE to find circular dependencies.
  Uses Ecto.Adapters.SQL for raw SQL support while maintaining connection pooling.
  """
  @spec detect_circular_dependencies() :: [map()]
  def detect_circular_dependencies do
    query = """
    WITH RECURSIVE dependency_path AS (
      -- Base case: all edges
      SELECT
        from_node_id as start_node,
        to_node_id as end_node,
        from_node_id,
        to_node_id,
        edge_type,
        weight,
        1 as depth,
        ARRAY[from_node_id, to_node_id] as path
      FROM graph_edges

      UNION ALL

      -- Recursive case: extend paths
      SELECT
        dp.start_node,
        ge.to_node_id as end_node,
        dp.from_node_id,
        ge.to_node_id,
        ge.edge_type,
        ge.weight,
        dp.depth + 1,
        dp.path || ge.to_node_id
      FROM dependency_path dp
      JOIN graph_edges ge ON dp.to_node_id = ge.from_node_id
      WHERE dp.depth < 10
        AND NOT ge.to_node_id = ANY(dp.path)
    )
    SELECT DISTINCT
      start_node,
      end_node,
      path,
      depth
    FROM dependency_path
    WHERE start_node = end_node
    ORDER BY depth
    """

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [start_node, end_node, path, depth] ->
          %{
            start_node: start_node,
            end_node: end_node,
            path: path,
            depth: depth
          }
        end)

      {:error, reason} ->
        raise "detect_circular_dependencies failed: #{inspect(reason)}"
    end
  end

  @doc """
  Calculate PageRank scores for all nodes using iterative algorithm.

  Simplified PageRank implementation using recursive CTE.
  Uses Ecto.Adapters.SQL for raw SQL support while maintaining connection pooling.
  """
  @spec calculate_pagerank(non_neg_integer(), float()) :: [map()]
  def calculate_pagerank(iterations \\ 20, damping_factor \\ 0.85) do
    query = """
    WITH RECURSIVE pagerank_iteration AS (
      -- Initialize PageRank scores
      SELECT
        node_id,
        1.0 / (SELECT COUNT(*) FROM graph_nodes) as pagerank_score,
        0 as iteration
      FROM graph_nodes

      UNION ALL

      -- Iterate PageRank calculation
      SELECT
        gn.node_id,
        (1 - $2) / (SELECT COUNT(*) FROM graph_nodes) +
        $2 * COALESCE(SUM(pr.pagerank_score / out_degree.out_count), 0) as pagerank_score,
        pr.iteration + 1
      FROM graph_nodes gn
      JOIN pagerank_iteration pr ON pr.iteration < $1
      LEFT JOIN graph_edges ge ON ge.to_node_id = gn.node_id
      LEFT JOIN (
        SELECT from_node_id, COUNT(*) as out_count
        FROM graph_edges
        GROUP BY from_node_id
      ) out_degree ON out_degree.from_node_id = ge.from_node_id
      WHERE pr.iteration = (
        SELECT MAX(iteration) FROM pagerank_iteration
      )
      GROUP BY gn.node_id, pr.iteration
    )
    SELECT
      node_id,
      pagerank_score
    FROM pagerank_iteration
    WHERE iteration = $1
    ORDER BY pagerank_score DESC
    """

    case Ecto.Adapters.SQL.query(Repo, query, [iterations, damping_factor]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [node_id, pagerank_score] ->
          %{
            node_id: node_id,
            pagerank_score: pagerank_score
          }
        end)

      {:error, reason} ->
        raise "calculate_pagerank failed: #{inspect(reason)}"
    end
  end

  @doc """
  Calculate and persist PageRank scores to graph_nodes table.

  Calculates PageRank for all nodes and updates the pagerank_score column
  in the graph_nodes table. This allows queries to find high-importance nodes.

  ## Parameters
  - `iterations` - Number of PageRank iterations (default: 20)
  - `damping_factor` - Damping factor for PageRank (default: 0.85)

  ## Returns
  - `{:ok, count}` - Number of nodes updated
  - `{:error, reason}` - Update failed

  ## Examples

      iex> CodeSearch.Ecto.persist_pagerank_scores()
      {:ok, 147}

      iex> CodeSearch.Ecto.persist_pagerank_scores(30, 0.85)
      {:ok, 147}
  """
  @spec persist_pagerank_scores(non_neg_integer(), float()) :: {:ok, non_neg_integer()} | {:error, term()}
  def persist_pagerank_scores(iterations \\ 20, damping_factor \\ 0.85) do
    try do
      # Calculate PageRank scores
      scores = calculate_pagerank(iterations, damping_factor)

      # Update each node with its PageRank score
      updated_count =
        Enum.reduce(scores, 0, fn %{node_id: node_id, pagerank_score: score}, count ->
          case Repo.update_all(
            from(gn in GraphNode, where: gn.node_id == ^node_id),
            set: [pagerank_score: score]
          ) do
            {1, _} -> count + 1
            _ -> count
          end
        end)

      {:ok, updated_count}
    rescue
      e ->
        Logger.error("Failed to persist PageRank scores", error: inspect(e))
        {:error, {:persist_failed, inspect(e)}}
    end
  end

  @doc """
  Get nodes sorted by PageRank score (most important first).

  Returns nodes ordered by PageRank score in descending order.

  ## Parameters
  - `codebase_id` - Codebase to query (optional, all if not specified)
  - `limit` - Maximum number of results (default: 10)

  ## Returns
  - List of nodes with highest PageRank scores

  ## Examples

      iex> CodeSearch.Ecto.get_top_nodes_by_pagerank("my-codebase", 5)
      [
        %{node_id: "123", name: "main", pagerank_score: 0.89},
        %{node_id: "456", name: "init", pagerank_score: 0.67},
        ...
      ]
  """
  @spec get_top_nodes_by_pagerank(String.t() | nil, non_neg_integer()) :: [map()]
  def get_top_nodes_by_pagerank(codebase_id \\ nil, limit \\ 10) do
    query =
      GraphNode
      |> where([gn], gn.pagerank_score > 0.0)

    query =
      if codebase_id do
        where(query, [gn], gn.codebase_id == ^codebase_id)
      else
        query
      end

    query
    |> order_by([gn], desc: gn.pagerank_score)
    |> limit(^limit)
    |> select([gn], %{
      node_id: gn.node_id,
      name: gn.name,
      file_path: gn.file_path,
      node_type: gn.node_type,
      pagerank_score: gn.pagerank_score,
      codebase_id: gn.codebase_id
    })
    |> Repo.all()
  end
end
