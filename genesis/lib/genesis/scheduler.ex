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
        avg_success = experiments |> Enum.map(& &1.success_rate) |> Enum.sum() / total
        avg_regression = experiments |> Enum.map(& &1.regression) |> Enum.sum() / total
        avg_llm_reduction = experiments |> Enum.map(& &1.llm_reduction) |> Enum.sum() / total

        # Group by experiment type (if available)
        by_type = experiments
          |> Enum.group_by(& &1.experiment_type)
          |> Enum.map(fn {type, exps} ->
            {type, %{
              count: Enum.count(exps),
              success_rate: exps |> Enum.map(& &1.success_rate) |> Enum.sum() / Enum.count(exps)
            }}
          end)
          |> Enum.into(%{})

        # Group by risk level
        by_risk = experiments
          |> Enum.group_by(& &1.risk_level)
          |> Enum.map(fn {risk, exps} ->
            {risk, %{
              count: Enum.count(exps),
              success_rate: exps |> Enum.map(& &1.success_rate) |> Enum.sum() / Enum.count(exps)
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
  """
  def report_metrics do
    Logger.info("Genesis.Scheduler: Starting report_metrics")
    # TODO: Implement MetricsReporter module
    {:ok, "Metrics reporting not yet implemented"}
  end

  @doc """
  Verify sandbox integrity and health.
  """
  def verify_sandbox_integrity do
    Logger.info("Genesis.Scheduler: Starting verify_sandbox_integrity")
    Genesis.SandboxMaintenance.verify_integrity()
  end
end
