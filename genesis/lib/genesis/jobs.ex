defmodule Genesis.Jobs do
  @moduledoc """
  Genesis Oban Jobs - Background job definitions for scheduled maintenance

  Provides Oban worker definitions for:
  - Experiment cleanup (every 6 hours)
  - Trend analysis (daily)
  - Metrics reporting (daily)

  These jobs are executed via Oban job queue system.
  """

  alias Genesis.Scheduler

  # ===== CLEANUP JOBS =====

  @doc """
  Clean up old completed experiments and their sandboxes.

  Runs every 6 hours via Oban.Cron.
  """
  def cleanup_experiments do
    Scheduler.cleanup_old_sandboxes()
  end

  # ===== ANALYSIS JOBS =====

  @doc """
  Analyze experiment trends and patterns.

  Runs daily at midnight via Oban.Cron.
  """
  def analyze_trends do
    Scheduler.analyze_trends()
  end

  # ===== REPORTING JOBS =====

  @doc """
  Report metrics to Centralcloud for aggregation.

  Runs daily at 1 AM via Oban.Cron.
  """
  def report_metrics do
    Scheduler.report_metrics()
  end
end
