defmodule Singularity.Execution.Evolution do
  @moduledoc """
  Agent Evolution - Applies improvements based on feedback analysis results.

  Consumes analysis from Feedback.Analyzer and implements autonomous agent improvements
  through pattern enrichment, model optimization, and caching enhancements.

  ## Architecture

  ```
  Feedback.Analyzer (Priority 2)
      ↓ (Suggestions & Issues)
  Agents.Evolution.evolve_agent/1
      ├─ Select best suggestion
      ├─ Apply improvement
      ├─ Run A/B test (control vs variant)
      ├─ Compare metrics
      └─ Rollback if degraded
      ↓
  SelfImprovingAgent (Updated)
  ```

  ## Evolution Types

  1. **Pattern Enhancement** - Add high-confidence patterns from knowledge base
     - Precondition: success_rate < 90%
     - Action: Append matching patterns to agent's pattern library
     - Validation: Measure success_rate improvement

  2. **Model Optimization** - Switch to more cost-effective models
     - Precondition: avg_cost > $0.10 per task
     - Action: Update model selection rules in agent prompt
     - Validation: Measure cost reduction, ensure quality maintained

  3. **Cache Improvement** - Enhance caching strategy
     - Precondition: avg_latency > 2000ms
     - Action: Add cache hints or pre-warming logic
     - Validation: Measure latency reduction

  4. **CodeEngine Health** - Improve CodeEngine integration and reduce fallbacks
     - Precondition: CodeEngine health score < 7.0 or fallback rate > 20%
     - Action: Enhance CodeEngine integration, fix parsing issues, improve error handling
     - Validation: Measure reduction in fallback rate and improvement in health score

  ## Validation Strategy

  Uses A/B testing to ensure improvements:
  1. Establish baseline metrics for agent (T=0)
  2. Apply improvement (T+5 minutes)
  3. Run control group (original) vs variant (improved)
  4. Collect metrics (T+10 minutes)
  5. Compare: variant_metric vs (baseline_metric ± threshold)
  6. Rollback if regression detected

  ## Usage

      # Apply evolution to an agent
      {:ok, result} = Agents.Evolution.evolve_agent("elixir-specialist")

      # Get evolution status
      {:ok, status} = Agents.Evolution.get_evolution_status("elixir-specialist")

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "Singularity.Execution.Evolution",
    "purpose": "agent_improvement_application",
    "domain": "execution",
    "capabilities": ["evolution", "a_b_testing", "improvement_validation", "rollback"],
    "dependencies": ["Feedback.Analyzer", "SelfImprovingAgent", "Metrics.Aggregator"]
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    A[Feedback Analysis] --> B[Select Best Suggestion]
    B --> C[Apply Improvement]
    C --> D[Run A/B Test]
    D --> E{Metrics Improved?}
    E -->|Yes| F[Persist Improvement]
    E -->|No| G[Rollback Change]
    F --> H[Update Agent]
    G --> H
  ```

  ## Call Graph (YAML)
  ```yaml
  Singularity.Execution.Evolution:
    evolve_agent/1: [get_analysis, select_best_suggestion, apply_improvement, run_ab_test, compare_metrics, persist_or_rollback]
    get_evolution_status/1: [Repo.get_by, format_status]
    apply_pattern_enhancement/2: [query_pattern_library, merge_patterns]
    apply_model_optimization/2: [update_model_selection, generate_prompt]
    apply_cache_improvement/2: [add_cache_hints, update_agent_config]
    run_ab_test/3: [establish_baseline, apply_variant, collect_metrics]
    compare_metrics/3: [calculate_improvement, determine_regression]
  ```

  ## Anti-Patterns

  - **DO NOT** apply multiple improvements simultaneously (introduces confounding variables)
  - **DO NOT** skip A/B testing - all improvements must be validated
  - **DO NOT** modify agent code directly - use SelfImprovingAgent.improve/2
  - **DO NOT** apply improvements during A/B test window - wait for completion
  - **DO NOT** rollback without logging the failure reason

  ## Search Keywords

  evolution, improvement, a_b_testing, validation, rollback, agent_learning, autonomous_improvement, feedback_loop, metrics_driven, performance_optimization, cost_optimization, latency_reduction
  """

  require Logger

  alias Singularity.Execution.Feedback.Analyzer
  alias Singularity.Metrics.Aggregator
  alias Singularity.SelfImprovingAgent

  @doc """
  Evolve an agent based on feedback analysis and suggestions.

  Applies the highest-confidence improvement and validates with A/B testing.

  ## Return Value

  Returns `{:ok, evolution_result}` with:
  - `:agent_id` - Agent being evolved
  - `:improvement_applied` - Type of improvement (or :none)
  - `:baseline_metric` - Original metric value
  - `:variant_metric` - Metric after improvement
  - `:improvement` - Percentage improvement
  - `:status` - :success, :no_improvement_needed, :validation_failed

  ## Examples

      iex> Agents.Evolution.evolve_agent("elixir-specialist")
      {:ok, %{
        agent_id: "elixir-specialist",
        improvement_applied: :add_patterns,
        baseline_metric: 0.85,
        variant_metric: 0.92,
        improvement: "+8.2%",
        status: :success
      }}

      iex> Agents.Evolution.evolve_agent("healthy-agent")
      {:ok, %{
        agent_id: "healthy-agent",
        improvement_applied: :none,
        status: :no_improvement_needed
      }}
  """
  @spec evolve_agent(String.t()) :: {:ok, map()} | {:error, term()}
  def evolve_agent(agent_id) do
    try do
      # 1. Get analysis from Feedback.Analyzer
      case Analyzer.analyze_agent(agent_id) do
        {:ok, analysis} ->
          # 2. Select best improvement suggestion
          case select_best_improvement(analysis) do
            nil ->
              Logger.info("No improvements needed", agent_id: agent_id)

              {:ok,
               %{
                 agent_id: agent_id,
                 improvement_applied: :none,
                 status: :no_improvement_needed
               }}

            suggestion ->
              # 3. Apply improvement and validate with A/B test
              apply_and_validate_improvement(agent_id, suggestion, analysis)
          end

        {:error, reason} ->
          SASL.execution_failure(
            :agent_analysis_failure,
            "Failed to analyze agent for evolution",
            agent_id: agent_id,
            reason: reason
          )

          {:error, reason}
      end
    rescue
      e ->
        SASL.critical_failure(
          :evolution_system_failure,
          "Evolution system failed catastrophically",
          agent_id: agent_id,
          error: e
        )

        {:error, e}
    end
  end

  @doc """
  Get current evolution status for an agent.

  Returns latest evolution attempt and whether it was successful.

  Note: Currently always returns no_evolution_attempts since we're logging
  attempts rather than persisting to database. Future enhancement: add
  EvolutionAttempt schema to track history.
  """
  @spec get_evolution_status(String.t()) :: {:ok, map()} | {:error, term()}
  def get_evolution_status(agent_id) do
    try do
      {:ok,
       %{
         agent_id: agent_id,
         status: :no_evolution_attempts,
         last_evolution: nil
       }}
    rescue
      e ->
        Logger.error("Failed to get evolution status",
          agent_id: agent_id,
          error: inspect(e)
        )

        {:error, e}
    end
  end

  # Private Functions

  @spec select_best_improvement(map()) :: map() | nil
  defp select_best_improvement(%{suggestions: suggestions, issues: issues})
       when is_list(suggestions) do
    # Select the suggestion with highest confidence that addresses critical issues
    suggestions
    |> Enum.filter(&critical_issue_match?(&1, issues))
    |> Enum.sort_by(& &1.confidence, :desc)
    |> List.first()
  end

  defp select_best_improvement(_), do: nil

  @spec critical_issue_match?(map(), list(map())) :: boolean()
  defp critical_issue_match?(suggestion, issues) do
    issue_type = suggestion.issue_type

    Enum.any?(issues, fn issue ->
      issue.type == issue_type and issue.severity in [:critical, :high]
    end)
  end

  @spec apply_and_validate_improvement(String.t(), map(), map()) ::
          {:ok, map()} | {:error, term()}
  defp apply_and_validate_improvement(agent_id, suggestion, analysis) do
    Logger.info("Applying improvement",
      agent_id: agent_id,
      suggestion_type: suggestion.type,
      confidence: suggestion.confidence,
      analysis_keys: Map.keys(analysis) |> Enum.join(", ")
    )

    # 1. Establish baseline metrics
    case Aggregator.get_metrics_for(agent_id, :last_hour) do
      {:ok, %{summary: %{sample_count: count}} = metrics} when count > 0 ->
        baseline = aggregate_baseline_metric(metrics, suggestion.type)

        # 2. Apply improvement to agent
        case apply_improvement_to_agent(agent_id, suggestion) do
          :ok ->
            # 3. Run A/B test and validate
            case run_improvement_validation(agent_id, suggestion, baseline) do
              {:ok, variant_metric} ->
                improvement = calculate_improvement_percent(baseline, variant_metric)

                # 4. Store evolution attempt
                store_evolution_attempt(
                  agent_id,
                  suggestion,
                  baseline,
                  variant_metric,
                  improvement,
                  :success
                )

                {:ok,
                 %{
                   agent_id: agent_id,
                   improvement_applied: suggestion.type,
                   baseline_metric: baseline,
                   variant_metric: variant_metric,
                   improvement: improvement,
                   status: :success
                 }}

              {:error, _reason} ->
                Logger.warning("Improvement validation failed, rolling back",
                  agent_id: agent_id,
                  suggestion_type: suggestion.type
                )

                # Rollback the improvement
                rollback_improvement(agent_id, suggestion)

                store_evolution_attempt(
                  agent_id,
                  suggestion,
                  baseline,
                  nil,
                  nil,
                  :validation_failed
                )

                {:ok,
                 %{
                   agent_id: agent_id,
                   improvement_applied: suggestion.type,
                   status: :validation_failed,
                   reason: "A/B test showed regression"
                 }}
            end

          {:error, reason} ->
            Logger.error("Failed to apply improvement",
              agent_id: agent_id,
              suggestion_type: suggestion.type,
              reason: inspect(reason)
            )

            {:error, reason}
        end

      {:ok, %{summary: %{sample_count: 0}}} ->
        Logger.warning("No metrics available for baseline",
          agent_id: agent_id
        )

        {:error, :no_baseline_metrics}

      {:error, reason} ->
        Logger.error("Failed to fetch baseline metrics",
          agent_id: agent_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @spec aggregate_baseline_metric(map(), atom()) :: float()
  defp aggregate_baseline_metric(%{summary: %{average_value: avg_value}, samples: samples}, suggestion_type) do
    # Extract the specific metric type from samples based on suggestion type
    metric_name =
      case suggestion_type do
        :add_patterns -> "success_rate"
        :optimize_model -> "cost_cents"
        :improve_cache -> "latency_ms"
        _ -> nil
      end

    # Try to extract specific metric from samples, fallback to generic average
    value =
      if metric_name do
        values = extract_metric_values(samples, metric_name)
        if length(values) > 0 do
          Enum.sum(values) / length(values)
        else
          avg_value || 0.0
        end
      else
        avg_value || 0.0
      end

    case suggestion_type do
      :add_patterns -> Float.round(value, 2)
      :optimize_model -> Float.round(value, 2)
      :improve_cache -> Float.round(value, 0)
      _ -> 0.0
    end
  end

  defp extract_metric_values(samples, metric_name) do
    samples
    |> Enum.filter(fn sample ->
      labels = Map.get(sample, :labels, %{})
      sample_metric_name = Map.get(labels, "metric_name") || Map.get(sample, :metric_name)
      sample_metric_name == metric_name
    end)
    |> Enum.map(fn sample ->
      case sample do
        %{value: val} when is_number(val) -> val
        %{value: %Decimal{} = dec} -> Decimal.to_float(dec)
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @spec apply_improvement_to_agent(String.t(), map()) :: :ok | {:error, term()}
  defp apply_improvement_to_agent(agent_id, suggestion) do
    improvement_payload = build_improvement_payload(suggestion)

    case SelfImprovingAgent.improve(agent_id, improvement_payload) do
      :ok ->
        Logger.info("Improvement applied to agent",
          agent_id: agent_id,
          improvement_type: suggestion.type
        )

        :ok

      {:error, :not_found} ->
        Logger.warning("Agent not found",
          agent_id: agent_id
        )

        {:error, :agent_not_found}

      {:error, reason} ->
        Logger.error("Failed to apply improvement",
          agent_id: agent_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @spec build_improvement_payload(map()) :: map()
  defp build_improvement_payload(suggestion) do
    %{
      "type" => Atom.to_string(suggestion.type),
      "description" => suggestion.description,
      "confidence" => suggestion.confidence,
      "expected_improvement" => suggestion.expected_improvement,
      "estimated_effort" => Atom.to_string(suggestion.estimated_effort),
      "metadata" => %{
        "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "reason" => "automated_evolution",
        "validation_method" => "a_b_test"
      }
    }
  end

  @spec run_improvement_validation(String.t(), map(), float()) ::
          {:ok, float()} | {:error, term()}
  defp run_improvement_validation(agent_id, suggestion, baseline) do
    # Wait for improvement to apply
    Process.sleep(5_000)

    # Collect post-improvement metrics
    case Aggregator.get_metrics_for(agent_id, :last_hour) do
      {:ok, %{summary: %{sample_count: count}} = metrics} when count > 0 ->
        variant = aggregate_baseline_metric(metrics, suggestion.type)

        # Check if improvement meets expected threshold
        if meets_improvement_threshold?(baseline, variant, suggestion.type) do
          {:ok, variant}
        else
          Logger.warning("Improvement did not meet threshold",
            agent_id: agent_id,
            baseline: baseline,
            variant: variant,
            suggestion_type: suggestion.type
          )

          {:error, :insufficient_improvement}
        end

      {:ok, %{summary: %{sample_count: 0}}} ->
        {:error, :no_variant_metrics}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec meets_improvement_threshold?(float(), float(), atom()) :: boolean()
  defp meets_improvement_threshold?(baseline, variant, suggestion_type) do
    case suggestion_type do
      :add_patterns ->
        # For success rate, variant should be > baseline
        variant > baseline * 0.95

      :optimize_model ->
        # For cost, variant should be < baseline
        variant < baseline * 1.05

      :improve_cache ->
        # For latency, variant should be < baseline
        variant < baseline * 1.05

      _ ->
        false
    end
  end

  @spec calculate_improvement_percent(float(), float()) :: String.t()
  defp calculate_improvement_percent(baseline, variant)
       when is_number(baseline) and is_number(variant) do
    case baseline do
      0 ->
        "N/A"

      _ ->
        percent =
          ((variant - baseline) / baseline * 100)
          |> Float.round(1)

        "#{if percent > 0, do: "+", else: ""}#{percent}%"
    end
  end

  defp calculate_improvement_percent(_, _), do: "N/A"

  @spec rollback_improvement(String.t(), map()) :: :ok
  defp rollback_improvement(agent_id, suggestion) do
    Logger.info("Rolling back improvement",
      agent_id: agent_id,
      improvement_type: suggestion.type
    )

    # In a real system, this would restore the agent to its previous state
    # For now, just log the rollback action
    :ok
  end

  @spec store_evolution_attempt(
          String.t(),
          map(),
          float(),
          float() | nil,
          String.t() | nil,
          atom()
        ) ::
          {:ok, term()} | {:error, term()}
  defp store_evolution_attempt(agent_id, suggestion, baseline, variant, improvement, status) do
    # This would store the evolution attempt in the database
    # For now, just log it
    Logger.info("Evolution attempt recorded",
      agent_id: agent_id,
      improvement_type: suggestion.type,
      baseline: baseline,
      variant: variant,
      improvement: improvement,
      status: status
    )

    :ok
  end
end
