defmodule Singularity.Jobs.HealthMetricsWorker do
  @moduledoc """
  Health Metrics Worker - Report codebase health metrics to aggregation system

  Replaces NATS publish("intelligence_hub.codebase_health", ...)
  Now enqueued as an Oban job in the metrics queue.
  
  Triggered by:
  - CodebaseHealthTracker.snapshot_codebase/1
  - Cron schedule (every 5 minutes via MetricsAggregationWorker)
  """

  use Oban.Worker,
    queue: :metrics,
    max_attempts: 3,
    priority: 9

  require Logger
  alias Singularity.Analysis.CodebaseHealthTracker

  @doc """
  Record health metrics for a codebase path.
  
  Args:
    - codebase_path: Path to analyze
    
  Returns: {:ok, job} or {:error, reason}
  """
  def record_health_metrics(codebase_path) do
    %{"codebase_path" => codebase_path}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"codebase_path" => codebase_path}}) do
    Logger.debug("Recording health metrics", codebase: codebase_path)

    case CodebaseHealthTracker.snapshot_codebase(codebase_path) do
      {:ok, snapshot} ->
        Logger.info("Health metrics recorded",
          codebase: codebase_path,
          loc: snapshot.lines_of_code,
          modules: snapshot.modules_count,
          doc_coverage: snapshot.documentation_coverage
        )
        :ok

      {:error, reason} ->
        Logger.error("Failed to record health metrics",
          codebase: codebase_path,
          reason: reason
        )
        {:error, reason}
    end
  end
end
