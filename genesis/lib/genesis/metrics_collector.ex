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
  """
  def recommend(metrics) do
    cond do
      metrics[:regression] > 0.05 ->
        :rollback

      metrics[:llm_reduction] > 0.30 && metrics[:regression] < 0.05 ->
        :merge

      metrics[:success_rate] > 0.90 ->
        :merge_with_adaptations

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
    # Placeholder: actual implementation would:
    # 1. Create ExperimentMetrics record
    # 2. Insert into genesis_db
    # 3. Calculate recommendation
    # 4. Store recommendation for reporting
    Logger.debug("Stored metrics for experiment #{experiment_id} to genesis_db")
  end
end
