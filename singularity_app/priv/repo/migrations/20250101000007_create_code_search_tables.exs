defmodule Singularity.Repo.Migrations.CreateCodeSearchTables do
  use Ecto.Migration

  @moduledoc """
  Creates unified semantic code search schema tables.

  These tables are used by CodeSearch module for vector-based code search,
  analysis, and graph relationships. Matches the schema created at runtime in
  CodeSearch.create_unified_schema/1.

  Tables created:
  - codebase_metadata: Main codebase metadata with 50+ columns and vector embeddings
  - codebase_registry: Tracks codebase paths and analysis status
  - graph_nodes: Graph nodes for Apache AGE compatibility with vectors
  - graph_edges: Graph edges for relationships (DAG support)
  - graph_types: Predefined graph types (CallGraph, ImportGraph, etc.)
  - vector_search: Semantic search with vector embeddings
  - vector_similarity_cache: Performance cache for similarity scores
  """

  def up do
    # ===== CODEBASE METADATA TABLE =====
    # Main table matching analysis-suite CodebaseMetadata structure
    create table(:codebase_metadata) do
      # === CODEBASE IDENTIFICATION ===
      add :codebase_id, :string, null: false, size: 255
      add :codebase_path, :string, null: false, size: 500

      # === BASIC FILE INFO ===
      add :path, :string, null: false, size: 500
      add :size, :bigint, null: false, default: 0
      add :lines, :integer, null: false, default: 0
      add :language, :string, null: false, default: "unknown", size: 50
      add :last_modified, :bigint, null: false, default: 0
      add :file_type, :string, null: false, default: "source", size: 50

      # === COMPLEXITY METRICS ===
      add :cyclomatic_complexity, :float, null: false, default: 0.0
      add :cognitive_complexity, :float, null: false, default: 0.0
      add :maintainability_index, :float, null: false, default: 0.0
      add :nesting_depth, :integer, null: false, default: 0

      # === CODE METRICS ===
      add :function_count, :integer, null: false, default: 0
      add :class_count, :integer, null: false, default: 0
      add :struct_count, :integer, null: false, default: 0
      add :enum_count, :integer, null: false, default: 0
      add :trait_count, :integer, null: false, default: 0
      add :interface_count, :integer, null: false, default: 0

      # === LINE METRICS ===
      add :total_lines, :integer, null: false, default: 0
      add :code_lines, :integer, null: false, default: 0
      add :comment_lines, :integer, null: false, default: 0
      add :blank_lines, :integer, null: false, default: 0

      # === HALSTEAD METRICS ===
      add :halstead_vocabulary, :integer, null: false, default: 0
      add :halstead_length, :integer, null: false, default: 0
      add :halstead_volume, :float, null: false, default: 0.0
      add :halstead_difficulty, :float, null: false, default: 0.0
      add :halstead_effort, :float, null: false, default: 0.0

      # === PAGERANK & GRAPH METRICS ===
      add :pagerank_score, :float, null: false, default: 0.0
      add :centrality_score, :float, null: false, default: 0.0
      add :dependency_count, :integer, null: false, default: 0
      add :dependent_count, :integer, null: false, default: 0

      # === PERFORMANCE METRICS ===
      add :technical_debt_ratio, :float, null: false, default: 0.0
      add :code_smells_count, :integer, null: false, default: 0
      add :duplication_percentage, :float, null: false, default: 0.0

      # === SECURITY METRICS ===
      add :security_score, :float, null: false, default: 0.0
      add :vulnerability_count, :integer, null: false, default: 0

      # === QUALITY METRICS ===
      add :quality_score, :float, null: false, default: 0.0
      add :test_coverage, :float, null: false, default: 0.0
      add :documentation_coverage, :float, null: false, default: 0.0

      # === SEMANTIC FEATURES (JSONB for flexibility) ===
      add :domains, :jsonb, default: fragment("'[]'::jsonb")
      add :patterns, :jsonb, default: fragment("'[]'::jsonb")
      add :features, :jsonb, default: fragment("'[]'::jsonb")
      add :business_context, :jsonb, default: fragment("'[]'::jsonb")
      add :performance_characteristics, :jsonb, default: fragment("'[]'::jsonb")
      add :security_characteristics, :jsonb, default: fragment("'[]'::jsonb")

      # === DEPENDENCIES & RELATIONSHIPS (JSONB for flexibility) ===
      add :dependencies, :jsonb, default: fragment("'[]'::jsonb")
      add :related_files, :jsonb, default: fragment("'[]'::jsonb")
      add :imports, :jsonb, default: fragment("'[]'::jsonb")
      add :exports, :jsonb, default: fragment("'[]'::jsonb")

      # === SYMBOLS (JSONB for flexibility) ===
      add :functions, :jsonb, default: fragment("'[]'::jsonb")
      add :classes, :jsonb, default: fragment("'[]'::jsonb")
      add :structs, :jsonb, default: fragment("'[]'::jsonb")
      add :enums, :jsonb, default: fragment("'[]'::jsonb")
      add :traits, :jsonb, default: fragment("'[]'::jsonb")

      # === VECTOR EMBEDDING ===
      # Using 1536 dimensions for OpenAI text-embedding-3-small
      add :vector_embedding, :vector, size: 1536, null: true

      timestamps(default: fragment("NOW()"))
    end

    # Unique constraint on codebase_id + path
    create unique_index(:codebase_metadata, [:codebase_id, :path])

    # Performance indexes
    create index(:codebase_metadata, [:codebase_id])
    create index(:codebase_metadata, [:codebase_path])
    create index(:codebase_metadata, [:codebase_id, :language])
    create index(:codebase_metadata, [:codebase_id, :file_type])
    create index(:codebase_metadata, [:codebase_id, :quality_score])
    create index(:codebase_metadata, [:codebase_id, :cyclomatic_complexity, :cognitive_complexity])
    create index(:codebase_metadata, [:codebase_id, :pagerank_score])

    # Vector index for similarity search (ivfflat for cosine similarity)
    execute """
    CREATE INDEX idx_codebase_metadata_vector ON codebase_metadata 
    USING ivfflat (vector_embedding vector_cosine_ops) 
    WITH (lists = 100)
    """

    # ===== CODEBASE REGISTRY TABLE =====
    # Tracks codebase paths and analysis status
    create table(:codebase_registry) do
      add :codebase_id, :string, null: false, size: 255
      add :codebase_path, :string, null: false, size: 500
      add :codebase_name, :string, null: false, size: 255
      add :description, :text
      add :language, :string, size: 50
      add :framework, :string, size: 100
      add :last_analyzed, :utc_datetime
      add :analysis_status, :string, default: "pending", size: 50
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")

      timestamps(default: fragment("NOW()"))
    end

    create unique_index(:codebase_registry, [:codebase_id])
    create index(:codebase_registry, [:codebase_path])
    create index(:codebase_registry, [:analysis_status])

    # ===== GRAPH NODES TABLE =====
    # For Apache AGE compatibility and graph analysis
    create table(:graph_nodes) do
      add :codebase_id, :string, null: false, size: 255
      add :node_id, :string, null: false, size: 255
      add :node_type, :string, null: false, size: 100
      add :name, :string, null: false, size: 255
      add :file_path, :string, null: false, size: 500
      add :line_number, :integer
      add :vector_embedding, :vector, size: 1536, null: true
      add :vector_magnitude, :float
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")

      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    create unique_index(:graph_nodes, [:codebase_id, :node_id])
    create index(:graph_nodes, [:codebase_id])
    create index(:graph_nodes, [:codebase_id, :node_type])

    # Vector index for graph node embeddings
    execute """
    CREATE INDEX idx_graph_nodes_vector ON graph_nodes 
    USING ivfflat (vector_embedding vector_cosine_ops) 
    WITH (lists = 100)
    """

    # ===== GRAPH EDGES TABLE =====
    # Graph edges for relationships (supports DAG)
    create table(:graph_edges) do
      add :codebase_id, :string, null: false, size: 255
      add :edge_id, :string, null: false, size: 255
      add :from_node_id, :string, null: false, size: 255
      add :to_node_id, :string, null: false, size: 255
      add :edge_type, :string, null: false, size: 100
      add :weight, :float, null: false, default: 1.0
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")

      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    create unique_index(:graph_edges, [:codebase_id, :edge_id])
    create index(:graph_edges, [:codebase_id])
    create index(:graph_edges, [:from_node_id])
    create index(:graph_edges, [:to_node_id])
    create index(:graph_edges, [:edge_type])

    # Note: Foreign key constraints are intentionally omitted to allow flexible node references

    # ===== GRAPH TYPES TABLE =====
    # Predefined graph types
    create table(:graph_types) do
      add :graph_type, :string, null: false, size: 100
      add :description, :text

      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    create unique_index(:graph_types, [:graph_type])

    # Insert default graph types
    execute """
    INSERT INTO graph_types (graph_type, description, created_at) VALUES
    ('CallGraph', 'Function call dependencies (DAG)', NOW()),
    ('ImportGraph', 'Module import dependencies (DAG)', NOW()),
    ('SemanticGraph', 'Conceptual relationships (General Graph)', NOW()),
    ('DataFlowGraph', 'Variable and data dependencies (DAG)', NOW())
    ON CONFLICT (graph_type) DO NOTHING
    """

    # ===== VECTOR SEARCH TABLE =====
    # Semantic search with vector embeddings
    create table(:vector_search) do
      add :codebase_id, :string, null: false, size: 255
      add :file_path, :string, null: false, size: 500
      add :content_type, :string, null: false, size: 100
      add :content, :text, null: false
      add :vector_embedding, :vector, size: 1536, null: false
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")

      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    create unique_index(:vector_search, [:codebase_id, :file_path, :content_type])
    create index(:vector_search, [:codebase_id])

    # Vector index for semantic search
    execute """
    CREATE INDEX idx_vector_search_embedding ON vector_search 
    USING ivfflat (vector_embedding vector_cosine_ops) 
    WITH (lists = 100)
    """

    # ===== VECTOR SIMILARITY CACHE TABLE =====
    # Performance cache for similarity scores
    create table(:vector_similarity_cache) do
      add :codebase_id, :string, null: false, size: 255
      add :query_vector_hash, :string, null: false, size: 64
      add :target_file_path, :string, null: false, size: 500
      add :similarity_score, :float, null: false

      add :created_at, :utc_datetime, default: fragment("NOW()")
    end

    create unique_index(:vector_similarity_cache, [:codebase_id, :query_vector_hash, :target_file_path])
    create index(:vector_similarity_cache, [:codebase_id])
    create index(:vector_similarity_cache, [:query_vector_hash])
  end

  def down do
    drop table(:vector_similarity_cache)
    drop table(:vector_search)
    drop table(:graph_types)
    drop table(:graph_edges)
    drop table(:graph_nodes)
    drop table(:codebase_registry)
    drop table(:codebase_metadata)
  end
end
