defmodule Singularity.Repo.Migrations.CreatePackageRegistryTables do
  use Ecto.Migration

  def change do
    # Package Registry Knowledge - Main package metadata table
    create table(:tools, primary_key: false) do
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

      # Vector embeddings for semantic search
      add :semantic_embedding, :vector, size: 768
      add :description_embedding, :vector, size: 768

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
    create unique_index(:tools, [:package_name, :version, :ecosystem], name: :tools_unique_identifier)

    # Performance indexes
    create index(:tools, [:package_name])
    create index(:tools, [:ecosystem])
    create index(:tools, [:github_stars])
    create index(:tools, [:download_count])
    create index(:tools, [:last_release_date])

    # Vector similarity index (ivfflat for faster approximate search)
    execute """
    CREATE INDEX tools_semantic_embedding_idx ON tools
    USING ivfflat (semantic_embedding vector_cosine_ops)
    WITH (lists = 100);
    """, """
    DROP INDEX IF EXISTS tools_semantic_embedding_idx;
    """

    # Package Code Examples - Code examples from package documentation
    create table(:tool_examples, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tool_id, references(:tools, type: :binary_id, on_delete: :delete_all), null: false

      add :title, :string, null: false
      add :code, :text, null: false
      add :language, :string
      add :explanation, :text
      add :tags, {:array, :string}, default: []
      add :code_embedding, :vector, size: 768
      add :example_order, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:tool_examples, [:tool_id])
    create index(:tool_examples, [:language])
    create index(:tool_examples, [:example_order])

    # Vector similarity index for code examples
    execute """
    CREATE INDEX tool_examples_code_embedding_idx ON tool_examples
    USING ivfflat (code_embedding vector_cosine_ops)
    WITH (lists = 100);
    """, """
    DROP INDEX IF EXISTS tool_examples_code_embedding_idx;
    """

    # Package Usage Patterns - Best practices and patterns
    create table(:tool_patterns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tool_id, references(:tools, type: :binary_id, on_delete: :delete_all), null: false

      add :pattern_type, :string # best_practice, anti_pattern, usage_pattern, migration_guide
      add :title, :string, null: false
      add :description, :text
      add :code_example, :text
      add :tags, {:array, :string}, default: []
      add :pattern_embedding, :vector, size: 768

      timestamps(type: :utc_datetime)
    end

    create index(:tool_patterns, [:tool_id])
    create index(:tool_patterns, [:pattern_type])

    # Vector similarity index for patterns
    execute """
    CREATE INDEX tool_patterns_pattern_embedding_idx ON tool_patterns
    USING ivfflat (pattern_embedding vector_cosine_ops)
    WITH (lists = 100);
    """, """
    DROP INDEX IF EXISTS tool_patterns_pattern_embedding_idx;
    """

    # Package Dependencies - Package dependency information
    create table(:tool_dependencies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tool_id, references(:tools, type: :binary_id, on_delete: :delete_all), null: false

      add :dependency_name, :string, null: false
      add :dependency_version, :string
      add :dependency_type, :string # runtime, dev, peer, optional
      add :is_optional, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:tool_dependencies, [:tool_id])
    create index(:tool_dependencies, [:dependency_name])
    create index(:tool_dependencies, [:dependency_type])
  end
end
