defmodule ObserverWeb.CodeQualityLive do
  use ObserverWeb.DashboardLive, fetch: &Observer.Dashboard.code_quality/0

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">Code Quality</h1>
          <p class="text-sm text-zinc-500 mt-1">Quality, complexity, and test coverage insights.</p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load code quality metrics</p>
          <p class="text-sm mt-1"><%= @error %></p>
        </div>
      <% end %>

      <%= if @data do %>
        <div class="grid gap-6 md:grid-cols-2">
          <section class="rounded-xl border border-zinc-200 bg-white shadow-sm p-6 space-y-3">
            <header class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-zinc-900">Health Status</h2>
              <span class={status_badge(@data.health_status)}>
                <%= String.upcase(to_string(@data.health_status || :unknown)) %>
              </span>
            </header>
            <dl class="space-y-2 text-sm text-zinc-700">
              <div class="flex justify-between">
                <dt class="font-medium">Quality score</dt>
                <dd><%= metric(@data.current_metrics, :quality_score) %></dd>
              </div>
              <div class="flex justify-between">
                <dt class="font-medium">Documentation coverage</dt>
                <dd><%= percent(Map.get(@data.documentation_coverage || %{}, :overall)) %></dd>
              </div>
              <div class="flex justify-between">
                <dt class="font-medium">Cyclomatic complexity</dt>
                <dd><%= metric(@data.complexity_metrics, :cyclomatic_complexity) %></dd>
              </div>
              <div class="flex justify-between">
                <dt class="font-medium">Files scanned</dt>
                <dd><%= metric(@data.current_metrics, :modules_analyzed) %></dd>
              </div>
            </dl>
          </section>

          <section class="rounded-xl border border-zinc-200 bg-white shadow-sm p-6 space-y-3">
            <header>
              <h2 class="text-lg font-semibold text-zinc-900">Test Metrics</h2>
            </header>
            <dl class="space-y-2 text-sm text-zinc-700">
              <div class="flex justify-between">
                <dt class="font-medium">Coverage</dt>
                <dd><%= percent(metric(@data.test_metrics, :coverage)) %></dd>
              </div>
              <div class="flex justify-between">
                <dt class="font-medium">Passing suites</dt>
                <dd><%= metric(@data.test_metrics, :passing_suites) %></dd>
              </div>
              <div class="flex justify-between">
                <dt class="font-medium">Flaky tests</dt>
                <dd><%= metric(@data.test_metrics, :flaky_tests) %></dd>
              </div>
            </dl>
            <div class="rounded-lg border border-zinc-200 bg-zinc-50 p-3 text-xs text-zinc-600">
              <p class="font-medium text-zinc-700 mb-1">Violations</p>
              <%= for {type, count} <- Map.get(@data.violations_summary || %{}, :by_type, []) do %>
                <p>
                  <%= String.capitalize(to_string(type)) %>:
                  <span class="font-semibold"><%= count %></span>
                </p>
              <% end %>
            </div>
          </section>
        </div>

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

  defp percent(%{percent: value}), do: percent(value)
  defp percent(_), do: "n/a"

  defp metric(nil, _), do: "n/a"
  defp metric(map, key) when is_map(map), do: Map.get(map, key, "n/a")
  defp metric(value, _), do: value || "n/a"

  defp status_badge(:excellent),
    do:
      "inline-flex items-center rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold text-emerald-700"

  defp status_badge(:good),
    do:
      "inline-flex items-center rounded-full bg-sky-100 px-3 py-1 text-xs font-semibold text-sky-700"

  defp status_badge(:fair),
    do:
      "inline-flex items-center rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-700"

  defp status_badge(:poor),
    do:
      "inline-flex items-center rounded-full bg-rose-100 px-3 py-1 text-xs font-semibold text-rose-700"

  defp status_badge(_),
    do:
      "inline-flex items-center rounded-full bg-zinc-100 px-3 py-1 text-xs font-semibold text-zinc-600"
end
