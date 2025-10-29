defmodule ObserverWeb.Router do
  use ObserverWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ObserverWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :auth do
    plug :check_auth
  end

  defp check_auth(conn, _opts) do
    case get_session(conn, :authenticated) do
      true -> conn
      _ -> 
        conn
        |> put_session(:return_to, conn.request_path)
        |> Phoenix.Controller.redirect(to: "/login")
        |> halt()
    end
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ObserverWeb do
    pipe_through :browser

    # Login routes (no auth required)
    get "/login", AuthController, :login
    post "/login", AuthController, :do_login
    delete "/logout", AuthController, :logout

    # Protected routes
    scope "/" do
      pipe_through :auth

        live "/", SystemHealthLive
      live "/adaptive-threshold", AdaptiveThresholdLive
      live "/nexus-llm-health", NexusLLMHealthLive
      live "/validation-metrics", ValidationMetricsLive
      live "/validation-metrics-store", ValidationMetricsStoreLive
      live "/failure-patterns", FailurePatternsLive

      # Advanced Dashboards (Phase 2)
      live "/agent-performance", AgentPerformanceLive
      live "/cost-analytics", CostAnalyticsLive
      live "/code-quality", CodeQualityLive
      live "/rule-evolution", RuleEvolutionLive
      live "/knowledge-base", KnowledgeBaseLive
      live "/task-execution", TaskExecutionLive
      live "/todos", TodosLive
      live "/hitl-approvals", HITLApprovalsLive
      live "/sasl-traces", SASLTraceLive
      # WebChat Integration
      live "/webchat", WebChatLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ObserverWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:observer, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard",
        metrics: ObserverWeb.Telemetry,
        ecto_repos: [Observer.Repo],
        pages: [
          # Custom Singularity dashboard pages
          genesis: Singularity.Dashboard.GenesisPage,
          system_health: Singularity.Dashboard.SystemHealthPage,
          llm: Singularity.Dashboard.LLMPage,
          agents: Singularity.Dashboard.AgentsPage
        ]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
