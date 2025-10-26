defmodule Singularity.Repo.Migrations.CreateMetricsEvents do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:metrics_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_name, :string, null: false
      add :measurement, :float, null: false
      add :unit, :string, null: false
      add :tags, :jsonb, null: false, default: "{}"
      add :recorded_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    # Query indexes - most common access patterns
    execute("""
      CREATE INDEX IF NOT EXISTS metrics_events_event_name_recorded_at_index
      ON metrics_events (event_name, recorded_at)
    """, "")

    execute("""
      CREATE INDEX IF NOT EXISTS metrics_events_recorded_at_index
      ON metrics_events (recorded_at)
    """, "")

    # GIN index for JSONB tag queries
    execute("""
      CREATE INDEX IF NOT EXISTS metrics_events_tags_index
      ON metrics_events (tags)
    """, "")
  end
end
