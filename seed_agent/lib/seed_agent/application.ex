defmodule SeedAgent.Application do
  @moduledoc """
  Application entrypoint bootstrapping clustering, telemetry, and the HTTP control plane.
  """
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies, [])
    http_config = Application.get_env(:seed_agent, SeedAgentWeb.Endpoint, [])
    http_opts = Keyword.get(http_config, :http, [])
    http_enabled? = System.get_env("HTTP_SERVER_ENABLED", "false") == "true"
    port = Keyword.get(http_opts, :port, 8080)
    transport_opts = Keyword.get(http_opts, :transport_options, [])

    thousand_island_opts =
      if transport_opts == [], do: [], else: [transport_options: transport_opts]

    bandit_child =
      if http_enabled? do
        Bandit.child_spec(
          plug: SeedAgentWeb.Router,
          scheme: :http,
          port: port,
          thousand_island_options: thousand_island_opts
        )
      end

    :ok = SeedAgent.Autonomy.Limiter.ensure_table()

    children =
      [
        SeedAgent.Control.QueueCrdt,
        {Cluster.Supervisor, [topologies, [name: SeedAgent.ClusterSupervisor]]},
        SeedAgent.Telemetry,
        SeedAgent.CodeStore,
        SeedAgent.ProcessRegistry,
        SeedAgent.Control.Listener,
        {Finch, name: SeedAgent.HttpClient},
        {Task.Supervisor, name: SeedAgent.TaskSupervisor},
        SeedAgent.AgentSupervisor,
        SeedAgent.HotReload.Manager,
        bandit_child
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: SeedAgent.Supervisor]

    Logger.info("SeedAgent application starting",
      http: http_opts,
      cluster: topologies,
      http_enabled: http_enabled?
    )

    Supervisor.start_link(children, opts)
  end
end
