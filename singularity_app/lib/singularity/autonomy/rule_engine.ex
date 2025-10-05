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
  - Planning.WorkPlanCoordinator for epic/feature decisions
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
    context = normalize_context(context)

    # Check cache first
    cache_key = generate_cache_key(rule, context)

    case get_cached_result(cache_key) do
      {:ok, cached_result} ->
        Logger.debug("MoonShine cache hit", rule_id: rule.id, cache_key: cache_key)
        {:ok, Map.put(cached_result, :cached, true)}

      :miss ->
        result = run_rule(rule, context)

        # Cache if high confidence
        if should_cache?(result) do
          cache_result(cache_key, result)
        end

        # Broadcast event
        broadcast_rule_executed(result)

        classify_result(result)
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
    fingerprint = context_fingerprint(context)
    cache_key(rule.id, fingerprint)
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

  ## Rule execution (Elixir implementation)

  defp run_rule(rule, context) do
    start_time = System.monotonic_time(:millisecond)
    patterns = rule.patterns || []
    confidence = calculate_confidence(patterns, context)
    decision = classify_decision(confidence, rule)
    reasoning = generate_reasoning(confidence, rule)
    execution_time = System.monotonic_time(:millisecond) - start_time

    %{
      rule_id: rule.id,
      confidence: confidence,
      decision: decision,
      reasoning: reasoning,
      execution_time_ms: execution_time,
      cached: false
    }
  end

  defp should_cache?(result), do: result.confidence >= 0.9

  defp calculate_confidence([], _context), do: 0.5

  defp calculate_confidence(patterns, context) do
    scores = Enum.map(patterns, &pattern_score(&1, context))
    total = Enum.reduce(scores, 0.0, &+/2)
    count = length(scores)

    if count == 0 do
      0.5
    else
      total / count
    end
  end

  defp pattern_score({:regex, _expression, opts}, _context) do
    weight = Keyword.get(opts, :weight, 1.0)
    weight * 0.8
  end

  defp pattern_score({:llm, _prompt, opts}, _context) do
    weight = Keyword.get(opts, :weight, 1.0)
    weight * 0.85
  end

  defp pattern_score({:metric, metric, op, threshold, opts}, context) do
    weight = Keyword.get(opts, :weight, 1.0)
    metrics = context.metrics
    value = fetch_metric(metrics, metric)

    cond do
      is_number(value) and passes_threshold?(value, op, threshold) ->
        weight

      is_number(value) and threshold not in [0, 0.0] ->
        ratio = value / threshold
        weight * ratio

      is_number(value) ->
        weight * 0.5

      true ->
        weight * 0.5
    end
  end

  defp pattern_score(_other, _context), do: 0.5

  defp passes_threshold?(value, op, threshold) do
    case op do
      :>= -> value >= threshold
      :> -> value > threshold
      :<= -> value <= threshold
      :< -> value < threshold
      :== -> value == threshold
      "<" -> value < threshold
      "<=" -> value <= threshold
      ">" -> value > threshold
      ">=" -> value >= threshold
      "==" -> value == threshold
      _ -> value >= threshold
    end
  end

  defp classify_decision(confidence, rule) when confidence >= 0.9 do
    {:autonomous, "Execute automatically: #{rule.name}"}
  end

  defp classify_decision(confidence, rule) when confidence >= 0.7 do
    {:collaborative,
     [
       "Approve: #{rule.name}",
       "Reject: #{rule.name}",
       "Modify parameters"
     ]}
  end

  defp classify_decision(confidence, rule) do
    {:escalated, "Low confidence (#{format_percent(confidence)}) - Human decision required"}
  end

  defp generate_reasoning(confidence, rule) when confidence >= 0.9 do
    "High confidence (#{format_percent(confidence)}) - #{rule.description} - Executing autonomously"
  end

  defp generate_reasoning(confidence, rule) when confidence >= 0.7 do
    "Moderate confidence (#{format_percent(confidence)}) - #{rule.description} - Requesting collaboration"
  end

  defp generate_reasoning(confidence, rule) do
    "Low confidence (#{format_percent(confidence)}) - #{rule.description} - Escalating to human"
  end

  defp context_fingerprint(context) do
    feature = context[:feature_id] || context[:feature] || "none"
    epic = context[:epic_id] || context[:epic] || "none"
    score = context[:agent_score] || 1.0

    Enum.join([feature, epic, to_string(score)], "|")
  end

  defp cache_key(rule_id, fingerprint), do: "moonshine:#{rule_id}:#{fingerprint}"

  defp normalize_context(context) do
    context
    |> Map.new()
    |> Map.update(:metrics, %{}, &normalize_metrics/1)
    |> Map.put_new(:agent_score, 1.0)
  end

  defp normalize_metrics(nil), do: %{}
  defp normalize_metrics(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      key_str =
        cond do
          is_binary(key) -> key
          is_atom(key) -> Atom.to_string(key)
          true -> to_string(key)
        end

      Map.put(acc, key_str, value)
    end)
  end
  defp normalize_metrics(_), do: %{}

  defp fetch_metric(metrics, metric) do
    metrics
    |> Map.get(normalize_metric_key(metric))
  end

  defp normalize_metric_key(metric) when is_binary(metric), do: metric
  defp normalize_metric_key(metric) when is_atom(metric), do: Atom.to_string(metric)
  defp normalize_metric_key(metric), do: to_string(metric)

  defp format_percent(confidence) do
    confidence
    |> Kernel.*(100.0)
    |> Float.round()
    |> trunc()
    |> Integer.to_string()
    |> Kernel.<>("%")
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
