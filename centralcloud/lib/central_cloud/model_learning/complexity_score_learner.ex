defmodule CentralCloud.ModelLearning.ComplexityScoreLearner do
  @moduledoc """
  Learns optimal complexity scores from real routing outcomes.

  Analyzes aggregated metrics and adjusts model complexity scores based on:
  - Success rates (models with high success get boosted)
  - Response times (slow models get penalized)
  - Usage patterns (frequent models given more weight)

  ## Learning Algorithm

  For each model at each complexity level:

  1. Check if sufficient data (>= 100 uses)
  2. Calculate success rate and avg response time
  3. Score adjustment:
     - Success > 95% → boost by +0.2
     - Success < 85% → reduce by -0.2
     - Response time > 2s → reduce by -0.1
     - Response time < 500ms → boost by +0.1
  4. Clamp to [0.0, 5.0]
  5. Publish update to instances via pgmq

  ## Learning Frequency

  Runs periodically (every 60 seconds by default).
  Only updates scores if change > 0.1 to avoid noise.
  """

  use GenServer
  require Logger

  alias CentralCloud.ModelLearning.{ModelMetrics, ModelScoreUpdater}

  @min_samples_for_learning 100  # Need at least 100 uses
  @success_threshold_high 0.95   # 95% success = boost
  @success_threshold_low 0.85    # 85% success = reduce
  @slowness_threshold_ms 2000    # Response time > 2s = penalty
  @fastness_threshold_ms 500     # Response time < 500ms = boost
  @min_score_change 0.1          # Don't update if change < 0.1

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    interval = Keyword.get(opts, :schedule_interval_ms, 60_000)

    Logger.info("ComplexityScoreLearner starting (interval: #{interval}ms)")

    # Schedule first learning run
    schedule_learning(interval)

    {:ok, %{interval: interval}}
  end

  def handle_info({:learn, interval}, state) do
    # Run learning
    case learn_from_metrics() do
      :ok -> Logger.debug("Complexity score learning complete")
      {:error, reason} -> Logger.warning("Learning failed: #{inspect(reason)}")
    end

    # Schedule next learning
    schedule_learning(interval)

    {:noreply, state}
  end

  # === Learning Logic ===

  @doc """
  Learn optimal complexity scores from accumulated metrics.
  """
  def learn_from_metrics do
    # Get all models with sufficient data
    high_usage = ModelMetrics.get_high_usage_models(@min_samples_for_learning)

    Enum.each(high_usage, fn metric ->
      optimize_model_score(metric)
    end)

    :ok
  rescue
    e ->
      Logger.error("Error in learn_from_metrics: #{inspect(e)}")
      {:error, e}
  end

  defp optimize_model_score(%{
    model_name: model,
    complexity_level: complexity,
    usage_count: usage_count,
    success_count: success_count,
    avg_response_time: avg_time
  }) do
    # Calculate success rate
    success_rate = success_count / max(usage_count, 1)

    # Get current score from provider config
    current_score = get_current_complexity_score(model, complexity)

    # Calculate optimal score
    new_score = calculate_optimal_score(current_score, success_rate, avg_time)

    # Only update if significant change
    if abs(new_score - current_score) > @min_score_change do
      Logger.info(
        "Updating #{model} complexity #{complexity}: " <>
        "#{current_score} → #{new_score} (success: #{success_rate}, time: #{avg_time}ms)"
      )

      # Publish update for instances to consume
      ModelScoreUpdater.publish_score_update(model, complexity, current_score, new_score)
    end
  end

  defp calculate_optimal_score(current_score, success_rate, avg_time) do
    success_adjustment = cond do
      success_rate > @success_threshold_high -> 0.2    # Very successful
      success_rate < @success_threshold_low -> -0.2    # Struggling
      true -> 0.0                                       # Acceptable
    end

    speed_adjustment = cond do
      avg_time && avg_time > @slowness_threshold_ms -> -0.1   # Slow
      avg_time && avg_time < @fastness_threshold_ms -> 0.1    # Fast
      true -> 0.0                                              # Normal
    end

    # Clamp to valid range [0.0, 5.0]
    (current_score + success_adjustment + speed_adjustment)
    |> max(0.0)
    |> min(5.0)
  end

  # Get current score from ExLLM ModelCatalog
  defp get_current_complexity_score(model, complexity) do
    complexity_atom = String.to_atom(complexity)

    case ExLLM.Core.ModelCatalog.get_complexity_score(model, complexity_atom) do
      {:ok, score} -> score
      {:error, _} -> 2.5  # Default if not found
    end
  rescue
    _ -> 2.5  # Default if error
  end

  # === Scheduling ===

  defp schedule_learning(interval) do
    Process.send_after(self(), {:learn, interval}, interval)
  end
end
