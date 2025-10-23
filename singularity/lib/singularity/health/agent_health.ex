defmodule Singularity.Health.AgentHealth do
  @moduledoc """
  Real-time agent health monitoring.

  Provides visibility into:
  - Agent status (idle, updating, errored)
  - Latest metrics (success_rate, latency, cost)
  - Recent failures/errors
  - Improvement history
  - Any issues that need attention
  """

  def get_agent_status(agent_id) do
    case GenServer.whereis({:via, Registry, {Singularity.ProcessRegistry, {:agent, agent_id}}}) do
      nil ->
        {:error, :agent_not_found}

      pid ->
        try do
          state = :sys.get_state(pid)
          {:ok, format_status(agent_id, state)}
        rescue
          _ -> {:error, :cannot_read_state}
        end
    end
  end

  def get_all_agents_status do
    Registry.select(Singularity.ProcessRegistry, [
      {
        {:_, :"$1", :"$2"},
        [{:==, {:element, 1, :"$1"}, :agent}],
        [:"$1"]
      }
    ])
    |> Enum.map(fn {_agent, agent_id} ->
      case get_agent_status(agent_id) do
        {:ok, status} -> {agent_id, status}
        {:error, _} -> {agent_id, %{error: "Cannot read state"}}
      end
    end)
  end

  defp format_status(agent_id, state) do
    %{
      agent_id: agent_id,
      status: Map.get(state, :status, :unknown),
      version: Map.get(state, :version, 0),
      cycles: Map.get(state, :cycles, 0),
      metrics: Map.get(state, :metrics, %{}),
      last_score: Map.get(state, :last_score, 0.0),
      last_improvement_cycle: Map.get(state, :last_improvement_cycle, 0),
      last_failure_cycle: Map.get(state, :last_failure_cycle, nil),
      improvement_history_count: state |> Map.get(:improvement_history, []) |> length(),
      improvement_history: state |> Map.get(:improvement_history, []) |> Enum.take(5),
      pending_plan: Map.get(state, :pending_plan) != nil,
      improvement_queue_size: state |> Map.get(:improvement_queue, :queue.new()) |> queue_size(),
      issues: identify_issues(state)
    }
  end

  defp identify_issues(state) do
    issues = []

    # Check for degradation
    issues =
      if Map.get(state, :last_failure_cycle) do
        cycles = Map.get(state, :cycles, 0)
        last_failure = Map.get(state, :last_failure_cycle, 0)

        if cycles - last_failure < 100 do
          [
            "Recent improvement failed (cycle #{last_failure}), agent in backoff"
            | issues
          ]
        else
          issues
        end
      else
        issues
      end

    # Check for stagnation
    issues =
      if Map.get(state, :cycles, 0) - Map.get(state, :last_improvement_cycle, 0) > 300 do
        ["Agent has not improved in 300 cycles, may be stagnant" | issues]
      else
        issues
      end

    # Check for low success rate
    metrics = Map.get(state, :metrics, %{})

    issues =
      if Map.get(metrics, :success_rate, 1.0) < 0.5 do
        ["Success rate critically low (#{Float.round(Map.get(metrics, :success_rate, 0) * 100, 1)}%)" | issues]
      else
        issues
      end

    issues =
      if Map.get(metrics, :success_rate, 1.0) < 0.75 do
        ["Success rate degraded (#{Float.round(Map.get(metrics, :success_rate, 0) * 100, 1)}%), improvement needed" | issues]
      else
        issues
      end

    # Check for stuck updates
    if Map.get(state, :status) == :updating and Map.get(state, :cycles, 0) > 100 do
      ["Agent stuck in updating status for > 100 cycles" | issues]
    else
      issues
    end
  end

  defp queue_size(queue) do
    try do
      :queue.len(queue)
    rescue
      _ -> 0
    end
  end
end
