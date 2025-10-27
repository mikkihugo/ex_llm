defmodule Singularity.Control.QueueCrdt do
  @moduledoc """
  Distributed AWLWW map (via DeltaCrdt) that tracks in-flight improvement
  fingerprints per agent so multiple nodes do not attempt the same upgrade.
  """
  use GenServer

  require Logger

  @crdt_name :singularity_queue_crdt

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, _opts, name: __MODULE__)
  end

  @doc "Reserve a fingerprint for an agent. Returns false if already reserved."
  @spec reserve(String.t(), integer() | nil) :: boolean()
  def reserve(_agent_id, nil), do: true

  def reserve(agent_id, fingerprint) do
    GenServer.call(__MODULE__, {:reserve, agent_id, fingerprint})
  end

  @doc "Release a previously reserved fingerprint."
  @spec release(String.t(), integer() | nil) :: :ok
  def release(_agent_id, nil), do: :ok

  def release(agent_id, fingerprint) do
    GenServer.cast(__MODULE__, {:release, agent_id, fingerprint})
  end

  @doc "Expose the CRDT pid for neighbour wiring."
  @spec crdt_pid() :: pid() | nil
  def crdt_pid, do: Process.whereis(@crdt_name)

  ## Server callbacks

  @impl true
  def init(_opts) do
    {:ok, crdt} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap, sync_interval: 5_000)
    Process.register(crdt, @crdt_name)
    :net_kernel.monitor_nodes(true, node_type: :visible)
    {:ok, %{crdt: crdt}, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    connect_neighbours(state.crdt)
    {:noreply, state}
  end

  @impl true
  def handle_call({:reserve, agent_id, fingerprint}, _from, %{crdt: crdt} = state) do
    current = read_set(crdt, agent_id)

    if MapSet.member?(current, fingerprint) do
      {:reply, false, state}
    else
      DeltaCrdt.put(crdt, agent_id, fn existing ->
        existing = existing || MapSet.new()
        MapSet.put(existing, fingerprint)
      end)

      {:reply, true, state}
    end
  end

  @impl true
  def handle_cast({:release, agent_id, fingerprint}, %{crdt: crdt} = state) do
    DeltaCrdt.put(crdt, agent_id, fn existing ->
      existing = existing || MapSet.new()
      MapSet.delete(existing, fingerprint)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:nodeup, _node, _info}, state) do
    connect_neighbours(state.crdt)
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, _node, _info}, state) do
    connect_neighbours(state.crdt)
    {:noreply, state}
  end

  defp connect_neighbours(crdt) do
    neighbours =
      Node.list()
      |> Enum.map(fn node ->
        :rpc.call(node, __MODULE__, :crdt_pid, [])
      end)
      |> Enum.reject(&is_nil/1)

    DeltaCrdt.set_neighbours(crdt, neighbours)
  end

  defp read_set(crdt, agent_id) do
    case DeltaCrdt.to_map(crdt) do
      map when is_map(map) -> Map.get(map, agent_id, MapSet.new())
      _ -> MapSet.new()
    end
  end
end
