defmodule ObserverWeb.TaskExecutionLive do
  use ObserverWeb.DashboardLive, fetch: &Observer.Dashboard.task_execution/0

  @impl true
  def render(assigns) do
    dashboard = assigns.data || %{}
    rates = Map.get(dashboard, :execution_rates, %{})
    timing = Map.get(dashboard, :timing_metrics, %{})

    assigns = assign(assigns, :rates, rates)
    assigns = assign(assigns, :timing, timing)

    ~H"""
    <div class="max-w-6xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">Task Execution</h1>
          <p class="text-sm text-zinc-500 mt-1">
            Success ratios and latency across TaskGraph executions.
          </p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load execution metrics</p>
          <p class="text-sm mt-1"><%= @error %></p>
        </div>
      <% end %>

      <%= if @data do %>
        <section class="grid gap-4 sm:grid-cols-2">
          <div class="rounded-xl border border-zinc-200 bg-white shadow-sm p-6">
            <h2 class="text-lg font-semibold text-zinc-900">Success Overview</h2>
            <dl class="mt-3 space-y-2 text-sm text-zinc-700">
              <div class="flex justify-between">
                <dt>Total executions</dt>
                <dd><%= @rates[:total_executions] || 0 %></dd>
              </div>
              <div class="flex justify-between">
                <dt>Successful</dt>
                <dd><%= @rates[:successful] || 0 %></dd>
              </div>
              <div class="flex justify-between">
                <dt>Failed</dt>
                <dd><%= @rates[:failed] || 0 %></dd>
              </div>
              <div class="flex justify-between">
                <dt>Success rate</dt>
                <dd><%= percent(@rates[:overall_success_rate]) %></dd>
              </div>
            </dl>
          </div>
          <div class="rounded-xl border border-zinc-200 bg-white shadow-sm p-6">
            <h2 class="text-lg font-semibold text-zinc-900">Latency</h2>
            <dl class="mt-3 space-y-2 text-sm text-zinc-700">
              <div class="flex justify-between">
                <dt>Average</dt>
                <dd><%= ms(@timing[:avg_total_time_ms]) %></dd>
              </div>
              <div class="flex justify-between">
                <dt>P95</dt>
                <dd><%= ms(@timing[:p95_total_time_ms]) %></dd>
              </div>
              <div class="flex justify-between">
                <dt>Slowest execution</dt>
                <dd><%= ms(@timing[:slowest_execution_ms]) %></dd>
              </div>
            </dl>
          </div>
        </section>

        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm">
          <header class="border-b border-zinc-100 px-6 py-4">
            <h2 class="text-lg font-semibold text-zinc-900">Raw Dashboard Payload</h2>
          </header>
          <pre class="overflow-x-auto whitespace-pre-wrap bg-zinc-900 p-6 text-xs leading-5 text-zinc-100">
    <%= pretty_json(@data) %>
          </pre>
        </section>
      <% end %>
    </div>
    """
  end

  defp percent(nil), do: "n/a"

  defp percent(value) when is_number(value),
    do: :io_lib.format("~.2f%", [value * 100]) |> IO.iodata_to_binary()

  defp percent(_), do: "n/a"

  defp ms(nil), do: "n/a"

  defp ms(value) when is_number(value),
    do: :io_lib.format("~.1f ms", [value]) |> IO.iodata_to_binary()

  defp ms(_), do: "n/a"
end
