defmodule ObserverWeb.DashboardLive do
  @moduledoc """
  Macro that injects refresh/load behaviour for dashboard style LiveViews.
  """

  defmacro __using__(opts) do
    fetch_fun = Keyword.fetch!(opts, :fetch)
    refresh_interval = Keyword.get(opts, :refresh_interval, quote(do: :timer.seconds(5)))

    quote do
      use ObserverWeb, :live_view

      @refresh_interval unquote(refresh_interval)
      @fetch_fun unquote(fetch_fun)

      @impl true
      def mount(_params, _session, socket) do
        socket =
          socket
          |> assign(:data, nil)
          |> assign(:error, nil)
          |> assign(:last_updated, nil)

        socket = refresh_data(socket)
        if connected?(socket), do: schedule_refresh()
        {:ok, socket}
      end

      @impl true
      def handle_info(:refresh, socket) do
        if connected?(socket), do: schedule_refresh()
        {:noreply, refresh_data(socket)}
      end

      defp schedule_refresh do
        Process.send_after(self(), :refresh, @refresh_interval)
      end

      defp refresh_data(socket) do
        case safe_fetch() do
          {:ok, data} ->
            assign(socket, data: data, error: nil, last_updated: DateTime.utc_now())

          {:error, reason} ->
            assign(socket, error: reason, last_updated: DateTime.utc_now())
        end
      end

      defp safe_fetch do
        try do
          @fetch_fun.()
        rescue
          error ->
            {:error, inspect(error)}
        end
      end

      defp pretty_json(data) do
        case Jason.encode(data, pretty: true) do
          {:ok, json} -> json
          _ -> inspect(data)
        end
      end

      defp format_timestamp(nil), do: "never"
      defp format_timestamp(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
    end
  end
end
