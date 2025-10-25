defmodule Singularity.Repo.Migrations.CreateCodeAnalysisResults do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:code_analysis_results, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Reference to code file
      add :code_file_id, references(:code_files, type: :binary_id, on_delete: :delete_all), null: false

      # Analysis metadata
      add :language_id, :string, null: false
      add :analyzer_version, :string, null: false, default: "1.0.0"
      add :analysis_type, :string, null: false  # "full", "rca_only", "ast_only"

      # Basic analysis results
      add :complexity_score, :float
      add :quality_score, :float
      add :maintainability_score, :float

      # RCA metrics (nullable for non-RCA languages)
      add :cyclomatic_complexity, :integer
      add :cognitive_complexity, :integer
      add :maintainability_index, :integer
      add :source_lines_of_code, :integer
      add :physical_lines_of_code, :integer
      add :logical_lines_of_code, :integer
      add :comment_lines_of_code, :integer

      # Halstead metrics
      add :halstead_difficulty, :float
      add :halstead_volume, :float
      add :halstead_effort, :float
      add :halstead_bugs, :float

      # AST extraction results
      add :functions_count, :integer
      add :classes_count, :integer
      add :imports_count, :integer
      add :exports_count, :integer

      # Full analysis data (JSONB for flexible storage)
      add :analysis_data, :jsonb
      add :functions, :jsonb
      add :classes, :jsonb
      add :imports_exports, :jsonb
      add :rule_violations, :jsonb
      add :patterns_detected, :jsonb

      # Error tracking
      add :has_errors, :boolean, default: false
      add :error_message, :text
      add :error_details, :jsonb

      # Performance tracking
      add :analysis_duration_ms, :integer
      add :cache_hit, :boolean, default: false

      # Timestamps
      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for common queries
    execute("""
      CREATE INDEX IF NOT EXISTS code_analysis_results_code_file_id_index
      ON code_analysis_results (code_file_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_analysis_results_language_id_index
      ON code_analysis_results (language_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_analysis_results_analysis_type_index
      ON code_analysis_results (analysis_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_analysis_results_inserted_at_index
      ON code_analysis_results (inserted_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_analysis_results_quality_score_index
      ON code_analysis_results (quality_score)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_analysis_results_complexity_score_index
      ON code_analysis_results (complexity_score)
    """, "")

    # Composite index for historical trending
    execute("""
      CREATE INDEX IF NOT EXISTS code_analysis_results_code_file_id_inserted_at_index
      ON code_analysis_results (code_file_id, inserted_at)
    """, "")

    # GIN index for JSONB queries
    execute("""
      CREATE INDEX IF NOT EXISTS code_analysis_results_analysis_data_index
      ON code_analysis_results (analysis_data)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_analysis_results_rule_violations_index
      ON code_analysis_results (rule_violations)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_analysis_results_patterns_detected_index
      ON code_analysis_results (patterns_detected)
    """, "")
  end
end
