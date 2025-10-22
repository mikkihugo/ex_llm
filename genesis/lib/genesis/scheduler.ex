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
end
