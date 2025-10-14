defmodule Singularity.Manager do
  @moduledoc """
  System manager for queue and resource management.
  """

  use GenServer

  @doc """
  Get current queue depth.
  """
  def queue_depth do
    # Get queue depth from the execution coordinator
    case Process.whereis(Singularity.Execution.SPARC.Orchestrator) do
      nil ->
        0

      pid ->
        case GenServer.call(pid, :queue_depth) do
          {:ok, depth} -> depth
          _ -> 0
        end
    end
  end

  @doc """
  Get system status.
  """
  def status do
    %{
      queue_depth: queue_depth(),
      agents_running: length(Singularity.AgentSupervisor.children()),
      memory_usage: :erlang.memory(:total),
      uptime: :erlang.statistics(:wall_clock) |> elem(0)
    }
  end

  @doc """
  Start the manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call(:queue_depth, _from, state) do
    depth = queue_depth()
    {:reply, depth, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = status()
    {:reply, status, state}
  end
end
