defmodule Singularity.Execution.Feedback.Analyzer do
  @moduledoc """
  Feedback Analyzer - Identifies agent improvement opportunities from metrics.

  Analyzes aggregated agent metrics (from Metrics.Aggregator) to identify
  improvement opportunities and generate actionable suggestions for the
  evolution system.

  ## Architecture

  ```
  Agent Metrics (from Priority 1)
      ↓
  Feedback.Analyzer.analyze_agent/1
      ├─ Check success_rate (< 90% → needs patterns)
      ├─ Check cost (> target → optimize model)
      └─ Check latency (> 2000ms → improve cache)
      ↓
  Issues + Suggestions
      ↓
  (Feeds into Priority 3) Agents.Evolution
  ```

  ## Analysis Rules

  ### Success Rate Issues
  - **Threshold**: < 90%
  - **Cause**: Agent failing more than acceptable
  - **Suggestion**: Add high-confidence patterns to prompt
  - **Target**: Increase success rate to 95%+

  ### Cost Issues
  - **Threshold**: > $0.10 per task (configurable)
  - **Cause**: Using expensive models or doing extra work
  - **Suggestion**: Optimize model selection (use Haiku for simple, Sonnet for complex)
  - **Target**: Reduce cost by 30-50%

  ### Latency Issues
  - **Threshold**: > 2000ms per task
  - **Cause**: Slow execution, cache misses, network delays
  - **Suggestion**: Improve caching strategy, parallelize work
  - **Target**: Reduce latency to < 1000ms

  ## Usage

      # Analyze single agent
      {:ok, analysis} = Analyzer.analyze_agent("elixir-specialist")

      # List all agents needing improvement
      agents_with_issues = Analyzer.find_agents_needing_improvement()

      # Get specific improvement for agent
      {:ok, suggestions} = Analyzer.get_suggestions_for("rust-nif-specialist")
  """

  require Logger
  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Metrics.Aggregator
  alias Singularity.Schemas.AgentMetric

  @doc """
  Analyze an agent's performance and identify improvement opportunities.

  Returns analysis with identified issues and improvement suggestions.

  ## Examples

      iex> Analyzer.analyze_agent("elixir-specialist")
      {:ok, %{
        agent_id: "elixir-specialist",
        issues: [
          %{type: :low_success_rate, value: 0.85, threshold: 0.90},
          %{type: :high_cost, value: 4.5, threshold: 3.0}
        ],
        suggestions: [
          %{type: :add_patterns, confidence: 0.85, expected_improvement: "+10% success rate"},
          %{type: :optimize_model, confidence: 0.70, expected_improvement: "-40% cost"}
        ],
        overall_health: :needs_improvement,
        priority: 1
      }}
  """
  @spec analyze_agent(String.t()) :: {:ok, map()} | {:error, term()}
  def analyze_agent(agent_id) do
    try do
      # Get recent metrics for the agent
      case Aggregator.get_metrics_for(agent_id, :last_week) do
        {:ok, metrics} when is_list(metrics) and length(metrics) > 0 ->
          # Aggregate metrics across the week
          aggregated = aggregate_metrics(metrics)
          issues = identify_issues(agent_id, aggregated)
          suggestions = generate_suggestions(agent_id, aggregated, issues)

          analysis = %{
            agent_id: agent_id,
            analyzed_at: DateTime.utc_now(),
            metrics: aggregated,
            issues: issues,
            suggestions: suggestions,
            overall_health: determine_health(issues),
            priority: calculate_priority(issues),
            issue_count: length(issues),
            suggestion_count: length(suggestions)
          }

          Logger.info("✅ Analyzed agent", agent_id: agent_id, issues: length(issues))
          {:ok, analysis}

        {:ok, []} ->
          Logger.warning("⚠️ No metrics found for agent", agent_id: agent_id)
          {:ok, %{agent_id: agent_id, issues: [], suggestions: [], overall_health: :no_data}}

        {:error, reason} ->
          Logger.error("❌ Failed to fetch metrics", agent_id: agent_id, reason: inspect(reason))
          {:error, reason}
      end
    rescue
      e in Exception ->
        Logger.error("❌ Analysis exception", agent_id: agent_id, error: inspect(e))
        {:error, e}
    end
  end

  @doc """
  Find all agents that need improvement (have issues).

  Returns list of agent IDs sorted by priority (highest first).
  """
  @spec find_agents_needing_improvement() :: {:ok, list(map())} | {:error, term()}
  def find_agents_needing_improvement do
    try do
      # Get all agents' latest metrics
      all_metrics = Aggregator.get_all_agent_metrics()

      results =
        all_metrics
        |> Enum.map(fn {agent_id, _metric} ->
          case analyze_agent(agent_id) do
            {:ok, analysis} -> analysis
            {:error, _} -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(fn analysis -> length(analysis.issues) > 0 end)
        |> Enum.sort_by(& &1.priority, :desc)

      {:ok, results}
    rescue
      e in Exception ->
        Logger.error("❌ Failed to find agents needing improvement", error: inspect(e))
        {:error, e}
    end
  end

  @doc """
  Get improvement suggestions for a specific agent.

  Returns list of actionable suggestions sorted by confidence (highest first).
  """
  @spec get_suggestions_for(String.t()) :: {:ok, list(map())} | {:error, term()}
  def get_suggestions_for(agent_id) do
    case analyze_agent(agent_id) do
      {:ok, analysis} ->
        suggestions = analysis.suggestions |> Enum.sort_by(& &1.confidence, :desc)
        {:ok, suggestions}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private Functions

  @spec aggregate_metrics(list(map())) :: map()
  defp aggregate_metrics(metrics) when is_list(metrics) and length(metrics) > 0 do
    count = length(metrics)

    avg_success_rate =
      metrics
      |> Enum.map(& &1.success_rate)
      |> Enum.sum()
      |> then(&(&1 / count))
      |> Float.round(2)

    avg_cost_cents =
      metrics
      |> Enum.map(& &1.avg_cost_cents)
      |> Enum.sum()
      |> then(&(&1 / count))
      |> Float.round(2)

    avg_latency_ms =
      metrics
      |> Enum.map(& &1.avg_latency_ms)
      |> Enum.sum()
      |> then(&(&1 / count))
      |> Float.round(0)

    %{
      avg_success_rate: avg_success_rate,
      avg_cost_cents: avg_cost_cents,
      avg_latency_ms: avg_latency_ms,
      metric_count: count,
      latest_metric: List.first(metrics)
    }
  end

  defp aggregate_metrics(_), do: %{}

  @spec identify_issues(String.t(), map()) :: list(map())
  defp identify_issues(agent_id, aggregated) do
    issues = []

    # Check success rate
    issues = check_success_rate(issues, aggregated)

    # Check cost
    issues = check_cost(issues, aggregated, agent_id)

    # Check latency
    issues = check_latency(issues, aggregated)

    issues |> Enum.reverse()
  end

  @spec check_success_rate(list(map()), map()) :: list(map())
  defp check_success_rate(issues, %{avg_success_rate: success_rate}) when success_rate < 0.90 do
    [
      %{
        type: :low_success_rate,
        value: success_rate,
        threshold: 0.90,
        severity: if(success_rate < 0.80, do: :critical, else: :high),
        description: "Success rate below 90% - agent failing too often"
      }
      | issues
    ]
  end

  defp check_success_rate(issues, _), do: issues

  @spec check_cost(list(map()), map(), String.t()) :: list(map())
  defp check_cost(issues, %{avg_cost_cents: cost}, _agent_id) when cost > 3.0 do
    [
      %{
        type: :high_cost,
        value: cost,
        threshold: 3.0,
        severity: if(cost > 5.0, do: :high, else: :medium),
        description: "Average cost per task exceeds target"
      }
      | issues
    ]
  end

  defp check_cost(issues, _aggregated, _agent_id), do: issues

  @spec check_latency(list(map()), map()) :: list(map())
  defp check_latency(issues, %{avg_latency_ms: latency}) when latency > 2000 do
    [
      %{
        type: :high_latency,
        value: latency,
        threshold: 2000,
        severity: if(latency > 5000, do: :high, else: :medium),
        description: "Execution latency exceeds 2 seconds target"
      }
      | issues
    ]
  end

  defp check_latency(issues, _), do: issues

  @spec generate_suggestions(String.t(), map(), list(map())) :: list(map())
  defp generate_suggestions(_agent_id, _aggregated, []) do
    []
  end

  defp generate_suggestions(agent_id, aggregated, issues) do
    suggestions = []

    # Suggestion for low success rate
    suggestions =
      Enum.reduce(issues, suggestions, fn
        %{type: :low_success_rate, value: sr}, acc ->
          [
            %{
              type: :add_patterns,
              issue_type: :low_success_rate,
              confidence: calculate_confidence(:add_patterns, sr),
              expected_improvement: "+#{min(15, round((0.95 - sr) * 100))}% success rate",
              description: "Add high-confidence patterns to improve success rate",
              estimated_effort: :low
            }
            | acc
          ]

        _, acc ->
          acc
      end)

    # Suggestion for high cost
    suggestions =
      Enum.reduce(issues, suggestions, fn
        %{type: :high_cost, value: cost}, acc ->
          [
            %{
              type: :optimize_model,
              issue_type: :high_cost,
              confidence: calculate_confidence(:optimize_model, cost),
              expected_improvement: "-#{min(50, round((cost - 2.0) / cost * 100))}% cost",
              description: "Optimize model selection based on task complexity",
              estimated_effort: :medium
            }
            | acc
          ]

        _, acc ->
          acc
      end)

    # Suggestion for high latency
    suggestions =
      Enum.reduce(issues, suggestions, fn
        %{type: :high_latency, value: latency}, acc ->
          [
            %{
              type: :improve_cache,
              issue_type: :high_latency,
              confidence: calculate_confidence(:improve_cache, latency),
              expected_improvement: "-#{min(60, round((latency - 1000) / latency * 100))}% latency",
              description: "Improve caching strategy to reduce execution time",
              estimated_effort: :medium
            }
            | acc
          ]

        _, acc ->
          acc
      end)

    suggestions |> Enum.reverse()
  end

  @spec determine_health(list(map())) :: atom()
  defp determine_health([]), do: :healthy

  defp determine_health(issues) do
    critical_count = Enum.count(issues, fn i -> i.severity == :critical end)

    cond do
      critical_count > 0 -> :critical
      length(issues) > 2 -> :needs_improvement
      true -> :degraded
    end
  end

  @spec calculate_priority(list(map())) :: non_neg_integer()
  defp calculate_priority(issues) do
    issues
    |> Enum.reduce(0, fn
      %{severity: :critical}, acc -> acc + 3
      %{severity: :high}, acc -> acc + 2
      %{severity: :medium}, acc -> acc + 1
      _, acc -> acc
    end)
  end

  @spec calculate_confidence(atom(), float()) :: float()
  defp calculate_confidence(:add_patterns, success_rate) do
    # Lower success rate = higher confidence that patterns will help
    (0.95 - success_rate)
    |> then(&min(1.0, &1 * 2))
    |> Float.round(2)
  end

  defp calculate_confidence(:optimize_model, cost) do
    # Higher cost = higher confidence that optimization will help
    (cost - 2.0)
    |> then(&min(1.0, &1 / 5.0))
    |> Float.round(2)
  end

  defp calculate_confidence(:improve_cache, latency) do
    # Higher latency = higher confidence that caching will help
    (latency - 1000)
    |> then(&min(1.0, &1 / 5000))
    |> Float.round(2)
  end

  defp calculate_confidence(_, _), do: 0.5
end
