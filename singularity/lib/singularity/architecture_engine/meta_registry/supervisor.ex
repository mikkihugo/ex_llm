defmodule Singularity.ArchitectureEngine.MetaRegistry.Supervisor do
  @moduledoc """
  Meta-Registry Supervisor - Manages meta-registry services and NATS subscriptions.

  Starts and supervises:
  - Message handlers for meta-registry NATS subjects
  - Framework registry initialization
  - Template loading and caching
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Architecture Engine Meta-Registry Supervisor...")

    children = [
      # Start the message handlers
      {Singularity.ArchitectureEngine.MetaRegistry.MessageHandlers, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
