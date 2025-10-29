defmodule CentralCloud.Repo.Migrations.CreateTemplatesTable do
  use Ecto.Migration

  def up do
    # Templates Table - Single source of truth for ALL template types
    create table(:templates, primary_key: false) do
      add :id, :string, primary_key: true  # Template ID (e.g., "elixir-genserver")
      add :category, :string, null: false  # base, bit, code_generation, framework, prompt, quality_standard, workflow
      
      # Metadata (JSONB for flexible structure)
      add :metadata, :jsonb, null: false, default: "{}"
      
      # Content (JSONB - can be code, snippets, prompt, quality, etc.)
      add :content, :jsonb, null: false
      
      # Composition (for templates that extend or compose others)
      add :extends, :string  # Base template ID
      add :compose, {:array, :string}  # Bit template IDs to compose
      
      # Quality and usage tracking
      add :quality_standard, :string
      add :usage_stats, :jsonb, default: "{\"count\": 0, \"success_rate\": 0.0, \"last_used\": null}"
      add :quality_score, :float, default: 0.8
      
      # Vector embedding for semantic search (2560-dim: Qodo 1536 + Jina v3 1024)
      add :embedding, :vector, size: 2560
      
      # Versioning
      add :version, :string, null: false, default: "1.0.0"
      add :deprecated, :boolean, default: false
      
      # Timestamps
      add :created_at, :utc_datetime, default: fragment("NOW()")
      add :updated_at, :utc_datetime, default: fragment("NOW()")
      add :last_synced_at, :utc_datetime  # When synced to Singularity instances
    end

    # Indexes
    create index(:templates, [:category])
    create index(:templates, [:version])
    create index(:templates, [:deprecated])
    create index(:templates, :metadata, using: "gin")  # For JSONB queries
    create index(:templates, :content, using: "gin")  # For JSONB queries
    
    # Vector index for semantic search
    create index(:templates, :embedding, using: "ivfflat", with: "lists = 100")
    
    # Composite indexes for common queries
    create index(:templates, [:category, :deprecated])
    create index(:templates, ["(metadata->>'language')", :category])
    
    # Unique constraint
    create unique_index(:templates, [:id, :version])
  end

  def down do
    drop index(:templates, [:embedding])
    drop index(:templates, ["(metadata->>'language')", :category])
    drop index(:templates, [:category, :deprecated])
    drop index(:templates, :content, using: "gin")
    drop index(:templates, :metadata, using: "gin")
    drop index(:templates, [:deprecated])
    drop index(:templates, [:version])
    drop index(:templates, [:category])
    drop table(:templates)
  end
end
