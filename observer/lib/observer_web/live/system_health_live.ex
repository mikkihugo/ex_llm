defmodule ObserverWeb.SystemHealthLive do
  use ObserverWeb, :live_view

  alias Observer.Dashboard

  @refresh_interval :timer.seconds(5)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:data, nil)
      |> assign(:error, nil)
      |> assign(:last_updated, nil)

    socket = load(socket)
    if connected?(socket), do: schedule_refresh()

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    if connected?(socket), do: schedule_refresh()
    {:noreply, load(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">System Health</h1>
          <p class="text-sm text-zinc-500 mt-1">
            Unified view of pipeline status across Nexus, validation, execution, and adaptive thresholds.
          </p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load system health</p>
          <p class="text-sm mt-1"><%= @error %></p>
        </div>
      <% end %>

      <%= if @data do %>
        <div class="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
          <.health_card title="LLM Providers" status={llm_status(@data.llm)}>
            <%= if health = @data.llm do %>
              <ul class="space-y-2">
                <%= for provider <- health.provider_health.providers do %>
                  <li class="flex items-center justify-between text-sm">
                    <span class="font-medium text-zinc-800"><%= provider[:name] %></span>
                    <span class={"font-semibold " <> health_color(provider[:status])}>
                      <%= provider[:status] |> to_string() |> String.upcase() %>
                    </span>
                  </li>
                <% end %>
              </ul>
              <p class="text-xs text-zinc-500 mt-3">
                Requests/min: <%= health.performance.total_requests_per_minute %> · Error rate: <%= percentage(
                  health.performance.average_error_rate
                ) %>
              </p>
            <% else %>
              <p class="text-sm text-zinc-500">No Nexus health data available.</p>
            <% end %>
          </.health_card>

          <.health_card title="Validation Pipeline" status={validation_status(@data.validation)}>
            <%= if validation = @data.validation do %>
              <div class="space-y-2 text-sm text-zinc-700">
                <p>
                  <span class="font-semibold">Accuracy:</span> <%= percentage(
                    validation.kpis.accuracy
                  ) %>
                </p>
                <p>
                  <span class="font-semibold">Execution success:</span> <%= percentage(
                    validation.kpis.execution_success_rate
                  ) %>
                </p>
                <p>
                  <span class="font-semibold">Avg validation time:</span> <%= format_ms(
                    validation.kpis.average_validation_time_ms
                  ) %>
                </p>
              </div>
            <% else %>
              <p class="text-sm text-zinc-500">Validation metrics unavailable.</p>
            <% end %>
          </.health_card>

          <.health_card title="Adaptive Threshold" status={adaptive_status(@data.adaptive_threshold)}>
            <%= if adaptive = @data.adaptive_threshold do %>
              <div class="space-y-2 text-sm text-zinc-700">
                <p>
                  <span class="font-semibold">Threshold:</span> <%= Float.round(
                    adaptive.status.current_threshold,
                    3
                  ) %>
                </p>
                <p>
                  <span class="font-semibold">Success rate:</span> <%= percentage(
                    adaptive.status.actual_success_rate
                  ) %>
                </p>
                <p>
                  <span class="font-semibold">Direction:</span> <%= adaptive.status.adjustment_direction
                  |> to_string()
                  |> String.replace("_", " ") %>
                </p>
              </div>
            <% else %>
              <p class="text-sm text-zinc-500">Adaptive threshold state unknown.</p>
            <% end %>
          </.health_card>

          <.health_card title="Task Execution" status={task_status(@data.task_execution)}>
            <%= if task = @data.task_execution do %>
              <div class="space-y-2 text-sm text-zinc-700">
                <p>
                  <span class="font-semibold">Success rate:</span> <%= percentage(
                    task.overview.success_rate
                  ) %>
                </p>
                <p>
                  <span class="font-semibold">Avg duration:</span> <%= format_ms(
                    task.overview.average_duration_ms
                  ) %>
                </p>
                <p>
                  <span class="font-semibold">Running tasks:</span> <%= task.overview.running_tasks %>
                </p>
              </div>
            <% else %>
              <p class="text-sm text-zinc-500">No task execution metrics available.</p>
            <% end %>
          </.health_card>

          <.health_card title="Cost Analytics" status={cost_status(@data.cost)}>
            <%= if cost = @data.cost do %>
              <div class="space-y-2 text-sm text-zinc-700">
                <p>
                  <span class="font-semibold">24h spend:</span>
                  $<%= cents_to_dollars(cost.summary.last_24h_spend_cents) %>
                </p>
                <p>
                  <span class="font-semibold">MTD spend:</span>
                  $<%= cents_to_dollars(cost.summary.month_to_date_spend_cents) %>
                </p>
                <p>
                  <span class="font-semibold">Top provider:</span> <%= cost.summary.top_provider %>
                </p>
              </div>
            <% else %>
              <p class="text-sm text-zinc-500">Cost metrics unavailable.</p>
            <% end %>
          </.health_card>
        </div>
      <% end %>
    </div>
    """
  end

  defp load(socket) do
    case Dashboard.system_health() do
      {:ok, data} ->
        assign(socket, data: data, error: nil, last_updated: DateTime.utc_now())

      {:error, reason} ->
        assign(socket,
          error: reason,
          last_updated: DateTime.utc_now()
        )
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp format_timestamp(nil), do: "never"
  defp format_timestamp(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")

  defp percentage(nil), do: "n/a"
  defp percentage(value) when is_float(value), do: "#{Float.round(value * 100, 2)}%"
  defp percentage(value) when is_number(value), do: "#{Float.round(value * 100 / 1, 2)}%"
  defp percentage(_), do: "n/a"

  defp format_ms(nil), do: "n/a"
  defp format_ms(value) when is_number(value), do: "#{Float.round(value, 1)} ms"
  defp format_ms(_), do: "n/a"

  defp cents_to_dollars(nil), do: "0.00"

  defp cents_to_dollars(cents) when is_number(cents),
    do: :io_lib.format("~.2f", [cents / 100]) |> IO.iodata_to_binary()

  defp cents_to_dollars(_), do: "0.00"

  defp llm_status(nil), do: :unknown
  defp llm_status(%{provider_health: %{overall_health: health}}), do: health || :unknown
  defp llm_status(_), do: :unknown

  defp validation_status(nil), do: :unknown

  defp validation_status(%{kpis: %{accuracy: acc}}) when is_number(acc) do
    cond do
      acc >= 0.9 -> :healthy
      acc >= 0.8 -> :warning
      true -> :critical
    end
  end

  defp validation_status(_), do: :unknown

  defp adaptive_status(nil), do: :unknown
  defp adaptive_status(%{status: %{convergence_status: status}}), do: status || :unknown
  defp adaptive_status(_), do: :unknown

  defp task_status(nil), do: :unknown

  defp task_status(%{overview: %{success_rate: rate}}) when is_number(rate) do
    cond do
      rate >= 0.9 -> :healthy
      rate >= 0.75 -> :warning
      true -> :critical
    end
  end

  defp task_status(_), do: :unknown

  defp cost_status(nil), do: :unknown
  defp cost_status(%{summary: %{spend_trend: trend}}), do: trend || :unknown
  defp cost_status(_), do: :unknown

  defp health_color(:healthy), do: "text-green-600"
  defp health_color(:warning), do: "text-amber-600"
  defp health_color(:critical), do: "text-rose-600"
  defp health_color(_), do: "text-zinc-500"

  attr :title, :string, required: true
  attr :status, :any, default: :unknown
  slot :inner_block, required: true

  defp health_card(assigns) do
    ~H"""
    <section class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
      <header class="flex items-start justify-between mb-4">
        <div>
          <h2 class="text-lg font-semibold text-zinc-900"><%= @title %></h2>
          <p class="text-xs uppercase tracking-wide text-zinc-400"><%= status_label(@status) %></p>
        </div>
        <span class={"inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold " <> status_badge_color(@status)}>
          <%= status_chip(@status) %>
        </span>
      </header>
      <div class="space-y-2 text-sm text-zinc-700">
        <%= render_slot(@inner_block) %>
      </div>
    </section>
    """
  end

  defp status_label(:healthy), do: "Healthy"
  defp status_label(:closed), do: "Healthy"
  defp status_label(:warning), do: "Warning"
  defp status_label(:open), do: "Open circuit"
  defp status_label(:half_open), do: "Half-open"
  defp status_label(:critical), do: "Critical"
  defp status_label(:max_threshold_reached), do: "Max threshold"
  defp status_label(:min_threshold_reached), do: "Min threshold"
  defp status_label(:converged), do: "Converged"
  defp status_label(:adjusting), do: "Adjusting"
  defp status_label(:initializing), do: "Initializing"
  defp status_label(_), do: "Unknown"

  defp status_chip(:healthy), do: "HEALTHY"
  defp status_chip(:warning), do: "WARNING"
  defp status_chip(:critical), do: "CRITICAL"
  defp status_chip(:converged), do: "CONVERGED"
  defp status_chip(:max_threshold_reached), do: "THRESHOLD HIGH"
  defp status_chip(:min_threshold_reached), do: "THRESHOLD LOW"
  defp status_chip(:adjusting), do: "ADJUSTING"
  defp status_chip(:initializing), do: "INITIALIZING"
  defp status_chip(:open), do: "OPEN"
  defp status_chip(:half_open), do: "HALF-OPEN"
  defp status_chip(_), do: "UNKNOWN"

  defp status_badge_color(:healthy), do: "bg-emerald-100 text-emerald-700"
  defp status_badge_color(:warning), do: "bg-amber-100 text-amber-700"
  defp status_badge_color(:critical), do: "bg-rose-100 text-rose-700"
  defp status_badge_color(:converged), do: "bg-sky-100 text-sky-700"
  defp status_badge_color(:adjusting), do: "bg-violet-100 text-violet-700"
  defp status_badge_color(:initializing), do: "bg-zinc-100 text-zinc-600"
  defp status_badge_color(:open), do: "bg-rose-100 text-rose-700"
  defp status_badge_color(:half_open), do: "bg-amber-100 text-amber-700"
  defp status_badge_color(:max_threshold_reached), do: "bg-rose-100 text-rose-700"
  defp status_badge_color(:min_threshold_reached), do: "bg-amber-100 text-amber-700"
  defp status_badge_color(_), do: "bg-zinc-100 text-zinc-500"
end
