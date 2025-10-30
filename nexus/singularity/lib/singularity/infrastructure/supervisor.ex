defmodule Singularity.Infrastructure.Supervisor do
  @moduledoc """
  Supervisor for Singularity infrastructure components.

  Manages core infrastructure services that must start early and are required
  by many other components.

  ## Managed Processes

  - Circuit breaker registry and dynamic supervisor
  - Error rate tracker GenServer
  - Startup warmup GenServer (system initialization)
  - Embedding model loader GenServer (ML model loading)

  This supervisor is started as part of the main application supervision tree.
  """

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Singularity Infrastructure Supervisor")

    children = [
      # Overseer keeps runtime visibility centralised (QuantumFlow edition)
      Singularity.Infrastructure.Overseer,

      # Circuit breaker registry for unique circuit names
      {Registry, keys: :unique, name: Singularity.Infrastructure.CircuitBreakerRegistry},

      # Dynamic supervisor for circuit breakers (created on-demand)
      {DynamicSupervisor,
       strategy: :one_for_one, name: Singularity.Infrastructure.CircuitBreakerSupervisor},

      # Error rate tracker (ETS-based)
      Singularity.Infrastructure.ErrorRateTracker,

      # Startup warmup (system initialization and health checks)
      Singularity.StartupWarmup,
      # HealthAgent stays as a pure module (invoked on demand; no child spec)

      # Embedding model loader (ML model initialization)
      Singularity.EmbeddingModelLoader,

      # HTTP health server (Plug + Cowboy)
      Singularity.Health.HttpServer
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
