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
  """
  def create_unified_schema(db_conn) do
    # Create the main codebase metadata table (matches analysis-suite CodebaseMetadata)
    create_codebase_metadata_table(db_conn)

    # Create graph tables for relationships
    create_graph_tables(db_conn)

    # Create vector search tables
    create_vector_search_tables(db_conn)

    # Create indexes for performance
    create_performance_indexes(db_conn)

    # Create Apache AGE extension if available
    create_apache_age_extension(db_conn)

    Logger.info("Unified codebase schema created successfully")
    :ok
  end

  defp create_codebase_metadata_table(db_conn) do
    # Main table matching analysis-suite CodebaseMetadata structure
    Postgrex.query!(
      db_conn,
      """
      CREATE TABLE IF NOT EXISTS codebase_metadata (
        -- Primary key
        id SERIAL PRIMARY KEY,
        
        -- === CODEBASE IDENTIFICATION ===
        codebase_id VARCHAR(255) NOT NULL,
        codebase_path VARCHAR(500) NOT NULL,
        
        -- === BASIC FILE INFO ===
        path VARCHAR(500) NOT NULL,
        size BIGINT NOT NULL DEFAULT 0,
        lines INTEGER NOT NULL DEFAULT 0,
        language VARCHAR(50) NOT NULL DEFAULT 'unknown',
        last_modified BIGINT NOT NULL DEFAULT 0,
        file_type VARCHAR(50) NOT NULL DEFAULT 'source',
        
        -- === COMPLEXITY METRICS ===
        cyclomatic_complexity FLOAT NOT NULL DEFAULT 0.0,
        cognitive_complexity FLOAT NOT NULL DEFAULT 0.0,
        maintainability_index FLOAT NOT NULL DEFAULT 0.0,
        nesting_depth INTEGER NOT NULL DEFAULT 0,
        
        -- === CODE METRICS ===
        function_count INTEGER NOT NULL DEFAULT 0,
        class_count INTEGER NOT NULL DEFAULT 0,
        struct_count INTEGER NOT NULL DEFAULT 0,
        enum_count INTEGER NOT NULL DEFAULT 0,
        trait_count INTEGER NOT NULL DEFAULT 0,
        interface_count INTEGER NOT NULL DEFAULT 0,
        
        -- === LINE METRICS ===
        total_lines INTEGER NOT NULL DEFAULT 0,
        code_lines INTEGER NOT NULL DEFAULT 0,
        comment_lines INTEGER NOT NULL DEFAULT 0,
        blank_lines INTEGER NOT NULL DEFAULT 0,
        
        -- === HALSTEAD METRICS ===
        halstead_vocabulary INTEGER NOT NULL DEFAULT 0,
        halstead_length INTEGER NOT NULL DEFAULT 0,
        halstead_volume FLOAT NOT NULL DEFAULT 0.0,
        halstead_difficulty FLOAT NOT NULL DEFAULT 0.0,
        halstead_effort FLOAT NOT NULL DEFAULT 0.0,
        
        -- === PAGERANK & GRAPH METRICS ===
        pagerank_score FLOAT NOT NULL DEFAULT 0.0,
        centrality_score FLOAT NOT NULL DEFAULT 0.0,
        dependency_count INTEGER NOT NULL DEFAULT 0,
        dependent_count INTEGER NOT NULL DEFAULT 0,
        
        -- === PERFORMANCE METRICS ===
        technical_debt_ratio FLOAT NOT NULL DEFAULT 0.0,
        code_smells_count INTEGER NOT NULL DEFAULT 0,
        duplication_percentage FLOAT NOT NULL DEFAULT 0.0,
        
        -- === SECURITY METRICS ===
        security_score FLOAT NOT NULL DEFAULT 0.0,
        vulnerability_count INTEGER NOT NULL DEFAULT 0,
        
        -- === QUALITY METRICS ===
        quality_score FLOAT NOT NULL DEFAULT 0.0,
        test_coverage FLOAT NOT NULL DEFAULT 0.0,
        documentation_coverage FLOAT NOT NULL DEFAULT 0.0,
        
        -- === SEMANTIC FEATURES (JSONB for flexibility) ===
        domains JSONB DEFAULT '[]'::jsonb,
        patterns JSONB DEFAULT '[]'::jsonb,
        features JSONB DEFAULT '[]'::jsonb,
        business_context JSONB DEFAULT '[]'::jsonb,
        performance_characteristics JSONB DEFAULT '[]'::jsonb,
        security_characteristics JSONB DEFAULT '[]'::jsonb,
        
        -- === DEPENDENCIES & RELATIONSHIPS (JSONB for flexibility) ===
        dependencies JSONB DEFAULT '[]'::jsonb,
        related_files JSONB DEFAULT '[]'::jsonb,
        imports JSONB DEFAULT '[]'::jsonb,
        exports JSONB DEFAULT '[]'::jsonb,
        
        -- === SYMBOLS (JSONB for flexibility) ===
        functions JSONB DEFAULT '[]'::jsonb,
        classes JSONB DEFAULT '[]'::jsonb,
        structs JSONB DEFAULT '[]'::jsonb,
        enums JSONB DEFAULT '[]'::jsonb,
        traits JSONB DEFAULT '[]'::jsonb,
        
        -- === VECTOR EMBEDDING ===
        vector_embedding VECTOR(1536) DEFAULT NULL,
        
        -- === TIMESTAMPS ===
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        
        -- === UNIQUE CONSTRAINT ===
        UNIQUE(codebase_id, path)
      )
      """,
      []
    )

    # Create codebase registry table to track codebase paths
    Postgrex.query!(
      db_conn,
      """
      CREATE TABLE IF NOT EXISTS codebase_registry (
        id SERIAL PRIMARY KEY,
        codebase_id VARCHAR(255) NOT NULL UNIQUE,
        codebase_path VARCHAR(500) NOT NULL,
        codebase_name VARCHAR(255) NOT NULL,
        description TEXT,
        language VARCHAR(50),
        framework VARCHAR(100),
        last_analyzed TIMESTAMP DEFAULT NULL,
        analysis_status VARCHAR(50) DEFAULT 'pending',
        metadata JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
      """,
      []
    )
  end

  defp create_graph_tables(db_conn) do
    # Graph nodes table (for Apache AGE compatibility)
    Postgrex.query!(
      db_conn,
      """
      CREATE TABLE IF NOT EXISTS graph_nodes (
        id SERIAL PRIMARY KEY,
        codebase_id VARCHAR(255) NOT NULL,
        node_id VARCHAR(255) NOT NULL,
        node_type VARCHAR(100) NOT NULL,
        name VARCHAR(255) NOT NULL,
        file_path VARCHAR(500) NOT NULL,
        line_number INTEGER DEFAULT NULL,
        vector_embedding VECTOR(1536) DEFAULT NULL,
        vector_magnitude FLOAT DEFAULT NULL,
        metadata JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP DEFAULT NOW(),
        
        UNIQUE(codebase_id, node_id)
      )
      """,
      []
    )

    # Graph edges table (for Apache AGE compatibility)
    Postgrex.query!(
      db_conn,
      """
      CREATE TABLE IF NOT EXISTS graph_edges (
        id SERIAL PRIMARY KEY,
        codebase_id VARCHAR(255) NOT NULL,
        edge_id VARCHAR(255) NOT NULL,
        from_node_id VARCHAR(255) NOT NULL,
        to_node_id VARCHAR(255) NOT NULL,
        edge_type VARCHAR(100) NOT NULL,
        weight FLOAT NOT NULL DEFAULT 1.0,
        metadata JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP DEFAULT NOW(),
        
        UNIQUE(codebase_id, edge_id),
        FOREIGN KEY (codebase_id, from_node_id) REFERENCES graph_nodes(codebase_id, node_id),
        FOREIGN KEY (codebase_id, to_node_id) REFERENCES graph_nodes(codebase_id, node_id)
      )
      """,
      []
    )

    # Graph types table (CallGraph, ImportGraph, SemanticGraph, DataFlowGraph)
    Postgrex.query!(
      db_conn,
      """
      CREATE TABLE IF NOT EXISTS graph_types (
        id SERIAL PRIMARY KEY,
        graph_type VARCHAR(100) NOT NULL UNIQUE,
        description TEXT,
        created_at TIMESTAMP DEFAULT NOW()
      )
      """,
      []
    )

    # Insert default graph types
    Postgrex.query!(
      db_conn,
      """
      INSERT INTO graph_types (graph_type, description) VALUES
      ('CallGraph', 'Function call dependencies (DAG)'),
      ('ImportGraph', 'Module import dependencies (DAG)'),
      ('SemanticGraph', 'Conceptual relationships (General Graph)'),
      ('DataFlowGraph', 'Variable and data dependencies (DAG)')
      ON CONFLICT (graph_type) DO NOTHING
      """,
      []
    )
  end

  defp create_vector_search_tables(db_conn) do
    # Vector search table for semantic search
    Postgrex.query!(
      db_conn,
      """
      CREATE TABLE IF NOT EXISTS vector_search (
        id SERIAL PRIMARY KEY,
        codebase_id VARCHAR(255) NOT NULL,
        file_path VARCHAR(500) NOT NULL,
        content_type VARCHAR(100) NOT NULL,
        content TEXT NOT NULL,
        vector_embedding VECTOR(1536) NOT NULL,
        metadata JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMP DEFAULT NOW(),
        
        UNIQUE(codebase_id, file_path, content_type)
      )
      """,
      []
    )

    # Vector similarity cache for performance
    Postgrex.query!(
      db_conn,
      """
      CREATE TABLE IF NOT EXISTS vector_similarity_cache (
        id SERIAL PRIMARY KEY,
        codebase_id VARCHAR(255) NOT NULL,
        query_vector_hash VARCHAR(64) NOT NULL,
        target_file_path VARCHAR(500) NOT NULL,
        similarity_score FLOAT NOT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        
        UNIQUE(codebase_id, query_vector_hash, target_file_path)
      )
      """,
      []
    )
  end

  defp create_performance_indexes(db_conn) do
    # Indexes for codebase_metadata table
    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_metadata_codebase_id 
      ON codebase_metadata(codebase_id)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_metadata_codebase_path 
      ON codebase_metadata(codebase_path)
      """,
      []
    )

    # Indexes for codebase_registry table
    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_registry_codebase_id 
      ON codebase_registry(codebase_id)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_registry_codebase_path 
      ON codebase_registry(codebase_path)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_registry_analysis_status 
      ON codebase_registry(analysis_status)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_metadata_path 
      ON codebase_metadata(codebase_id, path)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_metadata_language 
      ON codebase_metadata(codebase_id, language)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_metadata_file_type 
      ON codebase_metadata(codebase_id, file_type)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_metadata_quality_score 
      ON codebase_metadata(codebase_id, quality_score)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_metadata_complexity 
      ON codebase_metadata(codebase_id, cyclomatic_complexity, cognitive_complexity)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_metadata_pagerank 
      ON codebase_metadata(codebase_id, pagerank_score)
      """,
      []
    )

    # Vector index for similarity search
    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_codebase_metadata_vector 
      ON codebase_metadata USING ivfflat (vector_embedding vector_cosine_ops)
      """,
      []
    )

    # Indexes for graph tables
    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_graph_nodes_codebase_id 
      ON graph_nodes(codebase_id)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_graph_nodes_node_id 
      ON graph_nodes(codebase_id, node_id)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_graph_nodes_node_type 
      ON graph_nodes(codebase_id, node_type)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_graph_nodes_file_path 
      ON graph_nodes(codebase_id, file_path)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_graph_edges_codebase_id 
      ON graph_edges(codebase_id)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_graph_edges_from_node 
      ON graph_edges(codebase_id, from_node_id)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_graph_edges_to_node 
      ON graph_edges(codebase_id, to_node_id)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_graph_edges_edge_type 
      ON graph_edges(codebase_id, edge_type)
      """,
      []
    )

    # Vector index for graph nodes
    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_graph_nodes_vector 
      ON graph_nodes USING ivfflat (vector_embedding vector_cosine_ops)
      """,
      []
    )

    # Indexes for vector search
    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_vector_search_codebase_id 
      ON vector_search(codebase_id)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_vector_search_file_path 
      ON vector_search(codebase_id, file_path)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_vector_search_content_type 
      ON vector_search(codebase_id, content_type)
      """,
      []
    )

    Postgrex.query!(
      db_conn,
      """
      CREATE INDEX IF NOT EXISTS idx_vector_search_vector 
      ON vector_search USING ivfflat (vector_embedding vector_cosine_ops)
      """,
      []
    )
  end

  defp create_apache_age_extension(db_conn) do
    # Try to create Apache AGE extension if available
    try do
      Postgrex.query!(
        db_conn,
        """
        CREATE EXTENSION IF NOT EXISTS age;
        """,
        []
      )

      Logger.info("Apache AGE extension created successfully")
    rescue
      _error ->
        Logger.warning(
          "Apache AGE extension not available - using native PostgreSQL graph features"
        )
    end
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
