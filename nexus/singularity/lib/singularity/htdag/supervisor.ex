defmodule Singularity.HTDAG.Supervisor do
  @moduledoc """
  HTDAG Supervisor - Manages HTDAG-based automatic code ingestion infrastructure.

  Supervises HTDAG workflows, file watchers, and related processes for automatic
  code ingestion using PgFlow for workflow orchestration.

  ## Managed Processes

  - `Singularity.Execution.Planning.CodeFileWatcher` - Real-time file watching
  - `Singularity.HTDAG.AutoCodeIngestionDAG` - HTDAG workflow management
  - `Singularity.Workflows` - PgFlow workflow orchestration

  ## Dependencies

  Depends on:
  - Repo - For database access
  - PgFlow - For workflow persistence
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

    children = if enabled do
      [
        # Real-time file watching for automatic detection
        Singularity.Execution.Planning.CodeFileWatcher,
        
        # HTDAG workflow management
        Singularity.HTDAG.AutoCodeIngestionDAG,
        
        # Load balancer for gentle operation
        Singularity.HTDAG.LoadBalancer,
        
        # PgFlow workflow orchestration
        Singularity.Workflows
      ]
    else
      Logger.info("HTDAG auto ingestion disabled, skipping file watcher")
      []
    end

    Supervisor.init(children, strategy: :one_for_one)
  end
end