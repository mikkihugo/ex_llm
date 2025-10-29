defmodule Singularity.Repo.Migrations.CreateCodeMetricsTable do
  use Ecto.Migration

  def change do
    create table(:code_metrics, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # File & Language
      add :file_path, :string, null: false
      add :language, :string, null: false
      add :project_id, :string

      # AI-Powered Metrics (0-100 scale)
      add :type_safety_score, :float
      add :type_safety_details, :map

      add :coupling_score, :float
      add :coupling_details, :map

      add :error_handling_score, :float
      add :error_handling_details, :map

      # Traditional Metrics
      add :cyclomatic_complexity, :integer
      add :cognitive_complexity, :integer
      add :lines_of_code, :integer
      add :comment_lines, :integer
      add :blank_lines, :integer
      add :maintainability_index, :float

      # Composite Scores
      add :overall_quality_score, :float
      add :overall_quality_factors, :map

      # Analysis Context
      add :code_hash, :string
      add :analysis_timestamp, :utc_datetime_usec
      add :git_commit, :string
      add :branch, :string

      # Enrichment Data
      add :similar_patterns_found, :integer, default: 0
      add :pattern_matches, :map
      add :refactoring_opportunities, :integer, default: 0
      add :test_coverage_predicted, :float

      # Status & Metadata
      add :status, :string, default: "analyzed"
      add :error_message, :string
      add :processing_time_ms, :integer

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for common queries
    create index(:code_metrics, [:file_path, :language])
    create index(:code_metrics, [:language, :overall_quality_score])
    create index(:code_metrics, [:analysis_timestamp])
    create index(:code_metrics, [:status])
    create index(:code_metrics, [:code_hash], unique: true)

    # For metric history queries
    create index(:code_metrics, [:file_path, :analysis_timestamp])

    # For language reports
    create index(:code_metrics, [:language, :type_safety_score])
    create index(:code_metrics, [:language, :coupling_score])
    create index(:code_metrics, [:language, :error_handling_score])
  end
end
