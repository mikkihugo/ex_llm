defmodule Singularity.Repo.Migrations.CreatePatternCachingTables do
  use Ecto.Migration

  def change do
    # Enable pgvector extension for vector operations
    execute "CREATE EXTENSION IF NOT EXISTS vector;"

    # Table for caching patterns with TTL
    create table(:pattern_cache, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :pattern_key, :string
      add :pattern_data, :text  # JSON-encoded pattern
      add :instance_id, :string
      add :expires_at, :utc_datetime
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")

      timestamps()
    end

    create index(:pattern_cache, [:pattern_key, :instance_id])
    create index(:pattern_cache, [:expires_at])

    # Table for tracking pattern detections across instances
    create table(:instance_patterns, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :pattern_key, :string
      add :instance_id, :string
      add :confidence_score, :float
      add :detected_at, :utc_datetime
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")

      timestamps()
    end

    create index(:instance_patterns, [:pattern_key, :instance_id])
    create index(:instance_patterns, [:detected_at])

    # Table for storing pattern consensus across instances
    create table(:pattern_consensus, primary_key: false) do
      add :pattern_key, :string, primary_key: true
      add :total_instances, :integer
      add :average_confidence, :float
      add :consensus_level, :string

      timestamps()
    end

    create index(:pattern_consensus, [:consensus_level])
    create index(:pattern_consensus, [:updated_at])
  end
end
