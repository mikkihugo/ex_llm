defmodule Genesis.Repo.Migrations.CreateExperimentMetrics do
  use Ecto.Migration

  def change do
    create table(:experiment_metrics, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :experiment_id, references(:experiment_records, column: :experiment_id, type: :string), null: false

      # Outcome metrics
      add :success_rate, :float, null: false, default: 0.0, comment: "Percentage of tests passed (0.0 to 1.0)"
      add :regression, :float, null: false, default: 0.0, comment: "Percentage of regressions (0.0 to 1.0)"
      add :llm_reduction, :float, null: false, default: 0.0, comment: "Reduction in LLM calls (0.0 to 1.0)"
      add :runtime_ms, :integer, null: false, default: 0, comment: "Total execution time in milliseconds"

      # Performance metrics
      add :memory_peak_mb, :float, comment: "Peak memory usage in MB"
      add :cpu_usage_percent, :float, comment: "Average CPU utilization percentage"
      add :io_operations, :integer, default: 0, comment: "Number of disk I/O operations"

      # Quality metrics
      add :code_coverage_percent, :float, comment: "Code coverage percentage"
      add :complexity_change, :float, comment: "Change in cyclomatic complexity"
      add :performance_delta, :float, comment: "Performance improvement/regression percentage"

      # Test results
      add :test_count, :integer, default: 0, comment: "Total tests run"
      add :test_failures, :integer, default: 0, comment: "Number of test failures"
      add :test_errors, :integer, default: 0, comment: "Number of test errors"

      # Recommendation
      add :recommendation, :string, comment: "merge | merge_with_adaptations | rollback"
      add :recommendation_rationale, :text, comment: "Why this recommendation was made"

      # Detailed results
      add :detailed_results, :jsonb, default: "{}", comment: "Detailed test results and metrics"
      add :error_log, :text, comment: "Error messages if experiment failed"

      # Timestamps
      add :measured_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:experiment_metrics, [:experiment_id])
    create index(:experiment_metrics, [:recommendation])
    create index(:experiment_metrics, [:measured_at], order: :desc)
  end
end
