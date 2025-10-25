defmodule Singularity.Repo.Migrations.CreateRunnerExecutions do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:runner_executions) do
      add :execution_id, :string, null: false
      add :task_type, :string, null: false
      add :task_args, :map, default: %{}
      add :status, :string, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :completed_at, :utc_datetime_usec
      add :result, :map
      add :error, :text
      add :execution_time_ms, :integer
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS runner_executions_execution_id_key
      ON runner_executions (execution_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS runner_executions_status_index
      ON runner_executions (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS runner_executions_task_type_index
      ON runner_executions (task_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS runner_executions_started_at_index
      ON runner_executions (started_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS runner_executions_completed_at_index
      ON runner_executions (completed_at)
    """, "")
  end
end