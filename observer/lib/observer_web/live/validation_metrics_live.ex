defmodule ObserverWeb.ValidationMetricsLive do
  use ObserverWeb.DashboardLive, fetch: &Observer.Dashboard.validation_metrics/0

  @ranges [last_hour: "Last hour", last_day: "Last day", last_week: "Last week"]

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :ranges, @ranges)

    ~H"""
    <div class="max-w-5xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">Validation Metrics</h1>
          <p class="text-sm text-zinc-500 mt-1">
            Accuracy, execution success, and timing across validation phases.
          </p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load validation metrics</p>
          <p class="text-sm mt-1"><%= @error %></p>
        </div>
      <% end %>

      <%= if @data do %>
        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm">
          <header class="border-b border-zinc-100 px-6 py-4">
            <h2 class="text-lg font-semibold text-zinc-900">Key Performance Indicators</h2>
          </header>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-zinc-100 text-sm">
              <thead class="bg-zinc-50 text-left text-xs font-semibold uppercase tracking-wide text-zinc-500">
                <tr>
                  <th class="px-6 py-3">Range</th>
                  <th class="px-6 py-3">Validation accuracy</th>
                  <th class="px-6 py-3">Execution success</th>
                  <th class="px-6 py-3">Avg validation time</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-zinc-100 bg-white">
                <%= for {key, label} <- @ranges do %>
                  <% kpis = Map.get(@data, key, %{}) %>
                  <tr class="hover:bg-zinc-50">
                    <td class="px-6 py-3 font-medium text-zinc-900"><%= label %></td>
                    <td class="px-6 py-3 text-zinc-700">
                      <%= percent(kpis[:validation_accuracy]) %>
                    </td>
                    <td class="px-6 py-3 text-zinc-700">
                      <%= percent(kpis[:execution_success_rate]) %>
                    </td>
                    <td class="px-6 py-3 text-zinc-700">
                      <%= ms(kpis[:average_validation_time_ms]) %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </section>

        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm">
          <header class="border-b border-zinc-100 px-6 py-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-zinc-900">Raw Dashboard Payload</h2>
            <span class="text-xs font-medium uppercase tracking-wide text-zinc-400">debug</span>
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
