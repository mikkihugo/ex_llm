defmodule Singularity.Agents.Supervisor do
  @moduledoc """
  Agents Supervisor - Manages agent infrastructure.

  Supervises both fixed agent processes and the dynamic supervisor for spawned agents.

  ## Managed Processes

  - `Singularity.Agents.RuntimeBootstrapper` - GenServer ensuring runtime self-improving agent availability
  - `Singularity.AgentSupervisor` - DynamicSupervisor for spawning agents on-demand

  ## Agent Types

  Fixed agents (supervised here):
  - RuntimeBootstrapper - Ensures HTDAG auto-fixes work

  Dynamic agents (spawned via AgentSupervisor):
  - SelfImprovingAgent
  - CostOptimizedAgent
  - ArchitectureAgent
  - TechnologyAgent
  - RefactoringAgent
  - ChatConversationAgent
  - TodoWorkerAgent

  ## Dependencies

  Depends on:
  - LLM.Supervisor - For LLM-driven agent operations
  - NATS.Supervisor - For agent coordination
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Agents Supervisor...")

    children = [
      # Fixed agent - ensures runtime bootstrapping works
      Singularity.Agents.RuntimeBootstrapper,

      # Dynamic supervisor for spawning agents on-demand
      Singularity.AgentSupervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
