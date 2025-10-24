defmodule Singularity.AgentSupervisor do
  @moduledoc """
  Supervises dynamically generated agent workers.

  Provides control operations for all supervised agents:
  - `pause_all_agents/0` - Pause all agents at once
  - `resume_all_agents/0` - Resume all agents at once
  - `get_all_agents/0` - Get list of all agent PIDs

  ## Example

  iex> Singularity.AgentSupervisor.pause_all_agents()
  :ok

  iex> Singularity.AgentSupervisor.resume_all_agents()
  :ok

  iex> agents = Singularity.AgentSupervisor.get_all_agents()
  [#PID<0.1.0>, #PID<0.2.0>]

  iex> length(agents)
  2
  """
  use DynamicSupervisor

  require Logger

  alias Singularity.Agents.Agent

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Get list of all agent PIDs supervised by this supervisor.
  """
  def get_all_agents do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
  end

  def children do
    get_all_agents()
  end

  @doc """
  Pause all agents, preventing them from processing new tasks or improvements.

  Returns `:ok` if all agents were successfully paused, or `{:error, failures}`
  if some agents couldn't be paused.

  ## Example

      case Singularity.AgentSupervisor.pause_all_agents() do
        :ok -> IO.puts("All agents paused")
        {:error, failures} -> IO.puts("Failed to pause: " <> inspect(failures))
      end
  """
  @spec pause_all_agents() :: :ok | {:error, list()}
  def pause_all_agents do
    agents = get_all_agents()

    if Enum.empty?(agents) do
      Logger.info("No agents to pause")
      :ok
    else
      Logger.info("Pausing #{length(agents)} agents")

      failures =
        agents
        |> Enum.with_index()
        |> Enum.filter(fn {pid, _idx} ->
          case GenServer.cast(pid, :pause) do
            :ok -> false
            _ -> true
          end
        end)
        |> Enum.map(fn {pid, idx} -> {idx, pid} end)

      if Enum.empty?(failures) do
        :ok
      else
        {:error, failures}
      end
    end
  end

  @doc """
  Resume all agents that were previously paused.

  Returns `:ok` if all agents were successfully resumed, or `{:error, failures}`
  if some agents couldn't be resumed.

  ## Example

      case Singularity.AgentSupervisor.resume_all_agents() do
        :ok -> IO.puts("All agents resumed")
        {:error, failures} -> IO.puts("Failed to resume: " <> inspect(failures))
      end
  """
  @spec resume_all_agents() :: :ok | {:error, list()}
  def resume_all_agents do
    agents = get_all_agents()

    if Enum.empty?(agents) do
      Logger.info("No agents to resume")
      :ok
    else
      Logger.info("Resuming #{length(agents)} agents")

      failures =
        agents
        |> Enum.with_index()
        |> Enum.filter(fn {pid, _idx} ->
          case GenServer.cast(pid, :resume) do
            :ok -> false
            _ -> true
          end
        end)
        |> Enum.map(fn {pid, idx} -> {idx, pid} end)

      if Enum.empty?(failures) do
        :ok
      else
        {:error, failures}
      end
    end
  end

  @doc """
  Improve a specific agent by agent_id.

  Returns `:ok` if the agent was found and the improvement was queued,
  otherwise `{:error, :not_found}`.

  ## Example

      case Singularity.AgentSupervisor.improve_agent("agent-1", %{type: :optimization}) do
        :ok -> IO.puts("Improvement queued")
        {:error, :not_found} -> IO.puts("Agent not found")
      end
  """
  @spec improve_agent(String.t(), map()) :: :ok | {:error, :not_found}
  def improve_agent(agent_id, payload) when is_map(payload) do
    Agent.improve(agent_id, payload)
  end
end
