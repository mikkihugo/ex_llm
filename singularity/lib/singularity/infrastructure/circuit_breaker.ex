defmodule Singularity.Infrastructure.CircuitBreaker do
  @moduledoc """
  Circuit Breaker pattern implementation for protecting against cascading failures.

  ## Overview

  Implements the resilience pattern that prevents cascading failures when external services become unavailable.
  Manages three states: closed (normal), open (failing fast), and half-open (testing recovery).

  ## States

  - `:closed` - Normal operation, all requests pass through (failure_count resets on success)
  - `:open` - Failure threshold exceeded, fast-fail all requests without executing
  - `:half_open` - Testing if service recovered, allow probe request after reset timeout

  ## Usage

      # Execute operation through circuit breaker
      CircuitBreaker.call(:external_api, fn ->
        ExternalAPI.fetch_data()
      end)

      # Get current state and statistics
      CircuitBreaker.get_state(:external_api)
      CircuitBreaker.get_stats(:external_api)

      # Manually reset if service recovered
      CircuitBreaker.reset(:external_api)

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    \"module\": \"Singularity.Infrastructure.CircuitBreaker\",
    \"purpose\": \"Infrastructure resilience pattern preventing cascading failures with 3-state machine\",
    \"role\": \"infrastructure_pattern\",
    \"layer\": \"infrastructure_services\",
    \"key_responsibilities\": [
      \"Manage 3-state circuit breaker: closed → open → half_open\",
      \"Track failure counts and transition thresholds\",
      \"Fast-fail requests when circuit is open\",
      \"Test recovery with half_open probes\",
      \"Timeout-based automatic reset attempts\"
    ],
    \"prevents_duplicates\": [\"ResilientWrapper\", \"FailureDetector\", \"FastFailService\"],
    \"uses\": [\"GenServer\", \"Registry\", \"DynamicSupervisor\", \"Task\", \"DateTime\", \"Logger\"],
    \"state_machine\": \"3-state (closed, open, half_open)\",
    \"timeout_driven\": true,
    \"critical_for\": [\"pgmq integration\", \"LLM API calls\", \"External service calls\"]
  }
  ```

  ### Architecture Diagram (Mermaid)

  ```mermaid
  graph TB
    A[\"Request Arrives\"] --> B{\"Get State\"}
    B -->|Closed| C[\"Execute & Record\"]
    B -->|Half-Open| C
    B -->|Open| D{\"Reset Timeout Expired?\"}
    D -->|Yes| E[\"Transition to Half-Open\"]
    E --> C
    D -->|No| F[\"Fast-Fail: circuit_open\"]

    C --> G{\"Success?\"}
    G -->|Success| H{\"Was Half-Open?\"}
    H -->|Yes| I[\"Close Circuit<br/>Reset failure_count\"]
    H -->|No| J[\"Reset failure_count\"]

    G -->|Failure| K[\"Increment failure_count\"]
    K --> L{\"Threshold Exceeded?\"}
    L -->|Yes| M[\"Transition to Open<br/>Record last_failure_time\"]
    L -->|No| N[\"Stay Closed\"]

    I --> O[\"Return ok\"]
    J --> O
    M --> O
    N --> O
    F --> O
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: GenServer
      function: call/2, call/3
      purpose: State queries (get_state, should_attempt_reset, record_success, record_failure)
      critical: true
      pattern: \"Client-server RPC pattern for atomicity\"

    - module: Registry
      function: lookup/2
      purpose: Find existing circuit breaker by name
      critical: true
      pattern: \"Process registration for named circuit breakers\"

    - module: DynamicSupervisor
      function: start_child/2
      purpose: Start circuit breaker GenServer on first use
      critical: true
      pattern: \"Lazy initialization with dynamic supervision\"

    - module: Task
      function: async/1, await/2, shutdown/2
      purpose: Execute function with timeout and error handling
      critical: true
      pattern: \"Async execution with timeout enforcement\"

    - module: DateTime
      function: utc_now/0, diff/4
      purpose: Track failure time and calculate reset timeouts
      critical: true
      pattern: \"Time-based state transitions\"

    - module: Logger
      function: info/2, warning/2, error/2
      purpose: Log state transitions and decisions
      critical: false
      pattern: \"Observability for circuit state changes\"

  called_by:
    - module: Singularity.LLM.Service
      function: call/3, call_with_prompt/3
      purpose: Protect LLM API calls from cascading failures
      frequency: per_llm_call
      pattern: \"Resilience wrapper for external API\"

    - module: Singularity.pgmq.NatsClient
      function: publish/2, subscribe/2
      purpose: Protect pgmq operations from network failures
      frequency: per_pgmq_operation
      pattern: \"Infrastructure protection\"

    - module: Singularity.CodeAnalysis.ScanOrchestrator
      function: scan/2, scan/3
      purpose: Protect external scanner integrations
      frequency: per_scan
      pattern: \"Third-party tool resilience\"

  state_transitions:
    - name: normal_success
      from: closed
      to: closed
      trigger: request succeeds
      actions:
        - Increment success_count (implicit via failure_count reset)
        - Return {:ok, result} to caller
        - Log at debug level

    - name: threshold_exceeded
      from: closed
      to: open
      trigger: failure_count >= failure_threshold
      actions:
        - Set state to :open
        - Record last_failure_time
        - Increment failure_count
        - Log error level alert
      guards:
        - failure_count + 1 >= failure_threshold

    - name: attempt_reset
      from: open
      to: half_open
      trigger: reset_timeout_ms elapsed since last_failure_time
      actions:
        - Set state to :half_open
        - Reset half_open_success_count to 0
        - Allow next request to probe
        - Log info level
      guards:
        - DateTime.diff(now, last_failure_time) >= reset_timeout_ms

    - name: recovery_confirmed
      from: half_open
      to: closed
      trigger: request succeeds while in half_open
      actions:
        - Set state to :closed
        - Reset failure_count to 0
        - Reset last_failure_time to nil
        - Log info level \"recovered\"
        - Return {:ok, result}

    - name: recovery_failed
      from: half_open
      to: open
      trigger: request fails while in half_open
      actions:
        - Set state to :open
        - Increment failure_count
        - Update last_failure_time
        - Log error level

    - name: manual_reset
      from: open|half_open
      to: closed
      trigger: reset/1 called explicitly
      actions:
        - Set state to :closed
        - Reset failure_count to 0
        - Reset last_failure_time to nil
        - Reset half_open_success_count to 0
        - Log info level \"manually reset\"

  depends_on:
    - Erlang Task module (MUST be available)
    - Erlang Registry (MUST be available)
    - Singularity.Infrastructure.CircuitBreakerRegistry (MUST exist)
    - Singularity.Infrastructure.CircuitBreakerSupervisor (MUST exist for dynamic start)
    - DateTime module (MUST be available)
  ```

  ### Anti-Patterns

  #### ❌ DO NOT bypass circuit breaker with direct calls
  **Why:** Defeats the purpose of cascading failure protection. Circuit breaker MUST be applied to all external service calls.

  ```elixir
  # ❌ WRONG - Direct call without circuit breaker protection
  def fetch_user(user_id) do
    ExternalAPI.fetch_user(user_id)  # Can cascade failures!
  end

  # ✅ CORRECT - Wrapped in circuit breaker
  def fetch_user(user_id) do
    CircuitBreaker.call(:external_api, fn ->
      ExternalAPI.fetch_user(user_id)
    end)
  end
  ```

  #### ❌ DO NOT transition to Open without proper failure threshold
  **Why:** Circuit opens too fast or too slow, defeating resilience purpose.

  ```elixir
  # ❌ WRONG - Opens after 1 failure (too sensitive)
  CircuitBreaker.call(service, fun, failure_threshold: 1)

  # ✅ CORRECT - Opens after 5 failures (default, balanced)
  CircuitBreaker.call(service, fun)  # Uses @default_failure_threshold
  ```

  #### ❌ DO NOT use hardcoded circuit names across services
  **Why:** Different services have different failure characteristics and should have independent circuits.

  ```elixir
  # ❌ WRONG - Single circuit for all services
  CircuitBreaker.call(:generic_service, fun)

  # ✅ CORRECT - Named circuits per service
  CircuitBreaker.call(:external_api, fun)
  CircuitBreaker.call(:payment_gateway, fun)
  CircuitBreaker.call(:email_service, fun)
  ```

  #### ❌ DO NOT ignore reset_timeout_ms configuration
  **Why:** Half-open probes retry too early (service still down) or too late (service already recovered).

  ```elixir
  # ❌ WRONG - Using default reset timeout for slow service
  CircuitBreaker.call(:slow_service, fn ->
    SlowExternalAPI.process_request()  # Takes 30 seconds
  end)

  # ✅ CORRECT - Increase reset_timeout_ms for slower services
  CircuitBreaker.call(:slow_service, fn ->
    SlowExternalAPI.process_request()
  end, reset_timeout_ms: 120_000)  # 2 minutes before attempting probe
  ```

  ### Search Keywords

  circuit breaker, resilience pattern, cascading failure prevention, fast-fail, state machine,
  failure detection, recovery testing, half-open state, timeout-based reset, exponential backoff,
  service degradation, fault tolerance, external service protection, pgmq protection,
  LLM API resilience, infrastructure pattern, GenServer state machine, Registry-based lifecycle,
  DynamicSupervisor management, failure threshold, reset timeout, probe request
  """

  use GenServer
  require Logger

  @default_failure_threshold 5
  @default_timeout_ms 5_000
  @default_reset_timeout_ms 60_000

  defstruct [
    :name,
    :state,
    :failure_count,
    :last_failure_time,
    :failure_threshold,
    :timeout_ms,
    :reset_timeout_ms,
    :half_open_success_count
  ]

  ## Client API

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  @doc """
  Execute function through circuit breaker.

  Returns:
  - `{:ok, result}` - Success
  - `{:error, :circuit_open}` - Circuit is open, rejecting requests
  - `{:error, reason}` - Operation failed
  """
  def call(circuit_name, fun, opts \\ []) when is_function(fun, 0) do
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)

    # Ensure circuit breaker exists
    ensure_circuit(circuit_name, opts)

    case GenServer.call(via_tuple(circuit_name), :get_state, 5000) do
      :closed ->
        execute_and_record(circuit_name, fun, timeout_ms)

      :half_open ->
        execute_and_record(circuit_name, fun, timeout_ms)

      :open ->
        # Check if we should transition to half_open
        case GenServer.call(via_tuple(circuit_name), :should_attempt_reset, 5000) do
          true ->
            Logger.info("Circuit breaker attempting reset", circuit: circuit_name)
            execute_and_record(circuit_name, fun, timeout_ms)

          false ->
            Logger.warning("Circuit breaker is open, rejecting request", circuit: circuit_name)
            {:error, :circuit_open}
        end
    end
  end

  @doc """
  Get current state of circuit breaker.
  """
  def get_state(circuit_name) do
    ensure_circuit(circuit_name, [])
    GenServer.call(via_tuple(circuit_name), :get_state)
  end

  @doc """
  Get circuit breaker statistics.
  """
  def get_stats(circuit_name) do
    ensure_circuit(circuit_name, [])
    GenServer.call(via_tuple(circuit_name), :get_stats)
  end

  @doc """
  Manually reset circuit breaker.
  """
  def reset(circuit_name) do
    ensure_circuit(circuit_name, [])
    GenServer.call(via_tuple(circuit_name), :reset)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    failure_threshold = Keyword.get(opts, :failure_threshold, @default_failure_threshold)
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    reset_timeout_ms = Keyword.get(opts, :reset_timeout_ms, @default_reset_timeout_ms)

    state = %__MODULE__{
      name: name,
      state: :closed,
      failure_count: 0,
      last_failure_time: nil,
      failure_threshold: failure_threshold,
      timeout_ms: timeout_ms,
      reset_timeout_ms: reset_timeout_ms,
      half_open_success_count: 0
    }

    Logger.info("Circuit breaker initialized",
      name: name,
      failure_threshold: failure_threshold,
      timeout_ms: timeout_ms
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.state, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      name: state.name,
      state: state.state,
      failure_count: state.failure_count,
      failure_threshold: state.failure_threshold,
      last_failure_time: state.last_failure_time,
      time_until_reset: time_until_reset(state)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:should_attempt_reset, _from, state) do
    should_attempt = should_attempt_reset?(state)

    new_state =
      if should_attempt do
        %{state | state: :half_open, half_open_success_count: 0}
      else
        state
      end

    {:reply, should_attempt, new_state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    Logger.info("Circuit breaker manually reset", name: state.name)

    new_state = %{
      state
      | state: :closed,
        failure_count: 0,
        last_failure_time: nil,
        half_open_success_count: 0
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:record_success}, _from, state) do
    new_state =
      case state.state do
        :half_open ->
          # Success in half_open state - close the circuit
          Logger.info("Circuit breaker recovered", name: state.name)

          %{
            state
            | state: :closed,
              failure_count: 0,
              last_failure_time: nil,
              half_open_success_count: 0
          }

        _ ->
          # Success in closed state - reset failure count
          %{state | failure_count: 0}
      end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:record_failure}, _from, state) do
    new_failure_count = state.failure_count + 1

    new_state =
      if new_failure_count >= state.failure_threshold do
        Logger.error("Circuit breaker opened due to failures",
          name: state.name,
          failure_count: new_failure_count,
          threshold: state.failure_threshold
        )

        %{
          state
          | state: :open,
            failure_count: new_failure_count,
            last_failure_time: DateTime.utc_now()
        }
      else
        Logger.warning("Circuit breaker recorded failure",
          name: state.name,
          failure_count: new_failure_count,
          threshold: state.failure_threshold
        )

        %{state | failure_count: new_failure_count, last_failure_time: DateTime.utc_now()}
      end

    {:reply, :ok, new_state}
  end

  ## Private Helpers

  defp via_tuple(name) do
    {:via, Registry, {Singularity.Infrastructure.CircuitBreakerRegistry, name}}
  end

  defp ensure_circuit(name, opts) do
    # Try to get the circuit, start if doesn't exist
    case Registry.lookup(Singularity.Infrastructure.CircuitBreakerRegistry, name) do
      [] ->
        # Start the circuit breaker
        opts = Keyword.put(opts, :name, name)

        case DynamicSupervisor.start_child(
               Singularity.Infrastructure.CircuitBreakerSupervisor,
               {__MODULE__, opts}
             ) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          error -> error
        end

      [_] ->
        :ok
    end
  end

  defp execute_and_record(circuit_name, fun, timeout_ms) do
    task = Task.async(fun)

    try do
      result = Task.await(task, timeout_ms)
      GenServer.call(via_tuple(circuit_name), {:record_success}, 5000)
      {:ok, result}
    rescue
      error ->
        GenServer.call(via_tuple(circuit_name), {:record_failure}, 5000)
        {:error, error}
    catch
      :exit, {:timeout, _} ->
        Task.shutdown(task, :brutal_kill)
        GenServer.call(via_tuple(circuit_name), {:record_failure}, 5000)
        {:error, :timeout}

      :exit, reason ->
        GenServer.call(via_tuple(circuit_name), {:record_failure}, 5000)
        {:error, {:exit, reason}}
    end
  end

  defp should_attempt_reset?(state) do
    case state.state do
      :open ->
        if state.last_failure_time do
          elapsed_ms = DateTime.diff(DateTime.utc_now(), state.last_failure_time, :millisecond)
          elapsed_ms >= state.reset_timeout_ms
        else
          true
        end

      _ ->
        false
    end
  end

  defp time_until_reset(state) do
    case {state.state, state.last_failure_time} do
      {:open, %DateTime{} = last_failure} ->
        elapsed_ms = DateTime.diff(DateTime.utc_now(), last_failure, :millisecond)
        max(0, state.reset_timeout_ms - elapsed_ms)

      _ ->
        0
    end
  end
end
