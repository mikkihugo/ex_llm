defmodule Singularity.Web.Router do
  @moduledoc """
  Web router for Singularity internal interface.

  Provides access to:
  - Custom LiveView pages (approvals, documentation)
  - Phoenix LiveDashboard with system health monitoring
  - Health check and metrics endpoints

  ## Routes

  ### LiveView Pages
  - GET /approvals - Approval queue for code changes
  - GET /documentation - Documentation system status

  ### LiveDashboard
  - GET /dashboard - System monitoring dashboard

  ### Health & Metrics
  - GET /health - Health check status
  - GET /metrics - System metrics (JSON)

  ## Architecture

  Combines Phoenix LiveView for real-time UI with REST endpoints for
  health checks and monitoring. All routes are protected for internal use only.

  ## Custom Dashboard Pages

  Registered pages:
  - Singularity.Dashboard.SystemHealthPage - System health metrics
  - Singularity.Dashboard.AgentsPage - Active agents monitoring
  - Singularity.Dashboard.LLMPage - LLM metrics and costs
  """

  use Phoenix.Router

  import Phoenix.LiveView.Router
  import Phoenix.LiveDashboard.Router

  # Enable LiveSocket middleware for LiveView
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {Singularity.Web.Layouts, :app}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # LiveView routes
  scope "/", Singularity.Web do
    pipe_through(:browser)

    live("/", IndexLive)
    live("/approvals", ApprovalLive)
    live("/documentation", DocumentationLive)
  end

  # Phoenix LiveDashboard with custom pages
  scope "/" do
    pipe_through(:browser)

    live_dashboard("/dashboard",
      metrics: Singularity.Telemetry,
      custom_pages: [
        {Singularity.Dashboard.SystemHealthPage, "System"},
        {Singularity.Dashboard.AgentsPage, "Agents"},
        {Singularity.Dashboard.LLMPage, "LLM"}
      ]
    )
  end

  # API routes (health checks, metrics, etc.)
  scope "/api" do
    pipe_through(:api)

    get "/health", Singularity.Web.HealthController, :health
    get "/metrics", Singularity.Web.HealthController, :metrics
    get "/documentation/health", Singularity.Web.HealthController, :documentation_health
    get "/documentation/status", Singularity.Web.HealthController, :documentation_status
    post "/documentation/upgrade", Singularity.Web.HealthController, :documentation_upgrade
    post "/self-awareness/run", Singularity.Web.HealthController, :self_awareness_run
    get "/self-awareness/status", Singularity.Web.HealthController, :self_awareness_status
  end

  # Catch-all route (matches any request not matched above)
  scope "/" do
    pipe_through(:api)
    get "/*path", Singularity.Web.ErrorController, :not_found
  end
end
