defmodule Singularity.Evolution.AdaptiveConfidenceGating do
  @moduledoc """
  Adaptive Confidence Gating - Dynamically adjust publishing threshold

  Instead of hardcoding a 0.85 threshold, this module learns from real-world
  performance of published rules and adjusts the threshold automatically:

  - **Too many failures?** → Raise threshold (only super-confident rules)
  - **All succeed?** → Lower threshold (more rules can publish)
  - **Stable?** → Keep threshold steady (found the sweet spot)

  ## How It Works

  1. **Baseline**: Start with 0.85 threshold
  2. **Track**: Monitor success rate of published rules
  3. **Measure**: Compare actual success vs. target (usually 90%)
  4. **Adjust**: If gap too large, adjust threshold ±0.05
  5. **Converge**: Over time, system finds optimal threshold

  ## Usage

  ```elixir
  # Get current adaptive threshold
  threshold = AdaptiveConfidenceGating.get_current_threshold()

  # Check if a rule should publish
  should_publish = AdaptiveConfidenceGating.should_publish_rule?(rule)

  # Provide feedback on published rule
  def record_published_rule_result(rule_id, opts \ []) do

  # Get tuning status
  status = AdaptiveConfidenceGating.get_tuning_status()
  ```

  ## Convergence Example

  ```
  Iteration 1: Start at 0.85
    - Publish 10 rules
    - 7 succeed (70% success) - Too low!

  Iteration 2: Raise to 0.90
    - Publish 8 rules
    - 7 succeed (87.5% success) - Getting better

  Iteration 3: Lower to 0.88
    - Publish 10 rules
    - 9 succeed (90% success) - PERFECT!

  Result: Optimal threshold = 0.88
  ```
  """

  require Logger

  alias Singularity.Repo
  alias Singularity.Storage.ValidationMetricsStore

  @target_success_rate 0.90  # Goal: 90% of published rules should work
  @min_threshold 0.75        # Never go below this (still must be decent quality)
  @max_threshold 0.95        # Never go above this (too conservative)
  @adjustment_step 0.03      # How much to adjust per iteration
  @min_data_points 10        # Need at least N rules to make decisions

  defmodule ThresholdState do
    @moduledoc "Current gating threshold and tuning state"
    defstruct [
      :current_threshold,
      :target_success_rate,
      :published_rule_count,
      :successful_count,
      :actual_success_rate,
      :adjustment_direction,
      :last_adjusted_at,
      :convergence_status
    ]
  end

  @doc """
  Get the current adaptive threshold.

  Returns the dynamically calculated publishing threshold based on
  real-world performance of previously published rules.

  ## Returns
  - Float between 0.70 and 0.95
  """
  @spec get_current_threshold() :: float()
  def get_current_threshold do
    Logger.debug("AdaptiveConfidenceGating: Getting current threshold")

    case get_tuning_state() do
      %ThresholdState{current_threshold: threshold} when not is_nil(threshold) ->
        threshold

      _ ->
        # No data yet, start with 0.85
        0.85
    end
  end

  @doc """
  Determine if a rule should be published based on its confidence.

  Takes into account the dynamically calculated threshold.

  ## Parameters
  - `rule` - Rule map with `:confidence` field

  ## Returns
  - `true` if confidence >= adaptive threshold
  - `false` otherwise
  """
  @spec should_publish_rule?(map()) :: boolean()
  def should_publish_rule?(%{confidence: confidence}) do
    threshold = get_current_threshold()
    confidence >= threshold
  end

  def should_publish_rule?(_), do: false

  @doc """
  Record outcome of a published rule in real-world usage.

  Uses this feedback to adjust the publishing threshold over time.

  ## Parameters
  - `rule_id` - ID of the published rule
  - `opts` - Options:
    - `:success` - Boolean, did the rule work well?
    - `:effectiveness` - Float (0.0-1.0), how effective was it?

  ## Returns
  - `:ok` - Feedback recorded
  """
  @spec record_published_rule_result(String.t(), keyword()) :: :ok | {:error, term()}
  def record_published_rule_result(rule_id, opts \\ []) do
    Logger.debug("AdaptiveConfidenceGating: Recording published rule result",
      rule_id: rule_id,
      opts: opts
    )

    success = Keyword.get(opts, :success, false)

    try do
      # Update success tracking
      state = get_tuning_state()

      new_published_count = (state.published_rule_count || 0) + 1
      new_successful_count = if success, do: (state.successful_count || 0) + 1, else: (state.successful_count || 0)

      new_success_rate = if new_published_count > 0, do: new_successful_count / new_published_count, else: 0.0

      # Determine if we should adjust threshold
      if new_published_count >= @min_data_points do
        new_threshold = calculate_new_threshold(new_success_rate, state.current_threshold || 0.85)

        # Store updated state
        store_tuning_state(%ThresholdState{
          current_threshold: new_threshold,
          target_success_rate: @target_success_rate,
          published_rule_count: new_published_count,
          successful_count: new_successful_count,
          actual_success_rate: new_success_rate,
          adjustment_direction: adjustment_direction(new_success_rate),
          last_adjusted_at: DateTime.utc_now(),
          convergence_status: convergence_status(new_success_rate, new_threshold)
        })

        Logger.info("AdaptiveConfidenceGating: Threshold adjusted",
          old_threshold: state.current_threshold,
          new_threshold: new_threshold,
          success_rate: Float.round(new_success_rate, 3),
          reason: adjustment_reason(new_success_rate)
        )
      end

      :ok
    rescue
      error ->
        Logger.error("AdaptiveConfidenceGating: Error recording result",
          rule_id: rule_id,
          error: inspect(error)
        )

        {:error, error}
    end
  end

  @doc """
  Get detailed tuning status.

  Returns information about the current threshold, how close to convergence,
  and recommendations for tuning.

  ## Returns
  - Map with tuning metrics and status
  """
  @spec get_tuning_status() :: map()
  def get_tuning_status do
    Logger.debug("AdaptiveConfidenceGating: Getting tuning status")

    state = get_tuning_state()

    %{
      current_threshold: state.current_threshold || 0.85,
      target_success_rate: state.target_success_rate || @target_success_rate,
      published_rules: state.published_rule_count || 0,
      successful_rules: state.successful_count || 0,
      actual_success_rate: Float.round(state.actual_success_rate || 0.0, 3),
      adjustment_direction: state.adjustment_direction || :stable,
      convergence_status: state.convergence_status || :initializing,
      recommendation: generate_recommendation(state),
      min_threshold: @min_threshold,
      max_threshold: @max_threshold,
      last_adjusted_at: state.last_adjusted_at,
      data_points: state.published_rule_count || 0,
      min_data_points_needed: @min_data_points
    }
  end

  @doc """
  Reset threshold to default for testing.

  Clears learning history and starts fresh with 0.85.

  ## Returns
  - `:ok`
  """
  @spec reset_to_default() :: :ok
  def reset_to_default do
    Logger.warning("AdaptiveConfidenceGating: Resetting to default threshold")

    store_tuning_state(%ThresholdState{
      current_threshold: 0.85,
      target_success_rate: @target_success_rate,
      published_rule_count: 0,
      successful_count: 0,
      actual_success_rate: 0.0,
      adjustment_direction: :stable,
      last_adjusted_at: DateTime.utc_now(),
      convergence_status: :initializing
    })

    :ok
  end

  @doc """
  Get convergence metrics for monitoring.

  Shows how far off we are from target success rate and estimated
  iterations to convergence.

  ## Returns
  - Map with convergence metrics
  """
  @spec get_convergence_metrics() :: map()
  def get_convergence_metrics do
    state = get_tuning_state()
    actual = state.actual_success_rate || 0.0
    target = @target_success_rate
    gap = abs(actual - target)

    %{
      actual_success_rate: Float.round(actual, 3),
      target_success_rate: target,
      gap_to_target: Float.round(gap, 3),
      converged: gap < 0.05,
      estimated_iterations_remaining: ceil(gap / @adjustment_step),
      status: convergence_status(actual, state.current_threshold || 0.85),
      current_threshold: state.current_threshold || 0.85
    }
  end

  # Private Helpers

  defp get_tuning_state do
    # In real implementation, would fetch from database
    # For now, use in-memory state
    case Application.get_env(:singularity, :adaptive_threshold_state) do
      nil ->
        %ThresholdState{
          current_threshold: 0.85,
          target_success_rate: @target_success_rate,
          published_rule_count: 0,
          successful_count: 0,
          actual_success_rate: 0.0,
          adjustment_direction: :stable,
          convergence_status: :initializing
        }

      state ->
        state
    end
  end

  defp store_tuning_state(state) do
    Application.put_env(:singularity, :adaptive_threshold_state, state)
  end

  defp calculate_new_threshold(actual_success_rate, current_threshold) do
    gap = actual_success_rate - @target_success_rate

    new_threshold =
      cond do
        gap < -0.10 ->
          # Much lower than target, raise threshold significantly
          current_threshold + @adjustment_step * 2

        gap < -0.05 ->
          # Somewhat lower, raise moderately
          current_threshold + @adjustment_step

        gap > 0.10 ->
          # Much higher than target, lower threshold significantly
          current_threshold - @adjustment_step * 2

        gap > 0.05 ->
          # Somewhat higher, lower moderately
          current_threshold - @adjustment_step

        true ->
          # Close to target, keep stable
          current_threshold
      end

    # Clamp to min/max
    max(@min_threshold, min(@max_threshold, new_threshold))
    |> Float.round(3)
  end

  defp adjustment_direction(actual_success_rate) do
    gap = actual_success_rate - @target_success_rate

    cond do
      gap < -0.05 -> :raise_threshold
      gap > 0.05 -> :lower_threshold
      true -> :stable
    end
  end

  defp convergence_status(actual_success_rate, current_threshold) do
    gap = abs(actual_success_rate - @target_success_rate)

    cond do
      gap < 0.05 ->
        :converged

      current_threshold >= @max_threshold ->
        :max_threshold_reached

      current_threshold <= @min_threshold ->
        :min_threshold_reached

      true ->
        :adjusting
    end
  end

  defp adjustment_reason(actual_success_rate) do
    gap = actual_success_rate - @target_success_rate

    cond do
      gap < -0.10 -> "Published rules failing too often, raising threshold"
      gap < -0.05 -> "Published rules underperforming, raising threshold"
      gap > 0.10 -> "Published rules all succeeding, lowering threshold"
      gap > 0.05 -> "Published rules exceeding target, lowering threshold"
      true -> "Maintaining stable threshold"
    end
  end

  defp generate_recommendation(state) do
    case state.convergence_status do
      :converged ->
        "✅ Threshold converged! System has found optimal publishing level."

      :max_threshold_reached ->
        "⚠️  Hit max threshold (#{@max_threshold}). Rules still failing - check rule quality."

      :min_threshold_reached ->
        "⚠️  Hit min threshold (#{@min_threshold}). Rules overly aggressive - tighten criteria."

      :initializing ->
        "🔄 Collecting data (#{state.published_rule_count || 0}/#{@min_data_points} rules needed)"

      :adjusting ->
        gap = abs(state.actual_success_rate - @target_success_rate)
        iterations = ceil(gap / @adjustment_step)
        "🔧 Adjusting... (#{iterations} iterations remaining to convergence)"
    end
  end
end
