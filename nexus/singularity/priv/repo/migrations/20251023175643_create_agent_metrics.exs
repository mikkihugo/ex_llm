defmodule Singularity.Repo.Migrations.CreateAgentMetrics do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:agent_metrics) do
      add :agent_id, :string, null: false
      add :time_window, :tsrange, null: false
      add :success_rate, :float, null: false
      add :avg_cost_cents, :float, null: false
      add :avg_latency_ms, :float, null: false
      add :patterns_used, :jsonb, default: "{}"

      timestamps()
    end

    # Index for querying metrics by agent
    execute("""
      CREATE INDEX IF NOT EXISTS agent_metrics_agent_id_index
      ON agent_metrics (agent_id)
    """, "")

    # Index for time-range queries
    execute("""
      CREATE INDEX IF NOT EXISTS agent_metrics_time_window_index
      ON agent_metrics (time_window)
    """, "")

    # Composite index for common query pattern: agent + inserted_at
    execute("""
      CREATE INDEX IF NOT EXISTS agent_metrics_agent_id_inserted_at_index
      ON agent_metrics (agent_id, inserted_at)
    """, "")

    # Index for recent metrics lookup
    execute("""
      CREATE INDEX IF NOT EXISTS agent_metrics_inserted_at_agent_id_index
      ON agent_metrics (inserted_at, agent_id)
    """, "")
  end
end
