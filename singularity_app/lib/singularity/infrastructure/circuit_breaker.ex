defmodule Singularity.Infrastructure.CircuitBreaker do
  @moduledoc """
  Circuit Breaker pattern implementation for protecting against cascading failures.

  States:
  - `:closed` - Normal operation, all requests pass through
  - `:open` - Failure threshold exceeded, fast-fail all requests
  - `:half_open` - Testing if service recovered

  ## Usage

      CircuitBreaker.call(:external_api, fn ->
        ExternalAPI.fetch_data()
      end)
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
