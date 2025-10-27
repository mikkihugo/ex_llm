defmodule Singularity.Execution.Supervisor do
  @moduledoc """
  Execution Supervisor - Manages unified execution infrastructure.

  Supervises both planning (SAFe methodology, task decomposition) and todos (swarm execution)
  components in a unified execution system.

  ## Managed Processes

  ### Planning Components
  - `Singularity.Execution.TaskGraph.Orchestrator` - GenServer for dependency-aware task orchestration
  - `Singularity.Code.StartupCodeIngestion` - GenServer for TaskGraph self-diagnosis/auto-fix
  - `Singularity.Execution.SafeWorkPlanner` - GenServer for SAFe methodology planning
  - `Singularity.Execution.WorkPlanAPI` - GenServer providing work plan API

  ### Todo Components
  - `Singularity.Execution.TodoSwarmCoordinator` - GenServer orchestrating TODO worker agents

  ## Architecture

  Planning creates work → Todos executes work → Both share todos table

  ## Dependencies

  Depends on:
  - AgentSupervisor - For spawning TodoWorkerAgent processes
  - LLM.Supervisor - For LLM-driven planning and TODO solving
  - Repo - For todos and task_graph_executions tables
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Execution Supervisor...")

    children = [
      # Planning components
      Singularity.Execution.TaskGraph.Orchestrator,
      Singularity.Code.StartupCodeIngestion,
      Singularity.Execution.SafeWorkPlanner,
      Singularity.Execution.WorkPlanAPI,

      # Todo components
      Singularity.Execution.TodoSwarmCoordinator
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
