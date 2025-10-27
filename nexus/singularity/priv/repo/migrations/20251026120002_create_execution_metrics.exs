defmodule Singularity.Repo.Migrations.CreateExecutionMetrics do
  use Ecto.Migration

  def change do
    create table(:execution_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, :binary_id, null: false
      add :task_type, :string, null: false
      add :model, :string, null: false
      add :provider, :string, null: false
      add :cost_cents, :integer, default: 0
      add :tokens_used, :integer, default: 0
      add :prompt_tokens, :integer, default: 0
      add :completion_tokens, :integer, default: 0
      add :latency_ms, :integer, default: 0
      add :success, :boolean, default: true

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:execution_metrics, [:run_id])
    create index(:execution_metrics, [:model])
    create index(:execution_metrics, [:task_type])
    create index(:execution_metrics, [:provider])
    create index(:execution_metrics, [:success])
    create index(:execution_metrics, [:inserted_at])
  end
end
