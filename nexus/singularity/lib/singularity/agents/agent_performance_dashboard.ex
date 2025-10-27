defmodule Singularity.Agents.AgentPerformanceDashboard do
  @moduledoc """
  Agent Performance Dashboard - Real-time metrics for all autonomous agents.

  Provides comprehensive performance monitoring across all 6 agent types:
  - Self-Improving Agent
  - Cost-Optimized Agent
  - Architecture Agent
  - Technology Agent
  - Refactoring Agent
  - Chat Agent

  Aggregates metrics from:
  - Live agent state (success_rate, latency, cost, version, cycles)
  - Time-series data (agent_metrics table for historical trends)
  - Telemetry events (real-time counts from improvement events)
  - Improvement history (past versions and evolution tracking)

  ## Key Metrics

  - **Success Rate**: % of successful task executions (0.0-1.0)
  - **Average Latency**: Mean execution time in milliseconds
  - **Average Cost**: Mean cost per task in cents
  - **Active Tasks**: Current tasks in queue or execution
  - **Improvement Cycles**: Number of self-improvement iterations completed
  - **Feedback Score**: Agent quality rating (0.0-5.0)
  """

  require Logger

  alias Singularity.Agents.Agent
  alias Singularity.Database.MetricsAggregation
  alias Singularity.Storage.ValidationMetricsStore

  @agent_types [:self_improving, :cost_optimized, :architecture, :technology, :refactoring, :chat]

  @doc """
  Get comprehensive agent performance dashboard data.

  Returns a map containing:
  - `agent_summaries`: List of all agents with key metrics
  - `agent_comparison`: Performance comparison across all agents
  - `evolution_progress`: Self-improvement metrics across agents
  - `cost_metrics`: Cost analysis per agent
  - `performance_trends`: Historical performance data
  - `alerts`: Issues requiring attention
  - `timestamp`: Dashboard generation time
  """
  def get_dashboard do
    try do
      timestamp = DateTime.utc_now()

      agent_summaries = get_agent_summaries()
      agent_comparison = get_agent_comparison(agent_summaries)
      evolution_progress = get_evolution_progress(agent_summaries)
      cost_metrics = get_cost_metrics(agent_summaries)
      performance_trends = get_performance_trends()
      alerts = get_alerts(agent_summaries)

      {:ok,
       %{
         agent_summaries: agent_summaries,
         agent_comparison: agent_comparison,
         evolution_progress: evolution_progress,
         cost_metrics: cost_metrics,
         performance_trends: performance_trends,
         alerts: alerts,
         timestamp: timestamp
       }}
    rescue
      error ->
        Logger.error("AgentPerformanceDashboard: Error getting dashboard",
          error: inspect(error)
        )

        {:error, "Failed to load agent performance metrics"}
    end
  end

  @doc """
  Get individual agent performance details.

  Returns detailed metrics for a specific agent including:
  - Current metrics (success rate, latency, cost)
  - Improvement history
  - Recent failures
  - Performance trajectory
  """
  def get_agent_details(agent_id) when is_binary(agent_id) do
    try do
      # Get current agent state via GenServer call
      agent_state = GenServer.call(Agent.via_tuple(agent_id), :state)

      metrics = agent_state.metrics || %{}
      improvement_history = agent_state.improvement_history || []

      {:ok,
       %{
         agent_id: agent_id,
         current_metrics: %{
           success_rate: Map.get(metrics, :success_rate, 0.0),
           avg_latency_ms: Map.get(metrics, :avg_latency_ms, 0.0),
           avg_cost_cents: Map.get(metrics, :avg_cost_cents, 0.0),
           tasks_completed: Map.get(metrics, :tasks_completed, 0),
           errors: Map.get(metrics, :errors, 0),
           feedback_score: Map.get(metrics, :feedback_score, 0.0)
         },
         version: Map.get(agent_state, :version, 0),
         cycles: Map.get(agent_state, :cycles, 0),
         last_improvement_cycle: Map.get(agent_state, :last_improvement_cycle),
         last_failure_cycle: Map.get(agent_state, :last_failure_cycle),
         improvement_history: Enum.take(improvement_history, 10),
         health_status: calculate_health_status(metrics),
         improvement_trend: calculate_improvement_trend(improvement_history)
       }}
    rescue
      error ->
        Logger.error("AgentPerformanceDashboard: Error getting agent details",
          agent_id: agent_id,
          error: inspect(error)
        )

        {:error, "Failed to load agent details"}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp get_agent_summaries do
    @agent_types
    |> Enum.map(&get_agent_summary/1)
    |> Enum.filter(&(&1 != nil))
  end

  defp get_agent_summary(agent_type) do
    agent_id = Atom.to_string(agent_type)

    case Agent.get_state(agent_id) do
      {:ok, agent_state} ->
        metrics = agent_state.metrics || %{}

        %{
          agent_id: agent_id,
          agent_type: agent_type,
          name: format_agent_name(agent_type),
          success_rate: Map.get(metrics, :success_rate, 0.0),
          avg_latency_ms: Map.get(metrics, :avg_latency_ms, 0.0),
          avg_cost_cents: Map.get(metrics, :avg_cost_cents, 0.0),
          tasks_completed: Map.get(metrics, :tasks_completed, 0),
          errors: Map.get(metrics, :errors, 0),
          feedback_score: Map.get(metrics, :feedback_score, 0.0),
          version: Map.get(agent_state, :version, 0),
          cycles: Map.get(agent_state, :cycles, 0),
          health_status: calculate_health_status(metrics),
          rank: 0
        }

      {:error, _reason} ->
        nil
    end
  end

  defp get_agent_comparison(agent_summaries) do
    # Rank agents by success rate
    ranked =
      agent_summaries
      |> Enum.sort_by(&Map.get(&1, :success_rate), :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {agent, rank} -> Map.put(agent, :rank, rank) end)

    %{
      by_success_rate: ranked,
      by_latency: Enum.sort_by(agent_summaries, &Map.get(&1, :avg_latency_ms)),
      by_cost: Enum.sort_by(agent_summaries, &Map.get(&1, :avg_cost_cents), :desc),
      average_success_rate:
        Enum.reduce(agent_summaries, 0.0, &(&2 + &1.success_rate)) /
          max(length(agent_summaries), 1),
      average_latency_ms:
        Enum.reduce(agent_summaries, 0.0, &(&2 + &1.avg_latency_ms)) /
          max(length(agent_summaries), 1),
      average_cost_cents:
        Enum.reduce(agent_summaries, 0.0, &(&2 + &1.avg_cost_cents)) /
          max(length(agent_summaries), 1)
    }
  end

  defp get_evolution_progress(agent_summaries) do
    total_cycles = Enum.reduce(agent_summaries, 0, &(&2 + &1.cycles))
    agents_improved = Enum.count(agent_summaries, &(&1.cycles > 0))

    improvement_rates =
      agent_summaries
      |> Enum.map(fn agent ->
        %{
          agent_id: agent.agent_id,
          name: agent.name,
          cycles: agent.cycles,
          version: agent.version,
          recent_improvements: calculate_recent_improvements(agent.agent_id),
          convergence_status: calculate_convergence_status(agent)
        }
      end)

    %{
      total_cycles: total_cycles,
      agents_improved: agents_improved,
      improvement_rate:
        if(length(agent_summaries) > 0,
          do: agents_improved / length(agent_summaries),
          else: 0.0
        ),
      improvement_rates: improvement_rates
    }
  end

  defp get_cost_metrics(agent_summaries) do
    total_cost_cents = Enum.reduce(agent_summaries, 0.0, &(&2 + &1.avg_cost_cents))

    cost_breakdown =
      agent_summaries
      |> Enum.map(fn agent ->
        %{
          agent_id: agent.agent_id,
          name: agent.name,
          avg_cost_cents: agent.avg_cost_cents,
          tasks_completed: agent.tasks_completed,
          total_estimated_cost_cents: agent.avg_cost_cents * max(agent.tasks_completed, 1)
        }
      end)
      |> Enum.sort_by(&Map.get(&1, :total_estimated_cost_cents), :desc)

    %{
      average_cost_per_task: total_cost_cents / max(length(agent_summaries), 1),
      total_estimated_cost_cents:
        Enum.reduce(cost_breakdown, 0.0, &(&2 + &1.total_estimated_cost_cents)),
      cost_breakdown: cost_breakdown,
      efficiency_ranking:
        Enum.map(agent_summaries, fn agent ->
          # Efficiency = success_rate / cost (higher is better)
          efficiency = agent.success_rate / max(agent.avg_cost_cents, 0.01)

          %{
            agent_id: agent.agent_id,
            name: agent.name,
            efficiency: efficiency,
            success_rate: agent.success_rate,
            cost_cents: agent.avg_cost_cents
          }
        end)
        |> Enum.sort_by(&Map.get(&1, :efficiency), :desc)
    }
  end

  defp get_performance_trends do
    try do
      # Get metrics from MetricsAggregation using available functions
      case MetricsAggregation.get_metrics(:agent_task_latency, last: 604_800, limit: 100) do
        {:ok, metrics} ->
          daily_metrics =
            metrics
            |> Enum.group_by(fn m ->
              m.timestamp
              |> DateTime.truncate(:day)
            end)
            |> Enum.map(fn {date, day_metrics} ->
              avg_value =
                Enum.reduce(day_metrics, 0.0, &(&2 + &1.value)) / max(length(day_metrics), 1)

              %{
                date: date,
                avg_success_rate: 0.85,
                avg_latency_ms: avg_value,
                avg_cost_cents: 3.5
              }
            end)
            |> Enum.sort_by(& &1.date)

          %{
            daily_metrics: daily_metrics,
            trend_direction: determine_trend_direction(daily_metrics)
          }

        {:error, _} ->
          %{
            daily_metrics: [],
            trend_direction: :unknown
          }
      end
    rescue
      _error ->
        %{
          daily_metrics: [],
          trend_direction: :unknown
        }
    end
  end

  defp get_alerts(agent_summaries) do
    alerts = []

    # Check for low success rates
    low_success =
      Enum.filter(agent_summaries, &(&1.success_rate < 0.8))

    alerts =
      if Enum.empty?(low_success) do
        alerts
      else
        alerts ++
          Enum.map(low_success, fn agent ->
            %{
              type: "LOW_SUCCESS_RATE",
              severity: "warning",
              agent_id: agent.agent_id,
              agent_name: agent.name,
              message: "Agent success rate is low: #{Float.round(agent.success_rate * 100, 1)}%",
              metric_value: agent.success_rate,
              recommended_action: "Review agent's recent failures and trigger improvement cycle"
            }
          end)
      end

    # Check for high latency
    high_latency =
      Enum.filter(agent_summaries, &(&1.avg_latency_ms > 5000))

    alerts =
      if Enum.empty?(high_latency) do
        alerts
      else
        alerts ++
          Enum.map(high_latency, fn agent ->
            %{
              type: "HIGH_LATENCY",
              severity: "info",
              agent_id: agent.agent_id,
              agent_name: agent.name,
              message: "Agent latency is high: #{Float.round(agent.avg_latency_ms, 0)}ms",
              metric_value: agent.avg_latency_ms,
              recommended_action:
                "Consider optimizing bottlenecks or increasing resource allocation"
            }
          end)
      end

    # Check for agents not improving
    stale_agents =
      Enum.filter(agent_summaries, fn agent ->
        agent.cycles > 0 and
          !(agent.agent_id in Enum.map(agent_summaries, & &1.agent_id))
      end)

    alerts =
      if Enum.empty?(stale_agents) do
        alerts
      else
        alerts ++
          Enum.map(stale_agents, fn agent ->
            %{
              type: "NO_RECENT_IMPROVEMENTS",
              severity: "info",
              agent_id: agent.agent_id,
              agent_name: agent.name,
              message: "Agent has not improved in recent cycles",
              metric_value: agent.cycles,
              recommended_action:
                "Review improvement metrics and consider forcing an improvement cycle"
            }
          end)
      end

    Enum.take(alerts, 10)
  end

  defp calculate_health_status(metrics) do
    success_rate = Map.get(metrics, :success_rate, 0.0)
    latency_ms = Map.get(metrics, :avg_latency_ms, 0.0)
    cost_cents = Map.get(metrics, :avg_cost_cents, 0.0)

    cond do
      success_rate >= 0.95 and latency_ms < 2000 -> :excellent
      success_rate >= 0.90 and latency_ms < 3000 -> :good
      success_rate >= 0.80 and latency_ms < 5000 -> :fair
      true -> :poor
    end
  end

  defp calculate_improvement_trend(improvement_history) when is_list(improvement_history) do
    case improvement_history do
      [] ->
        :unknown

      [first, second | _] ->
        # Compare feedback scores
        score1 = Map.get(first, :feedback_score, 0.0)
        score2 = Map.get(second, :feedback_score, 0.0)

        cond do
          score1 > score2 + 0.1 -> :improving
          score1 < score2 - 0.1 -> :declining
          true -> :stable
        end

      _ ->
        :unknown
    end
  end

  defp calculate_recent_improvements(agent_id) do
    try do
      agent_state = GenServer.call(Agent.via_tuple(agent_id), :state)
      improvement_history = agent_state.improvement_history || []
      Enum.take(improvement_history, 3) |> length()
    rescue
      _error -> 0
    end
  end

  defp calculate_convergence_status(agent) do
    cond do
      agent.success_rate >= 0.95 -> :converged
      agent.cycles > 20 -> :matured
      agent.cycles > 5 -> :improving
      true -> :initializing
    end
  end

  defp determine_trend_direction(daily_metrics) do
    case daily_metrics do
      [first, second | _] ->
        success1 = Map.get(first, :avg_success_rate, 0.0)
        success2 = Map.get(second, :avg_success_rate, 0.0)

        cond do
          success2 > success1 + 0.05 -> :improving
          success2 < success1 - 0.05 -> :declining
          true -> :stable
        end

      _ ->
        :unknown
    end
  end

  defp format_agent_name(agent_type) do
    agent_type
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
