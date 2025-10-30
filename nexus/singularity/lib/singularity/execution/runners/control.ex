defmodule Singularity.Execution.Runners.Control do
  @moduledoc """
  Modern control system for coordinating agent improvements and system events.

  Provides a clean interface for:
  - Publishing improvement events via Pgflow workflows
  - Managing system state
  - Coordinating between agents
  - Event broadcasting
  """

  use GenServer
  require Logger

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

      iex> Singularity.Execution.Runners.Control.publish_improvement("agent-123", %{code: "def hello, do: :world"})
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

    # Use Pgflow workflow instead of direct pgmq publishing
    case Singularity.Infrastructure.PgFlow.Workflow.create_workflow(
           Singularity.Workflows.AgentImprovementWorkflow,
           %{"event" => event}
         ) do
      {:ok, workflow_id} ->
        Logger.debug("Created agent improvement workflow",
          agent_id: agent_id,
          workflow_id: workflow_id
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed to create agent improvement workflow",
          agent_id: agent_id,
          reason: reason
        )

        :ok
    end
  end

  @doc """
  Broadcast a system-wide event.

  ## Examples

      iex> Singularity.Execution.Runners.Control.broadcast_event(:agent_started, %{agent_id: "agent-123"})
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

  Note: With Pgflow migration, subscriptions are handled through workflow completion
  notifications rather than direct pgmq subscriptions.
  """
  @spec subscribe_to_agent(String.t()) :: :ok | {:error, term()}
  def subscribe_to_agent(agent_id) when is_binary(agent_id) do
    # Subscribe to PGFlow workflow completion events for agent improvements
    workflow_name = "agent_improvement_#{agent_id}"

    case Singularity.Infrastructure.PgFlow.Workflow.subscribe(workflow_name, fn workflow_result ->
           handle_agent_improvement_completion(agent_id, workflow_result)
         end) do
      {:ok, subscription_id} ->
        Logger.info("[Control] Subscribed to agent improvements via PGFlow",
          agent_id: agent_id,
          workflow: workflow_name,
          subscription_id: subscription_id
        )

        :ok

      {:error, reason} ->
        Logger.warning("[Control] Failed to subscribe to agent improvements via PGFlow",
          agent_id: agent_id,
          reason: reason
        )

        {:error, reason}
    end
  end

  @doc """
  Subscribe to all system events.

  Note: With Pgflow migration, subscriptions are handled through workflow completion
  notifications rather than direct pgmq subscriptions.
  """
  @spec subscribe_to_system_events() :: :ok | {:error, term()}
  def subscribe_to_system_events do
    # Subscribe to PGFlow workflow completion events for system-wide events
    workflow_name = "system_events"

    case Singularity.Infrastructure.PgFlow.Workflow.subscribe(workflow_name, fn workflow_result ->
           handle_system_event_completion(workflow_result)
         end) do
      {:ok, subscription_id} ->
        Logger.info("[Control] Subscribed to system events via PGFlow",
          workflow: workflow_name,
          subscription_id: subscription_id
        )

        :ok

      {:error, reason} ->
        Logger.warning("[Control] Failed to subscribe to system events via PGFlow",
          reason: reason
        )

        {:error, reason}
    end
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
  def handle_cast({:broadcast_event, event}, state) do
    # Create PGFlow workflow for system events
    workflow_name = "system_event_broadcast"

    case Singularity.Infrastructure.PgFlow.Workflow.create_workflow(
           Singularity.Workflows.SystemEventBroadcastWorkflow,
           %{
             "event_type" => event.type,
             "source" => event.source,
             "timestamp" => event.timestamp,
             "payload" => event.payload || %{}
           }
         ) do
      {:ok, workflow_id} ->
        Logger.debug("Broadcast system event via PGFlow workflow",
          event_type: event.type,
          source: event.source,
          workflow: workflow_name,
          workflow_id: workflow_id
        )

      {:error, reason} ->
        Logger.warning("Failed to create PGFlow workflow for system event",
          event_type: event.type,
          workflow: workflow_name,
          reason: reason
        )

        # Fallback: log the event
        Logger.debug("Broadcast system event", %{
          event_type: event.type,
          source: event.source,
          timestamp: event.timestamp
        })
    end

    # Update metrics
    new_metrics = Map.update!(state.metrics, :system_events_broadcast, &(&1 + 1))

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

  # Handle agent improvement workflow completion
  defp handle_agent_improvement_completion(agent_id, %{status: :completed, result: result}) do
    Logger.info("[Control] Agent improvement completed",
      agent_id: agent_id,
      result: result
    )

    # Notify agent coordinator about completion
    GenServer.cast(__MODULE__, {:agent_improvement_completed, agent_id, result})
    :ok
  end

  defp handle_agent_improvement_completion(agent_id, %{status: :failed, error: error}) do
    Logger.error("[Control] Agent improvement failed",
      agent_id: agent_id,
      error: error
    )

    :ok
  end

  defp handle_agent_improvement_completion(_agent_id, _), do: :ok

  # Handle system event workflow completion
  defp handle_system_event_completion(%{status: :completed, result: result}) do
    Logger.debug("[Control] System event workflow completed",
      result: result
    )

    :ok
  end

  defp handle_system_event_completion(%{status: :failed, error: error}) do
    Logger.warning("[Control] System event workflow failed",
      error: error
    )

    :ok
  end

  defp handle_system_event_completion(_), do: :ok

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
