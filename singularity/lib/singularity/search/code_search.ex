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

  Leverages connection pooling for better performance.

  ## Examples

      CodeSearch.semantic_search(Singularity.Repo, "my-codebase", vector, 10)
  """
  def semantic_search(_repo_or_conn, codebase_id, query_vector, limit \\ 10) do
    Singularity.CodeSearch.Ecto.semantic_search(codebase_id, query_vector, limit)
  end

  @doc """
  Find similar nodes using graph and vector similarity
  """
  def find_similar_nodes(_db_conn, codebase_id, query_node_id, top_k \\ 10) do
    Singularity.CodeSearch.Ecto.find_similar_nodes(codebase_id, query_node_id, top_k)
  end

  @doc """
  Search across multiple codebases using vector similarity
  """
  def multi_codebase_search(_db_conn, codebase_ids, query_vector, limit \\ 10) do
    Singularity.CodeSearch.Ecto.multi_codebase_search(codebase_ids, query_vector, limit)
  end

  @doc """
  Get graph dependencies (outgoing edges) (converted to Ecto)
  """
  def get_dependencies(_db_conn, node_id) do
    Singularity.CodeSearch.Ecto.get_dependencies(node_id)
  end

  @doc """
  Get graph dependents (incoming edges)
  """
  def get_dependents(_db_conn, node_id) do
    Singularity.CodeSearch.Ecto.get_dependents(node_id)
  end

  @doc """
  Detect circular dependencies using recursive CTE
  """
  def detect_circular_dependencies(_db_conn) do
    Singularity.CodeSearch.Ecto.detect_circular_dependencies()
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
