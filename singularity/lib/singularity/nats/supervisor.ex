defmodule Singularity.NATS.Supervisor do
  @moduledoc """
  NATS Supervisor - Manages NATS messaging infrastructure.

  Supervises all NATS-related processes in the correct startup order:
  1. NatsServer - Main NATS server connection
  2. NatsClient - Client interface for publishing/subscribing

  ## Restart Strategy

  Uses `:rest_for_one` because dependencies flow in order:
  - If NatsServer crashes, restart Client and other services (they depend on it)
  - If NatsClient crashes, restart other services (they depend on client)

  ## Managed Processes

  - `Singularity.NatsClient` - GenServer providing client interface
  - `Singularity.NatsServer` - GenServer managing NATS connection
  - `Singularity.Embedding.Service` - Embedding service for CentralCloud
  - `Singularity.Tools.DatabaseToolsExecutor` - Database tool execution

  ## Dependencies

  None - NATS infrastructure is self-contained and starts early.
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting NATS Supervisor...")

    children = [
      # Order matters! Client must start before Server (Server subscribes to Client)
      Singularity.NatsClient,
      Singularity.NatsServer,
      # Embedding service for CentralCloud
      Singularity.Embedding.Service,
      # Database-first tool executor
      Singularity.Tools.DatabaseToolsExecutor
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
