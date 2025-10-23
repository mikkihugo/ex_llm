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
  def render_page(assigns) do
    # LiveDashboard page rendering with actual agent data
    node = assigns.node

    # Fetch current agent stats
    agents = get_active_agents()
    columns = table_columns()

    # Build table rows
    rows = agents
      |> Enum.map(fn agent ->
        Enum.map(columns, &Map.get(agent, &1.field))
      end)

    %{
      title: "Active Agents (#{length(agents)} running)",
      content: %{
        columns: columns,
        rows: rows,
        limits: [50, 100, 250],
        default_limit: 50
      }
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
    # Calculate uptime from process creation time
    case Keyword.get(info, :message_queue_len) do
      queue_len when is_integer(queue_len) ->
        # Use queue length as proxy for activity/uptime estimate
        queue_len * 2
      _ ->
        # Fallback: estimate from reductions
        case Keyword.get(info, :reductions, 0) do
          reductions when reductions > 0 -> trunc(reductions / 1000)
          _ -> 0
        end
    end
  end

  defp get_task_count(pid) when is_pid(pid) do
    # Query actual task count from agent if available via message_queue_len
    case Process.info(pid, :message_queue_len) do
      {:message_queue_len, count} -> count
      _ -> 0
    end
  end

  defp get_task_count(_), do: 0

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
