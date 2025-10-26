defmodule ObserverWeb.AdaptiveThresholdLive do
  use ObserverWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("AdaptiveThresholdLive: Mounting")

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

  @impl true
  def handle_event("reset_threshold", _params, socket) do
    Logger.warning("AdaptiveThresholdLive: User requested threshold reset")

    case Singularity.Evolution.AdaptiveConfidenceGating.reset_to_default() do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Threshold reset to default (0.85)")
         |> fetch_metrics()}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to reset threshold: #{inspect(reason)}")
         |> fetch_metrics()}
    end
  end

  defp fetch_metrics(socket) do
    try do
      metrics = Singularity.Evolution.RuleQualityDashboard.get_adaptive_threshold_metrics()

      socket
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:metrics, metrics)
    rescue
      error ->
        Logger.error("AdaptiveThresholdLive: Error fetching metrics",
          error: inspect(error)
        )

        socket
        |> assign(:loading, false)
        |> assign(:error, "Failed to load metrics: #{inspect(error)}")
        |> assign(:metrics, nil)
    end
  end

  defp status_badge(status) do
    case status do
      :converged ->
        {"✅ Converged", "bg-green-100 text-green-800"}

      :adjusting ->
        {"🔧 Adjusting", "bg-blue-100 text-blue-800"}

      :initializing ->
        {"🔄 Initializing", "bg-yellow-100 text-yellow-800"}

      :max_threshold_reached ->
        {"⚠️ Max Threshold", "bg-red-100 text-red-800"}

      :min_threshold_reached ->
        {"⚠️ Min Threshold", "bg-red-100 text-red-800"}

      _ ->
        {"❓ Unknown", "bg-gray-100 text-gray-800"}
    end
  end

  defp direction_badge(direction) do
    case direction do
      :stable -> {"→ Stable", "bg-green-50 text-green-700"}
      :raise_threshold -> {"↑ Raising", "bg-orange-50 text-orange-700"}
      :lower_threshold -> {"↓ Lowering", "bg-blue-50 text-blue-700"}
      _ -> {"→ Unknown", "bg-gray-50 text-gray-700"}
    end
  end

  defp bar_width(value, max) do
    case max do
      0 -> 0
      _ -> value / max * 100
    end
  end

  defp success_bar_color(rate) do
    cond do
      rate >= 0.95 -> "bg-green-500"
      rate >= 0.90 -> "bg-green-400"
      rate >= 0.85 -> "bg-yellow-400"
      rate >= 0.75 -> "bg-orange-400"
      true -> "bg-red-400"
    end
  end

  defp format_float(value) when is_float(value), do: Float.round(value, 3)
  defp format_float(value) when is_nil(value), do: "N/A"
  defp format_float(value) when is_number(value), do: Float.round(value / 1.0, 3)
  defp format_float(_), do: "N/A"

  defp format_percent(value) when is_float(value) do
    "#{Float.round(value * 100, 1)}%"
  end

  defp format_percent(value) when is_number(value) do
    "#{Float.round(value * 100 / 1.0, 1)}%"
  end

  defp format_percent(_), do: "N/A"

  defp format_time(nil), do: "Never"

  defp format_time(datetime) do
    case datetime do
      %DateTime{} ->
        datetime
        |> DateTime.to_naive()
        |> NaiveDateTime.to_string()
        |> String.slice(0..18)

      _ ->
        "Unknown"
    end
  end
end
