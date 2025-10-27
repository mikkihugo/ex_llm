defmodule ObserverWeb.TodosLive do
  use ObserverWeb.DashboardLive, fetch: &Observer.Dashboard.todos/0

  @impl true
  def render(assigns) do
    dashboard = assigns.data || %{}
    counts = Map.get(dashboard, :counts, %{})
    swarm = Map.get(dashboard, :swarm, %{})
    recent_todos = Map.get(dashboard, :recent_todos, [])

    ~H"""
    <div class="max-w-7xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-semibold text-zinc-900">Todo Swarm</h1>
          <p class="text-sm text-zinc-500 mt-1">
            Autonomous agent swarm managing task execution and completion.
          </p>
        </div>
        <div class="text-sm text-zinc-500">
          <span class="font-medium text-zinc-700">Updated:</span>
          <%= format_timestamp(@last_updated) %>
        </div>
      </div>

      <%= if @error do %>
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
          <p class="font-medium">Unable to load todo metrics</p>
          <p class="text-sm mt-1"><%= @error %></p>
        </div>
      <% end %>

      <%= if @data do %>
        <!-- Status Overview Cards -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div class="bg-white rounded-lg border border-zinc-200 p-6 shadow-sm">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-yellow-100 rounded-full flex items-center justify-center">
                  <svg class="w-5 h-5 text-yellow-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd" />
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-zinc-500">Pending</p>
                <p class="text-2xl font-semibold text-zinc-900"><%= counts.pending || 0 %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg border border-zinc-200 p-6 shadow-sm">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                  <svg class="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-8.293l-3-3a1 1 0 00-1.414 0l-3 3a1 1 0 001.414 1.414L9 9.414V13a1 1 0 102 0V9.414l1.293 1.293a1 1 0 001.414-1.414z" clip-rule="evenodd" />
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-zinc-500">In Progress</p>
                <p class="text-2xl font-semibold text-zinc-900"><%= counts.in_progress || 0 %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg border border-zinc-200 p-6 shadow-sm">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-green-100 rounded-full flex items-center justify-center">
                  <svg class="w-5 h-5 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-zinc-500">Completed</p>
                <p class="text-2xl font-semibold text-zinc-900"><%= counts.completed || 0 %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg border border-zinc-200 p-6 shadow-sm">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-8 h-8 bg-red-100 rounded-full flex items-center justify-center">
                  <svg class="w-5 h-5 text-red-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-zinc-500">Failed</p>
                <p class="text-2xl font-semibold text-zinc-900"><%= counts.failed || 0 %></p>
              </div>
            </div>
          </div>
        </div>

        <!-- Swarm Status -->
        <div class="bg-white rounded-xl border border-zinc-200 shadow-sm">
          <header class="border-b border-zinc-100 px-6 py-4">
            <h2 class="text-lg font-semibold text-zinc-900">Swarm Status</h2>
          </header>
          <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div class="text-center">
                <p class="text-3xl font-bold text-zinc-900"><%= swarm.active_workers || 0 %></p>
                <p class="text-sm text-zinc-500">Active Workers</p>
              </div>
              <div class="text-center">
                <p class="text-3xl font-bold text-green-600"><%= swarm.completed || 0 %></p>
                <p class="text-sm text-zinc-500">Completed Today</p>
              </div>
              <div class="text-center">
                <p class="text-3xl font-bold text-red-600"><%= swarm.failed || 0 %></p>
                <p class="text-sm text-zinc-500">Failed Today</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Recent Todos -->
        <div class="bg-white rounded-xl border border-zinc-200 shadow-sm">
          <header class="border-b border-zinc-100 px-6 py-4">
            <h2 class="text-lg font-semibold text-zinc-900">Recent Todos</h2>
          </header>
          <div class="overflow-hidden">
            <%= if Enum.empty?(recent_todos) do %>
              <div class="p-6 text-center text-zinc-500">
                <p>No todos found</p>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-zinc-200">
                  <thead class="bg-zinc-50">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">Title</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">Status</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">Priority</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">Complexity</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">Created</th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-zinc-200">
                    <%= for todo <- recent_todos do %>
                      <tr class="hover:bg-zinc-50">
                        <td class="px-6 py-4 whitespace-nowrap">
                          <div class="text-sm font-medium text-zinc-900"><%= todo.title %></div>
                          <%= if todo.description do %>
                            <div class="text-sm text-zinc-500 truncate max-w-xs"><%= todo.description %></div>
                          <% end %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                          <span class={[
                            "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                            status_color(todo.status)
                          ]}>
                            <%= String.capitalize(todo.status) %>
                          </span>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-900">
                          <%= priority_label(todo.priority) %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-900">
                          <%= String.capitalize(todo.complexity || "medium") %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-500">
                          <%= format_timestamp(todo.inserted_at) %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("assigned"), do: "bg-blue-100 text-blue-800"
  defp status_color("in_progress"), do: "bg-purple-100 text-purple-800"
  defp status_color("completed"), do: "bg-green-100 text-green-800"
  defp status_color("failed"), do: "bg-red-100 text-red-800"
  defp status_color("blocked"), do: "bg-gray-100 text-gray-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp priority_label(1), do: "Critical"
  defp priority_label(2), do: "High"
  defp priority_label(3), do: "Medium"
  defp priority_label(4), do: "Low"
  defp priority_label(5), do: "Backlog"
  defp priority_label(_), do: "Unknown"
end
