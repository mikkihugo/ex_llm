defmodule Singularity.Repo.Migrations.CreateExperimentResults do
  use Ecto.Migration

  def change do
    create table(:experiment_results, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :experiment_id, :string, null: false
      add :status, :string, null: false  # success, timeout, failed
      add :metrics, :jsonb, null: false
      add :recommendation, :string, null: false  # merge, merge_with_adaptations, rollback
      add :changes_description, :text
      add :risk_level, :string  # low, medium, high
      add :recorded_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    # Index for querying by experiment_id
    create unique_index(:experiment_results, [:experiment_id])

    # Index for querying by status
    create index(:experiment_results, [:status])

    # Index for querying by recommendation
    create index(:experiment_results, [:recommendation])

    # Index for recent results (for learning queries)
    create index(:experiment_results, [:recorded_at])

    # JSONB index for metrics queries
    create index(:experiment_results, ["(metrics)"], using: :gin)
  end
end
