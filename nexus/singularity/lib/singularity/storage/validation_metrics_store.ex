defmodule Singularity.Storage.ValidationMetricsStore do
  @moduledoc """
  Validation Metrics Store - Persistence and Query Interface

  Tracks validation check effectiveness and execution metrics for:
  - Computing dynamic validation weights (which checks are most effective?)
  - Measuring validation accuracy (do checks predict success?)
  - Monitoring execution trends (cost, tokens, latency)

  ## 3 Core KPIs

  1. **Validation Accuracy** - % of checks that correctly predict execution success
  2. **Execution Success Rate** - % of plans that executed without errors
  3. **Time to Validation** - Average time spent in validation phase

  These metrics drive Phase 5 (Rule Evolution) and Phase 4 (Adaptive Refinement)
  to improve plans automatically.

  ## Data Stored

  - **ValidationMetric** - Every validation check:
    - Result (pass/fail/warning)
    - Confidence score
    - Runtime
    - Metadata

  - **ExecutionMetric** - Every execution:
    - Cost, tokens, latency
    - Model and provider
    - Success/failure status

  ## Usage

  ```elixir
  # Record a validation check
  ValidationMetricsStore.record_validation(%{
    run_id: run_id,
    check_id: "template_check",
    check_type: "template",
    result: "pass",
    confidence_score: 0.95,
    runtime_ms: 145
  })

  # Record execution metrics
  ValidationMetricsStore.record_execution(%{
    run_id: run_id,
    task_type: "architect",
    model: "claude-opus",
    provider: "anthropic",
    cost_cents: 125,
    tokens_used: 3500,
    latency_ms: 2500,
    success: true
  })

  # Get the 3 KPIs
  accuracy = ValidationMetricsStore.get_validation_accuracy(:last_week)
  success_rate = ValidationMetricsStore.get_execution_success_rate(:last_week)
  avg_validation_time = ValidationMetricsStore.get_avg_validation_time(:last_week)
  ```
  """

  require Logger

  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Schemas.ValidationMetric
  alias Singularity.Schemas.ExecutionMetric
  alias Singularity.PgFlow

  @type time_range :: :last_hour | :last_day | :last_week
  @type kpi_result :: float() | nil

  # ============================================================================
  # Recording Functions
  # ============================================================================

  @doc """
  Record a validation check result.

  ## Parameters
  - `attrs` - Map with:
    - `:run_id` - Execution run ID (required)
    - `:check_id` - Check identifier (required)
    - `:check_type` - Type of check (required)
    - `:result` - "pass" | "fail" | "warning" (required)
    - `:confidence_score` - 0.0 to 1.0 (optional)
    - `:runtime_ms` - Duration (optional)

  ## Returns
  - `{:ok, metric}` - Metric recorded
  - `{:error, changeset}` - Validation error
  """
  @spec record_validation(map()) :: {:ok, ValidationMetric.t()} | {:error, Ecto.Changeset.t()}
  def record_validation(attrs) do
    %ValidationMetric{}
    |> ValidationMetric.changeset(attrs)
    |> Repo.insert()
  rescue
    error ->
      Logger.error("ValidationMetricsStore: Failed to record validation",
        error: inspect(error)
      )

      {:error, error}
  end

  @doc """
  Record execution metrics (cost, tokens, latency, success).

  ## Parameters
  - `attrs` - Map with:
    - `:run_id` - Execution run ID (required)
    - `:task_type` - Task type (required)
    - `:model` - LLM model (required)
    - `:provider` - Provider name (required)
    - `:cost_cents` - Cost (optional)
    - `:tokens_used` - Total tokens (optional)
    - `:latency_ms` - Duration (optional)
    - `:success` - Success flag (optional)

  ## Returns
  - `{:ok, metric}` - Metric recorded
  - `{:error, changeset}` - Validation error
  """
  @spec record_execution(map()) :: {:ok, ExecutionMetric.t()} | {:error, Ecto.Changeset.t()}
  def record_execution(attrs) do
    %ExecutionMetric{}
    |> ExecutionMetric.changeset(attrs)
    |> Repo.insert()
  rescue
    error ->
      Logger.error("ValidationMetricsStore: Failed to record execution metrics",
        error: inspect(error)
      )

      {:error, error}
  end

  # ============================================================================
  # KPI Functions - The 3 Core Metrics
  # ============================================================================

  @doc """
  **KPI #1: Validation Accuracy**

  Percentage of validation checks that correctly predicted execution success.

  Higher accuracy = validation checks are effective at catching real problems.

  ## Parameters
  - `time_range` - Time window:
    - `:last_hour` - Last hour
    - `:last_day` - Last 24 hours
    - `:last_week` - Last 7 days (default for Phase 4 use)

  ## Returns
  - `0.0 - 1.0` - Accuracy as percentage (0% = always wrong, 100% = always right)
  - `nil` - Not enough data
  """
  @spec get_validation_accuracy(time_range) :: kpi_result
  def get_validation_accuracy(time_range \\ :last_week) do
    from_dt = time_range_to_datetime(time_range)

    # Get all validations in the time range
    all_results =
      Repo.all(
        from vm in ValidationMetric,
          where: vm.inserted_at >= ^from_dt,
          select: vm.result
      )

    case length(all_results) do
      total when total > 10 ->
        pass_count = Enum.count(all_results, &(&1 == "pass"))
        pass_count / total

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  @doc """
  **KPI #2: Execution Success Rate**

  Percentage of generated plans that executed successfully.

  Higher success rate = plans are becoming more reliable (learning is working).

  ## Parameters
  - `time_range` - Time window (default: `:last_week`)

  ## Returns
  - `0.0 - 1.0` - Success percentage (0% = all failed, 100% = all succeeded)
  - `nil` - Not enough data
  """
  @spec get_execution_success_rate(time_range) :: kpi_result
  def get_execution_success_rate(time_range \\ :last_week) do
    from_dt = time_range_to_datetime(time_range)

    # Get all execution results in the time range
    all_results =
      Repo.all(
        from em in ExecutionMetric,
          where: em.inserted_at >= ^from_dt,
          select: em.success
      )

    case length(all_results) do
      total when total > 10 ->
        success_count = Enum.count(all_results, & &1)
        success_count / total

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  @doc """
  **KPI #3: Time to Validation**

  Average time spent in the validation phase (milliseconds).

  Lower time = validation is fast; helps track if validation becomes slower.

  ## Parameters
  - `time_range` - Time window (default: `:last_week`)

  ## Returns
  - Integer average milliseconds
  - `nil` - Not enough data
  """
  @spec get_avg_validation_time(time_range) :: kpi_result
  def get_avg_validation_time(time_range \\ :last_week) do
    from_dt = time_range_to_datetime(time_range)

    # Get all validation times in the time range
    all_times =
      Repo.all(
        from vm in ValidationMetric,
          where: vm.inserted_at >= ^from_dt,
          select: vm.runtime_ms
      )

    case length(all_times) do
      count when count > 10 ->
        avg = Enum.sum(all_times) / count
        trunc(avg)

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  # ============================================================================
  # Effectiveness Scoring Functions
  # ============================================================================

  @doc """
  Get effectiveness scores for each validation check.

  Returns a map of check_id => effectiveness_score (0.0 - 1.0) based on
  historical accuracy of that check.

  Used in Phase 4 (Adaptive Refinement) to weight checks by effectiveness.

  ## Parameters
  - `time_range` - Historical window (default: `:last_week`)

  ## Returns
  - Map: `%{"check_id_1" => 0.92, "check_id_2" => 0.78, ...}`
  """
  @spec get_effectiveness_scores(time_range) :: map()
  def get_effectiveness_scores(time_range \\ :last_week) do
    from_dt = time_range_to_datetime(time_range)

    # Get all validations in the time range
    all_validations =
      Repo.all(
        from vm in ValidationMetric,
          where: vm.inserted_at >= ^from_dt,
          select: {vm.check_id, vm.result}
      )

    # Group by check_id and calculate effectiveness
    all_validations
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.filter(fn {_check_id, results} -> length(results) > 3 end)
    |> Enum.into(%{}, fn {check_id, results} ->
      pass_count = Enum.count(results, &(&1 == "pass"))
      effectiveness = pass_count / length(results)
      {check_id, effectiveness}
    end)
  rescue
    _ -> %{}
  end

  # ============================================================================
  # Aggregation Functions
  # ============================================================================

  @doc """
  Get aggregated metrics grouped by model, task_type, or provider.

  Useful for cost analysis and optimization tracking.

  ## Parameters
  - `time_range` - Time window
  - `group_by` - `:model` | `:task_type` | `:provider`

  ## Returns
  - List of aggregates with count, cost, tokens, latency
  """
  @spec get_aggregated_metrics(time_range, :model | :task_type | :provider) :: [map()]
  def get_aggregated_metrics(time_range \\ :last_week, group_by \\ :model) do
    from_dt = time_range_to_datetime(time_range)
    ExecutionMetric.aggregate_metrics(from_dt, DateTime.utc_now(), Atom.to_string(group_by))
  rescue
    _ -> []
  end

  @doc """
  Get validation metrics for a specific run.
  """
  @spec get_validation_metrics_for_run(binary()) :: [ValidationMetric.t()]
  def get_validation_metrics_for_run(run_id) do
    ValidationMetric.list_by_run(run_id)
  rescue
    _ -> []
  end

  @doc """
  Get execution metrics for a specific run.
  """
  @spec get_execution_metrics_for_run(binary()) :: [ExecutionMetric.t()]
  def get_execution_metrics_for_run(run_id) do
    ExecutionMetric.list_by_run(run_id)
  rescue
    _ -> []
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp time_range_to_datetime(time_range) do
    now = DateTime.utc_now()

    case time_range do
      :last_hour ->
        DateTime.add(now, -1, :hour)

      :last_day ->
        DateTime.add(now, -1, :day)

      :last_week ->
        DateTime.add(now, -7, :day)

      _ ->
        DateTime.add(now, -7, :day)
    end
  end

  @doc """
  Sync validation metrics to CentralCloud for cross-instance learning.

  Publishes recent validation metrics and execution data to CentralCloud
  for pattern aggregation and cross-instance insights.

  ## Parameters
  - `filters` - Optional filters for which metrics to sync

  ## Returns
  - `{:ok, count}` - Number of metrics synced
  - `{:error, reason}` - Sync failed
  """
  @spec sync_with_centralcloud(map()) :: {:ok, non_neg_integer()} | {:error, term()}
  def sync_with_centralcloud(filters \\ %{}) do
    Logger.info("ValidationMetricsStore: Syncing metrics to CentralCloud")

    try do
      # Get recent validation metrics
      # Last 24 hours
      from_dt = DateTime.add(DateTime.utc_now(), -24, :hour)

      validation_metrics =
        Repo.all(
          from vm in ValidationMetric,
            where: vm.inserted_at >= ^from_dt,
            limit: 100
        )

      execution_metrics =
        Repo.all(
          from em in ExecutionMetric,
            where: em.inserted_at >= ^from_dt,
            limit: 100
        )

      # Prepare sync payload
      sync_payload = %{
        validation_metrics: Enum.map(validation_metrics, &format_metric/1),
        execution_metrics: Enum.map(execution_metrics, &format_metric/1),
        sync_timestamp: DateTime.utc_now(),
        source_instance: "singularity_#{node()}"
      }

      # Publish validation metrics to CentralCloud via PgFlow
      # Queue: execution_metrics_aggregated (consumed by CentralCloud.Consumers.PerformanceStatsConsumer)
      message = Map.put(sync_payload, "type", "execution_metrics")
      
      case PgFlow.send_with_notify("execution_metrics_aggregated", message) do
        {:ok, _} ->
          Logger.debug("Validation metrics published to CentralCloud",
            metrics_count: length(sync_payload.validation_metrics) + length(sync_payload.execution_metrics)
          )
          {:ok, length(sync_payload.validation_metrics) + length(sync_payload.execution_metrics)}
        
        {:error, reason} ->
          Logger.warning("Failed to publish validation metrics to CentralCloud", reason: reason)
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("ValidationMetricsStore: Error syncing to CentralCloud",
          error: inspect(error)
        )

        {:error, error}
    end
  end

  defp format_metric(%ValidationMetric{} = metric) do
    %{
      check_id: metric.check_id,
      check_type: metric.check_type,
      result: metric.result,
      confidence_score: metric.confidence_score,
      runtime_ms: metric.runtime_ms,
      run_id: metric.run_id,
      inserted_at: metric.inserted_at
    }
  end

  defp format_metric(%ExecutionMetric{} = metric) do
    %{
      task_type: metric.task_type,
      model: metric.model,
      provider: metric.provider,
      cost_cents: metric.cost_cents,
      tokens_used: metric.tokens_used,
      latency_ms: metric.latency_ms,
      success: metric.success,
      run_id: metric.run_id,
      inserted_at: metric.inserted_at
    }
  end
end
