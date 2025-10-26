defmodule ObserverWeb.CostAnalyticsLive do
  use ObserverWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    Logger.info("CostAnalyticsLive: Mounting")

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
      {:ok, dashboard} = Singularity.LLM.CostAnalysisDashboard.get_dashboard()

      socket
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:dashboard, dashboard)
    rescue
      error ->
        Logger.error("CostAnalyticsLive: Error fetching metrics",
          error: inspect(error)
        )

        socket
        |> assign(:loading, false)
        |> assign(:error, "Failed to load cost metrics: #{inspect(error)}")
        |> assign(:dashboard, nil)
    end
  end

  defp format_cost(cents) when is_number(cents) do
    (cents / 100) |> Float.round(2) |> :erlang.float_to_binary([decimals: 2])
  end

  defp format_cost(_), do: "N/A"

  defp format_percentage(value) when is_number(value) do
    (value * 100) |> Float.round(1) |> :erlang.float_to_binary([decimals: 1])
  end

  defp format_percentage(_), do: "N/A"
end
