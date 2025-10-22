defmodule Genesis.Repo.Migrations.CreateExperimentRecords do
  use Ecto.Migration

  def change do
    create table(:experiment_records, primary_key: false) do
      add :experiment_id, :string, primary_key: true, comment: "Unique experiment identifier"
      add :instance_id, :string, null: false, comment: "Singularity instance that requested this experiment"
      add :status, :string, null: false, default: "pending", comment: "pending | running | success | failed"
      add :risk_level, :string, null: false, default: "medium", comment: "low | medium | high"
      add :experiment_type, :string, null: false, default: "improvement", comment: "Type of experiment"
      add :description, :text, comment: "Description of the experiment and proposed changes"

      # Sandbox information
      add :sandbox_path, :string, comment: "Path to isolated sandbox directory"
      add :baseline_commit, :string, comment: "Git commit hash before changes"
      add :final_commit, :string, comment: "Git commit hash after changes (if applicable)"

      # Proposed changes
      add :changes_files, {:array, :string}, default: [], comment: "List of files changed in this experiment"
      add :changes_description, :text, comment: "Description of what changes were proposed"
      add :estimated_impact, :float, comment: "Estimated impact score (0.0 to 1.0)"

      # Timestamps
      add :created_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :started_at, :utc_datetime_usec, comment: "When execution started"
      add :completed_at, :utc_datetime_usec, comment: "When execution completed"

      # Rollback plan
      add :rollback_plan, :text, comment: "Instructions for manual rollback if needed"
    end

    create index(:experiment_records, [:instance_id])
    create index(:experiment_records, [:status])
    create index(:experiment_records, [:created_at], order: :desc)
  end
end
