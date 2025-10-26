defmodule ObserverWeb.ValidationMetricsLive do
  use ObserverWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("ValidationMetricsLive: Mounting")

    if connected?(socket) do
      :timer.send_interval(15000, self(), :refresh_metrics)
    end

    {:ok,
     socket
     |> assign(:loading, true)
     |> assign(:error, nil)
     |> assign(:time_range, :last_week)
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

  @impl true
  def handle_event("set_time_range", %{"range" => range}, socket) do
    {:noreply,
     socket
     |> assign(:time_range, String.to_atom(range))
     |> fetch_metrics()}
  end

  defp fetch_metrics(socket) do
    try do
      dashboard = Singularity.Validation.ValidationDashboard.get_dashboard()

      case dashboard do
        {:ok, data} ->
          time_range = socket.assigns[:time_range] || :last_week

          kpi_key =
            case time_range do
              :last_hour -> :last_hour
              :last_day -> :last_day
              :last_week -> :last_week
              _ -> :last_week
            end

          kpi = data[kpi_key]

          socket
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> assign(:dashboard, data)
          |> assign(:current_kpi, kpi)

        {:error, reason} ->
          socket
          |> assign(:loading, false)
          |> assign(:error, "Failed to load metrics: #{inspect(reason)}")
          |> assign(:dashboard, nil)
          |> assign(:current_kpi, nil)
      end
    rescue
      error ->
        Logger.error("ValidationMetricsLive: Error fetching metrics", error: inspect(error))

        socket
        |> assign(:loading, false)
        |> assign(:error, "Error loading validation metrics")
        |> assign(:dashboard, nil)
        |> assign(:current_kpi, nil)
    end
  end

  defp health_status(accuracy, success_rate) do
    cond do
      accuracy >= 0.90 and success_rate >= 0.90 -> "✅ Excellent"
      accuracy >= 0.85 and success_rate >= 0.85 -> "✅ Good"
      accuracy >= 0.75 and success_rate >= 0.75 -> "⚠️ Fair"
      true -> "❌ Poor"
    end
  end

  defp health_color(accuracy, success_rate) do
    cond do
      accuracy >= 0.90 and success_rate >= 0.90 -> "bg-green-600"
      accuracy >= 0.85 and success_rate >= 0.85 -> "bg-green-500"
      accuracy >= 0.75 and success_rate >= 0.75 -> "bg-yellow-500"
      true -> "bg-red-500"
    end
  end

  defp trend_arrow(:improving), do: "📈 Improving"
  defp trend_arrow(:declining), do: "📉 Declining"
  defp trend_arrow(:stable), do: "→ Stable"
  defp trend_arrow(_), do: "❓ Unknown"

  defp priority_color("HIGH"), do: "bg-red-100 text-red-800"
  defp priority_color("MEDIUM"), do: "bg-yellow-100 text-yellow-800"
  defp priority_color("LOW"), do: "bg-blue-100 text-blue-800"
  defp priority_color("INFO"), do: "bg-green-100 text-green-800"
  defp priority_color(_), do: "bg-gray-100 text-gray-800"
end
