defmodule Singularity.Repo.Migrations.CreateTestExecutions do
  use Ecto.Migration

  def change do
    create table(:test_executions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Linking
      add :code_file_id, :uuid, null: false  # The code that was tested
      add :triggered_by_session_id, :uuid  # The generation session that triggered testing
      add :generation_session_id, :uuid  # If testing was part of validation

      # Test execution results
      add :test_pass_rate, :decimal, precision: 5, scale: 2, default: 0  # 0.0 to 100.0
      add :test_coverage_line, :decimal, precision: 5, scale: 2, default: 0  # 0.0 to 100.0
      add :test_coverage_branch, :decimal, precision: 5, scale: 2  # Optional branch coverage
      add :failed_test_count, :integer, default: 0
      add :passed_test_count, :integer, default: 0
      add :total_test_count, :integer, default: 0
      add :skipped_test_count, :integer, default: 0

      # Failure details
      add :first_failure_trace, :text  # Full stack trace of first error
      add :all_failures, :map  # Array of all test failures

      # Performance metrics
      add :execution_time_ms, :integer  # Total test execution time
      add :peak_memory_mb, :integer  # Memory used during tests

      # Status
      add :status, :string, null: false, default: "completed"  # completed, timeout, error

      # Timestamps
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    # Indexes
    create index(:test_executions, [:code_file_id])
    create index(:test_executions, [:triggered_by_session_id])
    create index(:test_executions, [:generation_session_id])
    create index(:test_executions, [:status])
    create index(:test_executions, [:inserted_at])

    # Foreign key for code_file (if it exists)
    # Note: This will be added in the RCA foreign keys migration
  end
end
