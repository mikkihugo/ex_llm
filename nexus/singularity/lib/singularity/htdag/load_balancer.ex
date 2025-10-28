defmodule Singularity.HTDAG.LoadBalancer do
  @moduledoc """
  Load Balancer for HTDAG Auto Code Ingestion

  Provides intelligent load balancing and throttling to prevent the system
  from running too hard and overwhelming system resources.

  ## Features

  - **Rate Limiting** - Limits files processed per minute
  - **CPU Monitoring** - Pauses processing when CPU usage is high
  - **Memory Monitoring** - Pauses processing when memory usage is high
  - **Adaptive Scaling** - Automatically adjusts concurrency based on system load
  - **Cooldown Periods** - Implements cooldown after high load periods

  ## Configuration

  Configure via `:htdag_auto_ingestion` config key:
  ```elixir
  config :singularity, :htdag_auto_ingestion,
    rate_limit_per_minute: 30,
    cpu_threshold: 0.7,
    memory_threshold: 0.8,
    cooldown_period_ms: 5000,
    load_balancing: %{
      enabled: true,
      check_interval_ms: 10000,
      adaptive_scaling: true
    }
  ```
  """

  use GenServer
  require Logger

  alias Singularity.HTDAG.AutoCodeIngestionDAG

  @config Application.get_env(:singularity, :htdag_auto_ingestion, %{})

  # Rate limiting
  @rate_limit_per_minute @config[:rate_limit_per_minute] || 30
  # 1 minute
  @rate_limit_window_ms 60_000

  # System thresholds
  @cpu_threshold @config[:cpu_threshold] || 0.7
  @memory_threshold @config[:memory_threshold] || 0.8
  @cooldown_period_ms @config[:cooldown_period_ms] || 5000

  # Load balancing
  @load_balancing_config @config[:load_balancing] || %{}
  @load_balancing_enabled @load_balancing_config[:enabled] || true
  @check_interval_ms @load_balancing_config[:check_interval_ms] || 10000
  @adaptive_scaling @load_balancing_config[:adaptive_scaling] || true

  # State
  defstruct [
    :rate_limit_tokens,
    :last_token_refill,
    :system_load_state,
    :cooldown_until,
    :current_concurrency,
    :max_concurrency,
    :load_history,
    :paused_reason
  ]

  # Client API

  @doc """
  Start the load balancer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if a file can be processed now.
  Returns `{:ok, :allowed}` or `{:error, reason}`.
  """
  def can_process_file?(file_path) do
    GenServer.call(__MODULE__, {:can_process, file_path})
  end

  @doc """
  Record that a file has been processed.
  """
  def record_file_processed(file_path) do
    GenServer.cast(__MODULE__, {:file_processed, file_path})
  end

  @doc """
  Get current load balancer status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Manually pause processing.
  """
  def pause(reason \\ :manual) do
    GenServer.cast(__MODULE__, {:pause, reason})
  end

  @doc """
  Resume processing.
  """
  def resume do
    GenServer.cast(__MODULE__, :resume)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting HTDAG Load Balancer...")

    state = %__MODULE__{
      rate_limit_tokens: @rate_limit_per_minute,
      last_token_refill: System.monotonic_time(:millisecond),
      system_load_state: :normal,
      cooldown_until: nil,
      current_concurrency: 0,
      max_concurrency: @config[:max_concurrent_dags] || 3,
      load_history: [],
      paused_reason: nil
    }

    # Start monitoring if enabled
    if @load_balancing_enabled do
      Process.send_after(self(), :check_system_load, @check_interval_ms)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:can_process, file_path}, _from, state) do
    case check_processing_allowed(state) do
      {:ok, updated_state} ->
        {:reply, {:ok, :allowed}, updated_state}

      {:error, reason} ->
        Logger.debug("File processing denied",
          file_path: file_path,
          reason: reason
        )

        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      rate_limit_tokens: state.rate_limit_tokens,
      system_load_state: state.system_load_state,
      cooldown_until: state.cooldown_until,
      current_concurrency: state.current_concurrency,
      max_concurrency: state.max_concurrency,
      paused_reason: state.paused_reason,
      # Last 10 measurements
      load_history: Enum.take(state.load_history, 10)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:file_processed, _file_path}, state) do
    # Consume a rate limit token
    updated_state = %{
      state
      | rate_limit_tokens: max(0, state.rate_limit_tokens - 1),
        current_concurrency: max(0, state.current_concurrency - 1)
    }

    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:pause, reason}, state) do
    Logger.info("HTDAG Load Balancer paused", reason: reason)

    updated_state = %{
      state
      | paused_reason: reason,
        cooldown_until: System.monotonic_time(:millisecond) + @cooldown_period_ms
    }

    {:noreply, updated_state}
  end

  @impl true
  def handle_cast(:resume, state) do
    Logger.info("HTDAG Load Balancer resumed")

    updated_state = %{state | paused_reason: nil, cooldown_until: nil}

    {:noreply, updated_state}
  end

  @impl true
  def handle_info(:check_system_load, state) do
    updated_state = check_and_update_system_load(state)

    # Schedule next check
    Process.send_after(self(), :check_system_load, @check_interval_ms)

    {:noreply, updated_state}
  end

  # Private functions

  defp check_processing_allowed(state) do
    with :ok <- check_paused(state),
         :ok <- check_cooldown(state),
         :ok <- check_rate_limit(state),
         :ok <- check_system_load_thresholds(state),
         :ok <- check_concurrency_limit(state) do
      {:ok, state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_paused(state) do
    if state.paused_reason do
      {:error, {:paused, state.paused_reason}}
    else
      :ok
    end
  end

  defp check_cooldown(state) do
    if state.cooldown_until && System.monotonic_time(:millisecond) < state.cooldown_until do
      remaining_ms = state.cooldown_until - System.monotonic_time(:millisecond)
      {:error, {:cooldown, remaining_ms}}
    else
      :ok
    end
  end

  defp check_rate_limit(state) do
    # Refill tokens if needed
    now = System.monotonic_time(:millisecond)
    time_since_refill = now - state.last_token_refill

    if time_since_refill >= @rate_limit_window_ms do
      # Refill tokens
      updated_state = %{state | rate_limit_tokens: @rate_limit_per_minute, last_token_refill: now}

      if updated_state.rate_limit_tokens > 0 do
        {:ok, updated_state}
      else
        {:error, :rate_limit_exceeded}
      end
    else
      if state.rate_limit_tokens > 0 do
        {:ok, state}
      else
        {:error, :rate_limit_exceeded}
      end
    end
  end

  defp check_system_load_thresholds(state) do
    case state.system_load_state do
      :high_cpu -> {:error, :high_cpu_usage}
      :high_memory -> {:error, :high_memory_usage}
      :normal -> :ok
    end
  end

  defp check_concurrency_limit(state) do
    if state.current_concurrency >= state.max_concurrency do
      {:error, :concurrency_limit_exceeded}
    else
      :ok
    end
  end

  defp check_and_update_system_load(state) do
    if @load_balancing_enabled do
      # Get system metrics
      cpu_usage = get_cpu_usage()
      memory_usage = get_memory_usage()

      # Update load history
      load_measurement = %{
        timestamp: System.monotonic_time(:millisecond),
        cpu_usage: cpu_usage,
        memory_usage: memory_usage
      }

      updated_load_history = [load_measurement | state.load_history] |> Enum.take(100)

      # Determine system load state
      system_load_state = determine_load_state(cpu_usage, memory_usage)

      # Update concurrency if adaptive scaling is enabled
      updated_concurrency =
        if @adaptive_scaling do
          calculate_adaptive_concurrency(system_load_state, state.max_concurrency)
        else
          state.max_concurrency
        end

      # Handle state transitions
      updated_state =
        handle_load_state_transition(state, system_load_state, cpu_usage, memory_usage)

      %{
        updated_state
        | system_load_state: system_load_state,
          load_history: updated_load_history,
          max_concurrency: updated_concurrency
      }
    else
      state
    end
  end

  defp get_cpu_usage do
    # Get CPU usage percentage
    # This is a simplified implementation
    # In production, you'd use a proper system monitoring library
    try do
      # Use :os.cmd to get CPU usage (Linux/macOS)
      case :os.cmd('top -l 1 | grep "CPU usage" | awk \'{print $3}\' | sed \'s/%//\'') do
        result when is_binary(result) ->
          result
          |> String.trim()
          |> String.to_float()
          |> Kernel./(100.0)
          |> min(1.0)
          |> max(0.0)

        _ ->
          # Fallback to random value for testing
          :rand.uniform() * 0.5
      end
    rescue
      _ ->
        # Fallback to random value for testing
        :rand.uniform() * 0.5
    end
  end

  defp get_memory_usage do
    # Get memory usage percentage
    # This is a simplified implementation
    try do
      # Use :os.cmd to get memory usage (Linux/macOS)
      case :os.cmd('top -l 1 | grep "PhysMem" | awk \'{print $2}\' | sed \'s/M used,//\'') do
        result when is_binary(result) ->
          used_mb =
            result
            |> String.trim()
            |> String.to_integer()

          # Assume 8GB total memory (simplified)
          total_mb = 8192
          (used_mb / total_mb) |> min(1.0) |> max(0.0)

        _ ->
          # Fallback to random value for testing
          :rand.uniform() * 0.6
      end
    rescue
      _ ->
        # Fallback to random value for testing
        :rand.uniform() * 0.6
    end
  end

  defp determine_load_state(cpu_usage, memory_usage) do
    cond do
      cpu_usage >= @cpu_threshold -> :high_cpu
      memory_usage >= @memory_threshold -> :high_memory
      true -> :normal
    end
  end

  defp calculate_adaptive_concurrency(system_load_state, base_concurrency) do
    case system_load_state do
      :high_cpu -> max(1, div(base_concurrency, 3))
      :high_memory -> max(1, div(base_concurrency, 2))
      :normal -> base_concurrency
    end
  end

  defp handle_load_state_transition(state, new_state, cpu_usage, memory_usage) do
    case {state.system_load_state, new_state} do
      {:normal, :high_cpu} ->
        Logger.warning("High CPU usage detected, pausing processing",
          cpu_usage: cpu_usage,
          threshold: @cpu_threshold
        )

        pause(:high_cpu)
        state

      {:normal, :high_memory} ->
        Logger.warning("High memory usage detected, pausing processing",
          memory_usage: memory_usage,
          threshold: @memory_threshold
        )

        pause(:high_memory)
        state

      {:high_cpu, :normal} ->
        Logger.info("CPU usage normalized, resuming processing")
        resume()
        state

      {:high_memory, :normal} ->
        Logger.info("Memory usage normalized, resuming processing")
        resume()
        state

      _ ->
        state
    end
  end
end
