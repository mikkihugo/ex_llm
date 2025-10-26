defmodule ObserverWeb.CostAnalyticsLive do
  use ObserverWeb.DashboardLive, fetch: &Observer.Dashboard.cost_analysis/0

  @impl true
  def render(assigns) do
    dashboard = assigns.data || %{}

    assigns =
      assigns
      |> assign(:total_cents, Map.get(dashboard, :total_cost_cents))
      |> assign(:forecast_cents, Map.get(dashboard, :forecasted_monthly_cost_cents))

    ~H"""
    <div class="max-w-6xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">Cost Analytics</h1>
          <p class="text-sm text-zinc-500 mt-1">Spending by provider, model, and task type.</p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load cost analytics</p>
          <p class="text-sm mt-1"><%= @error %></p>
        </div>
      <% end %>

      <%= if @data do %>
        <section class="grid gap-4 sm:grid-cols-2">
          <div class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
            <p class="text-xs uppercase tracking-wide text-zinc-400">Total Spend</p>
            <p class="text-3xl font-bold text-emerald-600 mt-1">
              $<%= cents_to_dollars(@total_cents) %>
            </p>
          </div>
          <div class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
            <p class="text-xs uppercase tracking-wide text-zinc-400">Forecast (30 days)</p>
            <p class="text-3xl font-bold text-sky-600 mt-1">
              $<%= cents_to_dollars(@forecast_cents) %>
            </p>
          </div>
        </section>

        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm">
          <header class="border-b border-zinc-100 px-6 py-4">
            <h2 class="text-lg font-semibold text-zinc-900">Spend by Provider</h2>
          </header>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-zinc-100 text-sm">
              <thead class="bg-zinc-50 text-left text-xs font-semibold uppercase tracking-wide text-zinc-500">
                <tr>
                  <th class="px-6 py-3">Provider</th>
                  <th class="px-6 py-3">Cost</th>
                  <th class="px-6 py-3">Executions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-zinc-100 bg-white">
                <%= for entry <- Map.get(@data, :cost_by_provider, []) do %>
                  <tr class="hover:bg-zinc-50">
                    <td class="px-6 py-3 font-medium text-zinc-900"><%= entry.provider %></td>
                    <td class="px-6 py-3 text-zinc-700">
                      $<%= cents_to_dollars(entry.total_cost_cents) %>
                    </td>
                    <td class="px-6 py-3 text-zinc-700"><%= entry.execution_count %></td>
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

  defp cents_to_dollars(nil), do: "0.00"

  defp cents_to_dollars(value) when is_number(value),
    do: :io_lib.format("~.2f", [value / 100]) |> IO.iodata_to_binary()

  defp cents_to_dollars(_), do: "0.00"
end
