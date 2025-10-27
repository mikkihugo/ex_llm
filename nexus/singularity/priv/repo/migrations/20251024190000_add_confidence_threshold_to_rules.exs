defmodule Singularity.Repo.Migrations.AddConfidenceThresholdToRules do
  use Ecto.Migration

  def change do
    alter table(:agent_behavior_confidence_rules) do
      add :confidence_threshold, :float, default: 0.7, null: false
      add :patterns, {:array, :map}, default: []
      # Note: embedding column already exists in database, skip adding it
#       ##  add :embedding, :vector  # pgvector - install via separate migration
      add :created_by_agent_id, :string
      add :evolution_count, :integer, default: 0
      add :execution_count, :integer, default: 0
      add :avg_execution_time_ms, :float, default: 0.0
      add :success_rate, :float, default: 0.0
      add :status, :string, default: "active"
      add :requires_consensus, :boolean, default: true
    end

    # Add indexes for faster queries
    execute("""
      CREATE INDEX IF NOT EXISTS agent_behavior_confidence_rules_confidence_threshold_index
      ON agent_behavior_confidence_rules (confidence_threshold)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_behavior_confidence_rules_status_index
      ON agent_behavior_confidence_rules (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS agent_behavior_confidence_rules_category_index
      ON agent_behavior_confidence_rules (category)
    """, "")
  end
end
