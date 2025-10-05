defmodule Singularity.Application do
  @moduledoc """
  Application entrypoint bootstrapping clustering, telemetry, and the HTTP control plane.
  """
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies, [])
    http_config = Application.get_env(:singularity, SingularityWeb.Endpoint, [])
    http_opts = Keyword.get(http_config, :http, [])
    http_enabled? = System.get_env("HTTP_SERVER_ENABLED", "false") == "true"
    port = Keyword.get(http_opts, :port, 8080)
    transport_opts = Keyword.get(http_opts, :transport_options, [])

    thousand_island_opts =
      if transport_opts == [], do: [], else: [transport_options: transport_opts]

    bandit_child =
      if http_enabled? do
        Bandit.child_spec(
          plug: SingularityWeb.Router,
          scheme: :http,
          port: port,
          thousand_island_options: thousand_island_opts
        )
      end

    :ok = Singularity.Autonomy.Limiter.ensure_table()

    children =
      [
        # Database
        Singularity.Repo,

        # Distributed Systems
        Singularity.Control.QueueCrdt,
        {Cluster.Supervisor, [topologies, [name: Singularity.ClusterSupervisor]]},
        # Event bus
        {Phoenix.PubSub, name: Singularity.PubSub},

        # Monitoring & Telemetry
        Singularity.Telemetry,

        # Caching (Rule Engine)
        {Cachex, name: :rule_engine_cache},

        # Memory Cache (Ultra-fast)
        Singularity.MemoryCache,

        # RAG & Template Optimization
        Singularity.TemplateOptimizer,
        Singularity.ExecutionCoordinator,

        # NATS Orchestrator (connects AI Server to ExecutionCoordinator)
        Singularity.NatsOrchestrator,

        # Auto-warmup (must be last to ensure all services are ready)
        Singularity.StartupWarmup,

        # Core Services
        Singularity.CodeStore,
        Singularity.ProcessRegistry,
        Singularity.Control.Listener,
        Singularity.Git.Supervisor,
        {Finch, name: Singularity.HttpClient},
        {Task.Supervisor, name: Singularity.TaskSupervisor},

        # SAFe 6.0 Planning
        Singularity.Conversation.Agent,
        Singularity.Planning.Coordinator,

        # Agents
        Singularity.AgentSupervisor,
        Singularity.HotReload.Manager,

        # HTTP Server
        bandit_child
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: Singularity.Supervisor]

    Logger.info("Singularity application starting",
      http: http_opts,
      cluster: topologies,
      http_enabled: http_enabled?
    )

    Supervisor.start_link(children, opts)
  end
end
