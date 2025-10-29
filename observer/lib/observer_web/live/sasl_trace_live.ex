defmodule ObserverWeb.SASLTraceLive do
  use ObserverWeb.DashboardLive, fetch: &Observer.Dashboard.sasl_traces/0, refresh_interval: :timer.seconds(3)

  @impl true
  def render(assigns) do
    traces = assigns.data[:traces] || []
    stats = assigns.data[:stats] || %{}
    
    assigns = assign(assigns, :traces, traces)
    assigns = assign(assigns, :stats, stats)
    
    ~H"""
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">SASL Trace Viewer</h1>
          <p class="text-sm text-zinc-500 mt-1">
            Real-time SASL error reports, crash reports, and supervisor progress from all applications.
          </p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load SASL traces</p>
          <p class="text-sm mt-1"><%= @error %></p>
          <p class="text-xs mt-2 text-rose-600">
            Make sure SASL logging is enabled in all applications (singularity, genesis, central_services, observer).
          </p>
        </div>
      <% end %>

      <%= if @data do %>
        <!-- Statistics Cards -->
        <section class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div class="rounded-lg border border-zinc-200 bg-white p-4 shadow-sm">
            <div class="text-sm font-medium text-zinc-500">Total Traces</div>
            <div class="mt-1 text-2xl font-semibold text-zinc-900">
              <%= @data[:total_count] || 0 %>
            </div>
          </div>
          
          <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 shadow-sm">
            <div class="text-sm font-medium text-rose-600">Errors</div>
            <div class="mt-1 text-2xl font-semibold text-rose-700">
              <%= @stats[:errors] || 0 %>
            </div>
          </div>
          
          <div class="rounded-lg border border-amber-200 bg-amber-50 p-4 shadow-sm">
            <div class="text-sm font-medium text-amber-600">Warnings</div>
            <div class="mt-1 text-2xl font-semibold text-amber-700">
              <%= @stats[:warnings] || 0 %>
            </div>
          </div>
          
          <div class="rounded-lg border border-zinc-200 bg-white p-4 shadow-sm">
            <div class="text-sm font-medium text-zinc-500">Crash Reports</div>
            <div class="mt-1 text-2xl font-semibold text-zinc-900">
              <%= @stats[:crash_reports] || 0 %>
            </div>
          </div>
        </section>

        <!-- Trace List -->
        <section class="rounded-xl border border-zinc-200 bg-white shadow-sm">
          <div class="border-b border-zinc-200 px-6 py-4">
            <h2 class="text-lg font-semibold text-zinc-900">Recent Traces</h2>
            <p class="text-sm text-zinc-500 mt-1">
              Showing <%= length(@traces) %> most recent SASL events from all applications
            </p>
          </div>
          
          <div class="divide-y divide-zinc-200">
            <%= for trace <- @traces do %>
              <div class={"px-6 py-4 hover:bg-zinc-50 transition-colors " <> severity_bg_class(trace.severity)}>
                <div class="flex items-start justify-between">
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2 mb-2">
                      <%= severity_badge(trace.type) %>
                      <span class="text-xs font-medium text-zinc-500">
                        <%= format_timestamp(trace.timestamp) %>
                      </span>
                      <%= if trace.source do %>
                        <span class="text-xs font-medium text-zinc-400">
                          ? <%= trace.source %>
                        </span>
                      <% end %>
                    </div>
                    <pre class="text-xs font-mono text-zinc-800 whitespace-pre-wrap break-words overflow-x-auto max-h-96 overflow-y-auto"><%= trace.content %></pre>
                  </div>
                </div>
              </div>
            <% end %>
            
            <%= if Enum.empty?(@traces) do %>
              <div class="px-6 py-12 text-center">
                <p class="text-sm text-zinc-500">No SASL traces found</p>
                <p class="text-xs text-zinc-400 mt-1">
                  Check log/sasl-error.log files in each application directory
                </p>
              </div>
            <% end %>
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  defp severity_badge(type) do
    {label, color_class} = case type do
      :crash_report -> {"CRASH", "bg-rose-100 text-rose-800"}
      :supervisor_report -> {"SUPERVISOR", "bg-amber-100 text-amber-800"}
      :error_report -> {"ERROR", "bg-rose-100 text-rose-800"}
      :progress_report -> {"PROGRESS", "bg-blue-100 text-blue-800"}
      :alarm_report -> {"ALARM", "bg-orange-100 text-orange-800"}
      _ -> {"OTHER", "bg-zinc-100 text-zinc-800"}
    end
    
    Phoenix.HTML.raw("""
    <span class="px-2 py-1 text-xs font-semibold rounded #{color_class}">
      #{label}
    </span>
    """)
  end

  defp severity_bg_class(:error), do: "bg-rose-50/50"
  defp severity_bg_class(:warning), do: "bg-amber-50/50"
  defp severity_bg_class(_), do: ""
end
