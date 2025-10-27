defmodule Singularity.Repo.Migrations.CreateFailurePatterns do
  use Ecto.Migration

  def change do
    create table(:failure_patterns) do
      add :run_id, :string, null: false
      add :story_type, :string
      add :story_signature, :string, null: false
      add :failure_mode, :string, null: false
      add :root_cause, :text
      add :plan_characteristics, :map, null: false, default: %{}
      add :validation_state, :string
      add :validation_errors, {:array, :map}, null: false, default: []
      add :execution_error, :text
      add :frequency, :integer, null: false, default: 1
      add :successful_fixes, {:array, :map}, null: false, default: []
      add :last_seen_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:failure_patterns, [:story_signature, :failure_mode])
    create index(:failure_patterns, [:story_type])
    create index(:failure_patterns, [:failure_mode])
    create index(:failure_patterns, [:last_seen_at])
  end
end
