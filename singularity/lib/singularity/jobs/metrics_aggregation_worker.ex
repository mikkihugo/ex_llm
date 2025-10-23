defmodule Singularity.Jobs.MetricsAggregationWorker do
  @moduledoc """
  Oban Worker for aggregating agent metrics (every 5 minutes).

  Runs every 5 minutes to aggregate telemetry events into actionable metrics.
  These metrics are stored in the agent_metrics table and feed the feedback
  analyzer, which drives autonomous agent evolution.

  ## What it Does

  1. Queries recent telemetry/usage events
  2. Aggregates per-agent metrics:
     - Success rate (% of successful tasks)
     - Average cost (cents per task)
     - Average latency (milliseconds)
     - Patterns used (frequency map)
  3. Stores aggregated metrics in agent_metrics table
  4. Makes data available to Feedback.Analyzer

  ## Schedule

  Every 5 minutes (via Oban.Plugins.Cron in config.exs)

  ## Failure Handling

  - Max attempts: 2 (if fails, retries once)
  - Errors are logged but don't block other jobs
  - Failed aggregations just mean no data for this cycle
  """

  use Oban.Worker, queue: :default, max_attempts: 2

  require Logger

  alias Singularity.Metrics.Aggregator

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("🔢 Aggregating agent metrics...")

    try do
      case Aggregator.aggregate_agent_metrics(:last_hour) do
        {:ok, metrics} ->
          metric_count = map_size(metrics)
          Logger.info("✅ Agent metrics aggregated", agents: metric_count)
          :ok

        {:error, reason} ->
          Logger.error("❌ Metrics aggregation failed", reason: inspect(reason))
          {:error, reason}
      end
    rescue
      e in Exception ->
        Logger.error("❌ Metrics aggregation exception", error: inspect(e), stacktrace: __STACKTRACE__)
        {:error, e}
    end
  end
end
