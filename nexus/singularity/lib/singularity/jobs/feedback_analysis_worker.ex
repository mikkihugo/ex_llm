defmodule Singularity.Jobs.FeedbackAnalysisWorker do
  @moduledoc """
  Oban Worker for analyzing feedback and identifying improvements (every 30 minutes).

  Runs every 30 minutes to analyze agent metrics and identify improvement
  opportunities. These suggestions are consumed by Agents.Evolution to drive
  autonomous agent improvement.

  ## What it Does

  1. Get all agents from metrics system
  2. Analyze each agent's performance
  3. Identify issues (low success, high cost, high latency)
  4. Generate improvement suggestions
  5. Store analysis results for evolution system

  ## Schedule

  Every 30 minutes (via Oban.Plugins.Cron in config.exs)

  ## Failure Handling

  - Max attempts: 2 (if fails, retries once)
  - Errors are logged but don't block other jobs
  - Individual agent analysis failures don't stop analysis of other agents
  """

  use Oban.Worker, queue: :default, max_attempts: 2

  require Logger

  alias Singularity.Execution.Feedback.Analyzer
  alias Singularity.Metrics.Aggregator

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("📊 Analyzing agent feedback...")

    try do
      # Find all agents needing improvement
      case Analyzer.find_agents_needing_improvement() do
        {:ok, agents_with_issues} ->
          log_analysis_results(agents_with_issues)
          Logger.info("✅ Feedback analysis complete", agents_analyzed: length(agents_with_issues))
          :ok

        {:error, reason} ->
          Logger.error("❌ Feedback analysis failed", reason: inspect(reason))
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("❌ Feedback analysis exception",
          error: inspect(e),
          stacktrace: __STACKTRACE__
        )

        {:error, e}
    end
  end

  defp log_analysis_results(agents) do
    # Group by health status for logging
    by_health =
      agents
      |> Enum.group_by(& &1.overall_health)
      |> Enum.map(fn {health, list} -> {health, length(list)} end)
      |> Map.new()

    Logger.info("📊 Analysis summary",
      total_agents_analyzed: length(agents),
      by_health: inspect(by_health),
      agents: Enum.map(agents, &%{agent: &1.agent_id, issues: &1.issue_count})
    )
  end
end
