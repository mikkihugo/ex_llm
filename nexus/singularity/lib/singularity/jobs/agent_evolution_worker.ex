defmodule Singularity.Jobs.AgentEvolutionWorker do
  @moduledoc """
  Oban Worker for autonomous agent evolution (every 1 hour).

  Runs every hour to apply improvements identified by the Feedback Analyzer.
  This is the final step in the self-evolution pipeline:

  1. Metrics Aggregation (Priority 1 - every 5 minutes)
  2. Feedback Analysis (Priority 2 - every 30 minutes)
  3. Agent Evolution (Priority 3 - every 1 hour) ← This worker

  ## What it Does

  1. Find all agents needing improvement (from Feedback.Analyzer)
  2. Evolve each agent:
     - Apply highest-confidence suggestion
     - Validate with A/B testing
     - Rollback if metrics degrade
  3. Log evolution results (success rate, cost savings, latency improvements)

  ## Schedule

  Every 1 hour (via Oban.Plugins.Cron in config.exs)

  ## Failure Handling

  - Max attempts: 2 (retries once if fails)
  - Individual agent evolution failures don't block others
  - Comprehensive error logging for debugging

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "Singularity.Jobs.AgentEvolutionWorker",
    "purpose": "autonomous_agent_evolution_job",
    "domain": "jobs",
    "capabilities": ["background_job", "agent_evolution", "improvement_application"],
    "dependencies": ["Execution.Evolution", "Execution.Feedback.Analyzer"]
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    A[Oban Cron Trigger] -->|Every 1 hour| B[AgentEvolutionWorker]
    B --> C[Find Agents Needing Improvement]
    C --> D[For Each Agent]
    D --> E[Evolve Agent]
    E --> F{Evolution Success?}
    F -->|Yes| G[Log Success]
    F -->|No| H[Log Failure]
    G --> I[Emit Metrics]
    H --> I
  ```

  ## Call Graph (YAML)
  ```yaml
  AgentEvolutionWorker:
    perform/1: [Analyzer.find_agents_needing_improvement, evolve_agents, log_evolution_results]
    evolve_agents/1: [Evolution.evolve_agent, handle_evolution_result]
    log_evolution_results/1: [Enum.group_by, Logger.info]
  ```

  ## Anti-Patterns

  - **DO NOT** stop evolution on first failure - continue with other agents
  - **DO NOT** run evolution concurrently - one per hour is safest
  - **DO NOT** skip logging - results are important for monitoring

  ## Search Keywords

  agent_evolution, autonomous_improvement, oban_worker, background_job, evolution_loop, self_improvement, feedback_driven, autonomous_learning
  """

  use Oban.Worker, queue: :default, max_attempts: 2

  require Logger

  alias Singularity.Execution.Evolution
  alias Singularity.Execution.Feedback.Analyzer

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("🚀 Starting agent evolution cycle...")

    try do
      # Find all agents needing improvement
      case Analyzer.find_agents_needing_improvement() do
        {:ok, agents_with_issues} ->
          # Evolve each agent and collect results
          evolution_results = evolve_agents(agents_with_issues)

          # Log the evolution results
          log_evolution_results(evolution_results)

          Logger.info("✅ Agent evolution cycle complete",
            agents_evolved: length(evolution_results),
            successful: count_successful(evolution_results),
            failed: count_failed(evolution_results)
          )

          :ok

        {:error, reason} ->
          Logger.error("❌ Failed to find agents for evolution", reason: inspect(reason))
          {:error, reason}
      end
    rescue
      e in Exception ->
        Logger.error("❌ Agent evolution exception",
          error: inspect(e),
          stacktrace: __STACKTRACE__
        )

        {:error, e}
    end
  end

  defp evolve_agents(agents) do
    agents
    |> Enum.map(fn agent ->
      agent_id = agent.agent_id

      case Evolution.evolve_agent(agent_id) do
        {:ok, result} ->
          Map.put(result, :status, :success)

        {:error, reason} ->
          Logger.error("Evolution failed for agent", agent_id: agent_id, reason: inspect(reason))

          %{
            agent_id: agent_id,
            status: :failed,
            reason: reason
          }
      end
    end)
  end

  defp log_evolution_results(results) do
    # Group results by status
    by_status =
      results
      |> Enum.group_by(& &1.status)
      |> Enum.map(fn {status, list} -> {status, length(list)} end)
      |> Map.new()

    # Log per-status counts
    Logger.info("📊 Evolution results summary",
      total: length(results),
      by_status: inspect(by_status)
    )

    # Log individual results with key metrics
    improvements =
      results
      |> Enum.filter(&(&1.improvement_applied && &1.improvement_applied != :none))
      |> Enum.map(
        &%{
          agent: &1.agent_id,
          improvement: &1.improvement_applied,
          change: &1.improvement
        }
      )

    if length(improvements) > 0 do
      Logger.info("📈 Improvements applied",
        count: length(improvements),
        details: Enum.map(improvements, &inspect/1)
      )
    end
  end

  defp count_successful(results) do
    Enum.count(results, &(&1.status == :success))
  end

  defp count_failed(results) do
    Enum.count(results, &(&1.status == :failed))
  end
end
