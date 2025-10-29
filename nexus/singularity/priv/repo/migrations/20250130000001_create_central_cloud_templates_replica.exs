defmodule Singularity.Repo.Migrations.CreateCentralCloudTemplatesReplica do
  @moduledoc """
  Creates read-only replica of CentralCloud unified_templates table.
  
  Templates are synced from CentralCloud via:
  1. PostgreSQL Logical Replication (automatic, real-time)
  2. pgflow notifications (real-time updates)
  
  This table is READ-ONLY - Singularity instances never write to it.
  CentralCloud is the single source of truth.
  """

  use Ecto.Migration

  def up do
    # Read-only template replica from CentralCloud
    create table(:central_cloud_templates, primary_key: false) do
      add :id, :string, primary_key: true  # Template ID
      add :category, :string, null: false
      
      # Metadata (JSONB)
      add :metadata, :jsonb, null: false, default: "{}"
      
      # Content (JSONB)
      add :content, :jsonb, null: false
      
      # Composition
      add :extends, :string
      add :compose, {:array, :string}
      
      # Quality and usage
      add :quality_standard, :string
      add :usage_stats, :jsonb, default: "{}"
      add :quality_score, :float, default: 0.8
      
      # Vector embedding (2560-dim)
      add :embedding, :vector, size: 2560
      
      # Versioning
      add :version, :string, null: false, default: "1.0.0"
      add :deprecated, :boolean, default: false
      
      # Timestamps
      add :created_at, :utc_datetime
      add :updated_at, :utc_datetime
      add :last_synced_at, :utc_datetime  # When synced from CentralCloud
    end

    # Indexes for fast queries
    create index(:central_cloud_templates, [:category])
    create index(:central_cloud_templates, [:deprecated])
    create index(:central_cloud_templates, [:version])
    create index(:central_cloud_templates, :metadata, using: "gin")
    create index(:central_cloud_templates, :content, using: "gin")
    
    # Vector index for semantic search
    create index(:central_cloud_templates, :embedding, using: "ivfflat", with: "lists = 100")
    
    # Composite indexes
    create index(:central_cloud_templates, [:category, :deprecated])
    create index(:central_cloud_templates, ["(metadata->>'language')", :category])
    
    # Unique constraint
    create unique_index(:central_cloud_templates, [:id, :version])
    
    # Add comment explaining read-only nature
    execute """
    COMMENT ON TABLE central_cloud_templates IS 
    'Read-only replica of CentralCloud templates. 
     Templates are synced from CentralCloud via logical replication and pgflow.
     DO NOT INSERT/UPDATE/DELETE directly - use CentralCloud.TemplateService.'
    """
  end

  def down do
    drop index(:central_cloud_templates, [:id, :version])
    drop index(:central_cloud_templates, ["(metadata->>'language')", :category])
    drop index(:central_cloud_templates, [:category, :deprecated])
    drop index(:central_cloud_templates, :embedding, using: "ivfflat")
    drop index(:central_cloud_templates, :content, using: "gin")
    drop index(:central_cloud_templates, :metadata, using: "gin")
    drop index(:central_cloud_templates, [:version])
    drop index(:central_cloud_templates, [:deprecated])
    drop index(:central_cloud_templates, [:category])
    drop table(:central_cloud_templates)
  end
end
