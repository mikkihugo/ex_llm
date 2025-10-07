defmodule Singularity.Repo.Migrations.CreateRunnerExecutions do
  use Ecto.Migration

  def change do
    create table(:runner_executions) do
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

    create unique_index(:runner_executions, [:execution_id])
    create index(:runner_executions, [:status])
    create index(:runner_executions, [:task_type])
    create index(:runner_executions, [:started_at])
    create index(:runner_executions, [:completed_at])
  end
end