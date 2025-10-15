defmodule Singularity.Execution.Planning.Supervisor do
  @moduledoc """
  Planning Supervisor - Manages autonomous planning and task decomposition infrastructure.

  Supervises HTDAG (Hierarchical Task DAG) components, SAFe work planning services, and TaskGraph orchestration.

  ## Managed Processes

  - `Singularity.Execution.TaskGraph.Orchestrator` - GenServer for dependency-aware task orchestration (unifies WorkerPool + HTDAGCore)
  - `Singularity.Execution.Planning.HTDAGAutoBootstrap` - GenServer for HTDAG self-diagnosis/auto-fix
  - `Singularity.Execution.Planning.SafeWorkPlanner` - GenServer for SAFe methodology planning
  - `Singularity.Execution.Planning.WorkPlanAPI` - GenServer providing work plan API

  ## Important Notes

  `Singularity.Execution.Planning.HTDAG` is NOT supervised here because it's a plain module
  providing API functions. The actual work is done by:
  - HTDAGCore (data structures)
  - HTDAGExecutor (execution logic)
  - HTDAGAutoBootstrap (supervised process for bootstrapping)
  - TaskGraph.Orchestrator (orchestration layer on top of HTDAGCore)

  ## Dependencies

  Depends on:
  - TaskGraph.WorkerPool - For worker spawning (Orchestrator delegates to WorkerPool)
  - Agents.Supervisor - For AgentSupervisor (TaskGraph.Orchestrator spawns role-based agents)
  - LLM.Supervisor - For task decomposition via LLM.Service
  - NATS.Supervisor - For htdag.execute.* NATS subjects
  - Repo - For todos and htdag_executions tables
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
      # TaskGraph orchestration layer (unifies WorkerPool + HTDAGCore)
      Singularity.Execution.TaskGraph.Orchestrator,
      # HTDAG infrastructure
      Singularity.Execution.Planning.HTDAGAutoBootstrap,
      # SAFe work planning
      Singularity.Execution.Planning.SafeWorkPlanner,
      Singularity.Execution.Planning.WorkPlanAPI
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
