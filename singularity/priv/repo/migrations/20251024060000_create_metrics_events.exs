defmodule Singularity.Repo.Migrations.CreateMetricsEvents do
  use Ecto.Migration

  def change do
    create table(:metrics_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_name, :string, null: false
      add :measurement, :float, null: false
      add :unit, :string, null: false
      add :tags, :jsonb, null: false, default: "{}"
      add :recorded_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    # Query indexes - most common access patterns
    create index(:metrics_events, [:event_name, :recorded_at],
      name: "metrics_events_event_time_idx")

    create index(:metrics_events, [:recorded_at],
      name: "metrics_events_recorded_at_idx")

    # GIN index for JSONB tag queries
    create index(:metrics_events, [:tags],
      name: "metrics_events_tags_idx",
      using: :gin)
  end
end
