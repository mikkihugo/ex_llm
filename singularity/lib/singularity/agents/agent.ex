defmodule Singularity.Agents.Agent do
  @moduledoc """
  Core GenServer representing a self-improving agent instance.

  The server keeps its own feedback loop: it observes metrics, decides when to
  evolve, synthesises new Gleam code, and hands the payload to the hot-reload
  manager. External systems can still push improvements, but they are no longer
  required for the agent to progress.

  ## Namespace Note

  This module is defined as `Singularity.Agents.Agent` (matching file location
  `agents/agent.ex`), but is aliased as `Singularity.Agent` at the application
  level for backwards compatibility.

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Agents.Agent",
    "purpose": "GenServer for autonomous self-improving AI agent with feedback loop and evolution",
    "role": "genserver",
    "layer": "agents",
    "criticality": "CRITICAL",
    "prevents_duplicates": [
      "Individual agent instances and state",
      "Agent feedback processing",
      "Agent performance metrics",
      "Agent evolution logic"
    ],
    "relationships": {
      "Agents.Supervisor": "Manages instances of this module",
      "Control": "Receives improvement feedback",
      "Agent.*": "Specialized agent strategies"
    }
  }
  ```

  ### Call Graph (Machine-Readable)

  ```yaml
  calls_out:
    - module: CodeStore
      purpose: Persist generated code
      critical: true

    - module: Control
      purpose: Publish improvement events
      critical: true

    - module: HotReload
      purpose: Real-time code updates
      critical: false

    - module: Autonomy.*
      purpose: Decision making and rule evaluation
      critical: true

  called_by:
    - module: Agents.Supervisor
      purpose: Dynamic supervision of agent instances

    - module: Runner
      purpose: Execution framework for agent work

    - module: NATS subjects (async)
      purpose: Task requests via messaging
  ```

  ### Anti-Patterns (Prevents Duplicates)

  - ❌ **DO NOT** create custom agent implementations - use Agent module
  - ❌ **DO NOT** bypass Agent for direct LLM calls - use this module
  - ✅ **DO** use Agent for all autonomous operations

  ### Search Keywords

  `agent`, `autonomous`, `self-improving`, `evolution`, `feedback`, `learning`, `metrics`, `task-execution`
  """
  use GenServer

  require Logger

  alias Singularity.{CodeStore, Control, HotReload, ProcessRegistry}
  alias Singularity.Execution.Autonomy.Decider
  alias Singularity.Execution.Autonomy.Limiter
  alias Singularity.Control.QueueCrdt
  alias Singularity.DynamicCompiler
  alias MapSet

  @default_tick_ms 5_000
  @history_limit 25

  @type outcome :: :success | :failure

  @type state :: %{
          id: String.t(),
          version: non_neg_integer(),
          context: map(),
          metrics: map(),
          status: :idle | :updating,
          cycles: non_neg_integer(),
          last_improvement_cycle: non_neg_integer(),
          last_failure_cycle: non_neg_integer() | nil,
          last_score: float(),
          pending_plan: map() | nil,
          pending_context: map() | nil,
          last_trigger: map() | nil,
          last_proposal_cycle: non_neg_integer() | nil,
          improvement_history: list(),
          improvement_queue: :queue.queue(),
          recent_fingerprints: MapSet.t(),
          pending_fingerprint: integer() | nil,
          pending_previous_code: String.t() | nil,
          pending_baseline: map() | nil,
          pending_validation_version: integer() | nil
        }

  ## Public API

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

  @doc """
  Enqueue an improvement payload for the agent identified by `agent_id`.

  Returns `:ok` if the agent was found and the request was handed to its process,
  otherwise `{:error, :not_found}`.
  """
  @spec improve(String.t(), map()) :: :ok | {:error, :not_found}
  def improve(agent_id, payload) when is_map(payload) do
    call_agent(agent_id, {:improve, payload})
  end

  @doc """
  Merge new metrics into the agent state. This is the hook for other processes
  to report observations (latency, reward, etc.).
  """
  @spec update_metrics(String.t(), map()) :: :ok | {:error, :not_found}
  def update_metrics(agent_id, metrics) when is_map(metrics) do
    call_agent(agent_id, {:update_metrics, metrics})
  end

  @doc """
  Record a single success or failure outcome. The agent uses these aggregates to
  estimate a score and decide whether it should evolve.
  """
  @spec record_outcome(String.t(), outcome) :: :ok | {:error, :not_found}
  def record_outcome(agent_id, outcome) when outcome in [:success, :failure] do
    call_agent(agent_id, {:record_outcome, outcome})
  end

  @doc """
  Force an evolution attempt on the next evaluation cycle, optionally providing
  a reason to document the trigger.
  """
  @spec force_improvement(String.t(), String.t()) :: :ok | {:error, :not_found}
  def force_improvement(agent_id, reason \\ "manual") do
    update_metrics(agent_id, %{force_improvement: true, force_reason: reason})
  end

  @doc """
  Execute a task using the specified agent.

  Routes to the appropriate agent type module (ArchitectureAgent, CostOptimizedAgent, etc.)
  which decides what tools to use and how to orchestrate them.

  ## Parameters

  - `agent_id`: String identifier of the agent (maps to agent type in registry)
  - `task`: String description of the task or task name
  - `context`: Map with task context (path, requirements, etc.)

  ## Returns

  - `{:ok, result}` - Task executed successfully with result
  - `{:error, :not_found}` - Agent not found in registry
  - `{:error, reason}` - Task execution failed with reason
  """
  @spec execute_task(String.t(), String.t(), map()) ::
          {:ok, term()} | {:error, :not_found | term()}
  def execute_task(agent_id, task, context \\ %{})

  def execute_task(agent_id, task, context)
      when is_binary(agent_id) and is_binary(task) and is_map(context) do
    case get_agent_type(agent_id) do
      {:ok, agent_type} ->
        case resolve_agent_module(agent_type) do
          {:ok, module} ->
            try do
              module.execute_task(task, context)
            rescue
              e ->
                Logger.error("Agent task execution failed",
                  agent_id: agent_id,
                  agent_type: agent_type,
                  task: task,
                  error: inspect(e)
                )

                {:error, "Agent task execution failed: #{Exception.message(e)}"}
            end

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  ## GenServer callbacks

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    queue = id |> CodeStore.load_queue() |> queue_from_list()

    state = %{
      id: id,
      version: 1,
      context: Map.new(opts),
      metrics: %{},
      status: :idle,
      cycles: 0,
      last_improvement_cycle: 0,
      last_failure_cycle: nil,
      last_score: 1.0,
      pending_plan: nil,
      pending_context: nil,
      last_trigger: nil,
      last_proposal_cycle: nil,
      improvement_history: [],
      improvement_queue: queue,
      recent_fingerprints: MapSet.new(),
      pending_fingerprint: nil,
      pending_previous_code: nil,
      pending_baseline: nil,
      pending_validation_version: nil
    }

    state
    |> maybe_schedule_queue_processing()
    |> schedule_tick()
    |> then(&{:ok, &1})
  end

  @impl true
  def handle_cast({:improve, payload}, state) do
    Logger.info("Agent improvement requested", agent_id: state.id)

    metadata = extract_metadata(payload)
    enriched_context = Map.merge(state.pending_context || %{}, metadata_context(metadata))

    state =
      state
      |> Map.put(:pending_plan, payload)
      |> Map.put(:pending_context, enriched_context)

    case HotReload.ModuleReloader.enqueue(state.id, payload) do
      :ok ->
        {:noreply, %{state | status: :updating}}

      {:error, reason} ->
        Logger.error("Failed to enqueue improvement", agent_id: state.id, reason: inspect(reason))

        failed_state =
          state
          |> Map.put(:pending_plan, nil)
          |> Map.put(:pending_context, nil)

        {:noreply, %{failed_state | status: :idle, last_failure_cycle: state.cycles}}
    end
  end

  @impl true
  def handle_cast({:update_metrics, metrics}, state) when is_map(metrics) do
    {:noreply, %{state | metrics: Map.merge(state.metrics, metrics)}}
  end

  @impl true
  def handle_cast({:record_outcome, outcome}, state) do
    metrics = increment_outcome(state.metrics, outcome)
    {:noreply, %{state | metrics: metrics}}
  end

  @impl true
  def handle_info(:tick, state) do
    state = increment_cycle(state)

    case Decider.decide(state) do
      {:continue, updated_state} ->
        {:noreply, schedule_tick(updated_state)}

      {:improve, payload, context, updated_state} ->
        {:noreply,
         updated_state
         |> maybe_start_improvement(payload, context)
         |> schedule_tick()}
    end
  end

  @impl true
  def handle_info({:reload_complete, version}, state) do
    QueueCrdt.release(state.id, state.pending_fingerprint)

    history_entry = %{
      version: version,
      completed_at: DateTime.utc_now(),
      cycle: state.cycles,
      context: state.pending_context
    }

    history =
      [history_entry | state.improvement_history]
      |> Enum.take(@history_limit)

    new_state =
      state
      |> Map.put(:version, version)
      |> Map.put(:status, :idle)
      |> Map.put(:last_improvement_cycle, state.cycles)
      |> Map.put(:pending_plan, nil)
      |> Map.put(:pending_context, nil)
      |> Map.put(:improvement_history, history)
      |> persist_queue_state()
      |> schedule_validation(version)

    emit_improvement_event(state.id, :success, %{count: 1}, %{version: version})

    {:noreply, process_queue(new_state)}
  end

  @impl true
  def handle_info({:reload_failed, reason}, state) do
    QueueCrdt.release(state.id, state.pending_fingerprint)

    Logger.warning("Agent improvement failed",
      agent_id: state.id,
      reason: inspect(reason)
    )

    new_state =
      state
      |> Map.put(:status, :idle)
      |> Map.put(:last_failure_cycle, state.cycles)
      |> Map.put(:pending_plan, nil)
      |> Map.put(:pending_context, nil)
      |> Map.put(:pending_fingerprint, nil)
      |> Map.put(:pending_previous_code, nil)
      |> Map.put(:pending_baseline, nil)
      |> Map.put(:pending_validation_version, nil)
      |> persist_queue_state()

    emit_improvement_event(state.id, :failure, %{count: 1}, %{reason: inspect(reason)})

    {:noreply, process_queue(new_state)}
  end

  @impl true
  def handle_info(:process_improvement_queue, state) do
    {:noreply, process_queue(state)}
  end

  def handle_info({:validate_improvement, _version}, %{pending_baseline: nil} = state) do
    {:noreply, state}
  end

  def handle_info(
        {:validate_improvement, version},
        %{pending_validation_version: current_version} = state
      )
      when current_version != version do
    {:noreply, state}
  end

  def handle_info({:validate_improvement, version}, state) do
    baseline = state.pending_baseline
    current = Singularity.Telemetry.snapshot()

    if regression?(baseline, current) do
      QueueCrdt.release(state.id, state.pending_fingerprint)

      Logger.warning("Validation detected regression, rolling back",
        agent_id: state.id,
        version: version,
        baseline: baseline,
        current: current
      )

      emit_improvement_event(state.id, :validation_failed, %{count: 1}, %{version: version})

      {:noreply,
       state
       |> Map.put(:pending_baseline, nil)
       |> Map.put(:pending_validation_version, nil)
       |> rollback_to_previous(version)}
    else
      emit_improvement_event(state.id, :validated, %{count: 1}, %{version: version})

      new_state =
        state
        |> Map.put(:pending_baseline, nil)
        |> Map.put(:pending_previous_code, nil)
        |> Map.put(:pending_validation_version, nil)
        |> finalize_successful_fingerprint()

      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call(:state, _from, state), do: {:reply, state, state}

  ## Helpers

  defp call_agent(agent_id, message) do
    agent_id = to_string(agent_id)

    case Registry.lookup(ProcessRegistry, {:agent, agent_id}) do
      [{pid, _}] ->
        GenServer.cast(pid, message)
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  defp get_agent_type(agent_id) do
    agent_id = to_string(agent_id)

    case Registry.lookup(ProcessRegistry, {:agent, agent_id}) do
      [{_pid, agent_type}] when is_atom(agent_type) ->
        {:ok, agent_type}

      [{_pid, agent_type}] when is_binary(agent_type) ->
        {:ok, String.to_atom(agent_type)}

      [{_pid, _}] ->
        # Agent found but no type metadata
        {:error, :agent_type_unknown}

      [] ->
        {:error, :not_found}
    end
  end

  defp resolve_agent_module(agent_type) when is_atom(agent_type) do
    case agent_type do
      :architecture ->
        {:ok, Singularity.Agents.ArchitectureAgent}

      :cost_optimized ->
        {:ok, Singularity.Agents.CostOptimizedAgent}

      :technology ->
        {:ok, Singularity.Agents.TechnologyAgent}

      :refactoring ->
        {:ok, Singularity.Agents.RefactoringAgent}

      :self_improving ->
        {:ok, Singularity.Agents.SelfImprovingAgent}

      :chat ->
        {:ok, Singularity.Agents.ChatConversationAgent}

      _ ->
        {:error, "Unknown agent type: #{inspect(agent_type)}"}
    end
  end

  defp resolve_agent_module(agent_type) when is_binary(agent_type) do
    agent_type
    |> String.to_atom()
    |> resolve_agent_module()
  rescue
    _ -> {:error, "Invalid agent type: #{agent_type}"}
  end

  defp make_id do
    "agent-" <> Integer.to_string(:erlang.unique_integer([:positive, :monotonic]))
  end

  defp schedule_tick(state) do
    interval = Map.get(state.context, :tick_interval_ms, @default_tick_ms)
    Process.send_after(self(), :tick, interval)
    state
  end

  defp increment_cycle(state) do
    Map.update!(state, :cycles, &(&1 + 1))
  end

  defp increment_outcome(metrics, :success), do: Map.update(metrics, :successes, 1, &(&1 + 1))
  defp increment_outcome(metrics, :failure), do: Map.update(metrics, :failures, 1, &(&1 + 1))

  defp extract_metadata(payload) do
    cond do
      Map.has_key?(payload, "metadata") -> Map.get(payload, "metadata") || %{}
      Map.has_key?(payload, :metadata) -> Map.get(payload, :metadata) || %{}
      true -> %{}
    end
  end

  defp metadata_context(metadata) when is_map(metadata) do
    Enum.reduce(metadata, %{}, fn
      {:reason, value}, acc -> Map.put(acc, :reason, value)
      {"reason", value}, acc -> Map.put(acc, :reason, value)
      {:score, value}, acc -> Map.put(acc, :score, value)
      {"score", value}, acc -> Map.put(acc, :score, value)
      {:samples, value}, acc -> Map.put(acc, :samples, value)
      {"samples", value}, acc -> Map.put(acc, :samples, value)
      {:stagnation_cycles, value}, acc -> Map.put(acc, :stagnation_cycles, value)
      {"stagnation_cycles", value}, acc -> Map.put(acc, :stagnation_cycles, value)
      {:generated_at, value}, acc -> Map.put(acc, :generated_at, value)
      {"generated_at", value}, acc -> Map.put(acc, :generated_at, value)
      _, acc -> acc
    end)
  end

  defp metadata_context(_), do: %{}

  defp maybe_start_improvement(state, payload, context) do
    fingerprint = payload_fingerprint(payload)

    cond do
      duplicate_payload?(state, fingerprint) ->
        Logger.debug("Skipping duplicate improvement payload", agent_id: state.id)
        emit_improvement_event(state.id, :duplicate, %{count: 1}, base_metadata(context))
        state

      state.status == :updating ->
        enqueue_improvement(state, payload, context)

      not Limiter.allow?(state.id) ->
        Logger.debug("Improvement rate limited, queued", agent_id: state.id)
        emit_improvement_event(state.id, :rate_limited, %{count: 1}, base_metadata(context))
        enqueue_improvement(state, payload, context)

      true ->
        start_improvement_if_valid(state, payload, context, fingerprint)
    end
  end

  defp start_improvement_if_valid(state, payload, context, fingerprint) do
    case ensure_valid_payload(payload) do
      {:error, {_tag, msg}} ->
        Logger.warning("Preflight validation failed",
          agent_id: state.id,
          reason: inspect(msg)
        )

        emit_improvement_event(state.id, :invalid, %{count: 1}, base_metadata(context))
        state

      :ok ->
        start_improvement_if_available(state, payload, context, fingerprint)
    end
  end

  defp start_improvement_if_available(state, payload, context, fingerprint) do
    if QueueCrdt.reserve(state.id, fingerprint) do
      Logger.info("Publishing self-improvement",
        agent_id: state.id,
        reason: context_fetch(context, :reason),
        score: context_fetch(context, :score),
        samples: context_fetch(context, :samples)
      )

      emit_improvement_event(
        state.id,
        :attempt,
        %{count: 1},
        Map.put(base_metadata(context), :source, :direct)
      )

      baseline = Singularity.Telemetry.snapshot()
      previous_code = read_active_code(state.id)

      Control.publish_improvement(state.id, payload)

      pending_context = Map.new(context, fn {k, v} -> {k, v} end)

      state
      |> Map.put(:pending_plan, payload)
      |> Map.put(:pending_context, pending_context)
      |> Map.put(:last_trigger, context)
      |> Map.put(:last_proposal_cycle, state.cycles)
      |> Map.put(:status, :updating)
      |> Map.put(:pending_fingerprint, fingerprint)
      |> Map.put(:pending_previous_code, previous_code)
      |> Map.put(:pending_baseline, baseline)
    else
      emit_improvement_event(state.id, :duplicate, %{count: 1}, base_metadata(context))
      state
    end
  end

  defp enqueue_improvement(state, payload, context) do
    fingerprint = payload_fingerprint(payload)

    cond do
      duplicate_payload?(state, fingerprint) ->
        Logger.debug("Ignoring duplicate queued payload", agent_id: state.id)
        emit_improvement_event(state.id, :duplicate, %{count: 1}, base_metadata(context))
        state

      queue_contains_fingerprint?(state.improvement_queue, fingerprint) ->
        Logger.debug("Payload already queued", agent_id: state.id)
        state

      true ->
        entry = %{
          payload: payload,
          context: context,
          inserted_at: System.system_time(:millisecond),
          fingerprint: fingerprint
        }

        new_queue = :queue.in(entry, state.improvement_queue)
        Process.send_after(self(), :process_improvement_queue, 1_000)

        emit_improvement_event(
          state.id,
          :queued,
          %{queue_depth: :queue.len(new_queue)},
          base_metadata(context)
        )

        persist_queue(state.id, new_queue)

        state
        |> Map.put(:improvement_queue, new_queue)
        |> Map.put_new(:last_trigger, context)
    end
  end

  defp process_queue(%{status: :updating} = state), do: state

  defp process_queue(%{improvement_queue: queue} = state) do
    case :queue.out(queue) do
      {{:value, entry}, rest} ->
        process_queue_entry(state, entry, rest)

      {:empty, _} ->
        persist_queue(state.id, queue)
        state
    end
  end

  defp process_queue_entry(state, entry, rest) do
    if Limiter.allow?(state.id) do
      Logger.info("Processing queued improvement",
        agent_id: state.id,
        queue_depth: :queue.len(rest)
      )

      emit_improvement_event(
        state.id,
        :attempt,
        %{count: 1},
        Map.put(base_metadata(entry.context), :source, :queue)
      )

      fingerprint =
        entry[:fingerprint] || entry["fingerprint"] || payload_fingerprint(entry.payload)

      process_validated_entry(state, entry, rest, fingerprint)
    else
      # Put it back and retry later
      Process.send_after(self(), :process_improvement_queue, 5_000)
      new_queue = :queue.in_r(entry, rest)
      persist_queue(state.id, new_queue)
      Map.put(state, :improvement_queue, new_queue)
    end
  end

  defp process_validated_entry(state, entry, rest, fingerprint) do
    case ensure_valid_payload(entry.payload) do
      {:error, {_tag, msg}} ->
        Logger.warning("Preflight validation failed (queued)",
          agent_id: state.id,
          reason: inspect(msg)
        )

        emit_improvement_event(
          state.id,
          :invalid,
          %{count: 1},
          base_metadata(entry.context)
        )

        persist_queue(state.id, rest)
        process_queue(%{state | improvement_queue: rest})

      :ok ->
        process_available_entry(state, entry, rest, fingerprint)
    end
  end

  defp process_available_entry(state, entry, rest, fingerprint) do
    if QueueCrdt.reserve(state.id, fingerprint) do
      baseline = Singularity.Telemetry.snapshot()
      previous_code = read_active_code(state.id)

      Control.publish_improvement(state.id, entry.payload)

      pending_context = Map.new(entry.context, fn {k, v} -> {k, v} end)

      new_state =
        state
        |> Map.put(:pending_plan, entry.payload)
        |> Map.put(:pending_context, pending_context)
        |> Map.put(:improvement_queue, rest)
        |> Map.put(:status, :updating)
        |> Map.put(:pending_fingerprint, fingerprint)
        |> Map.put(:pending_previous_code, previous_code)
        |> Map.put(:pending_baseline, baseline)

      persist_queue(state.id, rest)
      new_state
    else
      emit_improvement_event(
        state.id,
        :duplicate,
        %{count: 1},
        base_metadata(entry.context)
      )

      persist_queue(state.id, rest)
      process_queue(%{state | improvement_queue: rest})
    end
  end

  defp maybe_schedule_queue_processing(%{improvement_queue: queue} = state) do
    if :queue.is_empty(queue) do
      state
    else
      Process.send_after(self(), :process_improvement_queue, 1_000)
      state
    end
  end

  defp persist_queue_state(%{improvement_queue: queue} = state) do
    persist_queue(state.id, queue)
    state
  end

  defp queue_from_list(list) when is_list(list) do
    Enum.reduce(list, :queue.new(), fn entry, acc ->
      normalized = normalize_queue_entry(entry)
      :queue.in(normalized, acc)
    end)
  end

  defp queue_from_list(_), do: :queue.new()

  defp persist_queue(agent_id, queue) do
    CodeStore.save_queue(agent_id, :queue.to_list(queue))
  end

  defp schedule_validation(state, version) do
    Process.send_after(self(), {:validate_improvement, version}, validation_delay())
    Map.put(state, :pending_validation_version, version)
  end

  defp validation_delay do
    System.get_env("IMP_VALIDATION_DELAY_MS")
    |> parse_integer(30_000)
  end

  defp base_metadata(context) do
    %{
      reason: context_fetch(context, :reason),
      score: context_fetch(context, :score),
      samples: context_fetch(context, :samples)
    }
  end

  defp duplicate_payload?(_state, nil), do: false

  defp duplicate_payload?(state, fingerprint) do
    MapSet.member?(state.recent_fingerprints, fingerprint) or
      queue_contains_fingerprint?(state.improvement_queue, fingerprint) or
      state.pending_fingerprint == fingerprint
  end

  defp queue_contains_fingerprint?(queue, fingerprint) do
    queue
    |> :queue.to_list()
    |> Enum.any?(fn
      %{fingerprint: fp} when fp == fingerprint -> true
      _ -> false
    end)
  end

  defp ensure_valid_payload(%{"code" => code}) when is_binary(code),
    do: DynamicCompiler.validate(code)

  defp ensure_valid_payload(%{code: code}) when is_binary(code),
    do: DynamicCompiler.validate(code)

  defp ensure_valid_payload(_), do: {:error, {:invalid_payload, :missing_code}}

  defp payload_fingerprint(payload) when is_map(payload) do
    try do
      # Create a stable fingerprint by sorting keys and converting to binary
      sorted_payload =
        payload
        |> Map.to_list()
        |> Enum.sort_by(fn {k, _} -> k end)
        |> Enum.into(%{})

      :erlang.term_to_binary(sorted_payload)
      |> :erlang.phash2()
    rescue
      _ -> nil
    end
  end

  defp payload_fingerprint(payload) when is_binary(payload) do
    :erlang.phash2(payload)
  end

  defp payload_fingerprint(_), do: nil

  defp regression?(nil, _current), do: false

  defp regression?(baseline, current) do
    memory_growth = get_memory(current)
    baseline_memory = get_memory(baseline)
    run_queue = get_run_queue(current)
    baseline_run_queue = get_run_queue(baseline)

    memory_limit = baseline_memory * memory_multiplier()
    run_queue_limit = baseline_run_queue + run_queue_threshold()

    exceeds_memory_limit?(baseline_memory, memory_growth, memory_limit) or
      exceeds_run_queue_limit?(run_queue, run_queue_limit)
  end

  defp get_memory(data), do: data[:memory] || data["memory"] || 0
  defp get_run_queue(data), do: data[:run_queue] || data["run_queue"] || 0

  defp exceeds_memory_limit?(baseline_memory, memory_growth, memory_limit) do
    baseline_memory > 0 and memory_growth > memory_limit
  end

  defp exceeds_run_queue_limit?(run_queue, run_queue_limit) do
    run_queue > run_queue_limit
  end

  defp memory_multiplier do
    System.get_env("IMP_VALIDATION_MEMORY_MULT")
    |> case do
      nil ->
        1.25

      value ->
        case Float.parse(value) do
          {float, _} when float > 1.0 -> float
          _ -> 1.25
        end
    end
  end

  defp run_queue_threshold do
    System.get_env("IMP_VALIDATION_RUNQ_DELTA")
    |> parse_integer(50)
  end

  defp rollback_to_previous(%{pending_previous_code: nil} = state, _version) do
    Logger.warning("No previous code available for rollback", agent_id: state.id)

    state
    |> Map.put(:pending_fingerprint, nil)
    |> Map.put(:pending_previous_code, nil)
  end

  defp rollback_to_previous(%{pending_previous_code: code} = state, version) do
    payload = %{
      "code" => code,
      "metadata" => %{"rollback" => version}
    }

    emit_improvement_event(state.id, :rollback, %{count: 1}, %{version: version})

    fingerprint = payload_fingerprint(payload)

    case QueueCrdt.reserve(state.id, fingerprint) do
      false ->
        state
        |> Map.put(:pending_fingerprint, nil)
        |> Map.put(:pending_previous_code, nil)

      true ->
        _ = HotReload.ModuleReloader.enqueue(state.id, payload)
        Limiter.reset(state.id)

        baseline = Singularity.Telemetry.snapshot()

        state
        |> Map.put(:status, :updating)
        |> Map.put(:pending_plan, payload)
        |> Map.put(:pending_context, %{"reason" => "rollback"})
        |> Map.put(:pending_baseline, baseline)
        |> Map.put(:pending_previous_code, nil)
        |> Map.put(:pending_fingerprint, fingerprint)
        |> Map.put(
          :recent_fingerprints,
          MapSet.delete(state.recent_fingerprints, state.pending_fingerprint)
        )
    end
  end

  defp finalize_successful_fingerprint(%{pending_fingerprint: nil} = state), do: state

  defp finalize_successful_fingerprint(state) do
    new_set =
      state.recent_fingerprints
      |> MapSet.put(state.pending_fingerprint)
      |> trim_fingerprints()

    state
    |> Map.put(:recent_fingerprints, new_set)
    |> Map.put(:pending_fingerprint, nil)
  end

  defp read_active_code(agent_id) do
    paths = CodeStore.paths()
    active_path = Path.join(paths.active, "#{agent_id}.exs")

    case File.read(active_path) do
      {:ok, contents} -> contents
      _ -> nil
    end
  end

  defp parse_integer(nil, default), do: default

  defp parse_integer(value, default) do
    case Integer.parse(value) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  defp trim_fingerprints(set) do
    if MapSet.size(set) > 500 do
      set
      |> MapSet.to_list()
      |> Enum.take(400)
      |> MapSet.new()
    else
      set
    end
  end

  defp normalize_queue_entry(%{payload: payload, context: context} = entry) do
    fingerprint =
      Map.get(entry, :fingerprint) || Map.get(entry, "fingerprint") ||
        payload_fingerprint(payload)

    %{
      payload: payload,
      context: context || %{},
      inserted_at:
        Map.get(entry, :inserted_at) || Map.get(entry, "inserted_at") ||
          System.system_time(:millisecond),
      fingerprint: fingerprint
    }
  end

  defp normalize_queue_entry(data) when is_map(data) do
    payload = Map.get(data, "payload")
    context = Map.get(data, "context") || %{}
    fingerprint = Map.get(data, "fingerprint") || payload_fingerprint(payload)

    %{
      payload: payload,
      context: context,
      inserted_at: Map.get(data, "inserted_at") || System.system_time(:millisecond),
      fingerprint: fingerprint
    }
  end

  defp context_fetch(context, key) when is_map(context) do
    # Try different key formats
    cond do
      Map.has_key?(context, key) -> Map.get(context, key)
      Map.has_key?(context, Atom.to_string(key)) -> Map.get(context, Atom.to_string(key))
      Map.has_key?(context, to_string(key)) -> Map.get(context, to_string(key))
      true -> nil
    end
  end

  defp context_fetch(context, key) when is_list(context) do
    # Handle keyword list context
    Keyword.get(context, key) || Keyword.get(context, Atom.to_string(key))
  end

  defp context_fetch(_, _), do: nil

  defp emit_improvement_event(agent_id, event, measurements, metadata) do
    meta =
      metadata
      |> Map.new()
      |> Map.put(:agent_id, agent_id)

    :telemetry.execute([:singularity, :improvement, event], measurements, meta)
  end
end
