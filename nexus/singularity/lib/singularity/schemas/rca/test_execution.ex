defmodule Singularity.Schemas.RCA.TestExecution do
  @moduledoc """
  Root Cause Analysis (RCA) Schema: Test Execution Results

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.Schemas.RCA.TestExecution",
    "purpose": "Track test execution results for generated code validation",
    "type": "Ecto Schema - Test results",
    "operates_on": "Generated code test runs",
    "output": "Test metrics (pass rate, coverage, execution time) for RCA"
  }
  ```

  ## Purpose

  Captures validation outcomes through actual test execution:
  - Test pass rates and coverage metrics
  - Stack traces and failure details
  - Performance metrics during testing
  - Links tests to generation sessions for learning

  Enables learning from:
  - Which generation strategies pass more tests?
  - How does test coverage correlate with code quality?
  - What's the typical test execution time?
  - How are failures distributed across test types?

  ## Relationships

  - **belongs_to** :code_file - The generated code being tested
  - **belongs_to** :generation_session - The generation attempt that triggered testing
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "test_executions" do
    # Linking

    # Test execution results
    field :test_pass_rate, :decimal
    field :test_coverage_line, :decimal
    field :test_coverage_branch, :decimal
    field :failed_test_count, :integer, default: 0
    field :passed_test_count, :integer, default: 0
    field :total_test_count, :integer, default: 0
    field :skipped_test_count, :integer, default: 0

    # Failure details
    field :first_failure_trace, :string
    field :all_failures, :map

    # Performance metrics
    field :execution_time_ms, :integer
    field :peak_memory_mb, :integer

    # Status
    field :status, :string, default: "completed"

    # Timestamps
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    # Relationships
    belongs_to :code_file, Singularity.Schemas.CodeFile,
      foreign_key: :code_file_id,
      type: :binary_id

    belongs_to :generation_session, Singularity.Schemas.RCA.GenerationSession,
      foreign_key: :triggered_by_session_id,
      type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(test_execution, attrs) do
    test_execution
    |> cast(attrs, [
      :test_pass_rate,
      :test_coverage_line,
      :test_coverage_branch,
      :failed_test_count,
      :passed_test_count,
      :total_test_count,
      :skipped_test_count,
      :first_failure_trace,
      :all_failures,
      :execution_time_ms,
      :peak_memory_mb,
      :status,
      :started_at,
      :completed_at
    ])
    |> validate_required([:status])
    |> validate_inclusion(:status, ["completed", "timeout", "error"])
    |> validate_number(:test_pass_rate, greater_than_or_equal_to: Decimal.new(0), less_than_or_equal_to: Decimal.new(100))
    |> validate_number(:test_coverage_line, greater_than_or_equal_to: Decimal.new(0), less_than_or_equal_to: Decimal.new(100))
  end

  @doc """
  Create a new test execution record.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:status, "completed")
    |> put_change(:started_at, DateTime.utc_now(:microsecond))
    |> put_change(:completed_at, DateTime.utc_now(:microsecond))
  end

  @doc """
  Check if tests passed.
  """
  def all_tests_passed?(test_execution) do
    Decimal.equal?(test_execution.test_pass_rate, Decimal.new(100))
  end

  @doc """
  Check if coverage is acceptable (>= 80%).
  """
  def adequate_coverage?(test_execution, min_coverage \\ Decimal.new(80)) do
    case test_execution.test_coverage_line do
      nil -> false
      coverage -> Decimal.greater_than_or_equal?(coverage, min_coverage)
    end
  end

  @doc """
  Get test metrics summary.
  """
  def summary(test_execution) do
    %{
      all_passed: all_tests_passed?(test_execution),
      pass_rate: test_execution.test_pass_rate,
      coverage: test_execution.test_coverage_line,
      total_tests: test_execution.total_test_count,
      passed_tests: test_execution.passed_test_count,
      failed_tests: test_execution.failed_test_count,
      skipped_tests: test_execution.skipped_test_count,
      execution_time_ms: test_execution.execution_time_ms,
      has_failures: test_execution.failed_test_count > 0
    }
  end
end
