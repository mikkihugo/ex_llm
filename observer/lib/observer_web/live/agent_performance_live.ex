defmodule ObserverWeb.AgentPerformanceLive do
  use ObserverWeb.DashboardLive, fetch: &Observer.Dashboard.agent_performance/0

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">Agent Performance</h1>
          <p class="text-sm text-zinc-500 mt-1">Live metrics for all autonomous agents.</p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load agent metrics</p>
          <p class="text-sm mt-1"><%= @error %></p>
        </div>
      <% end %>

      <%= if @data do %>
        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm">
          <header class="border-b border-zinc-100 px-6 py-4">
            <h2 class="text-lg font-semibold text-zinc-900">Agent Summary</h2>
          </header>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-zinc-100 text-sm">
              <thead class="bg-zinc-50 text-left text-xs font-semibold uppercase tracking-wider text-zinc-500">
                <tr>
                  <th class="px-6 py-3">Agent</th>
                  <th class="px-6 py-3">Success Rate</th>
                  <th class="px-6 py-3">Avg Latency</th>
                  <th class="px-6 py-3">Avg Cost</th>
                  <th class="px-6 py-3">Tasks</th>
                  <th class="px-6 py-3">Errors</th>
                  <th class="px-6 py-3">Version</th>
                  <th class="px-6 py-3">Cycles</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-zinc-100 bg-white">
                <%= for agent <- Map.get(@data, :agent_summaries, []) do %>
                  <tr class="hover:bg-zinc-50">
                    <td class="px-6 py-3 font-medium text-zinc-900"><%= agent.name %></td>
                    <td class="px-6 py-3 text-zinc-700"><%= format_percent(agent.success_rate) %></td>
                    <td class="px-6 py-3 text-zinc-700"><%= format_ms(agent.avg_latency_ms) %></td>
                    <td class="px-6 py-3 text-zinc-700">
                      $<%= cents_to_dollars(agent.avg_cost_cents) %>
                    </td>
                    <td class="px-6 py-3 text-zinc-700"><%= agent.tasks_completed %></td>
                    <td class="px-6 py-3 text-zinc-700"><%= agent.errors %></td>
                    <td class="px-6 py-3 text-zinc-700"><%= agent.version %></td>
                    <td class="px-6 py-3 text-zinc-700"><%= agent.cycles %></td>
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

  defp format_percent(nil), do: "n/a"

  defp format_percent(value) when is_number(value),
    do: :io_lib.format("~.2f%", [value * 100]) |> IO.iodata_to_binary()

  defp format_percent(_), do: "n/a"

  defp format_ms(nil), do: "n/a"

  defp format_ms(value) when is_number(value),
    do: :io_lib.format("~.1f ms", [value]) |> IO.iodata_to_binary()

  defp format_ms(_), do: "n/a"

  defp cents_to_dollars(nil), do: "0.00"

  defp cents_to_dollars(value) when is_number(value),
    do: :io_lib.format("~.2f", [value / 100]) |> IO.iodata_to_binary()

  defp cents_to_dollars(_), do: "0.00"
end
