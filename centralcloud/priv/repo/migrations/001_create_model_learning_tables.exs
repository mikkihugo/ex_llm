defmodule CentralCloud.Repo.Migrations.CreateModelLearningTables do
  use Ecto.Migration

  def change do
    # Audit log of all routing decisions
    create table(:routing_records) do
      add :timestamp, :utc_datetime, null: false
      add :instance_id, :string, null: false
      add :complexity, :string, null: false
      add :model, :string, null: false
      add :provider, :string, null: false
      add :score, :float, null: false
      add :outcome, :string, default: "routed"
      add :response_time_ms, :integer
      add :capabilities_required, {:array, :string}, default: []
      add :preference, :string

      timestamps(type: :utc_datetime)
    end

    create index(:routing_records, [:model, :complexity])
    create index(:routing_records, [:timestamp, :instance_id])
    create index(:routing_records, [:outcome])

    # Aggregated metrics for learning
    create table(:model_routing_metrics) do
      add :model_name, :string, null: false
      add :complexity_level, :string, null: false
      add :usage_count, :bigint, default: 0
      add :success_count, :bigint, default: 0
      add :response_times, {:array, :integer}, default: []
      add :avg_response_time, :float
      add :response_time_count, :bigint, default: 0

      timestamps(type: :utc_datetime)
    end

    # Unique constraint: one row per (model, complexity) combo
    create unique_index(
      :model_routing_metrics,
      [:model_name, :complexity_level],
      name: :model_routing_metrics_model_complexity_idx
    )

    # Fast lookups by complexity
    create index(:model_routing_metrics, [:complexity_level])
    create index(:model_routing_metrics, [desc: :usage_count])
  end
end
