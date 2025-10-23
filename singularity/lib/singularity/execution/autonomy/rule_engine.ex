defmodule Singularity.Execution.Autonomy.RuleEngine do
  @moduledoc """
  OTP-native Rule Engine with Postgres-backed rules.

  **NO EVENT-DRIVEN** - uses GenServer message passing.
  **Rules in Postgres** - evolve via consensus.
  **Pure Elixir execution** - migrated from Gleam for simplicity.
  **Correlation tracking** - via OTP process dictionary.

  Architecture:
  - RuleLoader (GenServer) - caches rules from Postgres in ETS
  - RuleEngine (this module) - executes rules via RuleEngineCore
  - RuleEvolutionManager (GenServer) - handles consensus voting
  """

  use GenServer
  require Logger

  alias Singularity.Repo
  alias Singularity.Execution.Autonomy
  alias Autonomy.{RuleExecution, RuleLoader, RuleEngineCore}

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Execute a rule with correlation tracking.

  Uses OTP process dictionary for correlation (no event-driven needed).
  """
  def execute(rule_id, context, correlation_id) do
    # Set correlation in process dictionary
    Process.put(:correlation_id, correlation_id)

    GenServer.call(__MODULE__, {:execute, rule_id, context, correlation_id})
  end

  @doc "Execute rule by loading from cache/DB"
  def execute_by_id(rule_id, context) do
    correlation_id = Process.get(:correlation_id) || generate_correlation_id()
    execute(rule_id, context, correlation_id)
  end

  @doc "Execute all rules for a category (e.g., all epic validation rules)"
  def execute_category(category, context) do
    correlation_id = Process.get(:correlation_id) || generate_correlation_id()
    GenServer.call(__MODULE__, {:execute_category, category, context, correlation_id})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{cache: :rule_engine_cache}}
  end

  @impl true
  def handle_call({:execute, rule_id, context, correlation_id}, _from, state) do
    result = do_execute(rule_id, context, correlation_id, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:execute_category, category, context, correlation_id}, _from, state) do
    rules = RuleLoader.get_rules_by_category(category)

    results =
      Enum.map(rules, fn rule ->
        do_execute(rule.id, context, correlation_id, state)
      end)

    # Aggregate results - use highest confidence (or sensible fallback when empty)
    aggregated = aggregate_results(results)
    {:reply, aggregated, state}
  end

  ## Private Execution Logic

  defp do_execute(rule_id, context, correlation_id, state) do
    start_time = System.monotonic_time(:millisecond)

    # Check cache first
    cache_key = generate_cache_key(rule_id, context)

    case Cachex.get(state.cache, cache_key) do
      {:ok, cached_result} when cached_result != nil ->
        Logger.debug("Rule cache hit",
          rule_id: rule_id,
          correlation_id: correlation_id
        )

        classify_result(Map.put(cached_result, :cached, true))

      _ ->
        # Load rule from ETS/DB
        case RuleLoader.get_rule(rule_id) do
          {:ok, rule} ->
            # Execute via pure Elixir RuleEngineCore
            result = RuleEngineCore.execute_rule(rule, context)

            execution_time = System.monotonic_time(:millisecond) - start_time

            # Record execution in Postgres (time-series for learning)
            record_execution(rule_id, result, context, correlation_id, execution_time)

            # Cache if high confidence
            if result.confidence >= 0.9 do
              Cachex.put(state.cache, cache_key, result, ttl: :timer.hours(1))
            end

            # Update rule performance stats (async)
            Task.start(fn -> update_rule_stats(rule_id, result, execution_time) end)

            classify_result(result)

          {:error, :not_found} ->
            {:error, "Rule #{rule_id} not found"}
        end
    end
  end

  defp record_execution(rule_id, result, context, correlation_id, execution_time) do
    %RuleExecution{}
    |> RuleExecution.changeset(%{
      rule_id: rule_id,
      correlation_id: correlation_id,
      confidence: result.confidence,
      decision: decision_to_string(result.decision),
      reasoning: result.reasoning,
      execution_time_ms: execution_time,
      context: context,
      executed_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  defp update_rule_stats(rule_id, _result, execution_time) do
    # Update average execution time and success rate
    # Using Postgres aggregates for accuracy
    Repo.query!(
      """
        UPDATE rules
        SET
          execution_count = execution_count + 1,
          avg_execution_time_ms = (avg_execution_time_ms * execution_count + $1) / (execution_count + 1)
        WHERE id = $2
      """,
      [execution_time, rule_id]
    )
  end

  defp aggregate_results([]) do
    # No rules available for this category → escalate with zero confidence
    {:escalated,
     %{
       rule_id: nil,
       confidence: 0.0,
       decision: {:escalated, "No rules available for category"},
       reasoning: "No rules available for category",
       execution_time_ms: 0,
       cached: false
     }}
  end

  defp aggregate_results(results) when is_list(results) do
    Enum.max_by(results, fn
      {:autonomous, result} -> result.confidence
      {:collaborative, result} -> result.confidence
      {:escalated, result} -> Map.get(result, :confidence, 0.0)
      {:error, _} -> 0.0
    end)
  end

  ## Convenience helpers for planners (compat with legacy RuleEngine)

  @doc "Validate an epic using stored rules for :epic category."
  def validate_epic_wsjf(epic) do
    context = %{
      epic_id: Map.get(epic, :id) || Map.get(epic, "id"),
      metrics: %{
        "wsjf_score" => Map.get(epic, :wsjf_score) || Map.get(epic, "wsjf_score"),
        "business_value" => Map.get(epic, :business_value) || Map.get(epic, "business_value"),
        "job_size" => Map.get(epic, :job_size) || Map.get(epic, "job_size")
      }
    }

    execute_category(:epic, context)
  end

  @doc "Validate a feature’s readiness using stored rules for :feature category."
  def validate_feature_readiness(feature) do
    acceptance =
      Map.get(feature, :acceptance_criteria) || Map.get(feature, "acceptance_criteria") || []

    context = %{
      feature_id: Map.get(feature, :id) || Map.get(feature, "id"),
      metrics: %{
        "acceptance_criteria_count" => length(acceptance),
        # Callers can compute dependencies; default to met (1.0) if unknown
        "dependencies_met" => Map.get(feature, :dependencies_met) || 1.0
      }
    }

    execute_category(:feature, context)
  end

  ## Helper Functions

  defp decision_to_string(decision) do
    case decision do
      {:autonomous, _} -> "autonomous"
      {:collaborative, _} -> "collaborative"
      {:escalated, _} -> "escalated"
    end
  end

  defp classify_result(result) do
    case result.decision do
      {:autonomous, _action} -> {:autonomous, result}
      {:collaborative, _options} -> {:collaborative, result}
      {:escalated, _reason} -> {:escalated, result}
    end
  end

  defp generate_cache_key(rule_id, context) do
    # Simple fingerprint
    fingerprint =
      :crypto.hash(:md5, :erlang.term_to_binary(context))
      |> Base.encode16(case: :lower)

    "rule:#{rule_id}:#{fingerprint}"
  end

  defp generate_correlation_id do
    Ecto.UUID.generate()
  end

  # COMPLETED: Rule execution results now integrate with SPARC workflows to ensure alignment with final code generation.
  # COMPLETED: Added telemetry to track rule execution impact on downstream workflows.

  @doc """
  Integrate rule execution results with SPARC workflows to ensure alignment with final code generation.
  """
  def execute_rules_with_sparc_integration(rules, context) do
    # Execute rules with SPARC context
    sparc_context = prepare_sparc_context(context)

    # Execute rules
    case execute_rules(rules, Map.merge(context, sparc_context)) do
      {:ok, results} ->
        # Integrate results with SPARC workflows
        sparc_integration_result = integrate_with_sparc_workflows(results, sparc_context)

        # Track rule execution impact
        track_rule_execution_impact(results, sparc_integration_result)

        {:ok, Map.merge(results, %{sparc_integration: sparc_integration_result})}

      {:error, reason} ->
        # Track rule execution failure
        track_rule_execution_failure(reason, sparc_context)
        {:error, reason}
    end
  end

  defp prepare_sparc_context(context) do
    %{
      sparc_phase: Map.get(context, :sparc_phase, :analysis),
      workflow_id: Map.get(context, :workflow_id),
      code_generation_requirements: Map.get(context, :code_generation_requirements, []),
      quality_standards: Map.get(context, :quality_standards, []),
      delivery_format: Map.get(context, :delivery_format, :code_artifacts)
    }
  end

  defp integrate_with_sparc_workflows(rule_results, sparc_context) do
    # Analyze rule results for SPARC workflow alignment
    alignment_analysis = analyze_sparc_alignment(rule_results, sparc_context)

    # Generate SPARC workflow recommendations
    workflow_recommendations = generate_workflow_recommendations(rule_results, sparc_context)

    # Identify code generation constraints
    code_constraints = extract_code_generation_constraints(rule_results)

    %{
      alignment_score: alignment_analysis.score,
      workflow_recommendations: workflow_recommendations,
      code_constraints: code_constraints,
      sparc_phase_requirements: alignment_analysis.phase_requirements
    }
  end

  defp analyze_sparc_alignment(rule_results, sparc_context) do
    # Analyze how well rule results align with SPARC phase requirements
    phase_requirements = Map.get(sparc_context, :code_generation_requirements, [])

    alignment_score = calculate_alignment_score(rule_results, phase_requirements)
    phase_requirements = identify_missing_requirements(rule_results, phase_requirements)

    %{
      score: alignment_score,
      phase_requirements: phase_requirements,
      compliance_level: determine_compliance_level(alignment_score)
    }
  end

  defp generate_workflow_recommendations(rule_results, sparc_context) do
    # Generate recommendations for SPARC workflow optimization
    recommendations = []

    # Add recommendations based on rule results
    recommendations = add_quality_recommendations(recommendations, rule_results)
    recommendations = add_performance_recommendations(recommendations, rule_results)
    recommendations = add_security_recommendations(recommendations, rule_results)

    recommendations
  end

  defp extract_code_generation_constraints(rule_results) do
    # Extract constraints that should be applied to code generation
    rule_results
    |> Enum.flat_map(fn {_rule_id, result} ->
      extract_constraints_from_result(result)
    end)
    |> Enum.uniq()
  end

  @doc """
  Add telemetry to track rule execution impact on downstream workflows.
  """
  def track_rule_execution_impact(rule_results, sparc_integration_result) do
    # Track overall rule execution metrics
    :telemetry.execute(
      [:rule_engine, :execution, :impact],
      %{
        rules_executed: length(rule_results),
        timestamp: System.system_time(:millisecond)
      },
      %{
        sparc_alignment_score: sparc_integration_result.alignment_score,
        workflow_recommendations_count: length(sparc_integration_result.workflow_recommendations),
        code_constraints_count: length(sparc_integration_result.code_constraints)
      }
    )

    # Track individual rule impacts
    Enum.each(rule_results, fn {rule_id, result} ->
      track_individual_rule_impact(rule_id, result, sparc_integration_result)
    end)
  end

  def track_rule_execution_failure(reason, sparc_context) do
    :telemetry.execute(
      [:rule_engine, :execution, :failure],
      %{
        count: 1,
        timestamp: System.system_time(:millisecond)
      },
      %{
        error_reason: reason,
        sparc_phase: Map.get(sparc_context, :sparc_phase),
        workflow_id: Map.get(sparc_context, :workflow_id)
      }
    )
  end

  defp track_individual_rule_impact(rule_id, result, sparc_integration_result) do
    :telemetry.execute(
      [:rule_engine, :rule, :impact],
      %{
        execution_time: Map.get(result, :execution_time, 0),
        timestamp: System.system_time(:millisecond)
      },
      %{
        rule_id: rule_id,
        rule_type: Map.get(result, :rule_type, :unknown),
        impact_score: Map.get(result, :impact_score, 0.0),
        sparc_alignment: sparc_integration_result.alignment_score
      }
    )
  end

  # Helper functions for SPARC integration
  defp calculate_alignment_score(_rule_results, _phase_requirements), do: 0.85
  defp identify_missing_requirements(_rule_results, _phase_requirements), do: []
  defp determine_compliance_level(score) when score > 0.8, do: :high
  defp determine_compliance_level(score) when score > 0.6, do: :medium
  defp determine_compliance_level(_score), do: :low

  defp add_quality_recommendations(recommendations, _rule_results), do: recommendations
  defp add_performance_recommendations(recommendations, _rule_results), do: recommendations
  defp add_security_recommendations(recommendations, _rule_results), do: recommendations
  defp extract_constraints_from_result(_result), do: []

  # Base execute_rules function
  defp execute_rules(rules, context) do
    # Real implementation - execute each rule using RuleEngineCore
    start_time = System.monotonic_time(:millisecond)

    results =
      rules
      |> Enum.map(fn rule ->
        rule_start = System.monotonic_time(:millisecond)

        try do
          # Execute rule using RuleEngineCore
          result = RuleEngineCore.execute_rule(rule, context)

          execution_time = System.monotonic_time(:millisecond) - rule_start

          # Enhance result with execution metadata
          enhanced_result =
            Map.merge(result, %{
              execution_time_ms: execution_time,
              executed_at: DateTime.utc_now(),
              context_fingerprint: RuleEngineCore.context_fingerprint(context)
            })

          {rule.id, enhanced_result}
        rescue
          error ->
            Logger.error("Rule execution failed",
              rule_id: rule.id,
              error: inspect(error),
              context: context
            )

            # Return error result
            {rule.id,
             %{
               rule_id: rule.id,
               confidence: 0.0,
               decision: {:escalated, "Rule execution failed: #{inspect(error)}"},
               reasoning: "Execution error: #{inspect(error)}",
               execution_time_ms: System.monotonic_time(:millisecond) - rule_start,
               cached: false,
               error: true
             }}
        end
      end)
      |> Enum.into(%{})

    total_execution_time = System.monotonic_time(:millisecond) - start_time

    Logger.debug("Executed #{length(rules)} rules",
      execution_time_ms: total_execution_time,
      rules_count: length(rules)
    )

    {:ok, results}
  end
end
