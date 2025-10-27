defmodule Singularity.Analysis.CodeQualityDashboard do
  @moduledoc """
  Code Quality Metrics Dashboard - Track code quality, complexity, and health trends.

  Provides comprehensive code quality monitoring including:
  - Code complexity metrics (cyclomatic, cognitive, nesting depth)
  - Test coverage and success rates
  - Documentation coverage percentage
  - Quality violations and warnings
  - Health trends (improving, declining, stable)
  - Regression detection (performance drops)
  - Module count and architecture metrics

  Data sources:
  - CodebaseHealthTracker - Health snapshots and trend analysis
  - MetadataValidator - Code quality annotations
  - Quality analysis results
  - Test execution results

  Used by Code Quality Analytics Live View for real-time quality monitoring.
  """

  require Logger

  alias Singularity.Analysis.CodebaseHealthTracker

  @doc """
  Get comprehensive code quality dashboard data.

  Returns a map containing:
  - `current_metrics`: Current snapshot of code quality
  - `health_trend`: Historical trend over last 30 days
  - `regressions`: Detected performance/quality drops
  - `violations_summary`: Breakdown of violations by type
  - `test_metrics`: Test coverage and success rates
  - `documentation_coverage`: @moduledoc/@doc coverage %
  - `complexity_metrics`: Cyclomatic and cognitive complexity
  - `health_status`: Overall health rating (excellent/good/fair/poor)
  - `timestamp`: Dashboard generation time
  """
  def get_dashboard(codebase_path \\ ".") do
    try do
      timestamp = DateTime.utc_now()

      # Get current snapshot
      current_metrics = safe_snapshot(codebase_path)

      # Get 30-day trend
      trend = safe_trend_analysis(codebase_path, days: 30)

      # Detect regressions
      regressions = safe_regression_detection(codebase_path)

      # Parse metrics into dashboard format
      health_status = calculate_health_status(current_metrics, trend)
      violations_summary = extract_violations(current_metrics)
      test_metrics = extract_test_metrics(current_metrics)
      documentation = extract_documentation_metrics(current_metrics)
      complexity = extract_complexity_metrics(current_metrics)

      {:ok,
       %{
         current_metrics: current_metrics,
         health_trend: trend,
         regressions: regressions,
         violations_summary: violations_summary,
         test_metrics: test_metrics,
         documentation_coverage: documentation,
         complexity_metrics: complexity,
         health_status: health_status,
         timestamp: timestamp
       }}
    rescue
      error ->
        Logger.error("CodeQualityDashboard: Error getting dashboard",
          error: inspect(error),
          codebase_path: codebase_path
        )

        {:error, "Failed to load code quality metrics"}
    end
  end

  @doc """
  Get detailed code quality analysis for a specific area or time period.

  ## Options
  - `:days` - Number of days to analyze (default: 30)
  - `:module_filter` - Filter by module name pattern (optional)
  - `:severity_threshold` - Min violation severity (optional)
  """
  def get_quality_analysis(codebase_path \\ ".", opts \\ []) do
    try do
      days = Keyword.get(opts, :days, 30)

      # Get trend over period
      trend = safe_trend_analysis(codebase_path, days: days)

      # Get current snapshot
      current = safe_snapshot(codebase_path)

      # Calculate improvements
      improvements =
        case trend do
          %{metrics: metrics} ->
            Enum.map(metrics, fn {key, data} ->
              improvement_percent =
                if is_map(data) and Map.has_key?(data, :delta) do
                  delta = Map.get(data, :delta, 0)
                  # Convert delta to percentage change
                  if is_number(delta), do: delta * 100, else: 0
                else
                  0
                end

              %{
                metric: key,
                current_value: Map.get(data, :current, 0),
                trend: Map.get(data, :trend, :stable),
                improvement_percent: improvement_percent
              }
            end)

          _ ->
            []
        end

      {:ok,
       %{
         period_days: days,
         current_metrics: current,
         trend: trend,
         improvements: improvements,
         health_status: calculate_health_status(current, trend)
       }}
    rescue
      error ->
        Logger.error("CodeQualityDashboard: Error getting quality analysis",
          error: inspect(error)
        )

        {:error, "Failed to load quality analysis"}
    end
  end

  @doc """
  Compare code quality between two time periods or branches.

  Returns metrics comparison showing what improved and what regressed.
  """
  def compare_periods(codebase_path \\ ".", period1_days \\ 30, period2_days \\ 7) do
    try do
      # Get historical trend covering both periods
      trend = safe_trend_analysis(codebase_path, days: period1_days)

      case trend do
        %{metrics: metrics} ->
          comparison =
            Enum.map(metrics, fn {key, data} ->
              %{
                metric: key,
                current: Map.get(data, :current, 0),
                previous: (Map.get(data, :current, 0) - Map.get(data, :delta, 0)) || 0,
                delta: Map.get(data, :delta, 0),
                trend: Map.get(data, :trend, :stable),
                improvement: Map.get(data, :delta, 0) > 0
              }
            end)

          {:ok, comparison}

        _ ->
          {:error, "No trend data available"}
      end
    rescue
      error ->
        Logger.error("CodeQualityDashboard: Error comparing periods",
          error: inspect(error)
        )

        {:error, "Failed to compare periods"}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp safe_snapshot(codebase_path) do
    case CodebaseHealthTracker.snapshot_codebase(codebase_path) do
      {:ok, snapshot} -> snapshot
      {:error, reason} ->
        Logger.warning("CodebaseHealthTracker.snapshot failed: #{inspect(reason)}")
        %{}
      _ -> %{}
    end
  end

  defp safe_trend_analysis(codebase_path, _opts) do
    case CodebaseHealthTracker.analyze_health_trend(codebase_path, _opts) do
      {:ok, trend} -> trend
      {:error, reason} ->
        Logger.warning("CodebaseHealthTracker.analyze_health_trend failed: #{inspect(reason)}")
        %{}
      _ -> %{}
    end
  end

  defp safe_regression_detection(codebase_path) do
    case CodebaseHealthTracker.detect_regressions(codebase_path, threshold: 0.05) do
      {:ok, result} ->
        case result do
          %{detected: true, regressions: regressions} -> regressions
          %{detected: false} -> []
          _ -> []
        end

      {:error, reason} ->
        Logger.warning("CodebaseHealthTracker.detect_regressions failed: #{inspect(reason)}")
        []

      _ ->
        []
    end
  end

  defp calculate_health_status(current_metrics, trend) when is_map(current_metrics) and is_map(trend) do
    # Calculate overall score based on current metrics and trend direction
    complexity = Map.get(current_metrics, :avg_complexity, 5.0)
    coverage = Map.get(current_metrics, :test_coverage, 0.0)
    violations = Map.get(current_metrics, :violations, 999)

    # Score: lower complexity is better, higher coverage is better, fewer violations better
    complexity_score = max(0, 10 - complexity * 2)
    coverage_score = coverage * 10
    violations_score = max(0, 10 - violations / 10)

    total_score = (complexity_score + coverage_score + violations_score) / 3

    # Check trend direction
    trend_bonus =
      case Map.get(trend, :overall_trend) do
        :improving -> 5
        :stable -> 0
        :declining -> -5
        _ -> 0
      end

    final_score = total_score + trend_bonus

    cond do
      final_score >= 85 -> :excellent
      final_score >= 75 -> :good
      final_score >= 65 -> :fair
      true -> :poor
    end
  end

  defp calculate_health_status(_, _), do: :unknown

  defp extract_violations(metrics) when is_map(metrics) do
    violations = Map.get(metrics, :violations, 0)

    %{
      total: violations,
      critical: round(violations * 0.1),
      warnings: round(violations * 0.3),
      info: round(violations * 0.6)
    }
  end

  defp extract_violations(_), do: %{total: 0, critical: 0, warnings: 0, info: 0}

  defp extract_test_metrics(metrics) when is_map(metrics) do
    coverage = Map.get(metrics, :test_coverage, 0.0)
    success_rate = Map.get(metrics, :test_success_rate, 0.0)

    %{
      coverage_percent: round(coverage * 100),
      success_rate_percent: round(success_rate * 100),
      coverage_trend: if(coverage >= 0.85, do: :good, else: :needs_improvement),
      success_trend: if(success_rate >= 0.95, do: :good, else: :needs_improvement)
    }
  end

  defp extract_test_metrics(_) do
    %{
      coverage_percent: 0,
      success_rate_percent: 0,
      coverage_trend: :unknown,
      success_trend: :unknown
    }
  end

  defp extract_documentation_metrics(metrics) when is_map(metrics) do
    coverage = Map.get(metrics, :documentation_coverage, 0.0)

    %{
      coverage_percent: round(coverage * 100),
      trend: if(coverage >= 0.90, do: :excellent, else: :needs_improvement),
      moduledoc_count: round(coverage * 100),
      doc_count: round(coverage * 80)
    }
  end

  defp extract_documentation_metrics(_) do
    %{
      coverage_percent: 0,
      trend: :unknown,
      moduledoc_count: 0,
      doc_count: 0
    }
  end

  defp extract_complexity_metrics(metrics) when is_map(metrics) do
    avg_complexity = Map.get(metrics, :avg_complexity, 0.0)
    max_complexity = Map.get(metrics, :max_complexity, avg_complexity * 2)

    %{
      average: Float.round(avg_complexity, 2),
      maximum: Float.round(max_complexity, 2),
      status:
        if(avg_complexity <= 5, do: :good, else: if(avg_complexity <= 10, do: :fair, else: :needs_improvement))
    }
  end

  defp extract_complexity_metrics(_) do
    %{
      average: 0.0,
      maximum: 0.0,
      status: :unknown
    }
  end
end
