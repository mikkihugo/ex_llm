defmodule Singularity.Agents.Coordination.CoordinationSupervisor do
  @moduledoc """
  Coordination Supervisor - Manages the agent coordination infrastructure.

  Supervises:
  - CapabilityRegistry - Agent capability tracking
  - ExecutionCoordinator - Task execution management
  - (Future) WorkflowLearner - Pattern learning

  Integrated into the main supervision tree at Layer 4 (Agents & Execution).
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    max_restarts = Keyword.get(opts, :max_restarts, 3)
    max_seconds = Keyword.get(opts, :max_seconds, 5)

    Logger.info("[CoordinationSupervisor] Starting Agent Coordination infrastructure")
    Logger.info("[CoordinationSupervisor] Max restarts: #{max_restarts}, Max seconds: #{max_seconds}")

    children = [
      # CapabilityRegistry - track what agents can do
      {Singularity.Agents.Coordination.CapabilityRegistry, []},

      # LearningFeedback - periodically sync learned success rates to routing system
      {Singularity.Agents.Coordination.LearningFeedback, []},

      # CentralCloudSyncWorker - periodically push/pull capabilities across instances
      {Singularity.Agents.Coordination.CentralCloudSyncWorker, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
