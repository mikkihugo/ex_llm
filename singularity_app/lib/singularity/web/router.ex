defmodule Singularity.Web.Router do
  @moduledoc """
  Web router for Singularity internal interface.

  Provides access to:
  - Health check endpoint (/health)
  - Metrics endpoint (/metrics)
  - Phoenix LiveDashboard (planned - /dashboard)

  ## Usage

  Access dashboard at: http://localhost:4000/dashboard (when implemented)
  Health: http://localhost:4000/health
  Metrics: http://localhost:4000/metrics

  Note: Full LiveDashboard integration requires additional Phoenix setup.
  For now, use /metrics endpoint for JSON metrics.
  """

  # Placeholder - LiveDashboard requires full Phoenix endpoint setup
  # which is more complex than needed for internal tooling
  # For now, metrics are available via /metrics JSON endpoint

  def info do
    """
    Singularity Web Interface

    Available endpoints:
    - GET /health - Health check status
    - GET /metrics - System metrics (JSON)

    LiveDashboard: Coming soon
    """
  end
end
