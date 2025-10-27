defmodule Singularity.Repo.Migrations.CreateWorkflowRunsTable do
  use Ecto.Migration

  def up do
    create table(:workflow_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :workflow_slug, :string, null: false
      add :status, :string, null: false, default: "started"
      add :input, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :output, :jsonb
      add :remaining_steps, :integer, null: false, default: 0
      add :error_message, :text

      timestamps(type: :utc_datetime_usec)
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :failed_at, :utc_datetime_usec
    end

    create index(:workflow_runs, [:workflow_slug])
    create index(:workflow_runs, [:status])
    create index(:workflow_runs, [:inserted_at])

    # Composite index for common queries
    create index(:workflow_runs, [:workflow_slug, :status])

    # Partial index for active runs
    create index(:workflow_runs, [:id], where: "status = 'started'", name: :workflow_runs_active_idx)

    execute """
    COMMENT ON TABLE workflow_runs IS 'Tracks workflow execution instances (matches pgflow.runs)'
    """

    execute """
    COMMENT ON COLUMN workflow_runs.workflow_slug IS 'Workflow module name (e.g., Singularity.Workflows.LlmRequest)'
    """

    execute """
    COMMENT ON COLUMN workflow_runs.status IS 'Execution status: started, completed, failed'
    """

    execute """
    COMMENT ON COLUMN workflow_runs.remaining_steps IS 'Count of steps not yet completed in this run'
    """
  end

  def down do
    drop table(:workflow_runs)
  end
end
