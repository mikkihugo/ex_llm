defmodule Singularity.Repo.Migrations.CreateMetricsAggregated do
  use Ecto.Migration

  def change do
    create table(:metrics_aggregated, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_name, :string, null: false
      add :period, :string, null: false  # "hour" or "day"
      add :period_start, :utc_datetime_usec, null: false

      # Statistics over period
      add :count, :bigint, null: false
      add :sum, :float, null: false
      add :avg, :float, null: false
      add :min, :float, null: false
      add :max, :float, null: false
      add :stddev, :float

      # Tag filters used for this aggregation
      add :tags, :jsonb, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    # Unique constraint: prevent duplicate aggregations for same period
    create unique_index(:metrics_aggregated,
      [:event_name, :period, :period_start, :tags],
      name: "metrics_aggregated_unique_idx")

    # Query indexes - most common access patterns
    create index(:metrics_aggregated, [:event_name, :period_start],
      name: "metrics_aggregated_event_time_idx")

    create index(:metrics_aggregated, [:period, :period_start],
      name: "metrics_aggregated_period_time_idx")

    create index(:metrics_aggregated, [:period_start],
      name: "metrics_aggregated_period_start_idx")
  end
end
