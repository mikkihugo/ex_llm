defmodule Singularity.Repo.Migrations.CreateExecutionOutcomes do
  use Ecto.Migration

  def change do
    create table(:execution_outcomes) do
      add :agent, :string, null: false
      add :task_id, :string, null: false
      add :task_domain, :string, null: false
      add :success, :boolean, null: false
      add :latency_ms, :integer
      add :tokens_used, :integer
      add :quality_score, :float
      add :feedback, :text
      add :error, :text
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for efficient queries
    create index(:execution_outcomes, [:agent])
    create index(:execution_outcomes, [:task_domain])
    create index(:execution_outcomes, [:agent, :task_domain])
    create index(:execution_outcomes, [:success])
    create index(:execution_outcomes, [:inserted_at])
  end
end
