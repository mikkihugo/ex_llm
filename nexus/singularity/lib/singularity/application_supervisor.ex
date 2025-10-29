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
    children =
      [
        # Control plane and execution
        Singularity.Execution.Runners.Control,

        # Core engines
        # Singularity.Engine,  # Plain module, not a process
        # Singularity.Engine.Supervisor,  # Does not exist

        # Infrastructure components
        Singularity.Infrastructure.Supervisor,

        # Architecture engine
        # Singularity.Engines.ArchitectureEngine.MetaRegistry.Supervisor,  # Module does not exist

        # Git integration
        Singularity.Git.Supervisor

        # NIF-based services (when available)
        # Note: These may fail to load if NIF libraries are missing
        # but should not prevent the application from starting
      ]
      |> maybe_add_code_file_watcher()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp maybe_add_code_file_watcher(children) do
    auto_ingestion_config = Application.get_env(:singularity, :auto_ingestion, %{})

    if auto_ingestion_config[:enabled] do
      # Singleton pattern: if not running, start it; otherwise skip (already running)
      case Process.whereis(Singularity.Execution.Planning.CodeFileWatcher) do
        nil ->
          Logger.info("CodeFileWatcher not running - starting it (auto ingestion enabled)")
          children ++ [Singularity.Execution.Planning.CodeFileWatcher]

        _pid ->
          Logger.debug("CodeFileWatcher already running - skipping (singleton: 1 is enough)")
          children
      end
    else
      Logger.info("Skipping CodeFileWatcher - auto ingestion disabled via config")
      children
    end
  end
end
