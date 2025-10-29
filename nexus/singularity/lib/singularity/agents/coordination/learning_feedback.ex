defmodule Singularity.Agents.Coordination.LearningFeedback do
  @moduledoc """
  Learning Feedback - Periodic sync of learned success rates to CapabilityRegistry.

  Runs as a periodic GenServer that:
  1. Queries WorkflowLearner for learned agent statistics
  2. Updates CapabilityRegistry with improved success rates
  3. Logs learning progress and improvements

  This closes the feedback loop:
  ```
  ExecutionCoordinator
      ↓ records outcomes
  WorkflowLearner (ETS-based learning)
      ↓ learns patterns (periodic query)
  LearningFeedback
      ↓ updates registry
  CapabilityRegistry
      ↓ improves routing
  AgentRouter (better task assignments)
  ```

  ## Configuration

  - `:update_interval` - How often to sync learned rates (default: 5 minutes)
  - `:min_samples` - Minimum executions before considering agent for learning (default: 5)

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Agents.Coordination.LearningFeedback",
    "purpose": "Periodically sync learned agent performance back to routing system",
    "layer": "coordination",
    "pattern": "Periodic feedback sync",
    "responsibilities": [
      "Query WorkflowLearner for learned statistics",
      "Update CapabilityRegistry with improved success rates",
      "Track learning progress and improvements",
      "Log agent performance trends"
    ]
  }
  ```
  """

  use GenServer
  require Logger

  # 5 minutes
  @default_update_interval 5 * 60 * 1000
  @default_min_samples 5

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    update_interval = Keyword.get(opts, :update_interval, @default_update_interval)
    min_samples = Keyword.get(opts, :min_samples, @default_min_samples)

    Logger.info("[LearningFeedback] Started",
      update_interval_ms: update_interval,
      min_samples: min_samples
    )

    # Schedule first update immediately, then periodically
    Process.send_after(self(), :update_learned_rates, 1000)

    {:ok,
     %{
       update_interval: update_interval,
       min_samples: min_samples,
       last_update_at: nil,
       updated_agents: 0
     }}
  end

  @impl true
  def handle_info(:update_learned_rates, state) do
    # Query all agents and update their success rates based on learning
    update_all_agent_rates()

    # Schedule next update
    Process.send_after(self(), :update_learned_rates, state.update_interval)

    {:noreply, %{state | last_update_at: DateTime.utc_now()}}
  end

  # Private

  defp update_all_agent_rates do
    alias Singularity.Agents.Coordination.{WorkflowLearner, CapabilityRegistry}

    # Get all registered agents (returns AgentCapability structs)
    try do
      capabilities = CapabilityRegistry.all_agents()

      updated_count =
        capabilities
        |> Enum.map(fn cap ->
          agent_name = cap.name

          case WorkflowLearner.get_agent_stats(agent_name) do
            nil ->
              # No learning data yet
              nil

            stats ->
              # Update registry with learned success rate
              case WorkflowLearner.update_success_rates(agent_name) do
                :ok ->
                  Logger.info("[LearningFeedback] Updated success rate",
                    agent: agent_name,
                    success_rate: Float.round(stats.success_rate, 3),
                    samples: stats.total_executions,
                    domains: map_size(stats.domain_performance)
                  )

                  agent_name

                {:error, reason} ->
                  Logger.warning("[LearningFeedback] Failed to update success rate",
                    agent: agent_name,
                    reason: inspect(reason)
                  )

                  nil
              end
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> length()

      if updated_count > 0 do
        Logger.info("[LearningFeedback] Periodic learning sync completed",
          agents_updated: updated_count,
          timestamp: DateTime.utc_now()
        )
      end
    rescue
      e ->
        Logger.error("[LearningFeedback] Exception during learning sync",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )
    end
  end
end
