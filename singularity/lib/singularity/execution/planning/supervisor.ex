defmodule Singularity.Execution.Planning.Supervisor do
  @moduledoc """
  Planning Supervisor - Manages autonomous planning and task decomposition infrastructure.

  Supervises TaskGraph (Hierarchical Task DAG) components, SAFe work planning services, and TaskGraph orchestration.

  ## Managed Processes

  - `Singularity.Execution.TaskGraph.Orchestrator` - GenServer for dependency-aware task orchestration (unifies WorkerPool + TaskGraphCore)
  - `Singularity.Code.StartupCodeIngestion` - GenServer for TaskGraph self-diagnosis/auto-fix
  - `Singularity.Execution.Planning.SafeWorkPlanner` - GenServer for SAFe methodology planning
  - `Singularity.Execution.Planning.WorkPlanAPI` - GenServer providing work plan API

  ## Important Notes

  `Singularity.Execution.Planning.TaskGraph` is NOT supervised here because it's a plain module
  providing API functions. The actual work is done by:
  - TaskGraphCore (data structures)
  - TaskGraphExecutor (execution logic)
  - StartupCodeIngestion (supervised process for bootstrapping)
  - TaskGraph.Orchestrator (orchestration layer on top of TaskGraphCore)

  ## Dependencies

  Depends on:
  - TaskGraph.WorkerPool - For worker spawning (Orchestrator delegates to WorkerPool)
  - Agents.Supervisor - For AgentSupervisor (TaskGraph.Orchestrator spawns role-based agents)
  - LLM.Supervisor - For task decomposition via LLM.Service
  - Singularity.Jobs.PgmqClient.Supervisor - For task_graph.execute.* pgmq subjects
  - Repo - For todos and task_graph_executions tables
  """

  use Supervisor
  require Logger

  def start_link(_opts \\ []) do
    Supervisor.start_link(__MODULE__, _opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting Planning Supervisor...")

    children = [
      # TaskGraph orchestration layer (unifies WorkerPool + TaskGraphCore)
      Singularity.Execution.TaskGraph.Orchestrator,
      # TaskGraph infrastructure
      Singularity.Code.StartupCodeIngestion,
      # SAFe work planning
      Singularity.Execution.Planning.SafeWorkPlanner,
      Singularity.Execution.Planning.WorkPlanAPI
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
