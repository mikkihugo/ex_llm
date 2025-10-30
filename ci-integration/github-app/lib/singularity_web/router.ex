# GitHub App Router Configuration

defmodule SingularityWeb.Router do
  use SingularityWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :github_webhook do
    plug :accepts, ["json"]
    # Add webhook signature verification here
  end

  scope "/api", SingularityWeb do
    pipe_through :api

    # Health check
    get "/health", HealthController, :index

    # User-facing API (authenticated)
    scope "/v1" do
      # Repository analysis history
      get "/repos/:owner/:repo/analysis", ApiController, :repo_analysis

      # Repository trends
      get "/repos/:owner/:repo/trends", ApiController, :repo_trends

      # Update repository settings
      post "/repos/:owner/:repo/config", ApiController, :update_config
    end
  end

  scope "/webhooks", SingularityWeb do
    pipe_through :github_webhook

    # GitHub webhook endpoint
    post "/github", Webhooks.GithubController, :webhook
  end

  # Enable LiveDashboard in development
  if Mix.env() == :dev do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: SingularityWeb.Telemetry
    end
  end
end