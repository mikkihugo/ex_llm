defmodule Singularity.Autonomy.RuleEngine do
  @moduledoc """
  Confidence-Based Rule Engine for Autonomous Decision Making.

  Inspired by Zenflow's MoonShine pattern but implemented fresh for Singularity.

  Confidence Thresholds:
  - 90%+ : Autonomous execution
  - 70-89%: Collaborative (ask human)
  - <70% : Escalate to human

  Integrates with:
  - Cachex for rule result caching
  - Phoenix.PubSub for event broadcasting
  - Planning.Coordinator for epic/feature decisions
  """

  require Logger

  ## Public API

  @doc """
  Execute a rule and get confidence-based decision.

  ## Examples

      iex> rule = create_rule("code-quality-check")
      iex> context = %{feature_id: "feat-123", metrics: %{"complexity" => 5.2}}
      iex> RuleEngine.execute(rule, context)
      {:autonomous, %{confidence: 0.95, action: "Deploy automatically", ...}}
  """
  def execute(rule, context) do
    # Convert to Gleam types
    gleam_rule = elixir_rule_to_gleam(rule)
    gleam_context = elixir_context_to_gleam(context)

    # Check cache first
    cache_key = generate_cache_key(rule, context)

    case get_cached_result(cache_key) do
      {:ok, cached_result} ->
        Logger.debug("MoonShine cache hit", rule_id: rule.id, cache_key: cache_key)
        {:ok, Map.put(cached_result, :cached, true)}

      :miss ->
        # Execute rule via Gleam
        result = :singularity@rule_engine.execute_rule(gleam_rule, gleam_context)
        gleam_result = gleam_result_to_elixir(result)

        # Cache if high confidence
        if gleam_result.confidence >= 0.9 do
          cache_result(cache_key, gleam_result)
        end

        # Broadcast event
        broadcast_rule_executed(gleam_result)

        classify_result(gleam_result)
    end
  end

  @doc """
  Create a rule definition.

  ## Examples

      create_rule(
        id: "wsjf-validation",
        name: "WSJF Score Validation",
        category: :epic,
        patterns: [
          {:metric, "business_value", ">", 7, weight: 0.8},
          {:metric, "job_size", "<", 15, weight: 0.6}
        ]
      )
  """
  def create_rule(opts) do
    %{
      id: Keyword.fetch!(opts, :id),
      name: Keyword.fetch!(opts, :name),
      description: Keyword.get(opts, :description, ""),
      category: Keyword.get(opts, :category, :code_quality),
      patterns: Keyword.get(opts, :patterns, []),
      confidence_threshold: Keyword.get(opts, :confidence_threshold, 0.7)
    }
  end

  @doc "Create execution context"
  def create_context(opts \\ []) do
    %{
      feature_id: Keyword.get(opts, :feature_id),
      epic_id: Keyword.get(opts, :epic_id),
      code_snippet: Keyword.get(opts, :code_snippet),
      metrics: Keyword.get(opts, :metrics, %{}),
      agent_score: Keyword.get(opts, :agent_score, 1.0)
    }
  end

  ## Caching

  defp get_cached_result(cache_key) do
    case Cachex.get(:rule_engine_cache, cache_key) do
      {:ok, nil} -> :miss
      {:ok, result} -> {:ok, result}
      {:error, _} -> :miss
    end
  end

  defp cache_result(cache_key, result) do
    # Cache for 1 hour
    Cachex.put(:rule_engine_cache, cache_key, result, ttl: :timer.hours(1))
  end

  defp generate_cache_key(rule, context) do
    fingerprint = :singularity@rule_engine.context_fingerprint(elixir_context_to_gleam(context))
    :singularity@rule_engine.cache_key(rule.id, fingerprint)
  end

  ## Event Broadcasting

  defp broadcast_rule_executed(result) do
    Phoenix.PubSub.broadcast(
      Singularity.PubSub,
      "rules:executed",
      {:rule_executed, result}
    )

    # Also broadcast metrics
    :telemetry.execute(
      [:singularity, :rule_engine, :rule, :executed],
      %{
        duration: result.execution_time_ms,
        confidence: result.confidence
      },
      %{rule_id: result.rule_id}
    )
  end

  ## Type Conversions

  defp elixir_rule_to_gleam(rule) do
    %{
      id: rule.id,
      name: rule.name,
      description: rule.description,
      category: category_to_gleam(rule.category),
      patterns: Enum.map(rule.patterns, &pattern_to_gleam/1),
      confidence_threshold: rule.confidence_threshold
    }
  end

  defp elixir_context_to_gleam(context) do
    %{
      feature_id: option_to_gleam(context[:feature_id]),
      epic_id: option_to_gleam(context[:epic_id]),
      code_snippet: option_to_gleam(context[:code_snippet]),
      metrics: context[:metrics] || %{},
      agent_score: context[:agent_score] || 1.0
    }
  end

  defp gleam_result_to_elixir(result) do
    %{
      rule_id: result.rule_id,
      confidence: result.confidence,
      decision: decision_to_elixir(result.decision),
      reasoning: result.reasoning,
      execution_time_ms: result.execution_time_ms,
      cached: result.cached
    }
  end

  defp category_to_gleam(category) do
    case category do
      :code_quality -> {:CodeQuality}
      :performance -> {:Performance}
      :security -> {:Security}
      :refactoring -> {:Refactoring}
      :vision -> {:Vision}
      :epic -> {:Epic}
      :feature -> {:Feature}
      _ -> {:CodeQuality}
    end
  end

  defp pattern_to_gleam(pattern) do
    case pattern do
      {:regex, expression, opts} ->
        {:RegexPattern, expression, Keyword.get(opts, :weight, 1.0)}

      {:llm, prompt, opts} ->
        {:LLMPattern, prompt, Keyword.get(opts, :weight, 1.0)}

      {:metric, metric, _op, threshold, opts} ->
        {:MetricPattern, metric, threshold, Keyword.get(opts, :weight, 1.0)}
    end
  end

  defp decision_to_elixir(decision) do
    case decision do
      {:Autonomous, action} -> {:autonomous, action}
      {:Collaborative, options} -> {:collaborative, options}
      {:Escalated, reason} -> {:escalated, reason}
    end
  end

  defp option_to_gleam(nil), do: :none
  defp option_to_gleam(value), do: {:some, value}

  ## Result Classification

  defp classify_result(result) do
    case result.decision do
      {:autonomous, action} ->
        {:autonomous, result}

      {:collaborative, _options} ->
        {:collaborative, result}

      {:escalated, _reason} ->
        {:escalated, result}
    end
  end

  ## High-Level Helpers

  @doc "Check if epic should be approved based on WSJF"
  def validate_epic_wsjf(epic) do
    rule =
      create_rule(
        id: "epic-wsjf-validation",
        name: "Epic WSJF Validation",
        category: :epic,
        patterns: [
          {:metric, "wsjf_score", ">", 5.0, weight: 0.9},
          {:metric, "business_value", ">", 6, weight: 0.7},
          {:metric, "job_size", "<", 15, weight: 0.5}
        ]
      )

    context =
      create_context(
        epic_id: epic.id,
        metrics: %{
          "wsjf_score" => epic.wsjf_score,
          "business_value" => epic.business_value,
          "job_size" => epic.job_size
        }
      )

    execute(rule, context)
  end

  @doc "Check if feature is ready to implement"
  def validate_feature_readiness(feature) do
    rule =
      create_rule(
        id: "feature-readiness",
        name: "Feature Implementation Readiness",
        category: :feature,
        patterns: [
          {:metric, "acceptance_criteria_count", ">", 2, weight: 0.8},
          {:metric, "dependencies_met", "==", 1.0, weight: 0.9}
        ]
      )

    context =
      create_context(
        feature_id: feature.id,
        metrics: %{
          "acceptance_criteria_count" => length(feature.acceptance_criteria || []),
          "dependencies_met" => if(dependencies_met?(feature), do: 1.0, else: 0.0)
        }
      )

    execute(rule, context)
  end

  defp dependencies_met?(_feature) do
    # TODO: Check if all dependency features are completed
    true
  end
end
