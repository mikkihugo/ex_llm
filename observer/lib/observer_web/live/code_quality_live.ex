defmodule ObserverWeb.CodeQualityLive do
  use ObserverWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("CodeQualityLive: Mounting")

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
      {:ok, dashboard} = Singularity.Analysis.CodeQualityDashboard.get_dashboard()

      socket
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:dashboard, dashboard)
    rescue
      error ->
        Logger.error("CodeQualityLive: Error fetching metrics",
          error: inspect(error)
        )

        socket
        |> assign(:loading, false)
        |> assign(:error, "Failed to load code quality metrics: #{inspect(error)}")
        |> assign(:dashboard, nil)
    end
  end

  defp health_badge(status) do
    case status do
      :excellent -> {"✅ Excellent", "bg-green-100 text-green-800"}
      :good -> {"👍 Good", "bg-blue-100 text-blue-800"}
      :fair -> {"⚠️ Fair", "bg-yellow-100 text-yellow-800"}
      :poor -> {"❌ Poor", "bg-red-100 text-red-800"}
      _ -> {"❓ Unknown", "bg-gray-100 text-gray-800"}
    end
  end

  defp trend_badge(trend) do
    case trend do
      :improving -> {"📈 Improving", "bg-green-50 text-green-700"}
      :stable -> {"→ Stable", "bg-gray-50 text-gray-700"}
      :declining -> {"📉 Declining", "bg-red-50 text-red-700"}
      _ -> {"Unknown", "bg-gray-50 text-gray-700"}
    end
  end
end
