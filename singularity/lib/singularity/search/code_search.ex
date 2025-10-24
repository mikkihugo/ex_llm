defmodule Singularity.CodeSearch do
  @moduledoc """
  Code Search - Find code using natural language and embeddings

  This module provides semantic search capabilities for codebases using pgvector
  embeddings and PostgreSQL. It enables natural language queries like:
  - "Find authentication code"
  - "Show me error handling patterns"
  - "Where is user validation?"

  ## Features

  ### Semantic Search with Vector Embeddings
  - **Natural Language Queries**: Ask questions, find code
  - **Similarity Matching**: Find related/duplicate code
  - **50+ Code Metrics**: Complexity, quality, security, performance
  - **Multi-Language**: Rust, Elixir, Gleam, TypeScript

  ### Graph-Based Code Analysis
  - **Apache AGE**: Graph database for code relationships
  - **Dependency Analysis**: Track imports, function calls
  - **Impact Analysis**: What code depends on this?
  - **Graph Algorithms**: PageRank, centrality, shortest path

  ### Performance & Scalability
  - **Indexed Vector Search**: Fast similarity lookups with IVFFlat
  - **Batch Processing**: Embed entire codebases efficiently
  - **Incremental Updates**: Only re-embed changed files
  """

  require Logger

  @doc """
  Create unified codebase schema in PostgreSQL

  DEPRECATED: Schema is now managed by migrations.
  This function is kept for backward compatibility.
  All tables are automatically created when you run `mix ecto.migrate`.
  """
  def create_unified_schema(_db_conn) do
    Logger.info("create_unified_schema deprecated - use migrations instead: mix ecto.migrate")
    :ok
  end

  @doc """
  Register a new codebase
  """
  def register_codebase(_db_conn, codebase_id, codebase_path, codebase_name, opts \\ []) do
    description = Keyword.get(opts, :description, "")
    language = Keyword.get(opts, :language, "unknown")
    framework = Keyword.get(opts, :framework, "unknown")
    metadata = Keyword.get(opts, :metadata, %{})

    attrs = %{
      codebase_id: codebase_id,
      codebase_path: codebase_path,
      codebase_name: codebase_name,
      description: description,
      language: language,
      framework: framework,
      metadata: metadata
    }

    Singularity.CodeSearch.Ecto.register_codebase(attrs)
  end

  @doc """
  Get codebase registry entry (converted to Ecto)
  """
  def get_codebase_registry(_db_conn, codebase_id) do
    case Singularity.CodeSearch.Ecto.get_codebase_registry(codebase_id) do
      nil ->
        nil

      registry ->
        %{
          codebase_id: registry.codebase_id,
          codebase_path: registry.codebase_path,
          codebase_name: registry.codebase_name,
          description: registry.description,
          language: registry.language,
          framework: registry.framework,
          last_analyzed: registry.last_analyzed,
          analysis_status: registry.analysis_status,
          metadata: registry.metadata,
          created_at: registry.inserted_at,
          updated_at: registry.updated_at
        }
    end
  end

  @doc """
  List all registered codebases (converted to Ecto)
  """
  def list_codebases(_db_conn) do
    Singularity.CodeSearch.Ecto.list_codebases()
    |> Enum.map(fn registry ->
      %{
        codebase_id: registry.codebase_id,
        codebase_path: registry.codebase_path,
        codebase_name: registry.codebase_name,
        description: registry.description,
        language: registry.language,
        framework: registry.framework,
        last_analyzed: registry.last_analyzed,
        analysis_status: registry.analysis_status,
        created_at: registry.inserted_at,
        updated_at: registry.updated_at
      }
    end)
  end

  @doc """
  Update codebase analysis status
  """
  def update_codebase_status(_db_conn, codebase_id, status, opts \\ []) do
    last_analyzed = Keyword.get(opts, :last_analyzed, DateTime.utc_now())
    Singularity.CodeSearch.Ecto.update_codebase_status(codebase_id, status, last_analyzed)
  end

  @doc """
  Insert codebase metadata (converted to Ecto)
  """
  def insert_codebase_metadata(_db_conn, codebase_id, codebase_path, metadata) do
    attrs =
      metadata
      |> Map.put(:codebase_id, codebase_id)
      |> Map.put(:codebase_path, codebase_path)

    Singularity.CodeSearch.Ecto.upsert_metadata(attrs)
  end

  @doc """
  Insert graph node (converted to Ecto)
  """
  def insert_graph_node(_db_conn, codebase_id, node) do
    attrs =
      node
      |> Map.put(:codebase_id, codebase_id)

    Singularity.CodeSearch.Ecto.upsert_graph_node(attrs)
  end

  @doc """
  Insert graph edge (converted to Ecto)
  """
  def insert_graph_edge(_db_conn, codebase_id, edge) do
    attrs =
      edge
      |> Map.put(:codebase_id, codebase_id)

    Singularity.CodeSearch.Ecto.upsert_graph_edge(attrs)
  end

  @doc """
  Perform semantic search using vector similarity

  Accepts either an Ecto.Repo module or a raw Postgrex connection.
  Using Repo (recommended) leverages connection pooling for better performance.

  ## Examples

      # With Ecto.Repo (recommended - uses connection pooling)
      CodeSearch.semantic_search(Singularity.Repo, "my-codebase", vector, 10)

      # With raw Postgrex connection (for backwards compatibility)
      {:ok, conn} = Postgrex.start_link(...)
      CodeSearch.semantic_search(conn, "my-codebase", vector, 10)
  """
  def semantic_search(repo_or_conn, codebase_id, query_vector, limit \\ 10) do
    query = """
    SELECT
      path,
      language,
      file_type,
      quality_score,
      maintainability_index,
      vector_embedding <-> $2 as distance,
      1 - (vector_embedding <-> $2) as similarity_score
    FROM codebase_metadata
    WHERE codebase_id = $1 AND vector_embedding IS NOT NULL
    ORDER BY vector_embedding <-> $2
    LIMIT $3
    """

    params = [codebase_id, query_vector, limit]

    rows =
      case repo_or_conn do
        # Ecto.Repo module (connection pooling)
        repo when is_atom(repo) ->
          case Ecto.Adapters.SQL.query!(repo, query, params) do
            %{rows: rows} -> rows
          end

        # Raw Postgrex connection (backwards compatibility)
        conn ->
          case Postgrex.query!(conn, query, params) do
            %{rows: rows} -> rows
          end
      end

    Enum.map(rows, fn [
                        path,
                        language,
                        file_type,
                        quality_score,
                        maintainability_index,
                        _distance,
                        similarity_score
                      ] ->
      %{
        path: path,
        language: language,
        file_type: file_type,
        quality_score: quality_score,
        maintainability_index: maintainability_index,
        similarity_score: similarity_score
      }
    end)
  end

  @doc """
  Find similar nodes using graph and vector similarity
  """
  def find_similar_nodes(db_conn, codebase_id, query_node_id, top_k \\ 10) do
    Postgrex.query!(
      db_conn,
      """
      WITH query_node AS (
        SELECT vector_embedding, vector_magnitude
        FROM graph_nodes 
        WHERE codebase_id = $1 AND node_id = $2
      ),
      similarities AS (
        SELECT 
          gn.node_id,
          gn.name,
          gn.file_path,
          gn.node_type,
          1 - (gn.vector_embedding <-> qn.vector_embedding) as cosine_similarity,
          gn.vector_magnitude,
          qn.vector_magnitude as query_magnitude
        FROM graph_nodes gn
        CROSS JOIN query_node qn
        WHERE gn.codebase_id = $1 
          AND gn.node_id != $2 
          AND gn.vector_embedding IS NOT NULL
          AND qn.vector_embedding IS NOT NULL
      )
      SELECT 
        node_id,
        name,
        file_path,
        node_type,
        cosine_similarity,
        cosine_similarity as combined_similarity
      FROM similarities
      ORDER BY cosine_similarity DESC
      LIMIT $3
      """,
      [codebase_id, query_node_id, top_k]
    )
    |> Map.get(:rows)
    |> Enum.map(fn [node_id, name, file_path, node_type, cosine_similarity, combined_similarity] ->
      %{
        node_id: node_id,
        name: name,
        file_path: file_path,
        node_type: node_type,
        cosine_similarity: cosine_similarity,
        combined_similarity: combined_similarity
      }
    end)
  end

  @doc """
  Search across multiple codebases using vector similarity
  """
  def multi_codebase_search(db_conn, codebase_ids, query_vector, limit \\ 10) do
    # Convert codebase_ids list to SQL IN clause
    placeholders = Enum.map(1..length(codebase_ids), fn i -> "$#{i}" end) |> Enum.join(",")

    Postgrex.query!(
      db_conn,
      """
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
      """,
      codebase_ids ++ [query_vector, limit]
    )
    |> Map.get(:rows)
    |> Enum.map(fn [
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
  end

  @doc """
  Get graph dependencies (outgoing edges)
  """
  def get_dependencies(db_conn, node_id) do
    Postgrex.query!(
      db_conn,
      """
      SELECT 
        gn.node_id,
        gn.name,
        gn.file_path,
        gn.node_type,
        ge.edge_type,
        ge.weight
      FROM graph_edges ge
      JOIN graph_nodes gn ON ge.to_node_id = gn.node_id
      WHERE ge.from_node_id = $1
      ORDER BY ge.weight DESC
      """,
      [node_id]
    )
    |> Map.get(:rows)
    |> Enum.map(fn [node_id, name, file_path, node_type, edge_type, weight] ->
      %{
        node_id: node_id,
        name: name,
        file_path: file_path,
        node_type: node_type,
        edge_type: edge_type,
        weight: weight
      }
    end)
  end

  @doc """
  Get graph dependents (incoming edges)
  """
  def get_dependents(db_conn, node_id) do
    Postgrex.query!(
      db_conn,
      """
      SELECT 
        gn.node_id,
        gn.name,
        gn.file_path,
        gn.node_type,
        ge.edge_type,
        ge.weight
      FROM graph_edges ge
      JOIN graph_nodes gn ON ge.from_node_id = gn.node_id
      WHERE ge.to_node_id = $1
      ORDER BY ge.weight DESC
      """,
      [node_id]
    )
    |> Map.get(:rows)
    |> Enum.map(fn [node_id, name, file_path, node_type, edge_type, weight] ->
      %{
        node_id: node_id,
        name: name,
        file_path: file_path,
        node_type: node_type,
        edge_type: edge_type,
        weight: weight
      }
    end)
  end

  @doc """
  Detect circular dependencies using recursive CTE
  """
  def detect_circular_dependencies(db_conn) do
    Postgrex.query!(
      db_conn,
      """
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
        WHERE dp.depth < 10  -- Prevent infinite recursion
          AND NOT ge.to_node_id = ANY(dp.path)  -- Prevent cycles in path
      )
      SELECT DISTINCT
        start_node,
        end_node,
        path,
        depth
      FROM dependency_path
      WHERE start_node = end_node  -- Circular dependency detected
      ORDER BY depth
      """,
      []
    )
    |> Map.get(:rows)
    |> Enum.map(fn [start_node, end_node, path, depth] ->
      %{
        start_node: start_node,
        end_node: end_node,
        path: path,
        depth: depth
      }
    end)
  end

  @doc """
  Calculate PageRank scores for all nodes
  """
  def calculate_pagerank(db_conn, iterations \\ 20, damping_factor \\ 0.85) do
    # This is a simplified PageRank implementation
    # In production, you'd want to use Apache AGE's built-in PageRank algorithm

    Postgrex.query!(
      db_conn,
      """
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
      """,
      [iterations, damping_factor]
    )
    |> Map.get(:rows)
    |> Enum.map(fn [node_id, pagerank_score] ->
      %{
        node_id: node_id,
        pagerank_score: pagerank_score
      }
    end)
  end
end
