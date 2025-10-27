defmodule Singularity.Repo.Migrations.CreatePatternCachingTables do
  use Ecto.Migration

  def change do
    # Table for caching patterns by instance and codebase checksum
    create table(:pattern_cache, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :instance_id, :string, null: false
      add :codebase_hash, :string, null: false
      add :pattern_type, :string, null: false
      add :patterns, :jsonb, null: false
      add :cached_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec
      add :hit_count, :integer, default: 0
      add :metadata, :jsonb, default: %{}

      timestamps(updated_at: false)
    end

    # Table for patterns learned per instance
    create table(:instance_patterns, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :instance_id, :string, null: false
      add :pattern_name, :string, null: false
      add :pattern_type, :string, null: false
      add :pattern_data, :jsonb, null: false
      add :confidence, :float, null: false
      add :learned_at, :utc_datetime_usec, null: false
      add :source_codebase, :string
      add :usage_count, :integer, default: 0
      add :last_used_at, :utc_datetime_usec
      add :metadata, :jsonb, default: %{}

      timestamps(updated_at: false)
    end

    # Table for cross-instance pattern consensus
    create table(:pattern_consensus, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :pattern_name, :string, null: false
      add :pattern_type, :string, null: false
      add :consensus_data, :jsonb, null: false
      add :consensus_confidence, :float, null: false
      add :instance_count, :integer, null: false
      add :last_updated, :utc_datetime_usec, null: false
      add :metadata, :jsonb, default: %{}

      timestamps(updated_at: false)
    end

    # Indexes for performance
    create index(:pattern_cache, [:instance_id, :codebase_hash, :pattern_type], name: :pattern_cache_lookup_idx)
    create index(:pattern_cache, [:expires_at], name: :pattern_cache_expiry_idx)
    create index(:instance_patterns, [:instance_id, :pattern_type], name: :instance_patterns_lookup_idx)
    create index(:instance_patterns, [:pattern_name, :pattern_type], name: :instance_patterns_name_type_idx)
    create index(:pattern_consensus, [:pattern_name, :pattern_type], unique: true, name: :pattern_consensus_unique_idx)
    create index(:pattern_consensus, [:consensus_confidence], name: :pattern_consensus_confidence_idx)

    # Partial index for active patterns
    create index(:pattern_cache, [:cached_at], where: "expires_at IS NULL OR expires_at > NOW()", name: :pattern_cache_active_idx)
    create index(:instance_patterns, [:learned_at], where: "usage_count > 0", name: :instance_patterns_used_idx)
  end
end
