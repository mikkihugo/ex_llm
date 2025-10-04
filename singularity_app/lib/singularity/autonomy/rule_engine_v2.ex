defmodule Singularity.Autonomy.RuleEngineV2 do
  @moduledoc """
  OTP-native Rule Engine with Postgres-backed rules.

  **NO EVENT-DRIVEN** - uses GenServer message passing.
  **Rules in Postgres** - evolve via consensus.
  **Gleam execution** - fast, type-safe pattern matching.
  **Correlation tracking** - via OTP process dictionary.

  Architecture:
  - RuleLoader (GenServer) - caches rules from Postgres in ETS
  - RuleEngine (this module) - executes rules via Gleam
  - RuleEvolutionManager (GenServer) - handles consensus voting
  """

  use GenServer
  require Logger

  alias Singularity.{Repo, Autonomy}
  alias Autonomy.{Rule, RuleExecution, RuleLoader}

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

    # Aggregate results - use highest confidence
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

        {:ok, Map.put(cached_result, :cached, true)}

      _ ->
        # Load rule from ETS/DB
        case RuleLoader.get_rule(rule_id) do
          {:ok, gleam_rule} ->
            # Execute via Gleam
            gleam_context = elixir_context_to_gleam(context)
            gleam_result = :singularity@rule_engine.execute_rule(gleam_rule, gleam_context)
            result = gleam_result_to_elixir(gleam_result)

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
    Repo.query!("""
      UPDATE rules
      SET
        execution_count = execution_count + 1,
        avg_execution_time_ms = (avg_execution_time_ms * execution_count + $1) / (execution_count + 1)
      WHERE id = $2
    """, [execution_time, rule_id])
  end

  defp aggregate_results(results) do
    # Take highest confidence result
    Enum.max_by(results, fn
      {:ok, result} -> result.confidence
      {:error, _} -> 0.0
    end)
  end

  ## Type Conversions (same as before)

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

  defp decision_to_elixir(decision) do
    case decision do
      {:Autonomous, action} -> {:autonomous, action}
      {:Collaborative, options} -> {:collaborative, options}
      {:Escalated, reason} -> {:escalated, reason}
    end
  end

  defp decision_to_string(decision) do
    case decision do
      {:autonomous, _} -> "autonomous"
      {:collaborative, _} -> "collaborative"
      {:escalated, _} -> "escalated"
    end
  end

  defp option_to_gleam(nil), do: :none
  defp option_to_gleam(value), do: {:some, value}

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
