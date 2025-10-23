defmodule Singularity.Agents.MetricsFeeder do
  @moduledoc """
  Automatically feeds synthetic metrics to agents for self-improvement testing.

  Runs as a background GenServer, continuously generating realistic workload
  data to drive the evolution loop without requiring manual iex interaction.
  """
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, 10_000)

    Logger.info("Starting MetricsFeeder (interval: #{interval}ms)")
    schedule_feed(interval)

    {:ok, %{interval: interval, agents: %{}}}
  end

  @impl true
  def handle_info(:feed_metrics, state) do
    feed_all_agents(state.agents)
    schedule_feed(state.interval)
    {:noreply, state}
  end

  defp schedule_feed(interval) do
    Process.send_after(self(), :feed_metrics, interval)
  end

  defp feed_all_agents(agents) do
    # Get or create agents
    agent_ids = get_or_create_agents()

    Enum.each(agent_ids, fn agent_id ->
      feed_agent(agent_id)
    end)
  end

  defp get_or_create_agents do
    # Standard agent IDs for testing
    agent_ids = [
      "self-improving-test",
      "cost-optimized-test",
      "architecture-test",
      "technology-test",
      "refactoring-test",
      "chat-test"
    ]

    Enum.each(agent_ids, fn agent_id ->
      case Process.whereis({:via, Registry, {Singularity.ProcessRegistry, {:agent, agent_id}}}) do
        nil ->
          # Start agent if not running
          try do
            Singularity.SelfImprovingAgent.start_link(
              id: agent_id,
              tick_ms: 5000,
              context: %{type: infer_type(agent_id)}
            )
          rescue
            _ -> :ok
          end

        _pid ->
          :ok
      end
    end)

    agent_ids
  end

  defp infer_type(agent_id) do
    case agent_id do
      "self-improving-" <> _ -> :self_improving
      "cost-optimized-" <> _ -> :cost_optimized
      "architecture-" <> _ -> :architecture
      "technology-" <> _ -> :technology
      "refactoring-" <> _ -> :refactoring
      "chat-" <> _ -> :chat
      _ -> :unknown
    end
  end

  defp feed_agent(agent_id) do
    # Simulate realistic metrics
    metrics = generate_realistic_metrics()

    # Feed metrics
    case Singularity.SelfImprovingAgent.update_metrics(agent_id, metrics) do
      :ok ->
        Logger.debug("Fed metrics to #{agent_id}")

      {:error, reason} ->
        Logger.warning("Failed to feed metrics to #{agent_id}: #{inspect(reason)}")
    end

    # Randomly record outcomes
    Enum.each(1..random_outcome_count(), fn _ ->
      outcome = if :rand.uniform() < 0.8, do: :success, else: :failure

      case Singularity.SelfImprovingAgent.record_outcome(agent_id, outcome) do
        :ok -> :ok
        {:error, _} -> :ok
      end
    end)

    # Occasionally trigger improvements
    if :rand.uniform() < 0.1 do
      Singularity.SelfImprovingAgent.force_improvement(
        agent_id,
        "automatic_degradation_detected"
      )
    end
  end

  defp generate_realistic_metrics do
    # Vary success rate to sometimes drop below threshold (0.75)
    # This triggers the Decider to request improvements
    success_rate = case :rand.uniform() do
      x when x < 0.3 -> 0.5 + :rand.uniform() * 0.25  # 50-75% (triggers improvement)
      x when x < 0.7 -> 0.75 + :rand.uniform() * 0.25 # 75-100% (stable)
      _ -> 0.3 + :rand.uniform() * 0.45                # 30-75% (degradation)
    end

    %{
      success_rate: success_rate,
      avg_latency_ms: 800.0 + :rand.uniform() * 400.0,
      avg_cost_cents: 2.0 + :rand.uniform() * 5.0,
      tasks_completed: Enum.random(50..200),
      errors: Enum.random(0..10),
      feedback_score: 3.5 + :rand.uniform() * 1.5
    }
  end

  defp random_outcome_count do
    # Generate enough outcomes to hit the 8-sample minimum quickly
    Enum.random(3..8)
  end
end
