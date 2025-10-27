defmodule Singularity.Pipeline.Learning do
  @moduledoc """
  Unified Learning & Outcome Analysis Layer - Post-Execution Phase

  Consolidates all post-execution learning, analysis, and metrics into a single interface.

  This module serves as the integration layer for Phase 5 (Post-Execution Learning) of the
  self-evolving pipeline, coordinating:

  - **Outcome Analysis** - Analyze execution results and successes
  - **Metrics Aggregation** - Track performance, cost, and effectiveness metrics
  - **Validation Tracking** - Monitor which validation checks caught real issues
  - **Failure Pattern Matching** - Identify and store failure patterns for future reference

  ## Architecture

  This layer orchestrates multiple specialized learning components:
  - ValidationMetricsStore - tracks effectiveness of validation checks
  - FailurePatternStore - stores and queries failure patterns
  - MetricsAggregator - aggregates performance metrics
  - OutcomeAnalyzer - analyzes execution outcomes

  ## Single API

  ```
  :ok = Singularity.Pipeline.Learning.process(execution_result, _opts)
  ```

  Processes execution results and automatically:
  - Records metrics (tokens, cost, latency, success rate)
  - Stores failure patterns if execution failed
  - Updates validation effectiveness scores
  - Publishes learnings to CentralCloud (if available)

  ## Usage in Pipeline

  Used in Phase 5 of the self-evolving pipeline:

  ```elixir
  # Execute plan
  {:ok, result} = execute_plan(plan)

  # Process execution for learning
  :ok = Singularity.Pipeline.Learning.process(result)

  # Later: retrieve learned patterns
  patterns = Singularity.Pipeline.Learning.get_failure_patterns(filters)

  # Improve validation: use metrics to adjust check weights
  weights = Singularity.Pipeline.Learning.get_validation_weights()
  ```

  ## Data Stored

  For every execution:

  1. **Metrics** - Recorded in ValidationMetricsStore:
     - Check effectiveness (precision, recall)
     - Execution success rate
     - Cost and token usage
     - Time to validation and execution

  2. **Failures** - Recorded in FailurePatternStore:
     - Failure signature and context
     - Root cause analysis
     - Successful resolutions/fixes

  3. **Learnings** - Published to CentralCloud (if integrated):
     - Patterns that correlate with success/failure
     - Rule candidates for automation
  """

  require Logger

  alias Singularity.Storage.FailurePatternStore
  alias Singularity.Storage.ValidationMetricsStore
  alias Singularity.Schemas.Execution.JobResult
  alias Ecto.UUID

  @type execution_result :: map()
  @type process_opts :: keyword()

  @doc """
  Process execution results and extract learnings.

  Automatically:
  - Records metrics (cost, tokens, latency, success rate)
  - Stores failure patterns if execution failed
  - Updates validation effectiveness tracking
  - Publishes learnings to CentralCloud (if available)

  ## Parameters
  - `result` - Execution result map with:
    - `:success` - boolean indicating success
    - `:plan` - original plan
    - `:execution` - execution details
    - `:validation` - validation results
    - `:metrics` - execution metrics (cost, tokens, latency)

  - `_opts` - Options:
    - `:publish_central_cloud` - Publish learnings (default: true)
    - `:store_patterns` - Store failure patterns (default: true)
    - `:track_metrics` - Track effectiveness metrics (default: true)

  ## Returns
  - `:ok` - Processing successful
  - `{:error, reason}` - Error details

  ## Side Effects

  - Records metrics to ValidationMetricsStore
  - Records failures to FailurePatternStore
  - Publishes patterns to CentralCloud (if configured)
  """
  @spec process(execution_result, process_opts) :: :ok | {:error, term()}
  def process(result, _opts \\ []) do
    Logger.info("Pipeline.Learning: Processing execution result",
      success: result[:success],
      has_metrics: not is_nil(result[:metrics])
    )

    store_patterns = Keyword.get(opts, :store_patterns, true)
    track_metrics = Keyword.get(opts, :track_metrics, true)
    publish_central = Keyword.get(opts, :publish_central_cloud, true)

    try do
      # Store failure patterns if execution failed
      if store_patterns and not result[:success] do
        store_failure_pattern(result)
      end

      # Track validation effectiveness
      if track_metrics and result[:validation] do
        track_validation_metrics(result[:validation], result[:success])
      end

      # Track execution metrics
      if track_metrics and result[:metrics] do
        track_execution_metrics(result[:metrics], result[:success])
      end

      # Publish learnings to CentralCloud if available
      if publish_central do
        publish_to_central_cloud(result)
      end

      Logger.info("Pipeline.Learning: Result processed successfully")
      :ok
    rescue
      error ->
        Logger.error("Pipeline.Learning: Error processing result",
          error: inspect(error),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        )

        {:error, error}
    end
  end

  @doc """
  Retrieve failure patterns matching filters.

  ## Parameters
  - `filters` - Filter options (optional):
    - `:failure_mode` - Filter by failure mode
    - `:story_type` - Filter by story type
    - `:min_frequency` - Minimum occurrence count
    - `:limit` - Maximum results (default: 20)

  ## Returns
  - List of matching failure patterns with similarity/confidence scores
  """
  @spec get_failure_patterns(keyword()) :: [map()]
  def get_failure_patterns(filters \\ []) do
    FailurePatternStore.query(filters)
  rescue
    _ -> []
  end

  @doc """
  Find failure patterns similar to current execution context.

  Uses pattern matching to identify similar past failures.

  ## Parameters
  - `criteria` - Matching criteria:
    - `:story_signature` - Story signature to match
    - `:plan` - Plan characteristics

  - `_opts` - Options:
    - `:threshold` - Similarity threshold (default: 0.80)
    - `:limit` - Max results (default: 10)

  ## Returns
  - List of similar patterns with similarity scores
  """
  @spec find_similar_failures(map(), keyword()) :: [map()]
  def find_similar_failures(criteria, _opts \\ []) do
    FailurePatternStore.find_similar(criteria, _opts)
  rescue
    _ -> []
  end

  @doc """
  Get effective resolutions for failure patterns.

  Returns successful fixes from similar past failures.

  ## Parameters
  - `criteria` - Failure criteria to match

  ## Returns
  - List of successful remediation strategies
  """
  @spec get_successful_fixes(map()) :: [map()]
  def get_successful_fixes(criteria \\ %{}) do
    FailurePatternStore.get_successful_fixes(criteria)
  rescue
    _ -> []
  end

  @doc """
  Get validation effectiveness metrics.

  Returns scores for each validation check based on historical accuracy.

  ## Parameters
  - `time_range` - Time window for calculation:
    - `:last_hour` - Last hour
    - `:last_day` - Last 24 hours
    - `:last_week` - Last 7 days

  ## Returns
  - Map of check_id => effectiveness_score (0.0 - 1.0)
  """
  @spec get_validation_weights(atom()) :: map()
  def get_validation_weights(time_range \\ :last_week) do
    ValidationMetricsStore.get_effectiveness_scores(time_range)
  rescue
    _ -> %{}
  end

  @doc """
  Get execution metrics aggregated by complexity or task type.

  Useful for cost analysis and performance tracking.

  ## Parameters
  - `group_by` - Aggregation axis:
    - `:task_type` - Group by task type
    - `:model` - Group by LLM model used
    - `:provider` - Group by provider

  ## Returns
  - List of grouped metrics with cost, tokens, latency averages
  """
  @spec get_aggregated_metrics(atom()) :: [map()]
  def get_aggregated_metrics(group_by \\ :task_type) do
    ValidationMetricsStore.get_aggregated_metrics(:last_week, group_by)
  rescue
    _ -> []
  end

  @doc """
  Get the 3 core KPIs for pipeline effectiveness.

  Returns validation accuracy, execution success rate, and average validation time.

  ## Returns
  - `%{accuracy: 0.0-1.0, success_rate: 0.0-1.0, avg_validation_ms: int}`
  """
  @spec get_kpis() :: map()
  def get_kpis() do
    %{
      validation_accuracy: ValidationMetricsStore.get_validation_accuracy(),
      execution_success_rate: ValidationMetricsStore.get_execution_success_rate(),
      avg_validation_time_ms: ValidationMetricsStore.get_avg_validation_time()
    }
  rescue
    _ -> %{validation_accuracy: nil, execution_success_rate: nil, avg_validation_time_ms: nil}
  end

  # Private Helpers

  defp store_failure_pattern(result) do
    pattern = %{
      story_signature: extract_signature(result[:plan]),
      failure_mode: extract_failure_mode(result),
      root_cause: extract_root_cause(result),
      validation_state: extract_validation_state(result),
      validation_errors: extract_validation_errors(result),
      execution_error: extract_execution_error(result),
      plan_characteristics: extract_plan_characteristics(result[:plan]),
      story_type: result[:task_type] || "unknown",
      frequency: 1
    }

    case FailurePatternStore.insert(pattern) do
      {:ok, _} ->
        Logger.info("Pipeline.Learning: Failure pattern stored",
          failure_mode: pattern.failure_mode
        )

      {:error, reason} ->
        Logger.error("Pipeline.Learning: Failed to store failure pattern",
          reason: inspect(reason)
        )
    end
  end

  defp track_validation_metrics(validation, success) do
    run_id = UUID.generate()

    validation
    |> List.wrap()
    |> Enum.each(fn check ->
      metrics = %{
        run_id: run_id,
        check_id: check[:id] || "unknown",
        check_type: check[:type] || "unknown",
        result: if(success, do: "pass", else: "fail"),
        confidence_score: check[:confidence] || 0.5,
        runtime_ms: check[:duration_ms] || 0
      }

      case ValidationMetricsStore.record_validation(metrics) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning("Pipeline.Learning: Failed to record validation metric",
            reason: inspect(reason)
          )
      end
    end)
  end

  defp track_execution_metrics(metrics, _success) do
    run_id = UUID.generate()

    # Record cost, tokens, latency metrics
    case ValidationMetricsStore.record_execution(%{
           run_id: run_id,
           task_type: metrics[:task_type] || "unknown",
           model: metrics[:model] || "unknown",
           provider: metrics[:provider] || "unknown",
           cost_cents: metrics[:cost_cents] || 0,
           tokens_used: metrics[:tokens] || metrics[:tokens_used] || 0,
           prompt_tokens: metrics[:prompt_tokens] || 0,
           completion_tokens: metrics[:completion_tokens] || 0,
           latency_ms: metrics[:latency_ms] || 0,
           success: _success
         }) do
      {:ok, _} ->
        Logger.debug("Pipeline.Learning: Execution metrics recorded")

      {:error, reason} ->
        Logger.warning("Pipeline.Learning: Failed to record execution metrics",
          reason: inspect(reason)
        )
    end
  end

  defp publish_to_central_cloud(result) do
    # Try to publish learnings to CentralCloud if integrated
    cond do
      Code.ensure_loaded?(CentralCloud.Learnings) ->
        try do
          CentralCloud.Learnings.publish_execution_result(result)
        rescue
          _ -> :ok
        end

      Code.ensure_loaded?(CentralCloud.TemplateIntelligence) ->
        try do
          CentralCloud.TemplateIntelligence.ingest_execution_learning(result)
        rescue
          _ -> :ok
        end

      true ->
        Logger.debug("Pipeline.Learning: CentralCloud not configured, skipping publish")
    end
  end

  # Extraction Helpers

  defp extract_signature(plan) when is_map(plan) do
    plan[:story_signature] || plan["story_signature"] || nil
  end

  defp extract_signature(_), do: nil

  defp extract_failure_mode(result) do
    result[:failure_mode] ||
      (result[:error] && extract_error_type(result[:error])) ||
      "unknown"
  end

  defp extract_error_type(error) when is_binary(error) do
    cond do
      String.contains?(error, ["timeout"]) -> "timeout"
      String.contains?(error, ["validation"]) -> "validation_failed"
      String.contains?(error, ["constraint"]) -> "constraint_violation"
      String.contains?(error, ["not_found"]) -> "resource_not_found"
      true -> "execution_error"
    end
  end

  defp extract_error_type(_), do: "unknown"

  defp extract_root_cause(result) do
    result[:root_cause] || result[:error] || nil
  end

  defp extract_validation_state(result) do
    case result[:validation_passed] do
      true -> "passed"
      false -> "failed"
      nil -> "unknown"
    end
  end

  defp extract_validation_errors(result) do
    result[:validation_errors] || result[:validation_failures] || []
  end

  defp extract_execution_error(result) do
    result[:error] || result[:execution_error] || nil
  end

  defp extract_plan_characteristics(plan) when is_map(plan) do
    %{
      complexity: plan[:complexity] || plan["complexity"],
      task_type: plan[:task_type] || plan["task_type"],
      steps_count: length(plan[:steps] || plan["steps"] || []),
      dependencies_count: length(plan[:dependencies] || plan["dependencies"] || [])
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp extract_plan_characteristics(_), do: %{}
end
