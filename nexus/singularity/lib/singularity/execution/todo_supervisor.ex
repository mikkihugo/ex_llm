defmodule Singularity.Execution.TodoSupervisor do
  @moduledoc """
  Todo Supervisor - Manages todo swarm execution infrastructure.

  Supervises the TODO swarm coordinator which orchestrates autonomous agents
  to solve TODO items in parallel.

  ## Managed Processes

  - `Singularity.Execution.TodoSwarmCoordinator` - GenServer orchestrating TODO worker agents

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
  def init(opts) do
    Logger.info("Starting Todo Supervisor with options: #{inspect(opts)}")

    # Validate supervisor options
    case opts do
      [] -> Logger.debug("Todo Supervisor: No special options provided")
      _ -> Logger.debug("Todo Supervisor: Custom options provided: #{inspect(opts)}")
    end

    children = [
      Singularity.Execution.TodoSwarmCoordinator
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
