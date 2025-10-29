defmodule Singularity.Metrics.Supervisor do
  @moduledoc """
  Metrics Supervisor - Manages the metrics subsystem

  Supervises:
  - Metrics NIF library (Rust bindings)
  - Metrics database operations
  - Background metric collection tasks
  - Metric storage and cleanup

  ## Module Hierarchy

  ```
  Singularity.Metrics.Supervisor
    ├─ Metrics.NIF (module - no process)
    ├─ Metrics.CodeMetrics (module - no process)
    ├─ Metrics.Enrichment (module - no process)
    └─ Metrics.Orchestrator (module - no process)
  ```

  Note: Most metrics operations are stateless and use the NIF directly.
  This supervisor primarily ensures proper initialization.
  """

  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Metrics Supervisor...")

    children = [
      Singularity.Metrics.Pipeline
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
