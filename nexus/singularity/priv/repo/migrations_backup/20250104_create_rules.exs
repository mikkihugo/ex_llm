defmodule Singularity.Repo.Migrations.CreateRules do
  use Ecto.Migration

  def up do
    # Enable extensions
    execute "CREATE EXTENSION IF NOT EXISTS vector"
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"  # Fuzzy text matching
    execute "CREATE EXTENSION IF NOT EXISTS btree_gin"  # JSONB indexing

    # Rule categories enum
    execute """
    CREATE TYPE rule_category AS ENUM (
      'code_quality',
      'performance',
      'security',
      'refactoring',
      'vision',
      'epic',
      'feature',
      'capability',
      'story'
    )
    """

    # Pattern types enum
    execute """
    CREATE TYPE pattern_type AS ENUM (
      'regex',
      'llm',
      'metric',
      'dependency',
      'semantic'
    )
    """

    # Rules table
    create table(:rules, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :category, :rule_category, null: false
      add :confidence_threshold, :float, default: 0.7, null: false

      # Patterns stored as JSONB for flexibility
      add :patterns, :jsonb, default: "[]", null: false

      # Vector embedding for semantic similarity (pattern matching)
      add :embedding, :vector, size: 1536  # OpenAI ada-002 dimension

      # Evolution tracking
      add :version, :integer, default: 1, null: false
      add :parent_rule_id, references(:rules, type: :uuid, on_delete: :nilify_all)
      add :created_by_agent_id, :string  # Which agent created this rule
      add :evolution_count, :integer, default: 0, null: false

      # Performance tracking
      add :execution_count, :bigint, default: 0, null: false
      add :avg_execution_time_ms, :float, default: 0.0
      add :success_rate, :float, default: 0.0

      # Governance
      add :status, :string, default: "active", null: false  # active | trial | deprecated
      add :requires_consensus, :boolean, default: false, null: false

      timestamps(type: :utc_datetime_usec)
    end

    # Rule execution history (time-series for analysis)
    create table(:rule_executions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :rule_id, references(:rules, type: :uuid, on_delete: :cascade), null: false
      add :correlation_id, :uuid, null: false

      # Execution results
      add :confidence, :float, null: false
      add :decision, :string, null: false  # autonomous | collaborative | escalated
      add :reasoning, :text
      add :execution_time_ms, :integer, null: false

      # Context snapshot
      add :context, :jsonb, null: false

      # Outcome tracking (for learning)
      add :outcome, :string  # success | failure | unknown
      add :outcome_recorded_at, :utc_datetime_usec

      add :executed_at, :utc_datetime_usec, null: false
    end

    # Rule evolution proposals (consensus voting)
    create table(:rule_evolution_proposals, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :rule_id, references(:rules, type: :uuid, on_delete: :cascade), null: false
      add :proposer_agent_id, :string, null: false

      # Proposed changes
      add :proposed_patterns, :jsonb, null: false
      add :proposed_threshold, :float
      add :evolution_reasoning, :text, null: false

      # Trial results
      add :trial_results, :jsonb
      add :trial_confidence, :float

      # Consensus voting
      add :votes, :jsonb, default: "{}", null: false  # {agent_id: {vote, confidence}}
      add :consensus_reached, :boolean, default: false
      add :status, :string, default: "proposed", null: false  # proposed | approved | rejected | expired

      timestamps(type: :utc_datetime_usec)
    end

    # Rule pattern library (reusable patterns)
    create table(:rule_patterns, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :pattern_type, :pattern_type, null: false
      add :pattern_spec, :jsonb, null: false
      add :embedding, :vector, size: 1536

      # Usage stats
      add :usage_count, :integer, default: 0
      add :avg_confidence, :float, default: 0.0

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for performance
    create index(:rules, [:category])
    create index(:rules, [:status])
    create index(:rules, [:created_by_agent_id])
    create index(:rules, [:parent_rule_id])

    # Vector similarity search (pgvector)
    create index(:rules, [:embedding], using: :ivfflat, options: "vector_cosine_ops")

    # JSONB pattern search
    create index(:rules, [:patterns], using: :gin)

    # Rule executions time-series queries
    create index(:rule_executions, [:rule_id, :executed_at])
    create index(:rule_executions, [:correlation_id])
    create index(:rule_executions, [:executed_at])

    # Evolution proposals
    create index(:rule_evolution_proposals, [:rule_id, :status])
    create index(:rule_evolution_proposals, [:proposer_agent_id])

    # Pattern library
    create index(:rule_patterns, [:pattern_type])
    create index(:rule_patterns, [:embedding], using: :ivfflat, options: "vector_cosine_ops")
    create unique_index(:rule_patterns, [:name])
  end

  def down do
    drop table(:rule_patterns)
    drop table(:rule_evolution_proposals)
    drop table(:rule_executions)
    drop table(:rules)

    execute "DROP TYPE IF EXISTS pattern_type"
    execute "DROP TYPE IF EXISTS rule_category"
  end
end
