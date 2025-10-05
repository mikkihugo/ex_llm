defmodule Singularity.Autonomy.RuleEngineV2 do
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

  alias Singularity.{Repo, Autonomy}
  alias Autonomy.{Rule, RuleExecution, RuleLoader, RuleEngineCore}

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

  defp update_rule_stats(rule_id, result, execution_time) do
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
end
