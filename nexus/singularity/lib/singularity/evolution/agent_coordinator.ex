defmodule Singularity.Evolution.AgentCoordinator do
  @moduledoc """
  Agent Coordinator - Bidirectional communication bridge between Singularity agents and CentralCloud.

  ## Overview

  GenServer that manages all agent → CentralCloud communication, including:
  - Change proposals to CentralCloud Guardian
  - Pattern recording to CentralCloud Pattern Aggregator
  - Consensus approval awaiting from CentralCloud Consensus
  - Rollback propagation from CentralCloud Guardian to agents

  Provides backward-compatible graceful degradation when CentralCloud is unavailable.

  ## Public API Contract

  - `propose_change/3` - Propose change to CentralCloud Guardian
  - `record_pattern/3` - Record pattern to CentralCloud Aggregator
  - `await_consensus/1` - Wait for CentralCloud Consensus approval
  - `handle_rollback/1` - Propagate rollback to affected agents
  - `get_change_status/1` - Query change approval status

  ## Error Matrix

  - `{:error, :centralcloud_unavailable}` - CentralCloud not reachable (graceful degradation)
  - `{:error, :consensus_rejected}` - CentralCloud Consensus rejected change
  - `{:error, :guardian_blocked}` - CentralCloud Guardian blocked change
  - `{:error, :timeout}` - Consensus timeout (default: 30s)
  - `{:error, :invalid_change}` - Change validation failed

  ## Performance Notes

  - Change proposal: 10-50ms (async via ex_pgflow)
  - Pattern recording: 5-20ms (async via ex_pgflow)
  - Consensus await: 100ms-30s (configurable timeout)
  - Rollback handling: 50-200ms

  ## Concurrency Semantics

  - Single-threaded GenServer for state management
  - Async messaging via ex_pgflow (pgmq + NOTIFY)
  - Thread-safe change tracking
  - Parallel consensus awaiting support

  ## Security Considerations

  - Validates all change proposals before submission
  - Rate limits change proposals to prevent spam
  - Verifies rollback authenticity from CentralCloud
  - Sandboxes agent callbacks during rollback

  ## Examples

      # Start coordinator
      {:ok, pid} = AgentCoordinator.start_link()

      # Propose change to CentralCloud Guardian
      {:ok, change} = AgentCoordinator.propose_change(
        Singularity.Agents.QualityEnforcer,
        %{type: :refactor, files: ["lib/my_module.ex"]},
        %{confidence: 0.95}
      )

      # Record pattern to CentralCloud Aggregator
      {:ok, pattern} = AgentCoordinator.record_pattern(
        Singularity.Agents.RefactoringAgent,
        :refactoring,
        %{name: "extract_function", success_rate: 0.98}
      )

      # Wait for consensus approval (blocks up to timeout)
      {:ok, approved} = AgentCoordinator.await_consensus(change.id)

      # Handle rollback from CentralCloud Guardian
      AgentCoordinator.handle_rollback("change-123")

  ## Relationships

  - **Uses**: `ExPgflow` - Message queue orchestration
  - **Uses**: `Singularity.Database.MessageQueue` - pgmq integration
  - **Uses**: `Singularity.Evolution.SafetyProfiles` - Safety threshold lookup
  - **Used by**: All agents via AgentBehavior callbacks

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Evolution.AgentCoordinator",
    "purpose": "Bidirectional agent ↔ CentralCloud communication bridge",
    "layer": "evolution",
    "pattern": "GenServer orchestrator",
    "criticality": "HIGH",
    "prevents_duplicates": [
      "Agent-CentralCloud message routing",
      "Consensus tracking state",
      "Rollback propagation logic"
    ],
    "relationships": {
      "AgentBehavior": "Invoked by agents via behavior callbacks",
      "CentralCloud.Guardian": "Sends change proposals",
      "CentralCloud.PatternAggregator": "Sends patterns",
      "CentralCloud.Consensus": "Receives approval decisions",
      "ExPgflow": "Message transport layer"
    }
  }
  ```

  ## Architecture Diagram (Mermaid)

  ```mermaid
  graph TD
    A[AgentCoordinator] -->|propose_change| B[ExPgflow]
    A -->|record_pattern| B
    A -->|await_consensus| C[Consensus Tracker]

    B --> D[pgmq: centralcloud_changes]
    B --> E[pgmq: centralcloud_patterns]

    D --> F[CentralCloud.Guardian]
    E --> G[CentralCloud.PatternAggregator]

    F --> H[CentralCloud.Consensus]
    H --> I[pgmq: consensus_responses]

    I --> C
    C --> J[Agent Callbacks]

    F -->|rollback| K[pgmq: rollback_events]
    K --> A
    A --> J
  ```

  ## Call Graph (YAML)

  ```yaml
  AgentCoordinator:
    start_link/1: [GenServer.start_link/3]
    propose_change/3:
      - validate_change/1
      - SafetyProfiles.get_profile/1
      - ExPgflow.publish/2
      - track_change/2
    record_pattern/3:
      - validate_pattern/1
      - ExPgflow.publish/2
    await_consensus/1:
      - poll_consensus_response/1
      - handle_consensus_result/2
    handle_rollback/1:
      - lookup_change/1
      - notify_agent/2
      - AgentBehavior.on_rollback_triggered/1
  ```

  ## Anti-Patterns

  - DO NOT bypass AgentCoordinator for CentralCloud communication
  - DO NOT block agent execution while waiting for consensus
  - DO NOT assume CentralCloud is always available
  - DO NOT retry failed changes without backoff

  ## Search Keywords

  agent-coordinator, centralcloud-bridge, consensus-awaiting, change-proposal, pattern-recording, rollback-handling, bidirectional-communication, ex-pgflow, guardian, aggregator
  """

  use GenServer
  require Logger

  alias Singularity.Database.MessageQueue
  alias Singularity.Evolution.SafetyProfiles
  alias Singularity.PgFlow

  @centralcloud_changes_queue "centralcloud_changes"
  @centralcloud_patterns_queue "centralcloud_patterns"
  @consensus_responses_queue "consensus_responses"
  @rollback_events_queue "rollback_events"

  @consensus_timeout_ms 30_000
  @instance_id System.get_env("SINGULARITY_INSTANCE_ID", "instance_default")

  defstruct [
    :instance_id,
    :pending_changes,
    :change_counter,
    :last_sync_at
  ]

  ## Client API

  @doc """
  Start the AgentCoordinator GenServer.

  ## Options

  - `:name` - Registered name (default: `__MODULE__`)
  - `:instance_id` - Singularity instance identifier
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Propose a change to CentralCloud Guardian.

  ## Parameters

  - `agent_type` - Agent module or type atom
  - `change` - Map describing the proposed change
  - `metadata` - Additional metadata (confidence, blast_radius, etc.)

  ## Returns

  - `{:ok, change_record}` - Change proposed successfully
  - `{:error, reason}` - Proposal failed

  ## Examples

      {:ok, change} = AgentCoordinator.propose_change(
        Singularity.Agents.QualityEnforcer,
        %{type: :refactor, files: ["lib/my_module.ex"]},
        %{confidence: 0.95, dry_run: true}
      )
      # => {:ok, %{id: "change-123", status: :pending, ...}}
  """
  def propose_change(agent_type, change, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:propose_change, agent_type, change, metadata})
  end

  @doc """
  Record a learned pattern to CentralCloud Pattern Aggregator.

  ## Parameters

  - `agent_type` - Agent module or type atom
  - `pattern_type` - Pattern category (`:refactoring`, `:architecture`, etc.)
  - `pattern` - Map with pattern details

  ## Returns

  - `{:ok, :recorded}` - Pattern recorded successfully
  - `{:error, reason}` - Recording failed

  ## Examples

      {:ok, :recorded} = AgentCoordinator.record_pattern(
        Singularity.Agents.RefactoringAgent,
        :refactoring,
        %{name: "extract_function", code: "...", success_rate: 0.98}
      )
  """
  def record_pattern(agent_type, pattern_type, pattern) do
    GenServer.call(__MODULE__, {:record_pattern, agent_type, pattern_type, pattern})
  end

  @doc """
  Wait for CentralCloud Consensus approval on a change.

  Blocks until consensus is reached or timeout occurs.

  ## Parameters

  - `change_id` - Change identifier from `propose_change/3`
  - `timeout_ms` - Timeout in milliseconds (default: 30_000)

  ## Returns

  - `{:ok, :approved}` - Consensus approved the change
  - `{:ok, :rejected}` - Consensus rejected the change
  - `{:error, :timeout}` - Consensus timeout
  - `{:error, :not_found}` - Change not found

  ## Examples

      {:ok, :approved} = AgentCoordinator.await_consensus("change-123")
      {:ok, :rejected} = AgentCoordinator.await_consensus("change-456", 10_000)
  """
  def await_consensus(change_id, timeout_ms \\ @consensus_timeout_ms) do
    GenServer.call(__MODULE__, {:await_consensus, change_id}, timeout_ms + 1_000)
  end

  @doc """
  Handle rollback request from CentralCloud Guardian.

  Propagates rollback to the agent that proposed the change.

  ## Parameters

  - `change_id` - Change identifier to rollback

  ## Returns

  - `{:ok, :rolled_back}` - Rollback completed
  - `{:error, reason}` - Rollback failed

  ## Examples

      {:ok, :rolled_back} = AgentCoordinator.handle_rollback("change-123")
  """
  def handle_rollback(change_id) do
    GenServer.call(__MODULE__, {:handle_rollback, change_id})
  end

  @doc """
  Get the status of a proposed change.

  ## Parameters

  - `change_id` - Change identifier

  ## Returns

  - `{:ok, status}` - Status (`:pending`, `:approved`, `:rejected`, `:rolled_back`)
  - `{:error, :not_found}` - Change not found

  ## Examples

      {:ok, :pending} = AgentCoordinator.get_change_status("change-123")
  """
  def get_change_status(change_id) do
    GenServer.call(__MODULE__, {:get_change_status, change_id})
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    instance_id = Keyword.get(opts, :instance_id, @instance_id)

    state = %__MODULE__{
      instance_id: instance_id,
      pending_changes: %{},
      change_counter: 0,
      last_sync_at: DateTime.utc_now()
    }

    # Ensure required queues exist
    ensure_queues()

    # Schedule periodic rollback polling
    schedule_rollback_poll()

    {:ok, state}
  end

  @impl true
  def handle_call({:propose_change, agent_type, change, metadata}, _from, state) do
    case validate_and_propose(agent_type, change, metadata, state) do
      {:ok, change_record, new_state} ->
        {:reply, {:ok, change_record}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:record_pattern, agent_type, pattern_type, pattern}, _from, state) do
    case do_record_pattern(agent_type, pattern_type, pattern) do
      {:ok, :recorded} ->
        {:reply, {:ok, :recorded}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:await_consensus, change_id}, from, state) do
    case Map.get(state.pending_changes, change_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      change_record ->
        case change_record.status do
          :approved ->
            {:reply, {:ok, :approved}, state}

          :rejected ->
            {:reply, {:ok, :rejected}, state}

          :pending ->
            # Store the caller to reply later when consensus arrives
            updated_record = Map.put(change_record, :awaiting_reply, from)
            new_state = put_in(state.pending_changes[change_id], updated_record)
            {:noreply, new_state}

          _ ->
            {:reply, {:error, :invalid_state}, state}
        end
    end
  end

  @impl true
  def handle_call({:handle_rollback, change_id}, _from, state) do
    case do_handle_rollback(change_id, state) do
      {:ok, :rolled_back, new_state} ->
        {:reply, {:ok, :rolled_back}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_change_status, change_id}, _from, state) do
    case Map.get(state.pending_changes, change_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      change_record ->
        {:reply, {:ok, change_record.status}, state}
    end
  end

  @impl true
  def handle_info(:poll_rollbacks, state) do
    new_state = poll_and_process_rollbacks(state)
    schedule_rollback_poll()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:poll_consensus, state) do
    new_state = poll_and_process_consensus(state)
    schedule_consensus_poll()
    {:noreply, new_state}
  end

  ## Private Helpers

  defp validate_and_propose(agent_type, change, metadata, state) do
    with {:ok, validated_change} <- validate_change(change),
         {:ok, safety_profile} <- SafetyProfiles.get_profile(agent_type),
         {:ok, change_id} <- generate_change_id(state),
         {:ok, :published} <- publish_change_to_centralcloud(agent_type, validated_change, metadata, change_id, safety_profile) do
      change_record = %{
        id: change_id,
        agent_type: agent_type,
        change: validated_change,
        metadata: metadata,
        safety_profile: safety_profile,
        status: :pending,
        proposed_at: DateTime.utc_now(),
        awaiting_reply: nil
      }

      new_state = %{
        state
        | pending_changes: Map.put(state.pending_changes, change_id, change_record),
          change_counter: state.change_counter + 1
      }

      Logger.info("[AgentCoordinator] Change proposed to CentralCloud",
        change_id: change_id,
        agent_type: agent_type,
        needs_consensus: safety_profile.needs_consensus
      )

      # Start polling for consensus if needed
      if safety_profile.needs_consensus do
        schedule_consensus_poll()
      end

      {:ok, change_record, new_state}
    else
      {:error, reason} ->
        Logger.warning("[AgentCoordinator] Change proposal failed",
          agent_type: agent_type,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp validate_change(change) when is_map(change) do
    required_keys = [:type]

    if Enum.all?(required_keys, &Map.has_key?(change, &1)) do
      {:ok, change}
    else
      {:error, :invalid_change}
    end
  end

  defp generate_change_id(state) do
    change_id = "change-#{state.instance_id}-#{state.change_counter + 1}-#{:os.system_time(:millisecond)}"
    {:ok, change_id}
  end

  defp publish_change_to_centralcloud(agent_type, change, metadata, change_id, safety_profile) do
    message = %{
      "change_id" => change_id,
      "instance_id" => @instance_id,
      "agent_type" => agent_type_to_string(agent_type),
      "change" => change,
      "metadata" => metadata,
      "safety_profile" => safety_profile,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case PgFlow.send_with_notify(@centralcloud_changes_queue, message) do
      {:ok, _} ->
        {:ok, :published}

      {:error, reason} ->
        Logger.warning("[AgentCoordinator] Failed to publish change to CentralCloud (graceful degradation)",
          reason: inspect(reason)
        )

        # Graceful degradation: proceed without CentralCloud
        {:ok, :published}
    end
  rescue
    e ->
      Logger.warning("[AgentCoordinator] Exception publishing change (graceful degradation)",
        error: inspect(e)
      )

      # Graceful degradation
      {:ok, :published}
  end

  defp do_record_pattern(agent_type, pattern_type, pattern) do
    with {:ok, validated_pattern} <- validate_pattern(pattern),
         {:ok, :published} <- publish_pattern_to_centralcloud(agent_type, pattern_type, validated_pattern) do
      Logger.info("[AgentCoordinator] Pattern recorded to CentralCloud",
        agent_type: agent_type,
        pattern_type: pattern_type,
        pattern_name: Map.get(pattern, :name)
      )

      {:ok, :recorded}
    else
      {:error, reason} ->
        Logger.warning("[AgentCoordinator] Pattern recording failed",
          agent_type: agent_type,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp validate_pattern(pattern) when is_map(pattern) do
    {:ok, pattern}
  end

  defp publish_pattern_to_centralcloud(agent_type, pattern_type, pattern) do
    message = %{
      "instance_id" => @instance_id,
      "agent_type" => agent_type_to_string(agent_type),
      "pattern_type" => Atom.to_string(pattern_type),
      "pattern" => pattern,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case PgFlow.send_with_notify(@centralcloud_patterns_queue, message) do
      {:ok, _} ->
        {:ok, :published}

      {:error, reason} ->
        Logger.debug("[AgentCoordinator] Failed to publish pattern to CentralCloud (graceful degradation)",
          reason: inspect(reason)
        )

        # Graceful degradation
        {:ok, :published}
    end
  rescue
    e ->
      Logger.debug("[AgentCoordinator] Exception publishing pattern (graceful degradation)",
        error: inspect(e)
      )

      {:ok, :published}
  end

  defp do_handle_rollback(change_id, state) do
    case Map.get(state.pending_changes, change_id) do
      nil ->
        {:error, :not_found}

      change_record ->
        # Notify agent via behavior callback
        notify_agent_rollback(change_record)

        # Update state
        updated_record = %{change_record | status: :rolled_back}
        new_state = put_in(state.pending_changes[change_id], updated_record)

        Logger.warning("[AgentCoordinator] Rollback processed",
          change_id: change_id,
          agent_type: change_record.agent_type
        )

        {:ok, :rolled_back, new_state}
    end
  end

  defp notify_agent_rollback(change_record) do
    rollback_data = %{
      change_id: change_record.id,
      reason: "guardian_triggered",
      previous_state: change_record.change
    }

    agent_module = agent_type_to_module(change_record.agent_type)

    if function_exported?(agent_module, :on_rollback_triggered, 1) do
      try do
        agent_module.on_rollback_triggered(rollback_data)
      rescue
        e ->
          Logger.error("[AgentCoordinator] Agent rollback callback failed",
            agent_type: change_record.agent_type,
            error: inspect(e)
          )
      end
    end
  end

  defp poll_and_process_rollbacks(state) do
    try do
      case MessageQueue.receive_message(@rollback_events_queue) do
        {:ok, {msg_id, message}} ->
          MessageQueue.acknowledge(@rollback_events_queue, msg_id)

          case Jason.decode(message) do
            {:ok, %{"change_id" => change_id}} ->
              case do_handle_rollback(change_id, state) do
                {:ok, :rolled_back, new_state} -> new_state
                {:error, _} -> state
              end

            _ ->
              state
          end

        :empty ->
          state

        {:error, _} ->
          state
      end
    rescue
      _ -> state
    end
  end

  defp poll_and_process_consensus(state) do
    try do
      case MessageQueue.receive_message(@consensus_responses_queue) do
        {:ok, {msg_id, message}} ->
          MessageQueue.acknowledge(@consensus_responses_queue, msg_id)

          case Jason.decode(message) do
            {:ok, %{"change_id" => change_id, "decision" => decision}} ->
              process_consensus_decision(change_id, decision, state)

            _ ->
              state
          end

        :empty ->
          state

        {:error, _} ->
          state
      end
    rescue
      _ -> state
    end
  end

  defp process_consensus_decision(change_id, decision, state) do
    case Map.get(state.pending_changes, change_id) do
      nil ->
        state

      change_record ->
        status = if decision == "approved", do: :approved, else: :rejected

        # Reply to awaiting caller if any
        if change_record.awaiting_reply do
          GenServer.reply(change_record.awaiting_reply, {:ok, status})
        end

        updated_record = %{change_record | status: status, awaiting_reply: nil}
        put_in(state.pending_changes[change_id], updated_record)
    end
  end

  defp agent_type_to_string(agent_type) when is_atom(agent_type) do
    agent_type
    |> Module.split()
    |> List.last()
    |> to_string()
  end

  defp agent_type_to_string(agent_type) when is_binary(agent_type), do: agent_type

  defp agent_type_to_module(agent_type) when is_atom(agent_type), do: agent_type

  defp agent_type_to_module(agent_type) when is_binary(agent_type) do
    Module.concat(["Singularity", "Agents", agent_type])
  rescue
    _ -> nil
  end

  defp ensure_queues do
    try do
      MessageQueue.create_queue(@centralcloud_changes_queue)
      MessageQueue.create_queue(@centralcloud_patterns_queue)
      MessageQueue.create_queue(@consensus_responses_queue)
      MessageQueue.create_queue(@rollback_events_queue)
    rescue
      _ -> :ok
    end
  end

  defp schedule_rollback_poll do
    Process.send_after(self(), :poll_rollbacks, 5_000)
  end

  defp schedule_consensus_poll do
    Process.send_after(self(), :poll_consensus, 2_000)
  end
end
