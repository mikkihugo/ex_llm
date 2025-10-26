defmodule ObserverWeb.AgentPerformanceLive do
  use ObserverWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("AgentPerformanceLive: Mounting")

    if connected?(socket) do
      # Auto-refresh metrics every 5 seconds
      :timer.send_interval(5000, self(), :refresh_metrics)
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
      {:ok, dashboard} = Singularity.Agents.AgentPerformanceDashboard.get_dashboard()

      socket
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:dashboard, dashboard)
    rescue
      error ->
        Logger.error("AgentPerformanceLive: Error fetching metrics",
          error: inspect(error)
        )

        socket
        |> assign(:loading, false)
        |> assign(:error, "Failed to load agent metrics: #{inspect(error)}")
        |> assign(:dashboard, nil)
    end
  end

  defp status_badge(status) do
    case status do
      :excellent -> {"✅ Excellent", "bg-green-100 text-green-800"}
      :good -> {"👍 Good", "bg-blue-100 text-blue-800"}
      :fair -> {"⚠️ Fair", "bg-yellow-100 text-yellow-800"}
      :needs_improvement -> {"❌ Needs Work", "bg-red-100 text-red-800"}
      _ -> {"❓ Unknown", "bg-gray-100 text-gray-800"}
    end
  end

  defp format_cost(cents) when is_number(cents) do
    cents / 100 |> Float.round(2) |> :erlang.float_to_binary([decimals: 2])
  end

  defp format_cost(_), do: "N/A"

  defp format_percentage(value) when is_number(value) do
    (value * 100) |> Float.round(1) |> :erlang.float_to_binary([decimals: 1])
  end

  defp format_percentage(_), do: "N/A"
end
