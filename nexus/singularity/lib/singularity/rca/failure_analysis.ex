defmodule Singularity.RCA.FailureAnalysis do
  @moduledoc """
  RCA Failure Analysis - Correlate failures with root causes and fixes

  Enables answering questions about what goes wrong and how to fix it.

  ## Questions Answered

  - "What are the most common failure modes?"
  - "Which root causes are hardest to fix?"
  - "What's the correlation between failures and fix success?"
  - "Which agents are best at fixing their own mistakes?"
  - "What's the failure rate trend over time?"
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Schemas.{FailurePattern, CodeFile}
  alias Singularity.Schemas.RCA.{GenerationSession, FixApplication, TestExecution}

  @doc """
  Get all failures for a specific code file.

  Returns: List of failure patterns
  """
  def failures_for_code_file(code_file_id) do
    FailurePattern
    |> where(code_file_id: ^code_file_id)
    |> order_by(desc: :last_seen_at)
    |> Repo.all()
  end

  @doc """
  Get most common failure modes.

  Returns: List of {failure_mode, frequency}
  """
  def most_common_failure_modes(limit \\ 20) do
    FailurePattern
    |> select([fp], {fp.failure_mode, count(fp.id)})
    |> group_by([fp], fp.failure_mode)
    |> order_by([fp], desc: count(fp.id))
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Get most common root causes.

  Returns: List of {root_cause, frequency}
  """
  def most_common_root_causes(limit \\ 20) do
    FailurePattern
    |> select([fp], {fp.root_cause, count(fp.id)})
    |> group_by([fp], fp.root_cause)
    |> order_by([fp], desc: count(fp.id))
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Get fix success rate for a specific root cause.

  Returns: %{root_cause => %{total_fixes: N, successful_fixes: N, success_rate: X.X}}
  """
  def fix_success_rate_by_root_cause do
    from(fa in FixApplication,
      left_join: fp in FailurePattern,
      on: fa.failure_pattern_id == fp.id,
      where: not is_nil(fp.id),
      group_by: [fp.root_cause],
      select: {
        fp.root_cause,
        {
          count(fa.id),
          sum(
            fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", fa.fix_validation_status, "validated")
          )
        }
      }
    )
    |> Repo.all()
    |> Enum.map(fn {root_cause, {total, successful}} ->
      {root_cause,
       %{
         total_fixes: total,
         successful_fixes: successful || 0,
         success_rate:
           if(total > 0, do: ((successful || 0) / total * 100) |> Float.round(2), else: 0.0)
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Get fix success rate by fixer type (human vs agent).

  Returns: %{fixer_type => %{total: N, successful: N, success_rate: X.X}}
  """
  def fix_success_rate_by_fixer_type do
    FixApplication
    |> group_by([fa], fa.fixer_type)
    |> select([fa], {
      fa.fixer_type,
      {
        count(fa.id),
        sum(fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", fa.fix_validation_status, "validated"))
      }
    })
    |> Repo.all()
    |> Enum.map(fn {fixer_type, {total, successful}} ->
      {fixer_type,
       %{
         total: total,
         successful: successful || 0,
         success_rate:
           if(total > 0, do: ((successful || 0) / total * 100) |> Float.round(2), else: 0.0)
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Analyze failure patterns for learning.

  Returns comprehensive failure analysis.
  """
  def analyze_failure_patterns(limit \\ 100) do
    patterns =
      FailurePattern
      |> order_by(desc: :frequency)
      |> limit(^limit)
      |> Repo.all()

    Enum.map(patterns, fn pattern ->
      fixes =
        Repo.all(
          from fa in FixApplication,
            where: fa.failure_pattern_id == ^pattern.id
        )

      successful_fixes =
        Enum.filter(fixes, &(&1.fix_validation_status == "validated")) |> length()

      total_fixes = length(fixes)

      %{
        failure_mode: pattern.failure_mode,
        root_cause: pattern.root_cause,
        frequency: pattern.frequency,
        last_seen: pattern.last_seen_at,
        total_fix_attempts: total_fixes,
        successful_fixes: successful_fixes,
        fix_success_rate:
          if(total_fixes > 0,
            do: (successful_fixes / total_fixes * 100) |> Float.round(2),
            else: 0.0
          )
      }
    end)
  end

  @doc """
  Get the most difficult-to-fix failure modes (high frequency, low success rate).

  Returns: List of problematic failures
  """
  def difficult_to_fix_failures(min_frequency \\ 5, max_success_rate \\ 50.0) do
    from(fp in FailurePattern,
      left_join: fa in FixApplication,
      on: fa.failure_pattern_id == fp.id,
      where: fp.frequency >= ^min_frequency,
      group_by: [fp.id, fp.failure_mode, fp.root_cause, fp.frequency],
      having:
        fragment(
          "CAST(SUM(CASE WHEN ? = ? THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 < ?",
          fa.fix_validation_status,
          "validated",
          ^max_success_rate
        ),
      select: {
        fp.failure_mode,
        fp.root_cause,
        fp.frequency,
        {
          count(fa.id),
          sum(
            fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", fa.fix_validation_status, "validated")
          )
        }
      }
    )
    |> order_by([fp], desc: fp.frequency)
    |> Repo.all()
    |> Enum.map(fn {failure_mode, root_cause, frequency, {total_attempts, successful}} ->
      %{
        failure_mode: failure_mode,
        root_cause: root_cause,
        frequency: frequency,
        fix_attempts: total_attempts,
        successful_fixes: successful || 0,
        success_rate:
          if(total_attempts > 0,
            do: ((successful || 0) / total_attempts * 100) |> Float.round(2),
            else: 0.0
          )
      }
    end)
  end

  @doc """
  Analyze test failures for a generation session.

  Returns: Aggregated test failure information
  """
  def analyze_test_failures(generation_session_id) do
    test_executions =
      Repo.all(
        from te in TestExecution,
          where: te.generation_session_id == ^generation_session_id,
          order_by: [desc: te.inserted_at]
      )

    %{
      total_test_runs: length(test_executions),
      avg_pass_rate: average_decimal(Enum.map(test_executions, & &1.test_pass_rate)),
      avg_coverage: average_decimal(Enum.map(test_executions, & &1.test_coverage_line)),
      total_failed_tests: Enum.sum(Enum.map(test_executions, & &1.failed_test_count)),
      first_failure_traces:
        Enum.filter_map(
          test_executions,
          &(&1.first_failure_trace != nil),
          & &1.first_failure_trace
        )
    }
  end

  @doc """
  Get correlation between failure patterns and code metrics.

  Returns: Analysis showing which code metrics correlate with failures
  """
  def failure_code_metric_correlation(limit \\ 20) do
    from(fp in FailurePattern,
      left_join: cf in CodeFile,
      on: fp.code_file_id == cf.id,
      order_by: [desc: fp.frequency],
      limit: ^limit,
      select: {
        fp.failure_mode,
        fp.root_cause,
        fp.frequency,
        cf.language
      }
    )
    |> Repo.all()
    |> Enum.map(fn {failure_mode, root_cause, frequency, language} ->
      %{
        failure_mode: failure_mode,
        root_cause: root_cause,
        frequency: frequency,
        language: language
      }
    end)
  end

  # Helper function to calculate average of Decimal fields, ignoring nils
  defp average_decimal(values) do
    non_nil_values = Enum.filter(values, & &1)

    if Enum.empty?(non_nil_values) do
      nil
    else
      sum = Enum.reduce(non_nil_values, Decimal.new(0), &Decimal.add/2)
      count = Decimal.new(length(non_nil_values))
      Decimal.divide(sum, count)
    end
  end
end
