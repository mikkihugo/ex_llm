defmodule Singularity.Execution.Planning.Supervisor do
  @moduledoc """
  Planning Supervisor - Manages autonomous planning and task decomposition infrastructure.

  Supervises HTDAG (Hierarchical Task DAG) components and SAFe work planning services.

  ## Managed Processes

  - `Singularity.Execution.Planning.HTDAGAutoBootstrap` - GenServer for HTDAG self-diagnosis/auto-fix
  - `Singularity.Execution.Planning.SafeWorkPlanner` - GenServer for SAFe methodology planning
  - `Singularity.Execution.Planning.WorkPlanAPI` - GenServer providing work plan API

  ## Important Notes

  `Singularity.Execution.Planning.HTDAG` is NOT supervised here because it's a plain module
  providing API functions. The actual work is done by:
  - HTDAGCore (data structures)
  - HTDAGExecutor (execution logic)
  - HTDAGAutoBootstrap (supervised process for bootstrapping)

  ## Dependencies

  Depends on:
  - LLM.Supervisor - For task decomposition via LLM.Service
  - NATS.Supervisor - For htdag.execute.* NATS subjects
  - Repo - For htdag_executions table
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Planning Supervisor...")

    children = [
      Singularity.Execution.Planning.HTDAGAutoBootstrap,
      Singularity.Execution.Planning.SafeWorkPlanner,
      Singularity.Execution.Planning.WorkPlanAPI
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
