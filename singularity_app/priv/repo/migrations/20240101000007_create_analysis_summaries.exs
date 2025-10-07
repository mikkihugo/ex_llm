defmodule Singularity.Repo.Migrations.CreateAnalysisSummaries do
  use Ecto.Migration

  def change do
    create table(:analysis_summaries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codebase_id, :string, null: false
      add :analysis_data, :map, null: false, default: %{}
      add :analyzed_at, :utc_datetime, null: false

      # Aggregate metrics
      add :total_files, :integer, default: 0
      add :total_lines, :integer, default: 0
      add :total_functions, :integer, default: 0
      add :total_classes, :integer, default: 0

      # Quality metrics
      add :quality_score, :float, default: 0.0
      add :technical_debt_ratio, :float, default: 0.0
      add :average_complexity, :float, default: 0.0
      add :average_maintainability, :float, default: 0.0

      # Language distribution
      add :languages, :map, default: %{}

      timestamps()
    end

    # Primary indexes for querying
    create index(:analysis_summaries, [:analyzed_at])

    # Index for cleanup queries
    create index(:analysis_summaries, [:codebase_id])

    # Index for quality-based queries
    create index(:analysis_summaries, [:quality_score])
    create index(:analysis_summaries, [:technical_debt_ratio])

    # Unique constraint for time-series data (prevent duplicate analyses at same timestamp)
    create unique_index(:analysis_summaries, [:codebase_id, :analyzed_at])
  end
end
