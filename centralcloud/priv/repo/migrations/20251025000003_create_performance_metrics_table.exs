defmodule CentralCloud.Repo.Migrations.CreatePerformanceMetricsTable do
  use Ecto.Migration

  def change do
    create table(:job_statistics, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v7()")
      add :job_id, :uuid, null: false
      add :language, :string, null: false
      add :status, :string, null: false  # success, failure, timeout
      add :execution_time_ms, :integer, null: false
      add :memory_used_mb, :float
      add :lines_analyzed, :integer
      add :instance_id, :string  # Which Singularity instance ran this
      add :recorded_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:job_statistics, [:language])
    create index(:job_statistics, [:status])
    create index(:job_statistics, [:instance_id])
    create index(:job_statistics, [:recorded_at])

    # Aggregated metrics table (hourly/daily rollups)
    create table(:execution_metrics, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v7()")
      add :period_start, :utc_datetime_usec, null: false
      add :period_end, :utc_datetime_usec, null: false
      add :jobs_completed, :integer, null: false, default: 0
      add :jobs_failed, :integer, null: false, default: 0
      add :success_rate, :float, null: false, default: 0.0
      add :avg_execution_time_ms, :float
      add :total_memory_used_mb, :float
      add :p50_execution_time_ms, :float  # Percentile metrics
      add :p95_execution_time_ms, :float
      add :p99_execution_time_ms, :float
      add :instance_id, :string  # All instances or specific instance

      timestamps(type: :utc_datetime_usec)
    end

    create index(:execution_metrics, [:period_start])
    create index(:execution_metrics, [:instance_id])
    create index(:execution_metrics, [:success_rate])
  end
end
