defmodule ObserverWeb.RuleEvolutionLive do
  use ObserverWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("RuleEvolutionLive: Mounting")

    if connected?(socket) do
      :timer.send_interval(10000, self(), :refresh_metrics)
    end

    {:ok,
     socket
     |> assign(:loading, true)
     |> assign(:error, nil)
     |> fetch_metrics()}
  end

  @impl true
  def handle_info(:refresh_metrics, socket) do
    {:noreply, fetch_metrics(socket)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, fetch_metrics(socket)}
  end

  defp fetch_metrics(socket) do
    try do
      {:ok, dashboard} = Singularity.Evolution.RuleEvolutionProgressDashboard.get_dashboard()

      socket
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:dashboard, dashboard)
    rescue
      error ->
        Logger.error("RuleEvolutionLive: Error fetching metrics",
          error: inspect(error)
        )

        socket
        |> assign(:loading, false)
        |> assign(:error, "Failed to load rule evolution metrics: #{inspect(error)}")
        |> assign(:dashboard, nil)
    end
  end

  defp confidence_color(confidence) when is_number(confidence) do
    cond do
      confidence >= 0.95 -> "bg-green-100 text-green-800"
      confidence >= 0.90 -> "bg-blue-100 text-blue-800"
      confidence >= 0.85 -> "bg-yellow-100 text-yellow-800"
      confidence >= 0.75 -> "bg-orange-100 text-orange-800"
      true -> "bg-red-100 text-red-800"
    end
  end

  defp effectiveness_badge(effectiveness) do
    case effectiveness do
      :excellent -> {"✅ Excellent", "bg-green-100 text-green-800"}
      :good -> {"👍 Good", "bg-blue-100 text-blue-800"}
      :fair -> {"⚠️ Fair", "bg-yellow-100 text-yellow-800"}
      :needs_improvement -> {"❌ Needs Work", "bg-red-100 text-red-800"}
      _ -> {"❓ Unknown", "bg-gray-100 text-gray-800"}
    end
  end

  defp status_color(status) do
    case status do
      :active -> "text-green-600"
      :inactive -> "text-gray-600"
      _ -> "text-gray-600"
    end
  end
end
