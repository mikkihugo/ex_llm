defmodule CentralCloud.Repo.Migrations.CreateEvolutionTables do
  use Ecto.Migration

  def up do
    # Enable pgvector extension if not already enabled
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    # Guardian: approved_changes table
    create table(:approved_changes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :instance_id, :string, null: false
      add :change_type, :string, null: false
      add :code_changeset, :jsonb, null: false
      add :safety_profile, :jsonb, null: false
      add :status, :string, null: false, default: "active"
      add :rollback_strategy, :jsonb
      add :rollback_history, {:array, :jsonb}, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create index(:approved_changes, [:instance_id])
    create index(:approved_changes, [:change_type])
    create index(:approved_changes, [:status])
    create index(:approved_changes, [:inserted_at])

    # Guardian: change_metrics table (time-series metrics)
    create table(:change_metrics, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :change_id, references(:approved_changes, type: :uuid, on_delete: :delete_all), null: false
      add :instance_id, :string, null: false
      add :success_rate, :float
      add :error_rate, :float
      add :latency_p95_ms, :integer
      add :cost_cents, :float
      add :throughput_per_min, :integer
      add :reported_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:change_metrics, [:change_id])
    create index(:change_metrics, [:instance_id])
    create index(:change_metrics, [:reported_at])
    create index(:change_metrics, [:change_id, :reported_at])  # Time-series queries

    # Patterns: patterns table with pgvector embeddings
    create table(:patterns, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :pattern_type, :string, null: false
      add :code_pattern, :jsonb, null: false
      add :source_instances, {:array, :string}, null: false, default: []
      add :consensus_score, :float, default: 0.0
      add :success_rate, :float, null: false
      add :safety_profile, :jsonb
      add :embedding, :vector, size: 2560  # Qodo (1536) + Jina v3 (1024) = 2560-dim
      add :promoted_to_genesis, :boolean, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:patterns, [:pattern_type])
    create index(:patterns, [:consensus_score])
    create index(:patterns, [:promoted_to_genesis])
    create index(:patterns, [:inserted_at])

    # Vector similarity index for semantic search (HNSW for performance)
    execute """
    CREATE INDEX patterns_embedding_idx ON patterns
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    """

    # Patterns: pattern_usage table (tracking per-instance usage)
    create table(:pattern_usage, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :pattern_id, references(:patterns, type: :uuid, on_delete: :delete_all), null: false
      add :instance_id, :string, null: false
      add :success_rate, :float, null: false
      add :usage_count, :integer, null: false, default: 1
      add :last_used_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:pattern_usage, [:pattern_id])
    create index(:pattern_usage, [:instance_id])
    create index(:pattern_usage, [:last_used_at])
    create unique_index(:pattern_usage, [:pattern_id, :instance_id])

    # Consensus: consensus_votes table
    create table(:consensus_votes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :change_id, :string, null: false
      add :instance_id, :string, null: false
      add :vote, :string, null: false
      add :confidence, :float, null: false
      add :reason, :text, null: false
      add :voted_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:consensus_votes, [:change_id])
    create index(:consensus_votes, [:instance_id])
    create index(:consensus_votes, [:voted_at])
    create unique_index(:consensus_votes, [:change_id, :instance_id])

    # Add constraints
    execute """
    ALTER TABLE approved_changes
    ADD CONSTRAINT approved_changes_change_type_check
    CHECK (change_type IN ('pattern_enhancement', 'model_optimization', 'cache_improvement', 'code_refactoring'))
    """

    execute """
    ALTER TABLE approved_changes
    ADD CONSTRAINT approved_changes_status_check
    CHECK (status IN ('active', 'rolled_back', 'superseded', 'expired'))
    """

    execute """
    ALTER TABLE patterns
    ADD CONSTRAINT patterns_pattern_type_check
    CHECK (pattern_type IN ('framework', 'technology', 'service_architecture', 'code_template', 'error_handling'))
    """

    execute """
    ALTER TABLE consensus_votes
    ADD CONSTRAINT consensus_votes_vote_check
    CHECK (vote IN ('approve', 'reject'))
    """

    execute """
    ALTER TABLE consensus_votes
    ADD CONSTRAINT consensus_votes_confidence_check
    CHECK (confidence >= 0.0 AND confidence <= 1.0)
    """
  end

  def down do
    drop table(:consensus_votes)
    drop table(:pattern_usage)
    execute "DROP INDEX IF EXISTS patterns_embedding_idx"
    drop table(:patterns)
    drop table(:change_metrics)
    drop table(:approved_changes)
  end
end
