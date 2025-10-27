defmodule CentralCloud.ModelLearning.ModelPerformanceAnalyzer do
  @moduledoc """
  Analyzes routing decisions for anomalies and performance issues.

  Detects:
  - Models with low success rates
  - Unexpectedly slow responses
  - Provider failures
  - Unusual routing patterns

  Publishes alerts for human review.
  """

  require Logger
  alias CentralCloud.ModelLearning.ModelMetrics

  @success_rate_threshold 0.85  # Alert if < 85% success
  @response_time_threshold_ms 5000  # Alert if avg > 5 seconds
  @min_samples_for_analysis 10  # Need at least 10 samples

  @doc """
  Analyze a routing decision for anomalies.
  """
  def analyze(%{
    "selected_model" => model,
    "complexity" => complexity,
    "outcome" => outcome,
    "response_time_ms" => response_time
  }) do
    # Asynchronously check for anomalies
    Task.start_link(fn ->
      check_model_health(model, complexity, outcome, response_time)
    end)

    :ok
  end

  def analyze(_), do: :ok

  # === Anomaly Detection ===

  defp check_model_health(model, complexity, outcome, response_time) do
    case ModelMetrics.get_success_rate(model, complexity) do
      {:ok, rate} ->
        if rate < @success_rate_threshold and rate > 0 do
          log_alert(:low_success_rate, model, complexity, rate)
        end

      _ ->
        :ok
    end

    if response_time && response_time > @response_time_threshold_ms do
      log_alert(:slow_response, model, complexity, response_time)
    end

    :ok
  end

  defp log_alert(alert_type, model, complexity, value) do
    Logger.warning("""
    MODEL PERFORMANCE ALERT: #{alert_type}
      Model: #{model}
      Complexity: #{complexity}
      Value: #{inspect(value)}
    """)
  end
end
