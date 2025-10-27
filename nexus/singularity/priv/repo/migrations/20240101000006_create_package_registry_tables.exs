defmodule Singularity.Repo.Migrations.CreatePackageRegistryTables do
  use Ecto.Migration

  def change do
    # Package Registry Knowledge - Main package metadata table
    create_if_not_exists table(:tools, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :package_name, :string, null: false
      add :version, :string, null: false
      add :ecosystem, :string, null: false

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

      # Vector embeddings for semantic search (2560-dim: Qodo 1536 + Jina v3 1024)
      add :semantic_embedding, :vector, size: 2560, null: true
      add :description_embedding, :vector, size: 2560, null: true

      # Quality signals
      add :download_count, :integer, default: 0
      add :github_stars, :integer, default: 0
      add :last_release_date, :utc_datetime

      # Source tracking
      add :source_url, :string
      add :collected_at, :utc_datetime
      add :last_updated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Unique constraint on package_name, version, ecosystem
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS tools_package_name_version_ecosystem_key
      ON tools (package_name, version, ecosystem)
    """, "")

    # Performance indexes
    execute("""
      CREATE INDEX IF NOT EXISTS tools_package_name_index
      ON tools (package_name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tools_ecosystem_index
      ON tools (ecosystem)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tools_github_stars_index
      ON tools (github_stars)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tools_download_count_index
      ON tools (download_count)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tools_last_release_date_index
      ON tools (last_release_date)
    """, "")

    # Vector similarity index (HNSW for faster approximate search)
    execute """
    CREATE INDEX IF NOT EXISTS tools_semantic_embedding_idx ON tools
    USING hnsw (semantic_embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 200)
    """, """
    DROP INDEX IF EXISTS tools_semantic_embedding_idx
    """

    # Package Code Examples - Code examples from package documentation
    create_if_not_exists table(:tool_examples, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tool_id, references(:tools, type: :binary_id, on_delete: :delete_all), null: false

      add :title, :string, null: false
      add :code, :text, null: false
      add :language, :string
      add :explanation, :text
      add :tags, {:array, :string}, default: []
      add :code_embedding, :vector, size: 2560, null: true
      add :example_order, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS tool_examples_tool_id_index
      ON tool_examples (tool_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tool_examples_language_index
      ON tool_examples (language)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tool_examples_example_order_index
      ON tool_examples (example_order)
    """, "")

    # Vector similarity index for code examples
    execute """
    CREATE INDEX IF NOT EXISTS tool_examples_code_embedding_idx ON tool_examples
    USING hnsw (code_embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 200)
    """, """
    DROP INDEX IF EXISTS tool_examples_code_embedding_idx
    """

    # Package Usage Patterns - Best practices and patterns
    create_if_not_exists table(:tool_patterns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tool_id, references(:tools, type: :binary_id, on_delete: :delete_all), null: false

      add :pattern_type, :string # best_practice, anti_pattern, usage_pattern, migration_guide
      add :title, :string, null: false
      add :description, :text
      add :code_example, :text
      add :tags, {:array, :string}, default: []
      add :pattern_embedding, :vector, size: 2560, null: true

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS tool_patterns_tool_id_index
      ON tool_patterns (tool_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tool_patterns_pattern_type_index
      ON tool_patterns (pattern_type)
    """, "")

    # Vector similarity index for patterns
    execute """
    CREATE INDEX IF NOT EXISTS tool_patterns_pattern_embedding_idx ON tool_patterns
    USING hnsw (pattern_embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 200)
    """, """
    DROP INDEX IF EXISTS tool_patterns_pattern_embedding_idx
    """

    # Package Dependencies - Package dependency information
    create_if_not_exists table(:tool_dependencies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tool_id, references(:tools, type: :binary_id, on_delete: :delete_all), null: false

      add :dependency_name, :string, null: false
      add :dependency_version, :string
      add :dependency_type, :string # runtime, dev, peer, optional
      add :is_optional, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS tool_dependencies_tool_id_index
      ON tool_dependencies (tool_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tool_dependencies_dependency_name_index
      ON tool_dependencies (dependency_name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS tool_dependencies_dependency_type_index
      ON tool_dependencies (dependency_type)
    """, "")
  end
end
