defmodule Singularity.Repo.Migrations.CreateSearchMetricsTable do
  use Ecto.Migration

  def change do
    # NOTE: This table already exists in the database
    # This migration is idempotent - it only creates if table doesn't exist
    create_if_not_exists table(:search_metrics) do
      add :query, :string, null: false
      add :elapsed_ms, :integer, null: false
      add :results_count, :integer, null: false
      add :embedding_model, :string, null: false
      add :cache_hit, :boolean, default: false
      add :fallback_used, :boolean, default: false
      add :user_satisfaction, :integer
      add :result_index, :integer
      add :rated_at, :utc_datetime

      timestamps()
    end

    # Index for query lookups
    create_if_not_exists index(:search_metrics, [:query])
    # Index for time-based queries
    create_if_not_exists index(:search_metrics, [:inserted_at])
    # Composite index for query + satisfaction
    create_if_not_exists index(:search_metrics, [:query, :user_satisfaction])
  end
end
