defmodule Singularity.Execution.Autonomy.Decider do
  @moduledoc """
  Computes when an agent should attempt a self-improvement based on its
  performance metrics and progress cycles.

  The decider remains deliberately conservative: it prefers to collect a minimum
  number of observations before triggering an evolution, and it honours backoff
  windows after a failed upgrade so agents do not thrash.
  """

  alias Singularity.Execution.Autonomy.Planner

  @min_samples 8
  @score_threshold 0.75
  @stagnation_cycles 30
  @failure_backoff_cycles 10

  @type agent_state :: map()
  @type decision ::
          {:continue, agent_state}
          | {:improve_local, map(), map(), agent_state}
          | {:improve_experimental, map(), map(), agent_state}

  @doc """
  Decide whether the agent should propose a new strategy.

  Returns:
  - `{:continue, state}` when no action is required
  - `{:improve_local, payload, context, state}` for low-risk Type 1 improvements (applied directly)
  - `{:improve_experimental, payload, context, state}` for high-risk Type 3 improvements (sent to Genesis)

  The `payload` is ready to hand to `Singularity.Execution.Runners.Control.publish_improvement/2` and
  the `context` map captures the trigger metadata (reason, score, samples, risk_level, etc.).
  """
  @spec decide(agent_state) :: decision
  def decide(state) do
    state
    |> ensure_tracking_fields()
    |> maybe_clear_forced_flag()
    |> evaluate()
  end

  defp ensure_tracking_fields(state) do
    state
    |> Map.put_new(:metrics, %{})
    |> Map.put_new(:last_score, 1.0)
    |> Map.put_new(:last_trigger, nil)
    |> Map.put_new(:pending_plan, nil)
    |> Map.put_new(:last_improvement_cycle, 0)
    |> Map.put_new(:last_failure_cycle, nil)
  end

  defp maybe_clear_forced_flag(state) do
    metrics = Map.get(state, :metrics, %{})

    case Map.get(metrics, :force_improvement) do
      true ->
        reason = Map.get(metrics, :force_reason, "forced")
        cleaned_metrics = Map.drop(metrics, [:force_improvement, :force_reason])
        forced_context = %{reason: reason, trigger: :forced}
        %{state | metrics: cleaned_metrics, forced_context: forced_context}

      _ ->
        Map.put_new(state, :forced_context, nil)
    end
  end

  defp evaluate(%{status: :updating} = state), do: {:continue, state}
  defp evaluate(%{pending_plan: plan} = state) when not is_nil(plan), do: {:continue, state}

  defp evaluate(state) do
    cycles = Map.get(state, :cycles, 0)
    metrics = Map.get(state, :metrics, %{})
    successes = Map.get(metrics, :successes, 0)
    failures = Map.get(metrics, :failures, 0)
    samples = successes + failures
    score = normalized_score(successes, failures)
    stagnation = cycles - Map.get(state, :last_improvement_cycle, 0)
    backoff_respected? = backoff_complete?(cycles, Map.get(state, :last_failure_cycle))

    state = Map.put(state, :last_score, score)

    cond do
      forced?(state) and backoff_respected? ->
        planner_context =
          state.forced_context |> Map.put(:score, score) |> Map.put(:samples, samples)

        plan = Planner.generate_strategy_payload(state, planner_context)
        improvement_type = classify_improvement_risk(state, planner_context)
        {improvement_type, plan, planner_context, Map.put(state, :forced_context, nil)}

      not backoff_respected? ->
        {:continue, state}

      samples >= @min_samples and score < @score_threshold ->
        trigger = %{reason: :score_drop, score: score, samples: samples, stagnation: stagnation}
        plan = Planner.generate_strategy_payload(state, trigger)
        improvement_type = classify_improvement_risk(state, trigger)
        {improvement_type, plan, trigger, state}

      stagnation >= @stagnation_cycles ->
        trigger = %{reason: :stagnation, score: score, samples: samples, stagnation: stagnation}
        plan = Planner.generate_strategy_payload(state, trigger)
        improvement_type = classify_improvement_risk(state, trigger)
        {improvement_type, plan, trigger, state}

      true ->
        {:continue, state}
    end
  end

  defp normalized_score(0, 0), do: 1.0

  defp normalized_score(successes, failures) do
    total = successes + failures
    successes / max(total, 1)
  end

  defp backoff_complete?(_cycles, nil), do: true

  defp backoff_complete?(cycles, last_failure_cycle),
    do: cycles - last_failure_cycle >= @failure_backoff_cycles

  defp forced?(%{forced_context: context}) when is_map(context), do: true
  defp forced?(_), do: false

  @doc """
  Classify improvement as Type 1 (local, low-risk) or Type 3 (Genesis, high-risk).

  ## Classification Rules

  **Type 1 (Local):** Low-risk improvements applied directly
  - Performance drop detected (score_drop trigger)
  - Recent stagnation (stagnation < 100 cycles)
  - Reasonable score (> 0.3) - not severely broken

  **Type 3 (Genesis):** High-risk improvements tested in sandbox
  - Severe performance degradation (score < 0.3)
  - Extended stagnation (> 100 cycles without improvement)
  - Multiple consecutive failures
  - Forced improvement requests (manual intervention)
  """
  defp classify_improvement_risk(state, context) do
    score = Map.get(context, :score, 0.5)
    stagnation = Map.get(context, :stagnation, 0)
    reason = Map.get(context, :reason, :unknown)
    cycles = Map.get(state, :cycles, 0)
    last_failure_cycle = Map.get(state, :last_failure_cycle)

    # Count recent failures (within last 20 cycles)
    consecutive_failure_cycles =
      if last_failure_cycle && cycles - last_failure_cycle < 20 do
        cycles - last_failure_cycle
      else
        0
      end

    cond do
      # Severe degradation - send to Genesis for comprehensive testing
      score < 0.3 ->
        :improve_experimental

      # Extended stagnation - too many cycles without progress
      stagnation > 100 ->
        :improve_experimental

      # Recent failure with continuing problems
      consecutive_failure_cycles > 0 and stagnation > 50 ->
        :improve_experimental

      # Forced improvement - keep locally unless explicitly marked experimental
      reason == :forced and Map.get(context, :risk_level) != "high" ->
        :improve_local

      # Default: low-risk local improvement for parameter tuning
      true ->
        :improve_local
    end
  end
end
