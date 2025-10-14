defmodule Singularity.Execution.Todos.Supervisor do
  @moduledoc """
  Todos Supervisor - Manages TODO swarm execution infrastructure.

  Supervises the TODO swarm coordinator which orchestrates autonomous agents
  to solve TODO items in parallel.

  ## Managed Processes

  - `Singularity.Execution.Todos.TodoSwarmCoordinator` - GenServer orchestrating TODO worker agents

  ## TODO Swarm Architecture

  User creates TODO → Coordinator spawns workers → Workers solve → Report back

  The coordinator:
  - Monitors pending TODOs
  - Spawns TodoWorkerAgent processes via AgentSupervisor
  - Load balances across available agents
  - Tracks status and results
  - Handles failures and retries

  ## Dependencies

  Depends on:
  - AgentSupervisor - For spawning TodoWorkerAgent processes
  - LLM.Supervisor - For LLM-driven TODO solving
  - Repo - For todos table
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Todos Supervisor...")

    children = [
      Singularity.Execution.Todos.TodoSwarmCoordinator
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
