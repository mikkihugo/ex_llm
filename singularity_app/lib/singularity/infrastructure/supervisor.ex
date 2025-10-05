defmodule Singularity.Infrastructure.Supervisor do
  @moduledoc """
  Supervisor for Singularity error handling infrastructure.

  Manages:
  - Circuit breaker registry and dynamic supervisor
  - Error rate tracker GenServer
  - Other infrastructure components

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
      # Circuit breaker registry for unique circuit names
      {Registry, keys: :unique, name: Singularity.Infrastructure.CircuitBreakerRegistry},

      # Dynamic supervisor for circuit breakers (created on-demand)
      {DynamicSupervisor,
       strategy: :one_for_one, name: Singularity.Infrastructure.CircuitBreakerSupervisor},

      # Error rate tracker (ETS-based)
      Singularity.Infrastructure.ErrorRateTracker
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
