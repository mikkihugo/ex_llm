defmodule Genesis.Schemas.ExperimentMetrics do
  @moduledoc """
  ExperimentMetrics Schema

  Stores detailed metrics and results from experiment execution.

  Each metric record contains:
  - Outcome measurements (success rate, regression, LLM reduction)
  - Performance measurements (runtime, memory, CPU)
  - Quality measurements (code coverage, complexity changes)
  - Test results and errors
  - Final recommendation decision

  ## Metrics Tracked

  ### Outcome Metrics
  - `success_rate` - Percentage of tests passed (0.0-1.0)
  - `regression` - Percentage of regressions (0.0-1.0)
  - `llm_reduction` - Reduction in LLM calls (0.0-1.0)

  ### Performance Metrics
  - `runtime_ms` - Total execution time
  - `memory_peak_mb` - Peak memory usage
  - `cpu_usage_percent` - Average CPU utilization

  ### Quality Metrics
  - `code_coverage_percent` - Test coverage
  - `complexity_change` - Cyclomatic complexity change
  - `performance_delta` - Performance improvement/regression

  ### Recommendation
  - `:merge` - Safe to merge directly
  - `:merge_with_adaptations` - Merge with caution flags
  - `:rollback` - Reject and rollback
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "experiment_metrics" do
    # Outcome metrics
    field :success_rate, :float, default: 0.0
    field :regression, :float, default: 0.0
    field :llm_reduction, :float, default: 0.0
    field :runtime_ms, :integer, default: 0

    # Performance metrics
    field :memory_peak_mb, :float
    field :cpu_usage_percent, :float
    field :io_operations, :integer, default: 0

    # Quality metrics
    field :code_coverage_percent, :float
    field :complexity_change, :float
    field :performance_delta, :float

    # Test results
    field :test_count, :integer, default: 0
    field :test_failures, :integer, default: 0
    field :test_errors, :integer, default: 0

    # Recommendation
    field :recommendation, :string
    field :recommendation_rationale, :string

    # Detailed results
    field :detailed_results, :map, default: %{}
    field :error_log, :string

    # Timestamps
    field :measured_at, :utc_datetime_usec

    # Association
    belongs_to :experiment, Genesis.Schemas.ExperimentRecord, foreign_key: :experiment_id, references: :experiment_id, type: :string
  end

  @doc """
  Create a new metrics record.
  """
  def create_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [
      :experiment_id,
      :success_rate,
      :regression,
      :llm_reduction,
      :runtime_ms,
      :memory_peak_mb,
      :cpu_usage_percent,
      :io_operations,
      :code_coverage_percent,
      :complexity_change,
      :performance_delta,
      :test_count,
      :test_failures,
      :test_errors,
      :recommendation,
      :recommendation_rationale,
      :detailed_results,
      :error_log
    ])
    |> validate_required([:experiment_id])
    |> validate_number(:success_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:regression, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:llm_reduction, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end
end
