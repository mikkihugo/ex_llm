defmodule Singularity.Repo.Migrations.CreateToolKnowledge do
  use Ecto.Migration

  def up do
    # Enable pgvector extension if not already enabled
    execute("CREATE EXTENSION IF NOT EXISTS vector")

    # Main tool documentation table
    create table(:tools, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :tool_name, :string, null: false
      add :version, :string, null: false
      add :ecosystem, :string, null: false  # npm, cargo, hex, pypi, etc.

      # Documentation
      add :description, :text
      add :documentation, :text
      add :homepage_url, :string
      add :repository_url, :string
      add :license, :string

      # Metadata
      add :tags, {:array, :string}, default: []
      add :categories, {:array, :string}, default: []
      add :keywords, {:array, :string}, default: []

      # Vector embeddings (768 dims for Google AI)
      add :semantic_embedding, :vector, size: 768
      add :description_embedding, :vector, size: 768

      # Statistics
      add :download_count, :bigint, default: 0
      add :github_stars, :integer
      add :last_release_date, :utc_datetime

      # Source tracking
      add :source_url, :string
      add :collected_at, :utc_datetime
      add :last_updated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Unique constraint on tool + version + ecosystem
    create unique_index(:tools, [:tool_name, :version, :ecosystem],
      name: :tools_unique_identifier)

    # Indexes for common queries
    create index(:tools, [:ecosystem])
    create index(:tools, [:tool_name])
    create index(:tools, [:tags], using: :gin)
    create index(:tools, [:keywords], using: :gin)

    # Vector similarity search indexes (IVFFlat)
    execute("""
    CREATE INDEX tools_semantic_embedding_idx
    ON tools
    USING ivfflat (semantic_embedding vector_cosine_ops)
    WITH (lists = 100)
    """)

    execute("""
    CREATE INDEX tools_description_embedding_idx
    ON tools
    USING ivfflat (description_embedding vector_cosine_ops)
    WITH (lists = 100)
    """)

    # Code examples table
    create table(:tool_examples) do
      add :tool_id, references(:tools, type: :uuid, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :code, :text, null: false
      add :language, :string
      add :explanation, :text
      add :tags, {:array, :string}, default: []

      # Code embedding (384 dims for TF-IDF or 768 for Google AI)
      add :code_embedding, :vector, size: 768

      add :example_order, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:tool_examples, [:tool_id])
    create index(:tool_examples, [:language])

    execute("""
    CREATE INDEX tool_examples_code_embedding_idx
    ON tool_examples
    USING ivfflat (code_embedding vector_cosine_ops)
    WITH (lists = 50)
    """)

    # Dependencies table
    create table(:tool_dependencies) do
      add :tool_id, references(:tools, type: :uuid, on_delete: :delete_all), null: false
      add :dependency_name, :string, null: false
      add :dependency_version, :string
      add :dependency_type, :string  # runtime, dev, peer, optional
      add :is_optional, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:tool_dependencies, [:tool_id])
    create index(:tool_dependencies, [:dependency_name])

    # Best practices / usage patterns
    create table(:tool_patterns) do
      add :tool_id, references(:tools, type: :uuid, on_delete: :delete_all), null: false
      add :pattern_type, :string  # best_practice, anti_pattern, usage_pattern, migration_guide
      add :title, :string, null: false
      add :description, :text
      add :code_example, :text
      add :tags, {:array, :string}, default: []

      add :pattern_embedding, :vector, size: 768

      timestamps(type: :utc_datetime)
    end

    create index(:tool_patterns, [:tool_id])
    create index(:tool_patterns, [:pattern_type])

    execute("""
    CREATE INDEX tool_patterns_embedding_idx
    ON tool_patterns
    USING ivfflat (pattern_embedding vector_cosine_ops)
    WITH (lists = 50)
    """)

    # CLI commands / API reference
    create table(:tool_commands) do
      add :tool_id, references(:tools, type: :uuid, on_delete: :delete_all), null: false
      add :command, :string, null: false
      add :description, :text
      add :example, :text
      add :options, :jsonb  # Command line options/flags

      timestamps(type: :utc_datetime)
    end

    create index(:tool_commands, [:tool_id])

    # Framework/library detection metadata
    create table(:tool_frameworks) do
      add :tool_id, references(:tools, type: :uuid, on_delete: :delete_all), null: false
      add :framework_name, :string, null: false
      add :framework_version, :string
      add :confidence_score, :float  # 0.0 to 1.0
      add :detection_method, :string  # config_file, import_pattern, dependency

      timestamps(type: :utc_datetime)
    end

    create index(:tool_frameworks, [:tool_id])
    create index(:tool_frameworks, [:framework_name])

    # Usage statistics and learning data
    create table(:tool_usage_stats) do
      add :tool_id, references(:tools, type: :uuid, on_delete: :delete_all), null: false
      add :query_count, :integer, default: 0
      add :example_view_count, :integer, default: 0
      add :last_queried_at, :utc_datetime
      add :search_keywords, {:array, :string}, default: []
      add :related_tools, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tool_usage_stats, [:tool_id])

    # Code embeddings table (for RustToolingAnalyzer and code analysis)
    create table(:code_embeddings, primary_key: false) do
      add :path, :string, primary_key: true  # Unique file/component path
      add :label, :string
      add :metadata, :jsonb
      add :embedding, :vector, size: 768  # Google AI embeddings

      # Analysis metadata
      add :language, :string
      add :analysis_type, :string  # module, security, binary_size, license, etc.
      add :tool_used, :string  # cargo-audit, cargo-modules, etc.

      timestamps(type: :utc_datetime)
    end

    create index(:code_embeddings, [:language])
    create index(:code_embeddings, [:analysis_type])
    create index(:code_embeddings, [:tool_used])

    execute("""
    CREATE INDEX code_embeddings_embedding_idx
    ON code_embeddings
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100)
    """)
  end

  def down do
    drop index(:code_embeddings, [:tool_used])
    drop index(:code_embeddings, [:analysis_type])
    drop index(:code_embeddings, [:language])
    execute("DROP INDEX IF EXISTS code_embeddings_embedding_idx")
    drop table(:code_embeddings)

    drop table(:tool_usage_stats)
    drop table(:tool_usage_stats)
    drop table(:tool_frameworks)
    drop table(:tool_commands)
    drop index(:tool_patterns, [:pattern_type])
    drop index(:tool_patterns, [:tool_id])
    execute("DROP INDEX IF EXISTS tool_patterns_embedding_idx")
    drop table(:tool_patterns)

    drop index(:tool_dependencies, [:dependency_name])
    drop index(:tool_dependencies, [:tool_id])
    drop table(:tool_dependencies)

    drop index(:tool_examples, [:language])
    drop index(:tool_examples, [:tool_id])
    execute("DROP INDEX IF EXISTS tool_examples_code_embedding_idx")
    drop table(:tool_examples)

    drop index(:tools, [:keywords])
    drop index(:tools, [:tags])
    drop index(:tools, [:tool_name])
    drop index(:tools, [:ecosystem])
    drop index(:tools, [:tool_name, :version, :ecosystem])
    execute("DROP INDEX IF EXISTS tools_semantic_embedding_idx")
    execute("DROP INDEX IF EXISTS tools_description_embedding_idx")
    drop table(:tools)
  end
end
