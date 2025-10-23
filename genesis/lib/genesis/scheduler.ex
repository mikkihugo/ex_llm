defmodule Genesis.Scheduler do
  @moduledoc """
  Genesis Scheduler

  Provides scheduled maintenance tasks for Genesis via Oban:
  - Clean up completed experiments
  - Analyze experiment trends
  - Report metrics to Centralcloud
  - Verify sandbox integrity

  ## Scheduled Jobs (via Oban)

  - **Cleanup** (every 6 hours): Remove old sandboxes and metrics
  - **Analysis** (every 24 hours): Calculate trends and recommendations
  - **Reporting** (every 24 hours): Send metrics to Centralcloud

  Note: Jobs are enqueued via Oban. See config/config.exs for Oban setup.
  """

  require Logger

  @doc """
  Clean up old sandbox directories.
  """
  def cleanup_old_sandboxes do
    Logger.info("Genesis.Scheduler: Starting cleanup_old_sandboxes")
    Genesis.SandboxMaintenance.cleanup_old_sandboxes()
  end

  @doc """
  Analyze experiment trends for insights.

  Queries the last 30 days of experiments and calculates:
  - Overall success rate trend
  - High-performing experiment types
  - Regression patterns and anomalies
  - LLM call reduction effectiveness
  - Risk level impact analysis
  """
  def analyze_trends do
    Logger.info("Genesis.Scheduler: Starting analyze_trends")

    case analyze_experiment_metrics() do
      {:ok, insights} ->
        Logger.info("Genesis.Scheduler: Trend analysis completed - #{map_size(insights)} insights generated")
        {:ok, insights}

      {:error, reason} ->
        Logger.error("Genesis.Scheduler: Trend analysis failed - #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp analyze_experiment_metrics do
    alias Genesis.Repo
    alias Genesis.Schemas.ExperimentMetrics
    import Ecto.Query

    try do
      # Query experiments from last 30 days
      thirty_days_ago = DateTime.add(DateTime.utc_now(), -30 * 24 * 3600)

      experiments = Repo.all(
        from em in ExperimentMetrics,
        where: em.inserted_at >= ^thirty_days_ago,
        select: em
      )

      if Enum.empty?(experiments) do
        {:ok, %{
          total_experiments: 0,
          message: "No experiments in last 30 days"
        }}
      else
        # Calculate aggregate metrics
        total = Enum.count(experiments)
        successful = Enum.count(experiments, &(&1.success_rate >= 0.9))
        sum_success = experiments |> Enum.map(& &1.success_rate) |> Enum.sum()
        avg_success = sum_success / total
        sum_regression = experiments |> Enum.map(& &1.regression) |> Enum.sum()
        avg_regression = sum_regression / total
        sum_llm_reduction = experiments |> Enum.map(& &1.llm_reduction) |> Enum.sum()
        avg_llm_reduction = sum_llm_reduction / total

        # Group by experiment type (if available)
        by_type = experiments
          |> Enum.group_by(& &1.experiment_type)
          |> Enum.map(fn {type, exps} ->
            count = Enum.count(exps)
            sum = exps |> Enum.map(& &1.success_rate) |> Enum.sum()
            {type, %{
              count: count,
              success_rate: sum / count
            }}
          end)
          |> Enum.into(%{})

        # Group by risk level
        by_risk = experiments
          |> Enum.group_by(& &1.risk_level)
          |> Enum.map(fn {risk, exps} ->
            count = Enum.count(exps)
            sum = exps |> Enum.map(& &1.success_rate) |> Enum.sum()
            {risk, %{
              count: count,
              success_rate: sum / count
            }}
          end)
          |> Enum.into(%{})

        {:ok, %{
          total_experiments: total,
          successful_experiments: successful,
          success_rate: Float.round(avg_success, 4),
          avg_regression: Float.round(avg_regression, 4),
          avg_llm_reduction: Float.round(avg_llm_reduction, 4),
          by_type: by_type,
          by_risk_level: by_risk,
          period: "30 days",
          generated_at: DateTime.utc_now()
        }}
      end
    rescue
      e ->
        Logger.error("Exception during trend analysis: #{inspect(e)}")
        {:error, "Trend analysis failed: #{inspect(e)}"}
    end
  end

  @doc """
  Report metrics to Centralcloud for aggregation.

  Retrieves the latest trend analysis and publishes metrics to CentralCloud
  via NATS subject `system.metrics.genesis` for cross-instance analysis.

  ## Returns

  - `{:ok, metrics}` - Successfully reported metrics
  - `{:error, reason}` - Failed to retrieve or publish metrics
  """
  def report_metrics do
    Logger.info("Genesis.Scheduler: Starting report_metrics")

    # Get the latest trend analysis
    case analyze_experiment_metrics() do
      {:ok, insights} ->
        # Prepare metrics report for CentralCloud
        hostname = case :inet.gethostname() do
          {:ok, name} -> name |> to_string()
          {:error, _} -> "unknown"
        end

        report = %{
          "source" => "genesis",
          "hostname" => hostname,
          "timestamp" => DateTime.utc_now(),
          "metrics" => insights
        }

        # Publish to CentralCloud via NATS
        case publish_metrics_to_nats(report) do
          :ok ->
            Logger.info("Genesis.Scheduler: Metrics reported successfully to CentralCloud")
            {:ok, insights}

          {:error, reason} ->
            Logger.error("Genesis.Scheduler: Failed to publish metrics to CentralCloud - #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Genesis.Scheduler: Failed to analyze metrics - #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp publish_metrics_to_nats(report) do
    subject = "system.metrics.genesis"

    try do
      case Genesis.NatsClient.publish(subject, Jason.encode!(report)) do
        :ok ->
          Logger.info("Published metrics to #{subject}")
          :ok

        {:error, reason} ->
          Logger.error("Failed to publish metrics to NATS: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Exception while publishing metrics: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Verify sandbox integrity and health.
  """
  def verify_sandbox_integrity do
    Logger.info("Genesis.Scheduler: Starting verify_sandbox_integrity")
    Genesis.SandboxMaintenance.verify_integrity()
  end
end
