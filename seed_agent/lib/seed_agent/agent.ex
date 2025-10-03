defmodule SeedAgent.Agent do
  @moduledoc """
  Core GenServer representing a self-improving agent instance.
  """
  use GenServer

  require Logger

  alias SeedAgent.{HotReload, ProcessRegistry}

  @type state :: %{
          id: String.t(),
          version: non_neg_integer(),
          context: map(),
          metrics: map(),
          status: :idle | :updating
        }

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :id, make_id()),
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      shutdown: 10_000
    }
  end

  def start_link(opts) do
    id = opts |> Keyword.get(:id, make_id()) |> to_string()
    name = via_tuple(id)
    GenServer.start_link(__MODULE__, Keyword.put(opts, :id, id), name: name)
  end

  def via_tuple(id), do: {:via, Registry, {ProcessRegistry, {:agent, id}}}

  @impl true
  def init(opts) do
    state = %{
      id: Keyword.fetch!(opts, :id),
      version: 1,
      context: Map.new(opts),
      metrics: %{},
      status: :idle
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:improve, payload}, state) do
    Logger.info("Agent improvement requested", agent_id: state.id)

    case HotReload.Manager.enqueue(state.id, payload) do
      :ok ->
        {:noreply, %{state | status: :updating}}

      {:error, reason} ->
        Logger.error("Failed to enqueue improvement", agent_id: state.id, reason: inspect(reason))
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:update_metrics, metrics}, state) when is_map(metrics) do
    {:noreply, %{state | metrics: Map.merge(state.metrics, metrics)}}
  end

  @impl true
  def handle_info({:reload_complete, version}, state) do
    {:noreply, %{state | version: version, status: :idle}}
  end

  @impl true
  def handle_call(:state, _from, state), do: {:reply, state, state}

  defp make_id do
    "agent-" <> Integer.to_string(:erlang.unique_integer([:positive, :monotonic]))
  end
end
