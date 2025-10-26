defmodule ObserverWeb.KnowledgeBaseLive do
  use ObserverWeb.DashboardLive, fetch: &Observer.Dashboard.knowledge_base/0

  @impl true
  def render(assigns) do
    dashboard = assigns.data || %{}

    assigns =
      assigns
      |> assign(:efficiency, get_in(dashboard, [:efficiency_score, :overall]))
      |> assign(:cache_metrics, Map.get(dashboard, :cache_metrics, %{}))
      |> assign(:search_metrics, Map.get(dashboard, :search_metrics, %{}))

    ~H"""
    <div class="max-w-5xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">Knowledge Base</h1>
          <p class="text-sm text-zinc-500 mt-1">Embedding cache efficiency and search quality.</p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load knowledge base metrics</p>
          <p class="text-sm mt-1"><%= @error %></p>
        </div>
      <% end %>

      <%= if @data do %>
        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm p-6 space-y-4">
          <header>
            <h2 class="text-lg font-semibold text-zinc-900">Efficiency Score</h2>
            <p class="text-xs text-zinc-500">Overall knowledge base efficiency rating.</p>
          </header>
          <p class="text-4xl font-bold text-emerald-600"><%= @efficiency || "n/a" %></p>
          <dl class="grid gap-4 sm:grid-cols-3 text-sm text-zinc-700">
            <div>
              <dt class="uppercase text-xs font-semibold text-zinc-400">Cache hit rate</dt>
              <dd class="text-lg font-semibold"><%= percent(@cache_metrics[:hit_rate]) %></dd>
            </div>
            <div>
              <dt class="uppercase text-xs font-semibold text-zinc-400">Search relevance</dt>
              <dd class="text-lg font-semibold"><%= percent(@search_metrics[:relevance_rate]) %></dd>
            </div>
            <div>
              <dt class="uppercase text-xs font-semibold text-zinc-400">Top-K accuracy</dt>
              <dd class="text-lg font-semibold"><%= percent(@search_metrics[:top_k_accuracy]) %></dd>
            </div>
          </dl>
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
end
