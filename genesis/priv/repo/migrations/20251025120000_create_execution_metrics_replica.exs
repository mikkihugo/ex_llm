defmodule Genesis.Repo.Migrations.CreateExecutionMetricsReplica do
  @moduledoc """
  Create execution_metrics and job_statistics tables as read-only replicas from CentralCloud.

  These tables receive replicated data from CentralCloud via PostgreSQL Logical Replication.
  Genesis subscribes to:
  - job_statistics_pub (per-job execution details)
  - execution_metrics_pub (aggregated 5-minute metrics)

  ## Replication Flow

  ```
  CentralCloud.job_statistics (source)
    ↓ PUBLICATION: job_statistics_pub
  Genesis.job_statistics (replica, read-only)

  CentralCloud.execution_metrics (source)
    ↓ PUBLICATION: execution_metrics_pub
  Genesis.execution_metrics (replica, read-only)
  ```

  ## job_statistics Table

  Per-job execution statistics from all Singularity instances.

  - id (UUID v7) - Unique job execution record
  - job_id (UUID) - Job identifier (references job, allows NULL)
  - language - Programming language analyzed
  - status - Job status (running, completed, failed)
  - execution_time_ms - How long job took
  - memory_used_mb - Memory consumed
  - lines_analyzed - Code lines processed
  - instance_id - Which Singularity instance ran job
  - recorded_at - When job was recorded

  ## execution_metrics Table

  Aggregated metrics over 5-minute windows from all instances.

  - id (UUID v7) - Unique metrics record
  - period_start - Window start time (5-min boundaries)
  - period_end - Window end time
  - jobs_completed - Count of successful jobs in window
  - jobs_failed - Count of failed jobs
  - success_rate - Completion rate (0.0-1.0)
  - avg_execution_time_ms - Average job duration
  - total_memory_used_mb - Total memory for window
  - p50_execution_time_ms - 50th percentile duration
  - p95_execution_time_ms - 95th percentile duration
  - p99_execution_time_ms - 99th percentile duration
  - instance_id - Which instance reported metrics

  ## Constraints

  - (period_start, period_end, instance_id) unique per metrics record
  - Indexes optimized for time-series queries
  """

  use Ecto.Migration

  def change do
    # Job-level statistics table
    create table(:job_statistics, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v7()")
      add :job_id, :uuid
      add :language, :string, null: false
      add :status, :string, null: false  # running, completed, failed
      add :execution_time_ms, :integer
      add :memory_used_mb, :integer
      add :lines_analyzed, :integer
      add :instance_id, :string, null: false
      add :recorded_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:job_statistics, [:job_id], name: "job_statistics_job_id_idx")
    create index(:job_statistics, [:instance_id], name: "job_statistics_instance_id_idx")
    create index(:job_statistics, [:status], name: "job_statistics_status_idx")
    create index(:job_statistics, [:recorded_at], name: "job_statistics_recorded_at_idx")

    # Aggregated metrics table (5-minute windows)
    create table(:execution_metrics, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v7()")
      add :period_start, :utc_datetime_usec, null: false
      add :period_end, :utc_datetime_usec, null: false
      add :jobs_completed, :integer, default: 0
      add :jobs_failed, :integer, default: 0
      add :success_rate, :float, default: 1.0
      add :avg_execution_time_ms, :integer
      add :total_memory_used_mb, :integer
      add :p50_execution_time_ms, :integer
      add :p95_execution_time_ms, :integer
      add :p99_execution_time_ms, :integer
      add :instance_id, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:execution_metrics, [:period_start, :period_end, :instance_id],
      name: "execution_metrics_period_instance_unique"
    )

    create index(:execution_metrics, [:period_start], name: "execution_metrics_period_start_idx")
    create index(:execution_metrics, [:instance_id], name: "execution_metrics_instance_id_idx")
  end

  def down do
    drop table(:execution_metrics)
    drop table(:job_statistics)
  end
end
