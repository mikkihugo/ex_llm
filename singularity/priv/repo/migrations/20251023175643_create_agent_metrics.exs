defmodule Singularity.Repo.Migrations.CreateAgentMetrics do
  use Ecto.Migration

  def change do
    create table(:agent_metrics) do
      add :agent_id, :string, null: false
      add :time_window, :tsrange, null: false
      add :success_rate, :float, null: false
      add :avg_cost_cents, :float, null: false
      add :avg_latency_ms, :float, null: false
      add :patterns_used, :jsonb, default: "{}"

      timestamps()
    end

    # Index for querying metrics by agent
    create index(:agent_metrics, [:agent_id])

    # Index for time-range queries
    create index(:agent_metrics, [:time_window], using: :gist)

    # Composite index for common query pattern: agent + inserted_at
    create index(:agent_metrics, [:agent_id, :inserted_at])

    # Index for recent metrics lookup
    create index(:agent_metrics, [:inserted_at, :agent_id])
  end
end
