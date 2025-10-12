defmodule Singularity.NATS.Supervisor do
  @moduledoc """
  NATS Supervisor - Manages NATS messaging infrastructure.

  Supervises all NATS-related processes in the correct startup order:
  1. NatsServer - Main NATS server connection
  2. NatsClient - Client interface for publishing/subscribing
  3. NatsExecutionRouter - Routes NATS messages to appropriate handlers

  ## Restart Strategy

  Uses `:rest_for_one` because dependencies flow in order:
  - If NatsServer crashes, restart Client and Router (they depend on it)
  - If NatsClient crashes, restart Router (it depends on client)
  - If NatsExecutionRouter crashes, only restart it

  ## Managed Processes

  - `Singularity.NatsServer` - GenServer managing NATS connection
  - `Singularity.NatsClient` - GenServer providing client interface
  - `Singularity.NatsExecutionRouter` - GenServer routing messages

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
      Singularity.NatsExecutionRouter
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
