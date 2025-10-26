defmodule Singularity.LLM.LLMHealthDashboard do
  @moduledoc """
  LLM Health Dashboard - Monitoring LLM Provider Health via Nexus

  Provides dashboard queries for monitoring LLM provider health, circuit breaker status,
  and performance metrics across all LLM providers (Claude, Gemini, OpenAI, Copilot).

  ## Usage

  ```elixir
  # Get complete LLM health snapshot
  {:ok, dashboard} = LLMHealthDashboard.get_dashboard()

  # Get specific metrics
  health = LLMHealthDashboard.get_provider_health()
  circuits = LLMHealthDashboard.get_circuit_breaker_status()
  alerts = LLMHealthDashboard.get_alerts()
  ```
  """

  require Logger

  @doc """
  Get complete LLM health dashboard.

  Returns all LLM provider metrics and circuit breaker status.

  ## Returns
  - `{:ok, dashboard}` - Complete dashboard data
  - `{:error, reason}` - Retrieval failed
  """
  def get_dashboard do
    Logger.debug("LLMHealthDashboard: Generating complete dashboard")

    try do
      provider_health = get_provider_health()
      circuit_status = get_circuit_breaker_status()
      performance = get_performance_metrics()
      alerts = get_alerts()

      {:ok,
       %{
         provider_health: provider_health,
         circuit_status: circuit_status,
         performance: performance,
         alerts: alerts,
         timestamp: DateTime.utc_now()
       }}
    rescue
      error ->
        Logger.error("LLMHealthDashboard: Error generating dashboard",
          error: inspect(error)
        )

        {:error, error}
    end
  end

  @doc """
  Get health status for each LLM provider.

  Returns health metrics for all configured providers.

  ## Returns
  - Map with provider health data
  """
  def get_provider_health do
    Logger.debug("LLMHealthDashboard: Getting provider health")

    try do
      # Try to get circuit breaker dashboard data if available
      case safe_call_circuit_breaker_dashboard(:health_widget, []) do
        {:ok, widget} ->
          %{
            providers: parse_circuit_breaker_health(widget),
            overall_health: widget[:overall_level],
            overall_score: widget[:overall_score],
            healthy_count: widget[:healthy_circuits],
            unhealthy_count: widget[:unhealthy_circuits],
            critical_count: widget[:critical_circuits],
            status_timestamp: DateTime.utc_now()
          }

        {:error, _} ->
          # Fallback if circuit breaker module not available
          %{
            providers: default_provider_list(),
            overall_health: :unknown,
            overall_score: 0,
            healthy_count: 0,
            unhealthy_count: 0,
            critical_count: 0,
            status_timestamp: DateTime.utc_now()
          }
      end
    rescue
      error ->
        Logger.warning("LLMHealthDashboard: Error getting provider health",
          error: inspect(error)
        )

        %{
          providers: default_provider_list(),
          overall_health: :error,
          overall_score: 0,
          healthy_count: 0,
          unhealthy_count: 0,
          critical_count: 0,
          status_timestamp: DateTime.utc_now()
        }
    end
  end

  @doc """
  Get circuit breaker status for all LLM providers.

  Returns detailed circuit state information.

  ## Returns
  - Map with circuit breaker data
  """
  def get_circuit_breaker_status do
    Logger.debug("LLMHealthDashboard: Getting circuit breaker status")

    try do
      case safe_call_circuit_breaker_dashboard(:state_distribution_widget, []) do
        {:ok, widget} ->
          %{
            closed_circuits: count_by_state(widget[:distribution], :closed),
            open_circuits: count_by_state(widget[:distribution], :open),
            half_open_circuits: count_by_state(widget[:distribution], :half_open),
            total_circuits: widget[:total_circuits],
            distribution: widget[:distribution],
            timestamp: DateTime.utc_now()
          }

        {:error, _} ->
          %{
            closed_circuits: 0,
            open_circuits: 0,
            half_open_circuits: 0,
            total_circuits: 0,
            distribution: [],
            timestamp: DateTime.utc_now()
          }
      end
    rescue
      error ->
        Logger.warning("LLMHealthDashboard: Error getting circuit breaker status",
          error: inspect(error)
        )

        %{
          closed_circuits: 0,
          open_circuits: 0,
          half_open_circuits: 0,
          total_circuits: 0,
          distribution: [],
          timestamp: DateTime.utc_now()
        }
    end
  end

  @doc """
  Get performance metrics for LLM providers.

  Returns throughput, latency, and error rate data.

  ## Returns
  - Map with performance metrics
  """
  def get_performance_metrics do
    Logger.debug("LLMHealthDashboard: Getting performance metrics")

    try do
      case safe_call_circuit_breaker_dashboard(:throughput_widget, []) do
        {:ok, widget} ->
          %{
            total_requests_per_minute: widget[:total_requests_per_minute] || 0,
            average_error_rate: widget[:average_error_rate] || 0.0,
            circuit_data: widget[:circuit_data] || [],
            timestamp: DateTime.utc_now()
          }

        {:error, _} ->
          %{
            total_requests_per_minute: 0,
            average_error_rate: 0.0,
            circuit_data: [],
            timestamp: DateTime.utc_now()
          }
      end
    rescue
      error ->
        Logger.warning("LLMHealthDashboard: Error getting performance metrics",
          error: inspect(error)
        )

        %{
          total_requests_per_minute: 0,
          average_error_rate: 0.0,
          circuit_data: [],
          timestamp: DateTime.utc_now()
        }
    end
  end

  @doc """
  Get current alerts and critical issues.

  Returns list of active alerts and recommendations.

  ## Returns
  - List of alerts
  """
  def get_alerts do
    Logger.debug("LLMHealthDashboard: Getting alerts")

    try do
      case safe_call_circuit_breaker_dashboard(:get_alerts, []) do
        {:ok, alert_summary} ->
          alert_summary[:alerts] || []

        {:error, _} ->
          []
      end
    rescue
      error ->
        Logger.warning("LLMHealthDashboard: Error getting alerts", error: inspect(error))
        []
    end
  end

  # Private Helpers

  defp safe_call_circuit_breaker_dashboard(function, args) do
    try do
      # Try to call ExLLM.Infrastructure.CircuitBreaker.Metrics.Dashboard functions
      module = :"Elixir.ExLLM.Infrastructure.CircuitBreaker.Metrics.Dashboard"

      if Code.ensure_loaded?(module) do
        apply(module, function, args)
      else
        {:error, :module_not_loaded}
      end
    rescue
      _ -> {:error, :circuit_breaker_unavailable}
    end
  end

  defp parse_circuit_breaker_health(widget) do
    # Extract provider names and map to health info
    default_provider_list()
    |> Enum.map(fn provider ->
      %{
        name: provider[:name],
        health: widget[:overall_level] || :unknown,
        score: widget[:overall_score] || 0,
        status: provider_status(widget[:overall_level])
      }
    end)
  end

  defp default_provider_list do
    [
      %{name: "Claude (Anthropic)", alias: "claude"},
      %{name: "Gemini (Google)", alias: "gemini"},
      %{name: "GPT (OpenAI)", alias: "openai"},
      %{name: "Copilot (Microsoft)", alias: "copilot"}
    ]
  end

  defp provider_status(:excellent), do: "✅ Excellent"
  defp provider_status(:good), do: "✅ Good"
  defp provider_status(:fair), do: "⚠️ Fair"
  defp provider_status(:poor), do: "⚠️ Poor"
  defp provider_status(:critical), do: "❌ Critical"
  defp provider_status(_), do: "❓ Unknown"

  defp count_by_state(distribution, state) do
    distribution
    |> Enum.find(&(&1[:state] == state))
    |> case do
      nil -> 0
      item -> item[:count] || 0
    end
  end
end
