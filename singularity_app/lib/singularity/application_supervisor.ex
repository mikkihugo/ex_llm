defmodule Singularity.ApplicationSupervisor do
  @moduledoc """
  Main application supervisor that oversees core system components.

  This supervisor manages the lifecycle of essential Singularity services
  including the control plane, execution engines, and infrastructure components.
  """

  use Supervisor
  require Logger

  @doc """
  Start the application supervisor.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Control plane and execution
      Singularity.Control,

      # Core engines
      # Singularity.Engine,  # Plain module, not a process
      # Singularity.Engine.Supervisor,  # Does not exist

      # Infrastructure components
      Singularity.Infrastructure.Supervisor,

      # Architecture engine
      Singularity.ArchitectureEngine.MetaRegistry.Supervisor,

      # Git integration
      Singularity.Git.Supervisor,

      # NIF-based services (when available)
      # Note: These may fail to load if NIF libraries are missing
      # but should not prevent the application from starting
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end