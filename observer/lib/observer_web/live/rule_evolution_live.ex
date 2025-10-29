defmodule ObserverWeb.RuleEvolutionLive do
  use ObserverWeb.DashboardLive, fetch: &Observer.Dashboard.rule_evolution/0

  @impl true
  def render(assigns) do
    dashboard = assigns.data || %{}
    counts = Map.get(dashboard, :rule_counts, %{})
    health = Map.get(dashboard, :evolution_health, %{})

    assigns = assign(assigns, :counts, counts)
    assigns = assign(assigns, :health, health)

    ~H"""
    <div class="max-w-6xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">Rule Evolution</h1>
          <p class="text-sm text-zinc-500 mt-1">
            Monitor promotion stages and effectiveness of generated rules.
          </p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load rule evolution metrics</p>
          <p class="text-sm mt-1"><%= @error %></p>
        </div>
      <% end %>

      <%= if @data do %>
        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm p-6 space-y-3">
          <header class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-zinc-900">Stages</h2>
            <span class={health_badge(@health[:status])}>
              <%= String.upcase(to_string(@health[:status] || :unknown)) %>
            </span>
          </header>
          <dl class="grid gap-4 sm:grid-cols-3 text-sm text-zinc-700">
            <div>
              <dt class="uppercase text-xs font-semibold text-zinc-400">Candidates</dt>
              <dd class="text-lg font-semibold"><%= @counts[:candidate_rules] || 0 %></dd>
            </div>
            <div>
              <dt class="uppercase text-xs font-semibold text-zinc-400">Confident</dt>
              <dd class="text-lg font-semibold"><%= @counts[:confident_rules] || 0 %></dd>
            </div>
            <div>
              <dt class="uppercase text-xs font-semibold text-zinc-400">Published</dt>
              <dd class="text-lg font-semibold"><%= @counts[:published_rules] || 0 %></dd>
            </div>
          </dl>
        </section>

        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm">
          <header class="border-b border-zinc-100 px-6 py-4">
            <h2 class="text-lg font-semibold text-zinc-900">Recent Promotions</h2>
          </header>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-zinc-100 text-sm">
              <thead class="bg-zinc-50 text-left text-xs font-semibold uppercase tracking-wide text-zinc-500">
                <tr>
                  <th class="px-6 py-3">Rule</th>
                  <th class="px-6 py-3">Stage</th>
                  <th class="px-6 py-3">Confidence</th>
                  <th class="px-6 py-3">Promoted</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-zinc-100 bg-white">
                <%= for promotion <- Map.get(@data, :recent_promotions, []) do %>
                  <tr class="hover:bg-zinc-50">
                    <td class="px-6 py-3 font-medium text-zinc-900"><%= promotion[:rule_name] %></td>
                    <td class="px-6 py-3 text-zinc-700"><%= promotion[:new_stage] %></td>
                    <td class="px-6 py-3 text-zinc-700"><%= promotion[:confidence] %></td>
                    <td class="px-6 py-3 text-zinc-700"><%= promotion[:promoted_at] %></td>
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

  defp health_badge(:excellent),
    do:
      "inline-flex items-center rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold text-emerald-700"

  defp health_badge(:good),
    do:
      "inline-flex items-center rounded-full bg-sky-100 px-3 py-1 text-xs font-semibold text-sky-700"

  defp health_badge(:fair),
    do:
      "inline-flex items-center rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700"

  defp health_badge(:poor),
    do:
      "inline-flex items-center rounded-full bg-rose-100 px-3 py-1 text-xs font-semibold text-rose-700"

  defp health_badge(_),
    do:
      "inline-flex items-center rounded-full bg-zinc-100 px-3 py-1 text-xs font-semibold text-zinc-600"
end
