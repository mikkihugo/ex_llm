defmodule NexusWeb.Router do
  use Phoenix.Router

  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NexusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", NexusWeb do
    pipe_through :browser
    live "/", DashboardLive.Index, :index
  end

  # API endpoints for NATS communication
  scope "/api", NexusWeb do
    pipe_through :api

    # Singularity endpoints
    get "/singularity/status", SingularityController, :status
    post "/singularity/analyze", SingularityController, :analyze

    # Genesis endpoints
    get "/genesis/status", GenesisController, :status
    post "/genesis/experiment", GenesisController, :create_experiment

    # CentralCloud endpoints
    get "/centralcloud/status", CentralCloudController, :status
    get "/centralcloud/insights", CentralCloudController, :insights
  end

  # Other scopes may use custom stacks.
  # scope "/admin", NexusWeb do
  #   pipe_through :browser
  #   ...
  # end
end
