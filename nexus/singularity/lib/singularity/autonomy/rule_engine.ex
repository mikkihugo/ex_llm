defmodule Singularity.Autonomy.RuleEngine do
  @moduledoc """
  Rule Engine for autonomous decision making backed by the evolution pipeline.

  Delegates category evaluations to the `RuleEvolutionSystem`, transforming
  synthesized rules into confidence-based decisions usable by agents.
  """

  require Logger

  alias Singularity.Evolution.RuleEvolutionSystem

  @autonomous_threshold 0.9
  @collaborative_threshold 0.7
  @default_rule_limit 20

  @doc """
  Execute rules for a specific category using evolved rule intelligence.

  Returns `{:autonomous | :collaborative | :escalated, result}` tuples that
  mirror the legacy API while sourcing the underlying data from the learning
  system.
  """
  @spec execute_category(atom(), map()) ::
          {:autonomous | :collaborative | :escalated, map()} | {:error, term()}
  def execute_category(category, context) when is_atom(category) do
    Logger.debug("Autonomy.RuleEngine executing category",
      category: category,
      context_keys: extract_context_keys(context)
    )

    with {:ok, rules} <- fetch_evolved_rules(category, context),
         {:ok, rule} <- select_best_rule(category, rules, context) do
      payload = build_decision_payload(category, rule, context)

      Logger.debug("Autonomy.RuleEngine selected evolved rule",
        category: category,
        confidence: payload.confidence,
        recommended_checks: payload.recommended_checks
      )

      classify_decision(payload.confidence, payload)
    else
      {:error, :no_rules} ->
        Logger.info("No evolved rules available for category", category: category)

        {:escalated,
         %{
           confidence: 0.3,
           reasoning: "No evolved rules available for #{inspect(category)}",
           status: :no_rules
         }}

      {:error, reason} ->
        Logger.error("Autonomy.RuleEngine encountered an error",
          category: category,
          error: inspect(reason)
        )

        {:error, reason}
    end
  end

  def execute_category(category, _context) do
    {:error, {:invalid_category, category}}
  end

  @doc """
  Enumerate available rule categories.
  """
  def get_categories do
    [
      :cost_optimization,
      :quality_enhancement,
      :performance_monitoring,
      :resource_allocation,
      :task_prioritization,
      :error_handling,
      :learning_adaptation,
      :code_quality,
      :refactoring,
      :vision
    ]
  end

  @doc """
  Validate the supplied context for a category.
  """
  def validate_context(category, context) when is_map(context) do
    required_fields = get_required_fields(category)

    missing_fields =
      required_fields
      |> Enum.reject(&Map.has_key?(context, &1))

    if missing_fields == [] do
      {:ok, context}
    else
      {:error, {:missing_fields, missing_fields}}
    end
  end

  def validate_context(_category, context), do: {:error, {:invalid_context, context}}

  @doc """
  Return evolved rules for a category (best-effort).
  """
  def get_rules_for_category(category) do
    case fetch_evolved_rules(category, %{}) do
      {:ok, rules} -> rules
      {:error, _reason} -> []
    end
  end

  # -- Evolution bridge -----------------------------------------------------

  defp fetch_evolved_rules(category, context) do
    criteria = build_evolution_criteria(category, context)

    opts = [
      limit: @default_rule_limit,
      min_confidence: 0.0
    ]

    try do
      case RuleEvolutionSystem.analyze_and_propose_rules(criteria, opts) do
        {:ok, []} ->
          {:error, :no_rules}

        {:ok, rules} ->
          {:ok, rules}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, error}
    end
  end

  defp select_best_rule(_category, rules, context) do
    rules
    |> Enum.reject(&rule_mismatch?(&1, context))
    |> Enum.sort_by(&Map.get(&1, :confidence, 0.0), :desc)
    |> List.first()
    |> case do
      nil -> {:error, :no_rules}
      rule -> {:ok, rule}
    end
  end

  defp rule_mismatch?(rule, context) do
    required_complexity = Map.get(rule.pattern, :complexity)
    provided_complexity = value_from_context(context, :complexity)

    cond do
      is_nil(required_complexity) -> false
      is_nil(provided_complexity) -> false
      true -> to_string(required_complexity) != to_string(provided_complexity)
    end
  end

  defp build_decision_payload(category, rule, context) do
    recommended_checks = Map.get(rule.action, :checks, [])

    %{
      confidence: Map.get(rule, :confidence, 0.0),
      reasoning: build_rule_reasoning(rule, category, context, recommended_checks),
      recommended_checks: recommended_checks,
      status: rule.status,
      frequency: rule.frequency,
      success_rate: rule.success_rate,
      rule: rule
    }
  end

  defp build_rule_reasoning(rule, category, context, checks) do
    [
      "Evolved rule matched #{inspect(category)} with confidence #{Float.round(rule.confidence * 100, 1)}%",
      pattern_summary(rule.pattern),
      if(Enum.empty?(checks), do: nil, else: "Recommended checks: #{Enum.join(checks, ", ")}"),
      success_summary(rule),
      context_summary(context)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" | ")
  end

  defp pattern_summary(pattern) when is_map(pattern) do
    pattern
    |> Enum.map(fn {key, value} -> "#{key}=#{inspect(value)}" end)
    |> Enum.join(", ")
    |> case do
      "" -> nil
      summary -> "Pattern: #{summary}"
    end
  end

  defp pattern_summary(_), do: nil

  defp success_summary(%{frequency: freq, success_rate: rate})
       when is_integer(freq) and freq > 0 and is_number(rate) do
    "Support: frequency=#{freq}, success_rate=#{Float.round(rate * 100, 1)}%"
  end

  defp success_summary(_), do: nil

  defp context_summary(context) when is_map(context) do
    type = value_from_context(context, :type)
    complexity = value_from_context(context, :complexity)

    details =
      [
        if(type, do: "task_type=#{inspect(type)}"),
        if(complexity, do: "complexity=#{inspect(complexity)}")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    if details == "" do
      nil
    else
      "Context: #{details}"
    end
  end

  defp context_summary(_), do: nil

  defp build_evolution_criteria(category, context) do
    %{}
    |> maybe_put(:task_type, derive_task_type(category, context))
    |> maybe_put(:complexity, value_from_context(context, :complexity))
    |> maybe_put(:time_range, :last_week)
  end

  defp derive_task_type(category, context) do
    case value_from_context(context, :type) do
      nil -> default_task_type(category)
      type -> type
    end
  end

  defp default_task_type(:cost_optimization), do: :cost_optimization
  defp default_task_type(:quality_enhancement), do: :quality_enhancement
  defp default_task_type(:performance_monitoring), do: :performance
  defp default_task_type(:resource_allocation), do: :resource
  defp default_task_type(:task_prioritization), do: :planner
  defp default_task_type(:error_handling), do: :recovery
  defp default_task_type(:learning_adaptation), do: :learning
  defp default_task_type(:code_quality), do: :coder
  defp default_task_type(:refactoring), do: :refactor
  defp default_task_type(:vision), do: :architect
  defp default_task_type(_), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp value_from_context(%{} = context, key) do
    Map.get(context, key) ||
      Map.get(context, to_string(key)) ||
      case context do
        %{^key => value} -> value
        _ -> nil
      end
  end

  defp value_from_context(_context, _key), do: nil

  defp extract_context_keys(context) when is_map(context), do: Map.keys(context)
  defp extract_context_keys(_), do: []

  # -- Decision helpers -----------------------------------------------------

  defp classify_decision(confidence, result) when confidence >= @autonomous_threshold do
    {:autonomous, result}
  end

  defp classify_decision(confidence, result) when confidence >= @collaborative_threshold do
    {:collaborative, result}
  end

  defp classify_decision(confidence, result) do
    {:escalated,
     Map.update(
       result,
       :reasoning,
       "Low confidence (#{format_confidence(confidence)})",
       fn reasoning ->
         "#{reasoning} | Low confidence (#{format_confidence(confidence)})"
       end
     )}
  end

  defp get_required_fields(category) do
    case category do
      :cost_optimization -> [:budget, :task_complexity]
      :quality_enhancement -> [:quality_threshold, :output_type]
      :performance_monitoring -> [:metrics, :thresholds]
      :resource_allocation -> [:available_resources, :requirements]
      :task_prioritization -> [:deadline, :priority_level]
      :error_handling -> [:error_type, :context]
      :learning_adaptation -> [:performance_data, :learning_goals]
      :code_quality -> [:type]
      :refactoring -> [:type]
      :vision -> [:type]
      _ -> []
    end
  end

  defp format_confidence(confidence) do
    "#{Float.round(confidence * 100, 1)}%"
  end
end
