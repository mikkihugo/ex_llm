defmodule ObserverWeb.NexusLLMHealthLive do
  use ObserverWeb.DashboardLive, fetch: &Observer.Dashboard.llm_health/0

  @impl true
  def render(assigns) do
    dashboard = assigns.data || %{}

    assigns =
      assigns
      |> assign(:provider_health, Map.get(dashboard, :provider_health, %{}))
      |> assign(:providers, Map.get(dashboard, :provider_health, %{}) |> Map.get(:providers, []))
      |> assign(:circuit_status, Map.get(dashboard, :circuit_status, %{}))
      |> assign(:performance, Map.get(dashboard, :performance, %{}))

    ~H"""
    <div class="max-w-6xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">Nexus LLM Health</h1>
          <p class="text-sm text-zinc-500 mt-1">
            Circuit breaker and provider health for queued LLM calls.
          </p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load LLM health metrics</p>
          <p class="text-sm mt-1"><%= @error %></p>
        </div>
      <% end %>

      <%= if @data do %>
        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm p-6">
          <header class="flex items-center justify-between mb-4">
            <div>
              <h2 class="text-lg font-semibold text-zinc-900">Providers</h2>
              <p class="text-xs text-zinc-500">Circuit breaker state by provider.</p>
            </div>
            <span class="text-xs font-medium uppercase tracking-wide text-zinc-400">
              Healthy: <%= @provider_health[:healthy_count] || 0 %> · Unhealthy: <%= @provider_health[
                :unhealthy_count
              ] || 0 %>
            </span>
          </header>
          <div class="grid gap-3 md:grid-cols-2">
            <%= for provider <- @providers do %>
              <div class="rounded-lg border border-zinc-200 bg-zinc-50 p-4">
                <p class="text-sm font-semibold text-zinc-900"><%= provider[:name] || "Unknown" %></p>
                <p class={"mt-1 text-xs font-semibold uppercase " <> status_class(provider[:status])}>
                  <%= provider[:status] |> to_string() |> String.upcase() %>
                </p>
                <p class="text-xs text-zinc-500 mt-2">
                  Error rate: <%= percent(provider[:error_rate]) %> · Availability: <%= percent(
                    provider[:availability]
                  ) %>
                </p>
              </div>
            <% end %>
          </div>
        </section>

        <section class="grid gap-4 md:grid-cols-2">
          <div class="rounded-xl border border-zinc-200 bg-white shadow-sm p-6">
            <h2 class="text-lg font-semibold text-zinc-900">Circuit Status</h2>
            <dl class="mt-3 space-y-2 text-sm text-zinc-700">
              <div class="flex justify-between">
                <dt>Closed circuits</dt>
                <dd><%= @circuit_status[:closed_circuits] || 0 %></dd>
              </div>
              <div class="flex justify-between">
                <dt>Open circuits</dt>
                <dd><%= @circuit_status[:open_circuits] || 0 %></dd>
              </div>
              <div class="flex justify-between">
                <dt>Half-open</dt>
                <dd><%= @circuit_status[:half_open_circuits] || 0 %></dd>
              </div>
            </dl>
          </div>
          <div class="rounded-xl border border-zinc-200 bg-white shadow-sm p-6">
            <h2 class="text-lg font-semibold text-zinc-900">Performance</h2>
            <dl class="mt-3 space-y-2 text-sm text-zinc-700">
              <div class="flex justify-between">
                <dt>Requests / minute</dt>
                <dd><%= @performance[:total_requests_per_minute] || 0 %></dd>
              </div>
              <div class="flex justify-between">
                <dt>Average error rate</dt>
                <dd><%= percent(@performance[:average_error_rate]) %></dd>
              </div>
            </dl>
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

  defp status_class(:healthy), do: "text-emerald-600"
  defp status_class(:warning), do: "text-amber-600"
  defp status_class(:critical), do: "text-rose-600"
  defp status_class(_), do: "text-zinc-500"
end
