defmodule Singularity.Ingestion.HTDAG.StartHtdagIngestionSupervisor do
  @moduledoc """
  HTDAG Supervisor - Manages HTDAG-based automatic code ingestion infrastructure.

  Supervises HTDAG workflows, file watchers, and related processes for automatic
  code ingestion using QuantumFlow for workflow orchestration.

  ## Managed Processes

  - `Singularity.Ingestion.WatchFilesAndEnqueueIngestion` - Real-time file watching
  - `Singularity.Ingestion.HTDAG.RunCodeIngestionDAG` - HTDAG workflow management
  - `Singularity.Workflows` - QuantumFlow workflow orchestration

  ## Dependencies

  Depends on:
  - Repo - For database access
  - QuantumFlow - For workflow persistence
  - FileSystem - For file watching
  - UnifiedIngestionService - For code parsing and storage

  ## Configuration

  Configure via `:htdag_auto_ingestion` config key:
  ```elixir
  config :singularity, :htdag_auto_ingestion,
    enabled: true,
    watch_directories: ["lib", "packages", "nexus", "observer"],
    debounce_delay_ms: 500,
    max_concurrent_dags: 10
  ```
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting HTDAG Supervisor...")

    # Check if HTDAG auto ingestion is enabled
    enabled = Application.get_env(:singularity, :htdag_auto_ingestion, %{})[:enabled] || false

    children =
      if enabled do
        [
          # HTDAG workflow management
          Singularity.Ingestion.HTDAG.RunCodeIngestionDAG,

          # Load balancer for gentle operation
          Singularity.HTDAG.LoadBalancer,

          # QuantumFlow workflow orchestration
          Singularity.Workflows
        ]
      else
        Logger.info("HTDAG auto ingestion disabled")
        []
      end

    # Note: CodeFileWatcher is started by ApplicationSupervisor (singleton)
    # HTDAG workflows use the existing CodeFileWatcher instance via its public API

    Supervisor.init(children, strategy: :one_for_one)
  end
end
