defmodule Singularity.Execution.Autonomy.RuleEngineCore do
  @moduledoc """
  Pure Elixir Rule Engine - confidence-based autonomous decision making.

  Migrated from Gleam singularity/rule_engine.gleam

  Confidence thresholds:
  - 90%+ confidence: Autonomous execution
  - 70-89% confidence: Collaborative (ask human)
  - <70% confidence: Escalate to human

  ## Execution Types

  **Elixir Patterns** (default):
  - Pattern-based rules with regex, LLM, metric patterns
  - Fast, deterministic execution

  **Lua Scripts** (hot-reload):
  - Dynamic business logic stored in database
  - Update rules without recompiling Elixir
  - Access to context, files, git, LLM calls

  ## Usage

      # Elixir patterns
      rule = %{
        id: "quality-check",
        name: "Code Quality Check",
        description: "Validate code quality metrics",
        category: :code_quality,
        execution_type: :elixir_patterns,
        patterns: [
          %{type: :metric, metric: "complexity", threshold: 10.0, weight: 0.9}
        ],
        confidence_threshold: 0.8
      }

      # Lua script
      rule = %{
        id: "epic-validation",
        name: "Epic WSJF Validation",
        description: "Validate epic using dynamic Lua logic",
        category: :epic,
        execution_type: :lua_script,
        lua_script: "function validate_epic(context) ... end",
        confidence_threshold: 0.8
      }

      context = %{
        feature_id: "feat-123",
        metrics: %{"complexity" => 8.0},
        agent_score: 0.95
      }

      RuleEngineCore.execute_rule(rule, context)
      # => %{confidence: 0.9, decision: {:autonomous, "Execute automatically: Code Quality Check"}, ...}
  """

  require Logger

  @autonomous_threshold 0.9
  @collaborative_threshold 0.7

  @doc """
  Execute a rule and return confidence-based decision.

  Returns a result map with:
  - `:rule_id` - Rule identifier
  - `:confidence` - Confidence score (0.0-1.0)
  - `:decision` - One of:
    - `{:autonomous, action}` - Execute automatically
    - `{:collaborative, options}` - Ask human to choose
    - `{:escalated, reason}` - Escalate to human
  - `:reasoning` - Human-readable explanation
  - `:execution_time_ms` - Execution time
  - `:cached` - Whether result was cached
  """
  def execute_rule(rule, context) do
    start_time = System.monotonic_time(:millisecond)

    # Route based on execution type
    result =
      case Map.get(rule, :execution_type, :elixir_patterns) do
        :lua_script ->
          execute_lua_rule(rule, context)

        _ ->
          execute_pattern_rule(rule, context)
      end

    execution_time = System.monotonic_time(:millisecond) - start_time

    Map.put(result, :execution_time_ms, execution_time)
  end

  # Execute Lua-based rule
  defp execute_lua_rule(rule, context) do
    case Singularity.LuaRunner.execute_rule(rule.lua_script, context) do
      {:ok, lua_result} ->
        # Lua script must return: {decision, confidence, reasoning}
        # decision = "autonomous" | "collaborative" | "escalated"
        decision = parse_lua_decision(lua_result["decision"])
        confidence = lua_result["confidence"] || 0.5
        reasoning = lua_result["reasoning"] || "Lua rule executed"

        %{
          rule_id: rule.id,
          confidence: confidence,
          decision: decision,
          reasoning: reasoning,
          cached: false
        }

      {:error, reason} ->
        Logger.error("Lua rule execution failed",
          rule_id: rule.id,
          error: inspect(reason)
        )

        %{
          rule_id: rule.id,
          confidence: 0.0,
          decision: {:escalated, "Lua execution error: #{inspect(reason)}"},
          reasoning: "Lua script failed to execute",
          cached: false
        }
    end
  end

  # Execute pattern-based rule (original logic)
  defp execute_pattern_rule(rule, context) do
    # Calculate confidence from patterns
    confidence = calculate_confidence(rule.patterns || [], context)

    # Determine decision based on confidence
    decision = classify_decision(confidence, rule)

    %{
      rule_id: rule.id,
      confidence: confidence,
      decision: decision,
      reasoning: generate_reasoning(confidence, rule),
      cached: false
    }
  end

  # Parse Lua decision string to Elixir tuple
  defp parse_lua_decision("autonomous"), do: {:autonomous, "Execute automatically"}
  defp parse_lua_decision("collaborative"), do: {:collaborative, ["Approve", "Reject"]}
  defp parse_lua_decision("escalated"), do: {:escalated, "Human decision required"}
  defp parse_lua_decision(other), do: {:escalated, "Unknown decision: #{other}"}

  @doc """
  Check if result should be cached.
  """
  def should_cache(result) do
    result.confidence >= @autonomous_threshold
  end

  @doc """
  Create cache key from rule and context.
  """
  def cache_key(rule_id, context_fingerprint) do
    "moonshine:#{rule_id}:#{context_fingerprint}"
  end

  @doc """
  Calculate fingerprint for context.
  """
  def context_fingerprint(context) do
    feature = context[:feature_id] || "none"
    epic = context[:epic_id] || "none"
    # Ensure a string regardless of whether agent_score is present
    score = (context[:agent_score] || 1.0) |> to_string()

    Enum.join([feature, epic, score], "|")
  end

  @doc """
  Check if decision requires human approval.
  """
  def requires_human(result) do
    case result.decision do
      {:autonomous, _} -> false
      {:collaborative, _} -> true
      {:escalated, _} -> true
    end
  end

  @doc """
  Get decision urgency level.
  """
  def urgency_level(result) do
    case result.decision do
      {:autonomous, _} -> "low"
      {:collaborative, _} -> "medium"
      {:escalated, _} -> "high"
    end
  end

  ## Private Functions

  # Calculate confidence score from all patterns
  defp calculate_confidence([], _context), do: 0.5

  defp calculate_confidence(patterns, context) do
    scores = Enum.map(patterns, &pattern_score(&1, context))
    total = Enum.sum(scores)
    count = length(scores)

    if count > 0, do: total / count, else: 0.5
  end

  # Score individual pattern
  defp pattern_score(%{type: :regex, weight: weight}, _context) do
    # Regex patterns are deterministic
    weight * 0.8
  end

  defp pattern_score(%{type: :llm, weight: weight}, _context) do
    # LLM patterns have high confidence
    weight * 0.85
  end

  defp pattern_score(
         %{type: :metric, metric: metric, threshold: threshold, weight: weight},
         context
       ) do
    metrics = context[:metrics] || %{}

    case Map.get(metrics, metric) do
      nil -> weight * 0.5
      value when value >= threshold -> weight
      value -> weight * (value / threshold)
    end
  end

  defp pattern_score(_pattern, _context), do: 0.5

  # Classify decision based on confidence
  defp classify_decision(confidence, rule) when confidence >= @autonomous_threshold do
    {:autonomous, "Execute automatically: #{rule.name}"}
  end

  defp classify_decision(confidence, rule) when confidence >= @collaborative_threshold do
    {:collaborative,
     [
       "Approve: #{rule.name}",
       "Reject: #{rule.name}",
       "Modify parameters"
     ]}
  end

  defp classify_decision(confidence, _rule) do
    {:escalated, "Low confidence (#{format_confidence(confidence)}) - Human decision required"}
  end

  # Generate reasoning for the decision
  defp generate_reasoning(confidence, rule) when confidence >= @autonomous_threshold do
    "High confidence (#{format_confidence(confidence)}) - #{rule.description} - Executing autonomously"
  end

  defp generate_reasoning(confidence, rule) when confidence >= @collaborative_threshold do
    "Moderate confidence (#{format_confidence(confidence)}) - #{rule.description} - Requesting collaboration"
  end

  defp generate_reasoning(confidence, rule) do
    "Low confidence (#{format_confidence(confidence)}) - #{rule.description} - Escalating to human"
  end

  defp format_confidence(confidence) do
    "#{Float.round(confidence * 100, 0)}%"
  end
end
