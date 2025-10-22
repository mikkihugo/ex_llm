defmodule Genesis.Repo.Migrations.CreateSandboxHistory do
  use Ecto.Migration

  def change do
    create table(:sandbox_history, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :experiment_id, references(:experiment_records, column: :experiment_id, type: :string), null: false
      add :sandbox_path, :string, null: false, comment: "Full path to sandbox directory"
      add :action, :string, null: false, comment: "created | preserved | cleaned_up"
      add :reason, :text, comment: "Reason for the action"
      add :sandbox_size_mb, :float, comment: "Size of sandbox directory in MB"
      add :duration_seconds, :integer, comment: "How long the sandbox existed"

      # Metrics snapshot at time of action
      add :final_metrics, :jsonb, default: "{}", comment: "Experiment metrics snapshot"

      # Timestamps
      add :created_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:sandbox_history, [:experiment_id])
    create index(:sandbox_history, [:action])
    create index(:sandbox_history, [:created_at], order: :desc)
  end
end
