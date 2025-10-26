defmodule ObserverWeb.AdaptiveThresholdLive do
  use ObserverWeb.DashboardLive, fetch: &Observer.Dashboard.adaptive_threshold/0

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">Adaptive Threshold</h1>
          <p class="text-sm text-zinc-500 mt-1">
            Confidence gating status for automated rule publishing.
          </p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load adaptive threshold state</p>
          <p class="text-sm mt-1"><%= @error %></p>
        </div>
      <% end %>

      <%= if @data do %>
        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm p-6 space-y-4">
          <header class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold text-zinc-900">Current Threshold</h2>
              <p class="text-xs uppercase tracking-wide text-zinc-400">
                status: <%= @data.status.convergence_status %>
              </p>
            </div>
            <div class="text-right">
              <p class="text-3xl font-bold text-sky-600">
                <%= Float.round(@data.status.current_threshold, 3) %>
              </p>
              <p class="text-xs text-zinc-500">
                Target success rate: <%= percent(@data.status.target_success_rate) %>
              </p>
            </div>
          </header>

          <dl class="grid gap-4 sm:grid-cols-2">
            <div class="rounded-lg bg-sky-50 p-4">
              <dt class="text-xs font-semibold uppercase text-sky-600">Actual success rate</dt>
              <dd class="text-lg font-semibold text-sky-900">
                <%= percent(@data.status.actual_success_rate) %>
              </dd>
            </div>
            <div class="rounded-lg bg-indigo-50 p-4">
              <dt class="text-xs font-semibold uppercase text-indigo-600">Direction</dt>
              <dd class="text-lg font-semibold text-indigo-900">
                <%= human(@data.status.adjustment_direction) %>
              </dd>
            </div>
            <div class="rounded-lg bg-emerald-50 p-4">
              <dt class="text-xs font-semibold uppercase text-emerald-600">Published rules</dt>
              <dd class="text-lg font-semibold text-emerald-900">
                <%= @data.status.published_rules %>
              </dd>
            </div>
            <div class="rounded-lg bg-rose-50 p-4">
              <dt class="text-xs font-semibold uppercase text-rose-600">Successful rules</dt>
              <dd class="text-lg font-semibold text-rose-900">
                <%= @data.status.successful_rules %>
              </dd>
            </div>
          </dl>

          <div class="rounded-lg border border-zinc-200 bg-zinc-50 p-4">
            <p class="text-sm text-zinc-700">
              <span class="font-medium text-zinc-900">Recommendation:</span>
              <%= @data.status.recommendation %>
            </p>
          </div>

          <section class="rounded-lg border border-zinc-100 bg-white">
            <header class="border-b border-zinc-100 px-4 py-2 text-xs font-semibold uppercase tracking-wide text-zinc-400">
              Raw status payload
            </header>
            <pre class="overflow-x-auto whitespace-pre-wrap bg-zinc-900 p-4 text-xs leading-5 text-zinc-100">
    <%= pretty_json(@data) %>
            </pre>
          </section>
        </section>
      <% end %>
    </div>
    """
  end

  defp percent(nil), do: "n/a"

  defp percent(value) when is_number(value),
    do: :io_lib.format("~.2f%", [value * 100]) |> IO.iodata_to_binary()

  defp percent(_), do: "n/a"

  defp human(nil), do: "unknown"

  defp human(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp human(value), do: to_string(value)
end
