defmodule Singularity.Repo.Migrations.CreateValidationMetrics do
  use Ecto.Migration

  def change do
    create table(:validation_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, :binary_id, null: false
      add :check_id, :string, null: false
      add :check_type, :string, null: false
      add :result, :string, null: false
      add :confidence_score, :float, default: 0.5
      add :runtime_ms, :integer, default: 0
      add :context, :jsonb, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:validation_metrics, [:run_id])
    create index(:validation_metrics, [:check_id])
    create index(:validation_metrics, [:check_type])
    create index(:validation_metrics, [:result])
    create index(:validation_metrics, [:inserted_at])
  end
end
