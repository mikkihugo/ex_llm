defmodule Singularity.Validation.ValidationDashboard do
  @moduledoc """
  Validation Dashboard - Monitoring Validation Metrics and KPIs

  Provides dashboard queries for monitoring validation effectiveness, accuracy,
  execution success rates, and performance trends.

  ## 3 Core KPIs

  1. **Validation Accuracy** - % of checks that correctly predict execution success
  2. **Execution Success Rate** - % of plans that executed without errors
  3. **Average Validation Time** - Time spent in validation phase

  ## Usage

  ```elixir
  # Get complete dashboard
  {:ok, dashboard} = ValidationDashboard.get_dashboard()

  # Get specific KPI
  accuracy = ValidationDashboard.get_validation_accuracy(:last_week)
  success_rate = ValidationDashboard.get_execution_success_rate(:last_week)
  ```
  """

  require Logger

  alias Singularity.Storage.ValidationMetricsStore

  @doc """
  Get complete validation dashboard.

  Returns all validation metrics and KPIs.

  ## Returns
  - `{:ok, dashboard}` - Complete dashboard data
  - `{:error, reason}` - Retrieval failed
  """
  def get_dashboard do
    Logger.debug("ValidationDashboard: Generating complete dashboard")

    try do
      # Get KPIs for different time ranges
      last_hour = get_kpis(:last_hour)
      last_day = get_kpis(:last_day)
      last_week = get_kpis(:last_week)

      {:ok,
       %{
         last_hour: last_hour,
         last_day: last_day,
         last_week: last_week,
         trend: analyze_trend(last_hour, last_day, last_week),
         recommendations: generate_recommendations(last_week),
         timestamp: DateTime.utc_now()
       }}
    rescue
      error ->
        Logger.error("ValidationDashboard: Error generating dashboard",
          error: inspect(error)
        )

        {:error, error}
    end
  end

  @doc """
  Get KPIs for a specific time range.

  ## Parameters
  - `time_range` - :last_hour, :last_day, or :last_week

  ## Returns
  - Map with validation_accuracy, success_rate, avg_validation_time
  """
  def get_kpis(time_range \\ :last_week) do
    Logger.debug("ValidationDashboard: Getting KPIs for #{time_range}")

    try do
      accuracy = ValidationMetricsStore.get_validation_accuracy(time_range) || 0.0
      success_rate = ValidationMetricsStore.get_execution_success_rate(time_range) || 0.0
      avg_validation_time = ValidationMetricsStore.get_avg_validation_time(time_range) || 0

      %{
        validation_accuracy: Float.round(accuracy, 3),
        execution_success_rate: Float.round(success_rate, 3),
        average_validation_time_ms: avg_validation_time,
        is_healthy: accuracy >= 0.85 and success_rate >= 0.90,
        timestamp: DateTime.utc_now()
      }
    rescue
      error ->
        Logger.warning("ValidationDashboard: Error getting KPIs for #{time_range}",
          error: inspect(error)
        )

        %{
          validation_accuracy: 0.0,
          execution_success_rate: 0.0,
          average_validation_time_ms: 0,
          is_healthy: false,
          timestamp: DateTime.utc_now()
        }
    end
  end

  @doc """
  Get validation accuracy for time range.

  ## Returns
  - Float between 0.0 and 1.0
  """
  def get_validation_accuracy(time_range \\ :last_week) do
    Logger.debug("ValidationDashboard: Getting validation accuracy")

    try do
      ValidationMetricsStore.get_validation_accuracy(time_range) || 0.0
    rescue
      _ -> 0.0
    end
  end

  @doc """
  Get execution success rate for time range.

  ## Returns
  - Float between 0.0 and 1.0
  """
  def get_execution_success_rate(time_range \\ :last_week) do
    Logger.debug("ValidationDashboard: Getting execution success rate")

    try do
      ValidationMetricsStore.get_execution_success_rate(time_range) || 0.0
    rescue
      _ -> 0.0
    end
  end

  @doc """
  Get average validation time for time range.

  ## Returns
  - Integer milliseconds
  """
  def get_avg_validation_time(time_range \\ :last_week) do
    Logger.debug("ValidationDashboard: Getting average validation time")

    try do
      ValidationMetricsStore.get_avg_validation_time(time_range) || 0
    rescue
      _ -> 0
    end
  end

  # Private Helpers

  defp analyze_trend(last_hour, last_day, last_week) do
    hour_accuracy = last_hour[:validation_accuracy] || 0.0
    day_accuracy = last_day[:validation_accuracy] || 0.0
    week_accuracy = last_week[:validation_accuracy] || 0.0

    accuracy_trend =
      cond do
        hour_accuracy > day_accuracy and day_accuracy > week_accuracy -> :improving
        hour_accuracy < day_accuracy and day_accuracy < week_accuracy -> :declining
        true -> :stable
      end

    hour_success = last_hour[:execution_success_rate] || 0.0
    day_success = last_day[:execution_success_rate] || 0.0
    week_success = last_week[:execution_success_rate] || 0.0

    success_trend =
      cond do
        hour_success > day_success and day_success > week_success -> :improving
        hour_success < day_success and day_success < week_success -> :declining
        true -> :stable
      end

    %{
      accuracy_trend: accuracy_trend,
      success_trend: success_trend,
      overall_trend: if(accuracy_trend == :improving and success_trend == :improving, do: :improving, else: :stable)
    }
  end

  defp generate_recommendations(week_kpis) do
    accuracy = week_kpis[:validation_accuracy] || 0.0
    success_rate = week_kpis[:execution_success_rate] || 0.0

    recommendations = []

    # Accuracy recommendations
    recommendations =
      if accuracy < 0.80 do
        [
          %{
            priority: "HIGH",
            category: "validation_accuracy",
            message: "Validation accuracy is low (#{Float.round(accuracy * 100, 1)}%)",
            action: "Review validation check logic and improve confidence scoring"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if accuracy >= 0.90 do
        [
          %{
            priority: "LOW",
            category: "validation_accuracy",
            message: "Validation accuracy is excellent (#{Float.round(accuracy * 100, 1)}%)",
            action: "Consider using these checks as model for rule evolution"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Success rate recommendations
    recommendations =
      if success_rate < 0.85 do
        [
          %{
            priority: "HIGH",
            category: "success_rate",
            message: "Execution success rate is low (#{Float.round(success_rate * 100, 1)}%)",
            action: "Analyze failed executions and improve plan generation"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if success_rate >= 0.95 do
        [
          %{
            priority: "LOW",
            category: "success_rate",
            message: "Execution success rate is excellent (#{Float.round(success_rate * 100, 1)}%)",
            action: "Plans are executing reliably with current validation"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Balance recommendations
    recommendations =
      if accuracy >= 0.90 and success_rate >= 0.90 do
        [
          %{
            priority: "INFO",
            category: "overall",
            message: "Validation and execution are both healthy",
            action: "System is performing optimally"
          }
          | recommendations
        ]
      else
        recommendations
      end

    Enum.reverse(recommendations)
  end
end
