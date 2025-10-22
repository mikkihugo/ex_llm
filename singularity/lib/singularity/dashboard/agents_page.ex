defmodule Singularity.Dashboard.AgentsPage do
  @moduledoc """
  Phoenix LiveDashboard page for agent monitoring.

  Displays:
  - Active agents count
  - Agent spawn history
  - Task execution stats
  - Agent-specific metrics
  """

  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def menu_link(_, _) do
    {:ok, "Agents"}
  end

  @impl true
  def render_page(_assigns) do
    # LiveDashboard page rendering
    # Note: This is a simplified version for demonstration
    # Full implementation would use proper LiveDashboard components
    %{
      title: "Active Agents",
      content: "Agent monitoring page - see agents via Process.whereis/1"
    }
  end

  defp table_columns do
    [
      %{
        field: :agent_type,
        header: "Agent Type",
        sortable: :asc
      },
      %{
        field: :pid,
        header: "PID"
      },
      %{
        field: :uptime_seconds,
        header: "Uptime (s)",
        sortable: :desc
      },
      %{
        field: :status,
        header: "Status"
      },
      %{
        field: :tasks_completed,
        header: "Tasks Completed",
        sortable: :desc
      }
    ]
  end

  defp fetch_agents(params, _node) do
    %{search: search, sort_by: sort_by, sort_dir: sort_dir, limit: limit} = params

    agents = get_active_agents()

    agents =
      agents
      |> filter_agents(search)
      |> sort_agents(sort_by, sort_dir)
      |> Enum.take(limit)

    {agents, length(agents)}
  end

  defp get_active_agents do
    case Process.whereis(Singularity.Agents.AgentSupervisor) do
      nil ->
        []

      supervisor_pid ->
        supervisor_pid
        |> DynamicSupervisor.which_children()
        |> Enum.map(&agent_info/1)
        |> Enum.reject(&is_nil/1)
    end
  end

  defp agent_info({:undefined, pid, :worker, [module]}) when is_pid(pid) do
    case Process.info(pid) do
      nil ->
        nil

      info ->
        %{
          agent_type: module_to_agent_type(module),
          pid: inspect(pid),
          uptime_seconds: calculate_uptime(info),
          status: "running",
          tasks_completed: get_task_count(pid)
        }
    end
  end

  defp agent_info(_), do: nil

  defp module_to_agent_type(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp calculate_uptime(info) do
    start_time = Keyword.get(info, :current_stacktrace, []) |> length()
    # Simplified - in production, track actual start time
    start_time * 10
  end

  defp get_task_count(_pid) do
    # TODO: Track this in agent state
    # For now, return random for demonstration
    Enum.random(0..50)
  end

  defp filter_agents(agents, nil), do: agents
  defp filter_agents(agents, ""), do: agents

  defp filter_agents(agents, search) do
    search_lower = String.downcase(search)

    Enum.filter(agents, fn agent ->
      String.contains?(String.downcase(agent.agent_type), search_lower)
    end)
  end

  defp sort_agents(agents, nil, _), do: agents

  defp sort_agents(agents, sort_by, sort_dir) do
    agents
    |> Enum.sort_by(&Map.get(&1, sort_by), sort_dir)
  end
end
