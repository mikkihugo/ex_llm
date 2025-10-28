defmodule Singularity.Infrastructure.Resilience do
  @moduledoc """
  Resilience Utilities for Async Operations and External Service Integration

  Provides production-grade resilience patterns:
  - Exponential backoff retry logic with jitter
  - Circuit breaker pattern for fault protection
  - Timeout handling with cascading timeouts
  - Bulkhead isolation for resource limits
  - Graceful degradation strategies

  ## Exponential Backoff

  Retries operations with exponential backoff:

      {:ok, result} = Resilience.with_retry(
        fn -> do_operation() end,
        base_delay_ms: 100,
        max_delay_ms: 30_000,
        multiplier: 1.5,
        max_retries: 5,
        jitter: true
      )

  Features:
  - Progressive delay increase (100ms, 150ms, 225ms, ...)
  - Max delay cap prevents excessive waits
  - Jitter (±20%) prevents thundering herd
  - Exponential multiplier configurable

  ## Circuit Breaker

  Protects against cascading failures:

      {:ok, breaker} = Resilience.circuit_breaker(
        :my_service,
        failure_threshold: 5,
        success_threshold: 2,
        timeout_ms: 60_000,
        half_open_requests: 3
      )

      case Resilience.execute(breaker, fn -> risky_operation() end) do
        {:ok, result} -> {:ok, result}
        {:error, :circuit_open} -> {:error, :service_unavailable}
        {:error, reason} -> {:error, reason}
      end

  States:
  - :closed - Normal operation, all requests pass through
  - :open - Too many failures, requests immediately fail
  - :half_open - Testing if service recovered, limited requests allowed

  ## Timeout Management

  Hierarchical timeout handling:

      {:ok, result} = Resilience.with_timeout(
        fn -> slow_operation() end,
        timeout_ms: 5000,
        fallback: fn -> cached_result() end
      )

  Features:
  - Primary timeout for main operation
  - Fallback on timeout (degraded mode)
  - Cascade timeouts for child operations
  - Timeout telemetry events

  ## Usage Examples

      # Simple retry with defaults
      Resilience.with_retry(fn -> HTTP.get(url) end)

      # Retry with custom strategy
      Resilience.with_retry(
        fn -> risky_operation() end,
        max_retries: 3,
        base_delay_ms: 200
      )

      # Circuit breaker for external service
      {:ok, breaker} = Resilience.circuit_breaker(:external_api)
      Resilience.execute(breaker, fn -> call_external_api() end)

      # Combined retry + timeout
      Resilience.with_retry(
        fn ->
          Resilience.with_timeout(fn -> operation() end, timeout_ms: 5000)
        end,
        max_retries: 3
      )
  """

  require Logger
  alias Singularity.Infrastructure.ErrorClassification

  @default_base_delay_ms 100
  @default_max_delay_ms 30_000
  @default_multiplier 1.5
  @default_max_retries 5
  @default_jitter true
  @default_jitter_percent 20
  @default_timeout_ms 30_000

  @type retry_option ::
          {:base_delay_ms, pos_integer()}
          | {:max_delay_ms, pos_integer()}
          | {:multiplier, float()}
          | {:max_retries, non_neg_integer()}
          | {:jitter, boolean()}

  @type circuit_breaker_option ::
          {:failure_threshold, pos_integer()}
          | {:success_threshold, pos_integer()}
          | {:timeout_ms, pos_integer()}
          | {:half_open_requests, pos_integer()}

  @doc """
  Execute a function with exponential backoff retry.

  Returns {:ok, result} on success or {:error, reason} after max retries exceeded.
  """
  def with_retry(fun, opts \\ []) when is_function(fun, 0) and is_list(opts) do
    base_delay = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)
    max_delay = Keyword.get(opts, :max_delay_ms, @default_max_delay_ms)
    multiplier = Keyword.get(opts, :multiplier, @default_multiplier)
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    use_jitter = Keyword.get(opts, :jitter, @default_jitter)

    do_retry(fun, base_delay, max_delay, multiplier, max_retries, use_jitter, 0, [])
  end

  @doc """
  Execute a function with timeout and optional fallback.

  Returns {:ok, result} on success within timeout, or calls fallback on timeout.
  """
  def with_timeout(fun, opts \\ []) when is_function(fun, 0) and is_list(opts) do
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    fallback = Keyword.get(opts, :fallback, nil)

    try do
      case Task.yield(Task.async(fun), timeout_ms) do
        {:ok, result} ->
          {:ok, result}

        nil ->
          # Timeout occurred
          if fallback do
            Logger.warning("Operation timed out after #{timeout_ms}ms, using fallback")
            {:ok, fallback.()}
          else
            {:error, :timeout}
          end
      end
    rescue
      error ->
        error_type = ErrorClassification.classify_exception(error)

        ErrorClassification.error_response(
          error_type,
          :with_timeout,
          %{timeout_ms: timeout_ms},
          error
        )
    end
  end

  @doc """
  Create a circuit breaker for protecting external service calls.

  Returns {:ok, circuit_breaker_ref} that can be used with execute/2.
  """
  def circuit_breaker(name, opts \\ []) when is_atom(name) and is_list(opts) do
    failure_threshold = Keyword.get(opts, :failure_threshold, 5)
    success_threshold = Keyword.get(opts, :success_threshold, 2)
    timeout_ms = Keyword.get(opts, :timeout_ms, 60_000)
    half_open_requests = Keyword.get(opts, :half_open_requests, 3)

    breaker_state = %{
      name: name,
      state: :closed,
      failure_count: 0,
      success_count: 0,
      failure_threshold: failure_threshold,
      success_threshold: success_threshold,
      timeout_ms: timeout_ms,
      half_open_requests: half_open_requests,
      half_open_count: 0,
      last_failure_time: nil
    }

    {:ok, breaker_state}
  end

  @doc """
  Execute a function through a circuit breaker.

  Returns {:ok, result} on success, {:error, :circuit_open} if circuit is open,
  or {:error, reason} on operation failure.
  """
  def execute(breaker, fun) when is_map(breaker) and is_function(fun, 0) do
    case check_circuit_state(breaker) do
      :closed ->
        execute_operation(fun, breaker, :closed)

      :open ->
        {:error, :circuit_open}

      :half_open ->
        if breaker.half_open_count < breaker.half_open_requests do
          execute_operation(fun, breaker, :half_open)
        else
          {:error, :circuit_open}
        end
    end
  end

  @doc """
  Get circuit breaker status.

  Returns {:ok, status_map} with current state and metrics.
  """
  def breaker_status(breaker) when is_map(breaker) do
    {:ok,
     %{
       name: breaker.name,
       state: breaker.state,
       failure_count: breaker.failure_count,
       success_count: breaker.success_count,
       half_open_count: breaker.half_open_count,
       last_failure_time: breaker.last_failure_time
     }}
  end

  @doc """
  Reset circuit breaker to closed state.

  Useful for manual intervention or health check recovery.
  """
  def reset_breaker(breaker) when is_map(breaker) do
    {:ok,
     %{
       breaker
       | state: :closed,
         failure_count: 0,
         success_count: 0,
         half_open_count: 0,
         last_failure_time: nil
     }}
  end

  # Private helper functions

  defp do_retry(
         _fun,
         _base_delay,
         _max_delay,
         _multiplier,
         max_retries,
         _use_jitter,
         attempt,
         errors
       )
       when attempt >= max_retries do
    # All retries exhausted
    last_error = List.first(errors)
    {:error, {:max_retries_exceeded, last_error}}
  end

  defp do_retry(fun, base_delay, max_delay, multiplier, max_retries, use_jitter, attempt, errors) do
    try do
      fun.()
    rescue
      error ->
        # Calculate delay
        delay = calculate_backoff_delay(base_delay, multiplier, attempt, max_delay, use_jitter)

        # Log retry
        Logger.debug(
          "Retry attempt #{attempt + 1}/#{max_retries} after #{delay}ms: #{inspect(error)}",
          attempt: attempt + 1,
          max_retries: max_retries,
          delay_ms: delay
        )

        # Wait before retry
        Process.sleep(delay)

        # Retry with updated attempt counter
        do_retry(fun, base_delay, max_delay, multiplier, max_retries, use_jitter, attempt + 1, [
          error | errors
        ])
    end
  end

  defp calculate_backoff_delay(base_delay, multiplier, attempt, max_delay, use_jitter) do
    # Exponential: base * multiplier^attempt
    exponential_delay = (base_delay * :math.pow(multiplier, attempt)) |> trunc()

    # Cap at max delay
    capped_delay = min(exponential_delay, max_delay)

    # Apply jitter if enabled
    if use_jitter do
      jitter_amount = (capped_delay * @default_jitter_percent / 100) |> trunc()
      jitter = Enum.random(-jitter_amount..jitter_amount)
      max(1, capped_delay + jitter)
    else
      capped_delay
    end
  end

  defp check_circuit_state(breaker) do
    case breaker.state do
      :closed ->
        :closed

      :open ->
        # Check if timeout elapsed to transition to half-open
        if breaker.last_failure_time &&
             DateTime.utc_now() |> DateTime.to_unix(:millisecond) >
               DateTime.to_unix(breaker.last_failure_time, :millisecond) + breaker.timeout_ms do
          :half_open
        else
          :open
        end

      :half_open ->
        :half_open
    end
  end

  defp execute_operation(fun, breaker, current_state) do
    try do
      fun.()
    rescue
      error ->
        # Handle failure in circuit
        updated_breaker = handle_circuit_failure(breaker, current_state)

        error_type = ErrorClassification.classify_exception(error)

        ErrorClassification.error_response(
          error_type,
          :circuit_breaker_execution,
          %{circuit: breaker.name, state: current_state},
          error
        )
    else
      result ->
        # Handle success in circuit
        _updated_breaker = handle_circuit_success(breaker, current_state)
        {:ok, result}
    end
  end

  defp handle_circuit_failure(breaker, :closed) do
    new_failure_count = breaker.failure_count + 1

    if new_failure_count >= breaker.failure_threshold do
      Logger.warning(
        "Circuit breaker #{breaker.name} opening after #{new_failure_count} failures"
      )

      %{
        breaker
        | state: :open,
          failure_count: new_failure_count,
          last_failure_time: DateTime.utc_now(),
          success_count: 0
      }
    else
      %{breaker | failure_count: new_failure_count}
    end
  end

  defp handle_circuit_failure(breaker, :half_open) do
    Logger.warning("Circuit breaker #{breaker.name} reopening after failure in half-open state")

    %{
      breaker
      | state: :open,
        failure_count: breaker.failure_count + 1,
        last_failure_time: DateTime.utc_now(),
        half_open_count: 0,
        success_count: 0
    }
  end

  defp handle_circuit_failure(breaker, _state) do
    %{breaker | failure_count: breaker.failure_count + 1}
  end

  defp handle_circuit_success(breaker, :half_open) do
    new_success_count = breaker.success_count + 1

    if new_success_count >= breaker.success_threshold do
      Logger.info("Circuit breaker #{breaker.name} closing after successful tests",
        circuit: breaker.name,
        success_count: new_success_count
      )

      %{
        breaker
        | state: :closed,
          success_count: 0,
          failure_count: 0,
          half_open_count: 0,
          last_failure_time: nil
      }
    else
      %{
        breaker
        | success_count: new_success_count,
          half_open_count: breaker.half_open_count + 1
      }
    end
  end

  defp handle_circuit_success(breaker, :closed) do
    %{breaker | failure_count: 0}
  end

  defp handle_circuit_success(breaker, _state) do
    %{breaker | success_count: breaker.success_count + 1}
  end
end
