defmodule Genesis.Scheduler do
  @moduledoc """
  Genesis Quantum Scheduler

  Runs periodic maintenance tasks for Genesis:
  - Clean up completed experiments
  - Analyze experiment trends
  - Report metrics to Centralcloud
  - Verify sandbox integrity

  ## Scheduled Jobs

  - **Cleanup** (every 6 hours): Remove old sandboxes and metrics
  - **Analysis** (every 24 hours): Calculate trends and recommendations
  - **Reporting** (every 24 hours): Send metrics to Centralcloud
  """

  use Quantum.Scheduler,
    otp_app: :genesis

  @doc """
  Clean up old sandbox directories and record in sandbox_history.
  """
  def cleanup_old_sandboxes do
    Genesis.SandboxMaintenance.cleanup_old_sandboxes()
  end

  @doc """
  Analyze experiment trends for insights.
  """
  def analyze_trends do
    Genesis.MetricsAnalyzer.analyze_trends()
  end

  @doc """
  Report metrics to Centralcloud for aggregation.
  """
  def report_metrics do
    Genesis.MetricsReporter.report_to_centralcloud()
  end

  @doc """
  Verify sandbox integrity and health.
  """
  def verify_sandbox_integrity do
    Genesis.SandboxMaintenance.verify_integrity()
  end
end
