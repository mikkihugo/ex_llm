defmodule Genesis.MetricsCollector do
  @moduledoc """
  Genesis Metrics Collector

  Collects and stores experiment metrics for analysis and decision-making.

  ## Metrics Tracked

  - **Outcome Metrics**
    - success_rate: % of tests passed
    - regression: % of existing functionality broken
    - llm_reduction: % reduction in LLM calls (if applicable)
    - runtime: Total execution time

  - **Performance Metrics**
    - memory_peak: Peak memory usage
    - cpu_usage: Average CPU utilization
    - io_operations: Number of disk I/O operations

  - **Quality Metrics**
    - coverage: Code coverage percentage
    - complexity_change: Change in cyclomatic complexity
    - performance_delta: Performance improvement/regression

  ## Storage

  All metrics stored in genesis_db for:
  - Historical tracking
  - Trend analysis
  - Regression detection
  - Machine learning model training
  """

  use GenServer
  require Logger

  alias Genesis.Repo
  alias Genesis.Schemas.ExperimentMetrics

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Genesis.MetricsCollector starting...")
    {:ok, %{metrics: %{}}}
  end

  @doc """
  Record experiment metrics.
  """
  def record_experiment(experiment_id, metrics) do
    GenServer.call(__MODULE__, {:record, experiment_id, metrics})
  end

  @doc """
  Retrieve experiment metrics.
  """
  def get_metrics(experiment_id) do
    GenServer.call(__MODULE__, {:get, experiment_id})
  end

  @doc """
  Calculate recommendations based on metrics.

  Returns: :merge, :merge_with_adaptations, :rollback

  ## Decision Rules

  1. **Critical Failures** (rollback):
     - Regression > 5% (breaks existing functionality)
     - Success rate < 70% (mostly broken)

  2. **Excellent** (merge):
     - LLM reduction > 30% AND regression < 5%
     - Success rate > 95% AND no regression

  3. **Good** (merge_with_adaptations):
     - Success rate > 90% AND regression < 3%
     - LLM reduction > 20% AND regression < 2%

  4. **Marginal** (rollback):
     - Everything else
  """
  def recommend(metrics) do
    success_rate = metrics[:success_rate] || 0.0
    regression = metrics[:regression] || 0.1
    llm_reduction = metrics[:llm_reduction] || 0.0

    cond do
      # Critical failures - always rollback
      regression > 0.05 && success_rate < 0.90 ->
        :rollback

      success_rate < 0.70 ->
        :rollback

      # Excellent improvements - safe to merge
      llm_reduction > 0.30 && regression < 0.03 ->
        :merge

      success_rate > 0.95 && regression < 0.02 ->
        :merge

      # Good improvements - can merge with caution
      success_rate > 0.90 && regression < 0.05 ->
        :merge_with_adaptations

      llm_reduction > 0.20 && regression < 0.02 ->
        :merge_with_adaptations

      # Everything else defaults to rollback
      true ->
        :rollback
    end
  end

  @impl true
  def handle_call({:record, experiment_id, metrics}, _from, state) do
    Logger.info("Recording metrics for experiment #{experiment_id}")

    record_to_db(experiment_id, metrics)

    new_state = put_in(state.metrics[experiment_id], metrics)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get, experiment_id}, _from, state) do
    case Map.fetch(state.metrics, experiment_id) do
      {:ok, metrics} -> {:reply, {:ok, metrics}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  defp record_to_db(experiment_id, metrics) do
    # Calculate recommendation based on metrics
    recommendation = recommend(metrics)

    # Prepare metrics for database insertion
    metrics_attrs = %{
      experiment_id: experiment_id,
      success_rate: metrics[:success_rate] || 0.0,
      regression: metrics[:regression] || 0.0,
      llm_reduction: metrics[:llm_reduction] || 0.0,
      runtime_ms: metrics[:runtime_ms] || 0,
      test_count: metrics[:test_count] || 0,
      test_failures: metrics[:failures] || 0,
      recommendation: to_string(recommendation),
      recommendation_rationale: generate_rationale(metrics, recommendation),
      detailed_results: metrics,
      measured_at: DateTime.utc_now()
    }

    # Insert into database
    case ExperimentMetrics.create_changeset(metrics_attrs)
         |> Repo.insert() do
      {:ok, _metric_record} ->
        Logger.info(
          "Experiment #{experiment_id} metrics recorded - Success: #{metrics[:success_rate] * 100}%, Regression: #{metrics[:regression] * 100}%, LLM Reduction: #{metrics[:llm_reduction] * 100}%, Recommendation: #{recommendation}"
        )

      {:error, changeset} ->
        Logger.error(
          "Failed to record metrics for experiment #{experiment_id}: #{inspect(changeset.errors)}"
        )
    end
  end

  defp generate_rationale(metrics, recommendation) do
    success_rate = metrics[:success_rate] || 0.0
    regression = metrics[:regression] || 0.0
    llm_reduction = metrics[:llm_reduction] || 0.0

    case recommendation do
      :merge ->
        "Strong improvement: #{(llm_reduction * 100)
        |> Float.round(1)}% LLM reduction with #{(regression * 100)
        |> Float.round(1)}% regression and #{(success_rate * 100)
        |> Float.round(1)}% success rate"

      :merge_with_adaptations ->
        "Acceptable improvement: #{(success_rate * 100)
        |> Float.round(1)}% success rate with #{(regression * 100)
        |> Float.round(1)}% acceptable regression"

      :rollback ->
        "Insufficient quality: #{(success_rate * 100)
        |> Float.round(1)}% success rate with #{(regression * 100)
        |> Float.round(1)}% regression - does not meet merge criteria"

      _ ->
        "Decision: #{recommendation}"
    end
  end
end
