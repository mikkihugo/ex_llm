defmodule Singularity.LLM.RateLimiter do
  @moduledoc """
  Rate limiter and budget controller for LLM calls.

  Prevents:
  - Exceeding API rate limits (requests/minute)
  - Exceeding daily budget ($100/day default)
  - Concurrent request overload

  Uses OTP GenServer + ETS for fast, distributed limiting.

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.LLM.RateLimiter",
    "purpose": "GenServer-based rate limiter and budget controller for LLM API calls",
    "role": "infrastructure",
    "layer": "domain_services",
    "prevents_duplicates": ["LLMRateLimiter", "APIRateLimiter", "BudgetController"],
    "uses": ["GenServer", "OTP", "System.monotonic_time"],
    "alternatives": {
      "Expensive call without limits": "This prevents runaway costs",
      "Manual budget tracking": "This automates budget enforcement",
      "Synchronous blocking": "Allows queuing instead of immediate rejection"
    }
  }
  ```

  ### Architecture Diagram (Mermaid)

  ```mermaid
  graph TB
      Client["LLM Client (Service.call)"]
      RL["RateLimiter GenServer"]
      State["State: Limits & Budget"]
      Queue["Waiting Queue"]
      Reset["Daily Reset Timer"]

      Client -->|acquire(cost)| RL
      RL -->|check| State
      State -->|concurrent?| RL
      State -->|rate limit?| RL
      State -->|budget?| RL
      RL -->|full| Queue
      RL -->|ok| Client
      Queue -->|process_waiting| RL
      Reset -->|:daily_reset| RL
      RL -->|release(cost)| State

      style RL fill:#90EE90
      style State fill:#87CEEB
      style Queue fill:#FFD700
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: GenServer
      function: start_link/2
      purpose: Start rate limiter as OTP process
      critical: true

    - module: System
      function: monotonic_time/1
      purpose: Track minute boundaries for rate limits
      critical: true

    - module: DateTime
      function: utc_now/0
      purpose: Calculate daily reset schedule
      critical: false

    - module: Logger
      function: error/2, warning/2, info/2
      purpose: Track budget/rate limit events
      critical: false

  called_by:
    - module: Singularity.LLM.Service
      function: call/3, call_with_prompt/3
      purpose: Every LLM call acquires before execution
      frequency: per_llm_call

    - module: Singularity.Agents
      function: (any LLM-using agent)
      purpose: All agents use LLM through rate limiter
      frequency: per_task

  state_transitions:
    - name: acquire
      from: idle
      to: limited (if max reached)
      to: acquired (otherwise)
      conditions:
        - daily_spend + cost <= budget
        - current_concurrent < max_concurrent
        - minute_counter < max_per_minute

    - name: release
      from: acquired
      to: idle
      updates:
        - daily_spend += actual_cost
        - current_concurrent -= 1
      triggers: process_waiting_queue

    - name: daily_reset
      from: any
      to: idle (counters reset)
      triggers: Process.send_after (scheduled midnight)

  depends_on:
    - Erlang OTP (MUST exist)
    - GenServer behavior (MUST exist)
    - System clock (MUST be accurate)
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create per-model rate limiters
  **Why:** Single global limiter prevents cascading failures.
  ```elixir
  # ❌ WRONG - Separate limiters per model
  OpenAI.RateLimiter.acquire()
  Claude.RateLimiter.acquire()
  Gemini.RateLimiter.acquire()

  # ✅ CORRECT - Use single unified limiter
  RateLimiter.acquire(estimated_cost)
  ```

  #### ❌ DO NOT bypass rate limiter for "quick" calls
  **Why:** "Quick" calls add up; budget enforcement must be consistent.
  ```elixir
  # ❌ WRONG - Direct call without limiting
  LLM.Service.direct_call(messages)

  # ✅ CORRECT - Always use with_limit
  RateLimiter.with_limit(fn -> LLM.Service.call(...) end)
  ```

  #### ❌ DO NOT use hardcoded budget limits
  **Why:** Limits should be configurable per environment.
  ```elixir
  # ❌ WRONG - Hardcoded budget
  daily_budget: 100.00

  # ✅ CORRECT - Use configuration
  daily_budget: Application.get_env(:singularity, :llm_daily_budget)
  ```

  #### ❌ DO NOT accumulate costs without actual LLM response
  **Why:** Estimated cost ≠ actual cost; must use actual when available.
  ```elixir
  # ❌ WRONG - Only tracking estimated
  release(estimated_cost)

  # ✅ CORRECT - Use actual when available
  actual_cost = Map.get(response, :cost_usd, estimated_cost)
  release(actual_cost)
  ```

  ### Search Keywords

  rate limiting, budget control, llm api costs, concurrent requests, cost management,
  api quota enforcement, daily budgets, request queuing, genserver, otp patterns,
  cost optimization, concurrent limits, rate limits, api throttling, budget exhaustion,
  waiting queue, distributed rate limiting, cost tracking
  """

  use GenServer
  require Logger

  @default_budget_usd 100.00
  @default_max_concurrent 10
  @default_max_per_minute 60

  defstruct [
    :max_concurrent,
    :max_per_minute,
    :daily_budget_usd,
    :current_concurrent,
    :minute_counter,
    :minute_start,
    :daily_spend,
    :waiting_queue
  ]

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Acquire permission to make LLM call.

  Blocks if:
  - Budget exceeded
  - Too many concurrent requests
  - Rate limit exceeded

  Returns {:ok, :acquired} or {:error, reason}
  """
  def acquire(estimated_cost \\ 0.10) do
    GenServer.call(__MODULE__, {:acquire, estimated_cost}, :infinity)
  end

  @doc "Release concurrent slot after LLM call completes"
  def release(actual_cost) do
    GenServer.cast(__MODULE__, {:release, actual_cost})
  end

  @doc """
  Execute function with automatic acquire/release.

  Example:
    RateLimiter.with_limit(fn ->
      LLM.Service.call(:complex, messages, opts)
    end)
  """
  def with_limit(estimated_cost \\ 0.10, fun) when is_function(fun, 0) do
    case acquire(estimated_cost) do
      {:ok, :acquired} ->
        try do
          result = fun.()

          # Extract actual cost if available
          actual_cost =
            case result do
              {:ok, %{cost_usd: cost}} -> cost
              _ -> estimated_cost
            end

          release(actual_cost)
          result
        rescue
          error ->
            release(estimated_cost)
            reraise error, __STACKTRACE__
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Get current limiter stats"
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc "Reset daily counters (called at midnight)"
  def reset_daily do
    GenServer.cast(__MODULE__, :reset_daily)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    # Schedule daily reset at midnight
    schedule_daily_reset()

    state = %__MODULE__{
      max_concurrent: opts[:max_concurrent] || @default_max_concurrent,
      max_per_minute: opts[:max_per_minute] || @default_max_per_minute,
      daily_budget_usd: opts[:daily_budget_usd] || @default_budget_usd,
      current_concurrent: 0,
      minute_counter: 0,
      minute_start: System.monotonic_time(:second),
      daily_spend: 0.0,
      waiting_queue: :queue.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:acquire, estimated_cost}, from, state) do
    # Check budget
    if state.daily_spend + estimated_cost > state.daily_budget_usd do
      Logger.error("Daily budget exceeded",
        current: state.daily_spend,
        budget: state.daily_budget_usd,
        attempted: estimated_cost
      )

      {:reply, {:error, :budget_exceeded}, state}
    else
      # Check rate limits
      state = maybe_reset_minute_counter(state)

      cond do
        # Too many concurrent requests
        state.current_concurrent >= state.max_concurrent ->
          Logger.debug("Concurrent limit reached, queueing request",
            current: state.current_concurrent,
            max: state.max_concurrent
          )

          # Add to waiting queue
          new_queue = :queue.in({from, estimated_cost}, state.waiting_queue)
          {:noreply, %{state | waiting_queue: new_queue}}

        # Too many requests this minute
        state.minute_counter >= state.max_per_minute ->
          Logger.warning("Rate limit exceeded",
            count: state.minute_counter,
            max_per_minute: state.max_per_minute
          )

          {:reply, {:error, :rate_limit_exceeded}, state}

        # All checks passed - grant access
        true ->
          new_state = %{
            state
            | current_concurrent: state.current_concurrent + 1,
              minute_counter: state.minute_counter + 1
          }

          {:reply, {:ok, :acquired}, new_state}
      end
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      current_concurrent: state.current_concurrent,
      max_concurrent: state.max_concurrent,
      minute_counter: state.minute_counter,
      max_per_minute: state.max_per_minute,
      daily_spend: state.daily_spend,
      daily_budget: state.daily_budget_usd,
      budget_remaining: state.daily_budget_usd - state.daily_spend,
      waiting_queue_size: :queue.len(state.waiting_queue)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:release, actual_cost}, state) do
    # Release concurrent slot
    new_state = %{
      state
      | current_concurrent: max(0, state.current_concurrent - 1),
        daily_spend: state.daily_spend + actual_cost
    }

    # Process waiting queue if any
    new_state = process_waiting_queue(new_state)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:reset_daily, state) do
    Logger.info("Resetting daily LLM budget",
      previous_spend: state.daily_spend,
      requests_made: state.minute_counter
    )

    new_state = %{state | daily_spend: 0.0, minute_counter: 0}

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:daily_reset, state) do
    handle_cast(:reset_daily, state)
    schedule_daily_reset()
    {:noreply, state}
  end

  ## Private Functions

  defp maybe_reset_minute_counter(state) do
    now = System.monotonic_time(:second)

    if now - state.minute_start >= 60 do
      %{state | minute_counter: 0, minute_start: now}
    else
      state
    end
  end

  defp process_waiting_queue(state) do
    case :queue.out(state.waiting_queue) do
      {{:value, {from, estimated_cost}}, new_queue} ->
        # Can we process this queued request?
        if state.current_concurrent < state.max_concurrent and
             state.minute_counter < state.max_per_minute and
             state.daily_spend + estimated_cost <= state.daily_budget_usd do
          # Grant to queued requester
          GenServer.reply(from, {:ok, :acquired})

          %{
            state
            | waiting_queue: new_queue,
              current_concurrent: state.current_concurrent + 1,
              minute_counter: state.minute_counter + 1
          }
          # Process more if possible
          |> process_waiting_queue()
        else
          state
        end

      {:empty, _queue} ->
        state
    end
  end

  defp schedule_daily_reset do
    # Calculate milliseconds until next midnight UTC
    now = DateTime.utc_now()

    next_midnight =
      now
      |> DateTime.to_date()
      |> Date.add(1)
      |> DateTime.new!(~T[00:00:00])

    ms_until_midnight = DateTime.diff(next_midnight, now, :millisecond)

    Process.send_after(self(), :daily_reset, ms_until_midnight)
  end
end
