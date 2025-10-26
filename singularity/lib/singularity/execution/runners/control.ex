defmodule Singularity.Execution.Runners.Control do
  @moduledoc """
  Modern control system for coordinating agent improvements and system events.

  Provides a clean interface for:
  - Publishing improvement events
  - Managing system state
  - Coordinating between agents
  - Event broadcasting
  """

  use GenServer
  require Logger

  alias Singularity.Messaging.Client, as: NatsClient

  @type improvement_event :: %{
          agent_id: String.t(),
          payload: map(),
          timestamp: DateTime.t(),
          metadata: map()
        }

  @type system_event :: %{
          type: atom(),
          data: map(),
          timestamp: DateTime.t(),
          source: String.t()
        }

  ## Client API

  @doc """
  Publish an improvement event for an agent.

  ## Examples

      iex> Singularity.Control.publish_improvement("agent-123", %{code: "def hello, do: :world"})
      :ok
  """
  @spec publish_improvement(String.t(), map()) :: :ok
  def publish_improvement(agent_id, payload) when is_binary(agent_id) and is_map(payload) do
    event = %{
      agent_id: agent_id,
      payload: payload,
      timestamp: DateTime.utc_now(),
      metadata: %{source: :control}
    }

    GenServer.cast(__MODULE__, {:publish_improvement, event})
  end

  @doc """
  Broadcast a system-wide event.

  ## Examples

      iex> Singularity.Control.broadcast_event(:agent_started, %{agent_id: "agent-123"})
      :ok
  """
  @spec broadcast_event(atom(), map()) :: :ok
  def broadcast_event(type, data) when is_atom(type) and is_map(data) do
    event = %{
      type: type,
      data: data,
      timestamp: DateTime.utc_now(),
      source: "control"
    }

    GenServer.cast(__MODULE__, {:broadcast_event, event})
  end

  @doc """
  Get current system status.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Subscribe to improvement events for a specific agent.
  """
  @spec subscribe_to_agent(String.t()) :: :ok | {:error, term()}
  def subscribe_to_agent(agent_id) when is_binary(agent_id) do
    Singularity.Messaging.Client.subscribe("agent_improvements.#{agent_id}")
  end

  @doc """
  Subscribe to all system events.
  """
  @spec subscribe_to_system_events() :: :ok | {:error, term()}
  def subscribe_to_system_events do
    Singularity.Messaging.Client.subscribe("system_events")
  end

  ## GenServer Callbacks

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      active_agents: MapSet.new(),
      event_count: 0,
      last_event: nil,
      metrics: %{
        improvements_published: 0,
        system_events_broadcast: 0,
        active_subscribers: 0
      }
    }

    Logger.info("Control system started")
    {:ok, state}
  end

  @impl true
  def handle_cast({:publish_improvement, event}, state) do
    # Publish to agent-specific NATS subject
    Singularity.Messaging.Client.publish(
      "agent_improvements.#{event.agent_id}",
      Jason.encode!(%{improvement: event})
    )

    # Publish to general improvements NATS subject
    Singularity.Messaging.Client.publish("improvements", Jason.encode!(%{improvement: event}))

    # Update metrics
    new_metrics = Map.update!(state.metrics, :improvements_published, &(&1 + 1))

    # Log improvement published
    Logger.debug("Published improvement event", %{
      agent_id: event.agent_id,
      payload_size: map_size(event.payload),
      timestamp: event.timestamp
    })

    new_state = %{
      state
      | metrics: new_metrics,
        event_count: state.event_count + 1,
        last_event: event
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:broadcast_event, event}, state) do
    # Broadcast to system events NATS subject
    Singularity.Messaging.Client.publish("system_events", Jason.encode!(%{system_event: event}))

    # Update metrics
    new_metrics = Map.update!(state.metrics, :system_events_broadcast, &(&1 + 1))

    # Log system event broadcast
    Logger.debug("Broadcast system event", %{
      event_type: event.type,
      source: event.source,
      timestamp: event.timestamp
    })

    new_state = %{
      state
      | metrics: new_metrics,
        event_count: state.event_count + 1,
        last_event: event
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      active_agents: MapSet.size(state.active_agents),
      total_events: state.event_count,
      metrics: state.metrics,
      last_event: state.last_event,
      uptime: System.monotonic_time(:second) - :persistent_term.get(:singularity_start_time, 0)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info({:agent_started, agent_id}, state) do
    new_agents = MapSet.put(state.active_agents, agent_id)
    new_state = %{state | active_agents: new_agents}

    # Broadcast agent started event
    broadcast_event(:agent_started, %{agent_id: agent_id})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:agent_stopped, agent_id}, state) do
    new_agents = MapSet.delete(state.active_agents, agent_id)
    new_state = %{state | active_agents: new_agents}

    # Broadcast agent stopped event
    broadcast_event(:agent_stopped, %{agent_id: agent_id})

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
