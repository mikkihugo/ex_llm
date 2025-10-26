defmodule ObserverWeb.SystemHealthLive do
  use ObserverWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("SystemHealthLive: Mounting")

    if connected?(socket) do
      :timer.send_interval(30000, self(), :refresh_status)
    end

    {:ok,
     socket
     |> assign(:loading, true)
     |> assign(:error, nil)
     |> fetch_status()}
  end

  @impl true
  def handle_info(:refresh_status, socket) do
    {:noreply, fetch_status(socket)}
  end

  defp fetch_status(socket) do
    try do
      # Fetch all dashboard data
      {:ok, adaptive} = safe_fetch(:adaptive_threshold)
      {:ok, llm} = safe_fetch(:llm_health)
      {:ok, validation} = safe_fetch(:validation)

      socket
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:adaptive_threshold, adaptive)
      |> assign(:llm_health, llm)
      |> assign(:validation, validation)
    rescue
      error ->
        Logger.error("SystemHealthLive: Error fetching status", error: inspect(error))

        socket
        |> assign(:loading, false)
        |> assign(:error, "Error loading system health")
        |> assign(:adaptive_threshold, nil)
        |> assign(:llm_health, nil)
        |> assign(:validation, nil)
    end
  end

  defp safe_fetch(:adaptive_threshold) do
    case Singularity.Evolution.AdaptiveConfidenceGating.get_tuning_status() do
      status -> {:ok, status}
    end
  rescue
    _ -> {:ok, %{convergence_status: :unknown}}
  end

  defp safe_fetch(:llm_health) do
    case Singularity.LLM.LLMHealthDashboard.get_dashboard() do
      {:ok, data} -> {:ok, data[:provider_health]}
      _ -> {:ok, %{overall_health: :unknown}}
    end
  rescue
    _ -> {:ok, %{overall_health: :unknown}}
  end

  defp safe_fetch(:validation) do
    case Singularity.Validation.ValidationDashboard.get_kpis(:last_week) do
      kpi -> {:ok, kpi}
    end
  rescue
    _ -> {:ok, %{is_healthy: false}}
  end

  defp status_to_emoji(:converged), do: "✅"
  defp status_to_emoji(:adjusting), do: "🔧"
  defp status_to_emoji(:initializing), do: "🔄"
  defp status_to_emoji(:excellent), do: "✅"
  defp status_to_emoji(:good), do: "✅"
  defp status_to_emoji(:fair), do: "⚠️"
  defp status_to_emoji(:poor), do: "⚠️"
  defp status_to_emoji(:critical), do: "❌"
  defp status_to_emoji(true), do: "✅"
  defp status_to_emoji(false), do: "❌"
  defp status_to_emoji(_), do: "❓"
end
