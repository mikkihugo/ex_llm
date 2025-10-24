defmodule Singularity.Repo.Migrations.AddConfidenceThresholdToRules do
  use Ecto.Migration

  def change do
    alter table(:agent_behavior_confidence_rules) do
      add :confidence_threshold, :float, default: 0.7, null: false
      add :patterns, {:array, :map}, default: []
      add :embedding, Singularity.Pgvector.Vector
      add :version, :integer, default: 1
      add :created_by_agent_id, :string
      add :evolution_count, :integer, default: 0
      add :execution_count, :integer, default: 0
      add :avg_execution_time_ms, :float, default: 0.0
      add :success_rate, :float, default: 0.0
      add :status, :string, default: "active"
      add :requires_consensus, :boolean, default: true
    end

    # Add indexes for faster queries
    create index(:agent_behavior_confidence_rules, [:confidence_threshold])
    create index(:agent_behavior_confidence_rules, [:status])
    create index(:agent_behavior_confidence_rules, [:category])
  end
end
