defmodule Singularity.Repo.Migrations.CreateAutonomyTables do
  use Ecto.Migration

  @moduledoc """
  Creates autonomy system tables for rule execution tracking and evolution.

  These tables support the autonomous agent system's learning and improvement:
  - rule_executions: Time-series record of rule executions for analysis
  - rule_evolution_proposals: Consensus-based rule improvement proposals

  Related schemas:
  - Singularity.Execution.Autonomy.RuleExecution
  - Singularity.Execution.Autonomy.RuleEvolutionProposal
  """

  def up do
    # ===== RULE EXECUTIONS TABLE =====
    # Time-series record of rule executions for learning and analysis
    create table(:rule_executions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :rule_id, references(:rules, type: :binary_id, on_delete: :delete_all), null: false
      add :correlation_id, :binary_id, null: false

      # Execution details
      add :confidence, :float, null: false
      add :decision, :string, null: false
      add :reasoning, :string
      add :execution_time_ms, :integer, null: false

      # Context snapshot at execution time
      add :context, :map, null: false, default: %{}

      # Outcome tracking
      add :outcome, :string  # success, failure, unknown
      add :outcome_recorded_at, :utc_datetime_usec

      # Execution timestamp
      add :executed_at, :utc_datetime_usec, null: false
    end

    # Indexes for rule_executions
    create index(:rule_executions, [:rule_id])
    create index(:rule_executions, [:correlation_id])
    create index(:rule_executions, [:executed_at])
    create index(:rule_executions, [:decision])
    create index(:rule_executions, [:outcome])
    create index(:rule_executions, [:rule_id, :executed_at])
    create index(:rule_executions, [:context], using: :gin)

    # ===== RULE EVOLUTION PROPOSALS TABLE =====
    # Consensus-based rule evolution proposals
    create table(:rule_evolution_proposals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :rule_id, references(:rules, type: :binary_id, on_delete: :delete_all), null: false
      add :proposer_agent_id, :string, null: false

      # Proposed changes
      add :proposed_patterns, {:array, :map}, null: false
      add :proposed_threshold, :float
      add :evolution_reasoning, :string, null: false

      # Trial results
      add :trial_results, :map
      add :trial_confidence, :float

      # Consensus tracking
      add :votes, :map, default: %{}
      add :consensus_reached, :boolean, default: false
      add :status, :string, default: "proposed"  # proposed, approved, rejected, expired

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for rule_evolution_proposals
    create index(:rule_evolution_proposals, [:rule_id])
    create index(:rule_evolution_proposals, [:proposer_agent_id])
    create index(:rule_evolution_proposals, [:status])
    create index(:rule_evolution_proposals, [:consensus_reached])
    create index(:rule_evolution_proposals, [:inserted_at])
    create index(:rule_evolution_proposals, [:votes], using: :gin)

    # Composite indexes for common queries
    create index(:rule_evolution_proposals, [:rule_id, :status])
    create index(:rule_evolution_proposals, [:status, :consensus_reached])
  end

  def down do
    drop table(:rule_evolution_proposals)
    drop table(:rule_executions)
  end
end
