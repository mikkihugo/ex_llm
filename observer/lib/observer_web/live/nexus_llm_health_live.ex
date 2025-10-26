defmodule ObserverWeb.NexusLLMHealthLive do
  use ObserverWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("NexusLLMHealthLive: Mounting")

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
      dashboard = Singularity.LLM.LLMHealthDashboard.get_dashboard()

      case dashboard do
        {:ok, data} ->
          socket
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> assign(:dashboard, data)

        {:error, reason} ->
          socket
          |> assign(:loading, false)
          |> assign(:error, "Failed to load metrics: #{inspect(reason)}")
          |> assign(:dashboard, nil)
      end
    rescue
      error ->
        Logger.error("NexusLLMHealthLive: Error fetching metrics", error: inspect(error))

        socket
        |> assign(:loading, false)
        |> assign(:error, "Error loading LLM health metrics")
        |> assign(:dashboard, nil)
    end
  end

  defp health_badge(health) do
    case health do
      :excellent -> {"✅ Excellent", "bg-green-100 text-green-800"}
      :good -> {"✅ Good", "bg-green-100 text-green-800"}
      :fair -> {"⚠️ Fair", "bg-yellow-100 text-yellow-800"}
      :poor -> {"⚠️ Poor", "bg-orange-100 text-orange-800"}
      :critical -> {"❌ Critical", "bg-red-100 text-red-800"}
      :unknown -> {"❓ Unknown", "bg-gray-100 text-gray-800"}
      _ -> {"❓ Unknown", "bg-gray-100 text-gray-800"}
    end
  end

  defp state_color(:closed), do: "bg-green-500"
  defp state_color(:half_open), do: "bg-yellow-500"
  defp state_color(:open), do: "bg-red-500"
  defp state_color(_), do: "bg-gray-500"
end
