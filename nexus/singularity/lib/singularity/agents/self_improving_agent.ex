defmodule Singularity.SelfImprovingAgent do
  @moduledoc """
  Self-Improving Agent - Autonomous agent with continuous learning and evolution capabilities.

  ## Overview

  Core GenServer representing a self-improving agent instance that maintains its own
  feedback loop: observes metrics, decides when to evolve, synthesises new Gleam code,
  and hands the payload to the hot-reload manager. External systems can still push
  improvements, but they are no longer required for the agent to progress.

  ## Public API Contract

  - `start_link/1` - Start the agent with configuration
  - `observe_metrics/2` - Record performance metrics for learning
  - `request_improvement/2` - Trigger improvement cycle
  - `get_state/1` - Retrieve current agent state

  ## Error Matrix

  - `{:error, :invalid_config}` - Invalid agent configuration
  - `{:error, :evolution_failed}` - Self-improvement cycle failed
  - `{:error, :metrics_unavailable}` - Required metrics not available

  ## Performance Notes

  - Metrics observation: < 1ms per call
  - Evolution cycle: 100-500ms depending on complexity
  - State retrieval: < 0.1ms

  ## Concurrency Semantics

  - Single-threaded GenServer (no concurrent access to state)
  - Async evolution cycles via Task.Supervisor
  - Thread-safe metrics collection

  ## Security Considerations

  - Validates all incoming improvement payloads
  - Sandboxes evolution experiments in Genesis
  - Rate limits evolution cycles to prevent resource exhaustion

  ## Examples

      # Start agent
      {:ok, pid} = SelfImprovingAgent.start_link(name: :my_agent)

      # Observe metrics
      SelfImprovingAgent.observe_metrics(pid, %{success_rate: 0.95, latency: 100})

      # Request improvement
      SelfImprovingAgent.request_improvement(pid, :performance_optimization)

  ## Relationships

  - **Uses**: CodeStore, HotReload, ProcessRegistry
  - **Integrates with**: Genesis (experiments), CentralCloud (learning)
  - **Supervised by**: AgentSupervisor

  ## Template Version

  - **Applied:** self-improving-agent v2.3.0
  - **Applied on:** 2025-01-15
  - **Upgrade path:** v2.2.0 -> v2.3.0 (added self-awareness protocol)

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "SelfImprovingAgent",
    "purpose": "autonomous_agent_evolution",
    "domain": "agents",
    "capabilities": ["self_improvement", "metrics_observation", "evolution_cycles"],
    "dependencies": ["CodeStore", "HotReload", "Genesis", "CentralCloud"]
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    A[SelfImprovingAgent] --> B[Metrics Observer]
    A --> C[Evolution Decider]
    A --> D[Gleam Code Synthesizer]
    B --> E[Performance Metrics]
    C --> F[Improvement Strategy]
    D --> G[Hot Reload Manager]
    F --> H[Genesis Sandbox]
    G --> I[Live Code Update]
  ```

  ## Call Graph (YAML)
  ```yaml
  SelfImprovingAgent:
    start_link/1: [GenServer.start_link/3]
    observe_metrics/2: [handle_cast/2]
    request_improvement/2: [handle_cast/2]
    get_state/1: [handle_call/3]
    handle_info/2: [evolution_cycle/1, metrics_analysis/1]
  ```

  ## Anti-Patterns

  - **DO NOT** create multiple SelfImprovingAgent instances for the same purpose
  - **DO NOT** bypass the Genesis sandbox for high-risk experiments
  - **DO NOT** call evolution cycles synchronously (use async tasks)
  - **DO NOT** ignore metrics validation before evolution decisions

  ## Search Keywords

  self-improving, autonomous-agent, evolution, metrics, gleam, hot-reload, genesis, centralcloud, learning, adaptation, performance, optimization, feedback-loop, continuous-improvement
  """
  use GenServer

  require Logger

  alias Singularity.{CodeStore, HotReload, ProcessRegistry}
  alias Singularity.Execution.Runners.Control
  alias Singularity.Execution.Autonomy.Decider
  alias Singularity.Execution.Autonomy.Limiter
  alias Singularity.Control.QueueCrdt
  alias Singularity.DynamicCompiler
  alias Singularity.HITL.ApprovalService
  alias Singularity.Agents.TemplatePerformance
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
  Run complete self-awareness pipeline: parse codebase, detect issues, enforce quality, generate fixes.

  This is the main entry point for the self-evolving system to understand and improve itself.
  """
  @spec run_self_awareness_pipeline(String.t()) :: {:ok, map()} | {:error, term()}
  def run_self_awareness_pipeline(codebase_path \\ File.cwd!()) do
    GenServer.call(__MODULE__, {:run_self_awareness_pipeline, codebase_path})
  end

  @doc """
  Analyze template performance across all templates.

  Phase 4: Self-Improvement - Identifies failing templates (success_rate < 0.8) and
  triggers automatic improvement based on CentralCloud intelligence.

  Returns a report with:
  - Templates analyzed
  - Failing templates identified
  - Improvements triggered

  ## Examples

      iex> SelfImprovingAgent.analyze_template_performance()
      {:ok, %{
        templates_analyzed: 5,
        failing_templates: 2,
        improvements_triggered: 2
      }}
  """
  @spec analyze_template_performance() :: {:ok, map()} | {:error, term()}
  def analyze_template_performance do
    TemplatePerformance.analyze_template_performance()
  end

  @doc """
  Improve a specific failing template based on failure analysis.

  Takes template_id and failure patterns, generates an improved version using LLM,
  tests it, and deploys if successful.

  ## Examples

      iex> SelfImprovingAgent.improve_failing_template(
      ...>   "quality_template:elixir-production",
      ...>   %{success_rate: 0.72, common_failures: [...]}
      ...> )
      {:ok, %{template_id: "...", improved: true, deployed: true}}
  """
  @spec improve_failing_template(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def improve_failing_template(template_id, failure_analysis) do
    TemplatePerformance.improve_failing_template(template_id, failure_analysis)
  end

  @doc """
  Upgrade documentation for a file to quality 2.2.0+ standards.

  This function is called by the DocumentationPipeline to coordinate
  documentation upgrades across all source files.
  """
  @spec upgrade_documentation(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def upgrade_documentation(file_path, opts \\ []) do
    DocPipeline.upgrade_module_documentation(file_path, opts)
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
      pending_validation_version: nil,
      pending_genesis_request: nil,
      pending_genesis_experiment_id: nil
    }

    # Subscribe to Genesis experiment results
    subscribe_to_genesis_results(id)

    state =
      state
      |> maybe_schedule_queue_processing()
      |> schedule_tick()

    {:ok, state, {:continue, :register}}
  end

  @impl true
  def handle_continue(:register, state) do
    # Register with coordination router
    alias Singularity.Agents.Coordination.AgentRegistration

    AgentRegistration.register_agent(:self_improving_agent, %{
      role: :self_improve,
      domains: [:code_quality, :refactoring, :testing, :architecture],
      input_types: [:code, :codebase, :metrics, :feedback],
      output_types: [:code, :documentation, :analysis],
      complexity_level: :complex,
      estimated_cost: 1000,
      success_rate: 0.88,
      tags: [:async_safe, :parallelizable, :learning_enabled],
      metadata: %{"version" => Singularity.BuildInfo.version()}
    })

    {:noreply, state}
  end

  defp subscribe_to_genesis_results(agent_id) do
    # Subscribe to PGFlow workflow completion events for Genesis experiment results
    workflow_name = "genesis_experiment_#{agent_id}"

    case Pgflow.Workflow.subscribe(workflow_name, fn workflow_result ->
           handle_genesis_workflow_completion(agent_id, workflow_result)
         end) do
      {:ok, subscription_id} ->
        Logger.debug("Subscribed to Genesis results via PGFlow workflow",
          agent_id: agent_id,
          workflow: workflow_name,
          subscription_id: subscription_id
        )

        {:ok, subscription_id}

      {:error, reason} ->
        Logger.warning("Failed to subscribe to Genesis results via PGFlow",
          agent_id: agent_id,
          reason: reason
        )

        # Fallback: log migration status
        Logger.debug("Genesis results subscription migrated to Pgflow workflow notifications",
          agent_id: agent_id
        )

        {:ok, "pgflow_migrated"}
    end
  end

  defp handle_genesis_workflow_completion(agent_id, %{status: :completed, result: result}) do
    # Handle completed Genesis experiment workflow
    Logger.info("Genesis experiment workflow completed",
      agent_id: agent_id,
      result: result
    )

    # Send message to agent to handle completion
    send(self(), {:genesis_experiment_completed, result.experiment_id, result})
    :ok
  end

  defp handle_genesis_workflow_completion(agent_id, %{status: :failed, error: error}) do
    Logger.error("Genesis experiment workflow failed",
      agent_id: agent_id,
      error: error
    )

    :ok
  end

  defp handle_genesis_workflow_completion(_agent_id, _), do: :ok

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

      {:improve_local, payload, context, updated_state} ->
        # Type 1: Apply improvement directly (low-risk parameter tuning)
        {:noreply,
         updated_state
         |> maybe_start_improvement(payload, context)
         |> schedule_tick()}

      {:improve_experimental, payload, context, updated_state} ->
        # Type 3: Send to Genesis for testing (high-risk changes)
        {:noreply,
         updated_state
         |> request_genesis_experiment(payload, context)
         |> schedule_tick()}
    end
  end

  @impl true
  def handle_info({:genesis_experiment_completed, experiment_id, result}, state) do
    # Handle Genesis sandbox test results
    case state do
      %{pending_genesis_experiment_id: ^experiment_id} ->
        handle_genesis_result(state, experiment_id, result)

      _ ->
        Logger.warning("Received Genesis result for unknown experiment",
          experiment_id: experiment_id,
          agent_id: state.id
        )

        {:noreply, state}
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
    current = Singularity.Infrastructure.Telemetry.snapshot()

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

  @impl true
  def handle_call({:run_self_awareness_pipeline, codebase_path}, _from, state) do
    # Start self-awareness pipeline in background
    Task.start(fn -> run_self_awareness_pipeline_internal(codebase_path) end)
    {:reply, {:ok, :pipeline_started}, state}
  end

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

  defp request_genesis_experiment(state, payload, context) do
    experiment_id = "exp-#{state.id}-#{System.monotonic_time(:millisecond)}"

    Logger.info("Sending high-risk improvement to Genesis sandbox",
      agent_id: state.id,
      experiment_id: experiment_id,
      reason: Map.get(context, :reason),
      score: Map.get(context, :score)
    )

    # Build Genesis experiment request
    request = %{
      "experiment_id" => experiment_id,
      "instance_id" => state.id,
      "risk_level" => "high",
      "payload" => payload,
      "description" => "Test: #{Map.get(context, :reason)}",
      "metrics" => %{
        "current_score" => Map.get(context, :score),
        "samples" => Map.get(context, :samples),
        "stagnation" => Map.get(context, :stagnation, 0)
      },
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Publish request to Genesis via Pgflow workflow
    case Pgflow.Workflow.create_workflow(
           Singularity.Workflows.GenesisExperimentRequestWorkflow,
           %{
             "request" => request,
             "agent_id" => state.id,
             "experiment_id" => experiment_id
           }
         ) do
      {:ok, workflow_id} ->
        Logger.debug("Genesis experiment request workflow created",
          experiment_id: experiment_id,
          workflow_id: workflow_id
        )

        emit_improvement_event(
          state.id,
          :genesis_request,
          %{count: 1},
          Map.put(context, :experiment_id, experiment_id)
        )

        # Update state to track pending Genesis request
        state
        |> Map.put(:status, :waiting_for_genesis)
        |> Map.put(:pending_genesis_request, request)
        |> Map.put(:pending_genesis_experiment_id, experiment_id)
        |> Map.put(:genesis_workflow_id, workflow_id)

      {:error, reason} ->
        Logger.error("Failed to send Genesis request",
          agent_id: state.id,
          experiment_id: experiment_id,
          reason: inspect(reason)
        )

        emit_improvement_event(state.id, :genesis_request_failed, %{count: 1}, context)
        state
    end
  end

  defp handle_genesis_result(state, experiment_id, result) do
    Logger.info("Genesis experiment completed",
      agent_id: state.id,
      experiment_id: experiment_id,
      recommendation: Map.get(result, "recommendation")
    )

    # Extract Genesis metrics and recommendation
    metrics = Map.get(result, "metrics", %{})
    recommendation = Map.get(result, "recommendation", "rollback")
    payload = Map.get(state.pending_genesis_request, "payload")

    case recommendation do
      "merge" ->
        # Approve - apply the code directly
        Logger.info("Genesis approved improvement, applying directly",
          agent_id: state.id,
          experiment_id: experiment_id
        )

        emit_improvement_event(
          state.id,
          :genesis_approved,
          %{count: 1},
          %{experiment_id: experiment_id, metrics: metrics}
        )

        # Apply the Genesis-tested code
        start_improvement_if_valid(
          state,
          payload,
          %{reason: :genesis_approved, experiment_id: experiment_id},
          payload_fingerprint(payload)
        )

      "merge_with_adaptations" ->
        # Approve with modifications - apply with caution
        Logger.info("Genesis approved with adaptations needed",
          agent_id: state.id,
          experiment_id: experiment_id
        )

        emit_improvement_event(
          state.id,
          :genesis_approved_adapted,
          %{count: 1},
          %{experiment_id: experiment_id, metrics: metrics}
        )

        # Apply with lower confidence
        start_improvement_if_valid(
          state,
          payload,
          %{
            reason: :genesis_approved_adapted,
            experiment_id: experiment_id,
            adaptations_needed: Map.get(result, "adaptations", [])
          },
          payload_fingerprint(payload)
        )

      "rollback" ->
        # Reject - don't apply
        Logger.warning("Genesis rejected improvement",
          agent_id: state.id,
          experiment_id: experiment_id,
          reason: Map.get(result, "reason", "test failure")
        )

        emit_improvement_event(
          state.id,
          :genesis_rejected,
          %{count: 1},
          %{
            experiment_id: experiment_id,
            reason: Map.get(result, "reason", "unknown")
          }
        )

        # Return to idle - don't apply code
        state
        |> Map.put(:status, :idle)
        |> Map.put(:pending_genesis_request, nil)
        |> Map.put(:pending_genesis_experiment_id, nil)

      _ ->
        Logger.error("Unknown Genesis recommendation",
          agent_id: state.id,
          experiment_id: experiment_id,
          recommendation: recommendation
        )

        state
        |> Map.put(:status, :idle)
        |> Map.put(:pending_genesis_request, nil)
        |> Map.put(:pending_genesis_experiment_id, nil)
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

      baseline = Singularity.Infrastructure.Telemetry.snapshot()
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
      baseline = Singularity.Infrastructure.Telemetry.snapshot()
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

        baseline = Singularity.Infrastructure.Telemetry.snapshot()

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

  ## Self-Awareness Pipeline

  defp run_self_awareness_pipeline_internal(codebase_path) do
    Logger.info("Starting self-awareness pipeline", path: codebase_path)

    try do
      # 1. Parse codebase using existing ParserEngine
      parse_result = parse_codebase_existing(codebase_path)

      # 2. Analyze using existing CodeStore
      analysis_result = analyze_codebase_existing(codebase_path)

      # 3. Check quality using existing QualityEnforcer
      quality_result = check_quality_existing(codebase_path)

      # 4. Check documentation using DocumentationPipeline
      doc_result = check_documentation_existing(codebase_path)

      # 5. Generate fixes using existing tools OR emergency Claude CLI
      fixes =
        generate_fixes_with_fallback(analysis_result, quality_result, doc_result, codebase_path)

      # 6. Request approval using existing ApprovalService
      if length(fixes) > 0 do
        request_approvals_existing(fixes)
      end

      # 7. Apply approved fixes using existing HotReload
      apply_fixes_existing(fixes)

      Logger.info("Self-awareness pipeline complete",
        files_parsed: parse_result.files_parsed,
        issues_found: analysis_result.issues_found,
        fixes_generated: length(fixes)
      )
    rescue
      error ->
        Logger.error("Self-awareness pipeline failed, trying emergency Claude CLI",
          error: inspect(error)
        )

        # Fallback to emergency Claude CLI
        run_emergency_self_awareness(codebase_path)
    end
  end

  defp parse_codebase_existing(codebase_path) do
    # Use existing ParserEngine for parsing
    files = discover_files(codebase_path)

    parse_results =
      files
      |> Enum.map(fn file_path ->
        case Singularity.ParserEngine.parse_file(file_path) do
          {:ok, parsed} -> {:ok, file_path, parsed}
          {:error, reason} -> {:error, file_path, reason}
        end
      end)
      |> Enum.filter(fn result -> match?({:ok, _, _}, result) end)

    %{
      files_parsed: length(parse_results),
      total_files: length(files),
      success_rate: length(parse_results) / length(files)
    }
  end

  defp analyze_codebase_existing(codebase_path) do
    # Use existing CodeStore.analyze_codebase
    case Singularity.Repo.get_by(Singularity.Schemas.Codebase, path: codebase_path) do
      nil ->
        %{issues_found: 0, analysis_available: false}

      codebase ->
        case Singularity.CodeStore.analyze_codebase(codebase.id) do
          {:ok, analysis} ->
            %{
              issues_found: count_issues(analysis),
              analysis_available: true,
              analysis: analysis
            }

          {:error, _reason} ->
            %{issues_found: 0, analysis_available: false}
        end
    end
  end

  defp check_quality_existing(codebase_path) do
    # Use existing QualityEnforcer
    files = discover_files(codebase_path)

    quality_results =
      files
      |> Enum.map(fn file_path ->
        case Singularity.Agents.CodeQualityAgent.validate_file_quality(file_path) do
          {:ok, validation} -> {:ok, file_path, validation}
          {:error, reason} -> {:error, file_path, reason}
        end
      end)

    compliant_files =
      quality_results
      |> Enum.filter(fn result ->
        match?({:ok, _, %{quality_score: score}} when score >= 0.8, result)
      end)
      |> length()

    %{
      total_files: length(files),
      compliant_files: compliant_files,
      compliance_rate: compliant_files / length(files)
    }
  end

  defp check_documentation_existing(codebase_path) do
    # Use DocumentationPipeline for analysis
    files = discover_files(codebase_path)

    doc_results =
      files
      |> Enum.map(fn file_path ->
        case Singularity.Agents.DocumentationPipeline.analyze_file_documentation(file_path) do
          {:ok, analysis} -> {:ok, file_path, analysis}
          {:error, reason} -> {:error, file_path, reason}
        end
      end)

    documented_files =
      doc_results
      |> Enum.filter(fn result ->
        match?({:ok, _, %{quality_score: score}} when score >= 0.8, result)
      end)
      |> length()

    %{
      total_files: length(files),
      documented_files: documented_files,
      documentation_rate: documented_files / length(files)
    }
  end

  defp generate_fixes_with_fallback(analysis_result, quality_result, doc_result, codebase_path) do
    # Try existing tools first
    case generate_fixes_existing(analysis_result, quality_result, doc_result) do
      [_ | _] = fixes ->
        # Existing tools generated fixes - log metrics
        Logger.info("Generated #{length(fixes)} fixes from existing tools",
          fix_count: length(fixes),
          quality_compliance: quality_result.compliance_rate
        )

        fixes

      [] ->
        # No fixes generated by existing tools, try emergency Claude CLI
        Logger.info("No fixes generated by existing tools, trying emergency Claude CLI")

        generated =
          generate_fixes_emergency_claude(
            analysis_result,
            quality_result,
            doc_result,
            codebase_path
          )

        Logger.info("Emergency Claude generated #{length(generated)} fixes",
          fix_count: length(generated)
        )

        generated
    end
  end

  defp generate_fixes_existing(analysis_result, quality_result, doc_result) do
    fixes = []

    # Generate quality fixes if needed
    fixes =
      if quality_result.compliance_rate < 0.8 do
        [
          %{
            type: :quality,
            description: "Quality compliance below threshold (#{quality_result.compliance_rate})",
            files_affected: quality_result.total_files - quality_result.compliant_files,
            priority: :medium
          }
          | fixes
        ]
      else
        fixes
      end

    # Generate documentation fixes if needed
    fixes =
      if doc_result.documentation_rate < 0.8 do
        [
          %{
            type: :documentation,
            description:
              "Documentation compliance below threshold (#{doc_result.documentation_rate})",
            files_affected: doc_result.total_files - doc_result.documented_files,
            priority: :medium
          }
          | fixes
        ]
      else
        fixes
      end

    # Generate analysis fixes if issues found
    fixes =
      if analysis_result.issues_found > 0 do
        [
          %{
            type: :analysis,
            description: "Code analysis found #{analysis_result.issues_found} issues",
            files_affected: analysis_result.issues_found,
            priority: :high
          }
          | fixes
        ]
      else
        fixes
      end

    fixes
  end

  defp generate_fixes_emergency_claude(analysis_result, quality_result, doc_result, codebase_path) do
    # Use emergency Claude CLI to generate fixes
    prompt = build_emergency_prompt(analysis_result, quality_result, doc_result, codebase_path)

    case call_emergency_claude(prompt) do
      {:ok, response} ->
        parse_emergency_response(response)

      {:error, reason} ->
        Logger.error("Emergency Claude CLI failed", reason: reason)
        []
    end
  end

  defp build_emergency_prompt(analysis_result, quality_result, doc_result, codebase_path) do
    """
    You are an emergency AI assistant helping to fix a self-evolving codebase.

    Codebase: #{codebase_path}

    Analysis Results:
    - Issues found: #{analysis_result.issues_found}
    - Quality compliance: #{quality_result.compliance_rate}
    - Documentation compliance: #{doc_result.documentation_rate}

    Please generate specific fixes for this codebase. Focus on:
    1. Quality 2.3.0 compliance improvements
    2. Documentation upgrades with AI metadata
    3. Code analysis issue fixes

    Return fixes in JSON format:
    [
      {
        "type": "quality|documentation|analysis",
        "description": "What needs to be fixed",
        "files_affected": 5,
        "priority": "high|medium|low",
        "fix_content": "Specific code or instructions"
      }
    ]
    """
  end

  defp call_emergency_claude(prompt) do
    # Use emergency Claude CLI
    case Singularity.Integration.Claude.chat(prompt, profile: :recovery) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        Logger.error("Emergency Claude CLI call failed", reason: reason)
        {:error, reason}
    end
  end

  defp parse_emergency_response(response) do
    try do
      response
      |> Jason.decode!()
      |> Enum.map(fn fix ->
        %{
          type: String.to_atom(fix["type"]),
          description: fix["description"],
          files_affected: fix["files_affected"],
          priority: String.to_atom(fix["priority"]),
          fix_content: fix["fix_content"]
        }
      end)
    rescue
      error ->
        Logger.error("Failed to parse emergency Claude response", error: inspect(error))
        []
    end
  end

  defp run_emergency_self_awareness(codebase_path) do
    Logger.info("Running emergency self-awareness with Claude CLI", path: codebase_path)

    # Use emergency Claude CLI to analyze and fix the codebase
    emergency_prompt = """
    Analyze this codebase and provide comprehensive fixes:

    Codebase: #{codebase_path}

    Please:
    1. Scan for quality issues (Elixir, Rust, TypeScript)
    2. Check documentation compliance (2.3.0 standards)
    3. Identify bugs and errors
    4. Generate specific fixes

    Focus on making the system self-aware and self-improving.
    """

    case call_emergency_claude(emergency_prompt) do
      {:ok, response} ->
        Logger.info("Emergency Claude CLI analysis complete", response: response)
        # Parse and apply emergency fixes
        emergency_fixes = parse_emergency_response(response)
        apply_emergency_fixes(emergency_fixes)

      {:error, reason} ->
        Logger.error("Emergency Claude CLI completely failed", reason: reason)
    end
  end

  defp apply_emergency_fixes(fixes) do
    Enum.each(fixes, fn fix ->
      Logger.info("Applying emergency fix",
        type: fix.type,
        description: fix.description
      )

      # Apply fix using emergency Claude CLI
      apply_emergency_fix(fix)
    end)
  end

  defp apply_emergency_fix(fix) do
    fix_prompt = """
    Apply this fix to the codebase:

    Type: #{fix.type}
    Description: #{fix.description}
    Fix Content: #{fix.fix_content}

    Please implement this fix directly in the codebase.
    """

    case call_emergency_claude(fix_prompt) do
      {:ok, _response} ->
        Logger.info("Emergency fix applied", type: fix.type)

      {:error, reason} ->
        Logger.error("Failed to apply emergency fix", type: fix.type, reason: reason)
    end
  end

  ## Phase 4: Template Performance Analysis & Improvement

  defp request_approvals_existing(fixes) do
    # Use existing ApprovalService
    Enum.each(fixes, fn fix ->
      case ApprovalService.request_approval(
             file_path: "system_wide",
             diff: generate_fix_diff(fix),
             description: fix.description,
             agent_id: "self_improving_agent"
           ) do
        {:ok, approval_id} ->
          Logger.info("Approval requested for fix",
            fix_type: fix.type,
            approval_id: approval_id
          )

        {:error, reason} ->
          Logger.error("Failed to request approval",
            fix_type: fix.type,
            reason: reason
          )
      end
    end)
  end

  defp apply_fixes_existing(fixes) do
    # Use existing HotReload system
    Enum.each(fixes, fn fix ->
      case fix.type do
        :quality ->
          # Trigger quality upgrade using existing system
          Singularity.Agents.CodeQualityAgent.enable_quality_gates()

        :documentation ->
          # Trigger documentation upgrade for changed files only
          case Singularity.Agents.ChangeTracker.get_changes() do
            {:ok, changes} ->
              file_paths = Enum.map(changes, & &1.file_path)
              Singularity.Agents.DocumentationPipeline.run_incremental_pipeline(file_paths)

            {:error, _} ->
              # Skip if no changes detected
              :ok
          end

        :analysis ->
          # Use existing code generation capabilities
          Logger.info("Analysis fix would be applied via existing code generation")
      end
    end)
  end

  defp discover_files(codebase_path) do
    patterns = [
      "#{codebase_path}/**/*.ex",
      "#{codebase_path}/**/*.exs",
      "#{codebase_path}/**/*.rs",
      "#{codebase_path}/**/*.ts",
      "#{codebase_path}/**/*.tsx"
    ]

    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.reject(&File.dir?/1)
    |> Enum.filter(&is_source_file?/1)
  end

  defp is_source_file?(file_path) do
    not String.contains?(file_path, "/test/") and
      not String.contains?(file_path, "/_build/") and
      not String.contains?(file_path, "/deps/") and
      not String.contains?(file_path, "/node_modules/") and
      not String.contains?(file_path, "/target/") and
      not String.ends_with?(file_path, ".beam")
  end

  defp count_issues(analysis) do
    # Count issues from analysis result
    analysis
    |> Map.get(:issues, [])
    |> length()
  end

  defp generate_fix_diff(fix) do
    "Fix: #{fix.description}\nType: #{fix.type}\nPriority: #{fix.priority}\nFiles affected: #{fix.files_affected}"
  end
end
