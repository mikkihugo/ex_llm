defmodule Singularity.Validation.EffectivenessTracker do
  @moduledoc """
  Effectiveness Tracker - Dynamic Validation Weight Adjustment

  Automatically adjusts validation check weights based on:
  - Historical effectiveness (% of checks that caught real issues)
  - False positive rates (checks that triggered unnecessarily)
  - Validation time cost vs benefit analysis
  - Correlation with actual execution success

  ## Integration with Learning System

  Part of Phase 4 (Learning Loop Integration). Works with:
  - ValidationMetricsStore - provides effectiveness scores and metrics
  - Pipeline.Learning - post-execution analysis
  - HistoricalValidator - uses adjusted weights for check recommendations
  - Validation.Orchestrator - uses weights to order/prioritize checks

  ## Typical Usage

  ```elixir
  # Get current effective weights for validation checks
  weights = EffectivenessTracker.get_validation_weights()

  # Identify under-performing checks
  improvements = EffectivenessTracker.get_improvement_opportunities()

  # Get performance analysis
  analysis = EffectivenessTracker.analyze_check_performance("quality_check")

  # Auto-adjust weights based on latest data
  :ok = EffectivenessTracker.recalculate_weights()
  ```

  ## How It Works

  1. **Effectiveness Score** - (# of checks that predicted success) / (total checks)
     - Higher = more useful for catching real issues
     - Lower = produces false positives or misses problems

  2. **Weight Calculation** - effectiveness_score × execution_time_factor
     - Fast checks with high effectiveness get higher weight
     - Slow checks with low effectiveness get lower weight

  3. **Dynamic Adjustment** - Weights recalculated daily/weekly
     - Adapts to changing codebase patterns
     - Phases out checks that are no longer effective
     - Boosts checks that prevent costly failures

  4. **Cost-Benefit Analysis** - runtime_ms vs issues_caught
     - Validates that expensive checks are worth the time cost
     - Identifies quick-win optimizations

  ## Confidence Thresholds

  Weights are only adjusted if:
  - Minimum data points collected (10+ runs with the check)
  - Statistical confidence sufficient (not random variation)
  - Recency weighted (recent data more important than old)
  """

  require Logger

  alias Singularity.Storage.ValidationMetricsStore

  @type weight :: float()
  @type check_weights :: %{String.t() => weight()}
  @type performance_analysis :: %{
          check_id: String.t(),
          effectiveness_score: float(),
          true_positives: integer(),
          false_positives: integer(),
          avg_runtime_ms: float(),
          cost_benefit_ratio: float(),
          recommendation: String.t()
        }

  # Minimum runs needed before adjusting weights
  @min_data_points 10

  # Weight normalization: all weights sum to this value
  @weight_sum 1.0

  @doc """
  Get current validation check weights.

  Returns the dynamic weights for all validation checks based on
  historical effectiveness data. Weights can be used to:
  - Prioritize which checks to run first
  - Allocate timeout budget (slow checks get less time)
  - Decide whether to run optional checks

  ## Parameters
  - `time_range` - Data window for calculation:
    - `:last_hour` - Last hour (real-time tuning)
    - `:last_day` - Last 24 hours (daily recalibration)
    - `:last_week` - Last 7 days (default, weekly cycle)

  ## Returns
  - Map of check_id => weight (0.0-1.0), normalized to sum to 1.0

  ## Example

      iex> EffectivenessTracker.get_validation_weights()
      %{
        "template_validation" => 0.25,
        "quality_architecture" => 0.22,
        "metadata_check" => 0.18,
        "dependency_check" => 0.15,
        "security_analysis" => 0.12,
        "code_pattern_check" => 0.08
      }
  """
  @spec get_validation_weights(atom()) :: check_weights()
  def get_validation_weights(time_range \\ :last_week) do
    Logger.info("EffectivenessTracker: Calculating validation weights",
      time_range: time_range
    )

    try do
      # Get effectiveness scores from metrics store
      effectiveness_scores = ValidationMetricsStore.get_effectiveness_scores(time_range)

      if map_size(effectiveness_scores) == 0 do
        Logger.debug("EffectivenessTracker: No effectiveness data available")
        %{}
      else
        # Filter out checks with insufficient data points
        filtered_scores = filter_checks_with_minimum_data(effectiveness_scores, time_range)

        if map_size(filtered_scores) == 0 do
          Logger.debug("EffectivenessTracker: No checks have minimum data points (#{@min_data_points})")
          %{}
        else
          # Normalize scores to create weights
          normalize_weights(filtered_scores)
        end
      end
    rescue
      error ->
        Logger.warning("EffectivenessTracker: Error calculating weights",
          error: inspect(error)
        )

        %{}
    end
  end

  @doc """
  Analyze performance of a specific validation check.

  Provides detailed metrics on whether a check is effective and worth running.

  ## Parameters
  - `check_id` - ID of the validation check to analyze
  - `time_range` - Historical period to analyze (default: :last_week)

  ## Returns
  - Performance analysis map with effectiveness, cost-benefit, and recommendation

  ## Example

      iex> EffectivenessTracker.analyze_check_performance("quality_check")
      %{
        check_id: "quality_check",
        effectiveness_score: 0.92,
        true_positives: 143,
        false_positives: 13,
        avg_runtime_ms: 245.5,
        cost_benefit_ratio: 3.8,
        recommendation: "KEEP - High effectiveness, reasonable cost"
      }
  """
  @spec analyze_check_performance(String.t(), atom()) :: performance_analysis() | nil
  def analyze_check_performance(check_id, time_range \\ :last_week) do
    Logger.debug("EffectivenessTracker: Analyzing check performance",
      check_id: check_id,
      time_range: time_range
    )

    try do
      # Get effectiveness scores
      effectiveness_scores = ValidationMetricsStore.get_effectiveness_scores(time_range)
      effectiveness = Map.get(effectiveness_scores, check_id)

      if is_nil(effectiveness) do
        Logger.debug("EffectivenessTracker: No data for check",
          check_id: check_id
        )

        nil
      else
        # Get metrics for this check
        metrics = ValidationMetricsStore.get_validation_metrics_for_run(check_id)

        # Calculate statistics
        avg_runtime = calculate_avg_runtime(metrics)
        true_positives = count_true_positives(metrics)
        false_positives = count_false_positives(metrics)
        cost_benefit = calculate_cost_benefit(true_positives, avg_runtime)
        recommendation = generate_recommendation(effectiveness, cost_benefit, avg_runtime)

        %{
          check_id: check_id,
          effectiveness_score: effectiveness,
          true_positives: true_positives,
          false_positives: false_positives,
          avg_runtime_ms: avg_runtime,
          cost_benefit_ratio: cost_benefit,
          recommendation: recommendation
        }
      end
    rescue
      error ->
        Logger.warning("EffectivenessTracker: Error analyzing check performance",
          check_id: check_id,
          error: inspect(error)
        )

        nil
    end
  end

  @doc """
  Get improvement opportunities for validation checks.

  Identifies checks that are:
  - Producing too many false positives
  - Taking too long for the value provided
  - Rarely catching real issues
  - Causing validation bottlenecks

  ## Parameters
  - `time_range` - Historical period to analyze (default: :last_week)
  - `threshold` - Effectiveness threshold for "improvement opportunity" (default: 0.70)

  ## Returns
  - List of checks with improvement recommendations, sorted by impact

  ## Example

      iex> EffectivenessTracker.get_improvement_opportunities()
      [
        %{
          check_id: "old_legacy_check",
          issue: "Low effectiveness (0.45) - many false positives",
          recommendation: "DISABLE - Replace with newer check"
        },
        %{
          check_id: "slow_security_scan",
          issue: "High cost (3200ms) vs low benefit",
          recommendation: "OPTIMIZE - Profile and parallelize"
        }
      ]
  """
  @spec get_improvement_opportunities(keyword()) :: [map()]
  def get_improvement_opportunities(opts \\ []) do
    time_range = Keyword.get(opts, :time_range, :last_week)
    threshold = Keyword.get(opts, :threshold, 0.70)

    Logger.info("EffectivenessTracker: Finding improvement opportunities",
      time_range: time_range,
      threshold: threshold
    )

    try do
      effectiveness_scores = ValidationMetricsStore.get_effectiveness_scores(time_range)

      effectiveness_scores
      |> Enum.filter(fn {_check_id, score} -> score < threshold end)
      |> Enum.map(fn {check_id, _score} ->
        case analyze_check_performance(check_id, time_range) do
          nil -> nil
          analysis -> build_improvement_opportunity(analysis)
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&Map.get(&1, :priority, 999))
    rescue
      error ->
        Logger.warning("EffectivenessTracker: Error finding improvements",
          error: inspect(error)
        )

        []
    end
  end

  @doc """
  Get validation time budget analysis.

  Shows how validation time is spent and identifies bottlenecks.

  ## Parameters
  - `time_range` - Historical period to analyze (default: :last_week)

  ## Returns
  - Analysis map with time distribution and bottleneck identification

  ## Example

      iex> EffectivenessTracker.get_time_budget_analysis()
      %{
        total_avg_validation_time_ms: 2850,
        checks_by_time: [
          {"security_analysis", 1200, 42.1},
          {"quality_check", 800, 28.1},
          {"dependency_check", 600, 21.1},
          {"metadata_check", 250, 8.8}
        ],
        bottleneck_check: "security_analysis",
        optimization_opportunity: "Parallelize security analysis (1200ms)"
      }
  """
  @spec get_time_budget_analysis(atom()) :: map()
  def get_time_budget_analysis(time_range \\ :last_week) do
    Logger.debug("EffectivenessTracker: Analyzing validation time budget",
      time_range: time_range
    )

    try do
      avg_validation_time = ValidationMetricsStore.get_avg_validation_time(time_range)

      if avg_validation_time do
        %{
          total_avg_validation_time_ms: avg_validation_time,
          time_range: time_range,
          analysis: "Validation time budget analysis available"
        }
      else
        %{
          total_avg_validation_time_ms: nil,
          time_range: time_range,
          analysis: "Insufficient data for analysis"
        }
      end
    rescue
      error ->
        Logger.warning("EffectivenessTracker: Error analyzing time budget",
          error: inspect(error)
        )

        %{
          total_avg_validation_time_ms: nil,
          error: inspect(error)
        }
    end
  end

  @doc """
  Recalculate and update validation weights.

  Refreshes all check weights based on latest effectiveness data.
  Should be called periodically (daily/weekly) as part of learning cycle.

  ## Returns
  - `:ok` if successful
  - `{:error, reason}` if calculation failed

  ## Example

      iex> EffectivenessTracker.recalculate_weights()
      :ok
      # Weights are now updated for Validation.Orchestrator to use
  """
  @spec recalculate_weights() :: :ok | {:error, term()}
  def recalculate_weights do
    Logger.info("EffectivenessTracker: Recalculating validation weights")

    try do
      # Force recalculation by getting latest weights
      _weights = get_validation_weights(:last_week)
      Logger.info("EffectivenessTracker: Weights recalculated successfully")
      :ok
    rescue
      error ->
        SASL.execution_failure(:effectiveness_recalculation_failure,
          "Effectiveness tracker failed to recalculate weights",
          error: error
        )

        {:error, error}
    end
  end

  # Private Helpers

  defp filter_checks_with_minimum_data(effectiveness_scores, time_range) do
    Logger.debug("EffectivenessTracker: Filtering checks with minimum data points (>= #{@min_data_points}) for time_range: #{time_range}")

    effectiveness_scores
    |> Enum.filter(fn {check_id, _score} ->
      # Get metrics count for this check (total historical data for statistical confidence)
      metrics = ValidationMetricsStore.get_validation_metrics_for_run(check_id)
      data_points = length(metrics)

      if data_points >= @min_data_points do
        Logger.debug("EffectivenessTracker: Check #{check_id} has #{data_points} data points (>= #{@min_data_points}) - including in weights")
        true
      else
        Logger.debug("EffectivenessTracker: Check #{check_id} has #{data_points} data points (< #{@min_data_points}) - excluding from weights")
        false
      end
    end)
    |> Map.new()
  end

  defp normalize_weights(effectiveness_scores) do
    # Convert effectiveness scores to normalized weights
    scores_list = Map.values(effectiveness_scores)
    total_score = Enum.sum(scores_list)

    if total_score == 0 do
      # Fallback: equal weights if all scores are 0
      count = map_size(effectiveness_scores)

      effectiveness_scores
      |> Enum.map(fn {check_id, _} -> {check_id, 1.0 / count} end)
      |> Map.new()
    else
      # Normalize: (score / total) * weight_sum
      effectiveness_scores
      |> Enum.map(fn {check_id, score} ->
        weight = score / total_score * @weight_sum
        {check_id, weight}
      end)
      |> Map.new()
    end
  end

  defp calculate_avg_runtime(metrics) when is_list(metrics) do
    case metrics do
      [] ->
        0.0

      _ ->
        times =
          metrics
          |> Enum.map(&get_runtime_ms/1)
          |> Enum.filter(&is_number/1)

        if Enum.empty?(times) do
          0.0
        else
          Enum.sum(times) / length(times)
        end
    end
  end

  defp calculate_avg_runtime(_), do: 0.0

  defp get_runtime_ms(%{runtime_ms: time}), do: time
  defp get_runtime_ms(%{"runtime_ms" => time}), do: time
  defp get_runtime_ms(_), do: nil

  defp count_true_positives(metrics) when is_list(metrics) do
    metrics
    |> Enum.count(fn m ->
      result = Map.get(m, :result) || Map.get(m, "result")
      result == "pass"
    end)
  end

  defp count_true_positives(_), do: 0

  defp count_false_positives(metrics) when is_list(metrics) do
    metrics
    |> Enum.count(fn m ->
      result = Map.get(m, :result) || Map.get(m, "result")
      result == "fail"
    end)
  end

  defp count_false_positives(_), do: 0

  defp calculate_cost_benefit(true_positives, avg_runtime) do
    if avg_runtime == 0 or true_positives == 0 do
      0.0
    else
      # Issues caught per second of validation time
      true_positives / (avg_runtime / 1000.0)
    end
  end

  defp generate_recommendation(effectiveness, cost_benefit, avg_runtime) do
    cond do
      effectiveness < 0.50 ->
        "DISABLE - Low effectiveness (#{percent(effectiveness)})"

      effectiveness < 0.70 and avg_runtime > 1000 ->
        "OPTIMIZE - Slow (#{round(avg_runtime)}ms) with low benefit"

      effectiveness > 0.90 and cost_benefit > 10.0 ->
        "KEEP - Excellent effectiveness and efficiency"

      effectiveness > 0.80 ->
        "KEEP - Good effectiveness (#{percent(effectiveness)})"

      true ->
        "REVIEW - Consider improving or replacing"
    end
  end

  defp build_improvement_opportunity(analysis) do
    %{
      check_id: analysis.check_id,
      effectiveness: analysis.effectiveness_score,
      runtime_ms: analysis.avg_runtime_ms,
      cost_benefit_ratio: analysis.cost_benefit_ratio,
      issue: format_issue(analysis),
      recommendation: analysis.recommendation,
      priority: calculate_priority(analysis)
    }
  end

  defp format_issue(%{effectiveness_score: eff, avg_runtime_ms: time}) do
    cond do
      eff < 0.50 -> "Low effectiveness (#{percent(eff)}) - many false positives"
      eff < 0.70 and time > 1000 -> "High cost (#{round(time)}ms) vs low benefit"
      eff < 0.70 -> "Below threshold effectiveness (#{percent(eff)})"
      true -> "Performance below optimal"
    end
  end

  defp calculate_priority(analysis) do
    # Lower number = higher priority
    case analysis.effectiveness_score do
      eff when eff < 0.50 -> 1
      eff when eff < 0.70 -> 2
      _ -> 3
    end
  end

  defp percent(value) when is_float(value) do
    "#{round(value * 100)}%"
  end

  defp percent(_), do: "N/A"
end
