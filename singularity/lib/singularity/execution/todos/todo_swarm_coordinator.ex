defmodule Singularity.Execution.Todos.TodoSwarmCoordinator do
  @moduledoc """
  TodoSwarmCoordinator - Orchestrates swarm-based todo execution.

  ## Architecture

  User creates todo → Coordinator spawns workers → Workers solve → Report back

  ## Responsibilities

  - Monitor pending todos
  - Spawn TodoWorkerAgent processes
  - Load balance across available agents
  - Track agent status and results
  - Handle failures and retries
  - Coordinate dependencies

  ## Usage

  ```elixir
  # Start coordinator (usually in supervision tree)
  {:ok, pid} = TodoSwarmCoordinator.start_link([])

  # Manually trigger swarm
  TodoSwarmCoordinator.spawn_swarm(max_workers: 5)

  # Check swarm status
  TodoSwarmCoordinator.get_status()
  ```

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Todos.TodoSwarmCoordinator",
    "purpose": "GenServer-based swarm orchestrator for distributed todo execution across worker pools",
    "role": "orchestrator",
    "layer": "execution_todos",
    "key_responsibilities": [
      "Maintain GenServer state for active worker pool",
      "Poll TodoStore for ready todos periodically",
      "Spawn TodoWorkerAgent processes with load balancing",
      "Monitor worker process lifecycle and handle crashes",
      "Track worker status, completions, and failures",
      "Coordinate dependency-aware todo execution"
    ],
    "prevents_duplicates": ["WorkerPool", "TodoExecutor", "SwarmManager", "WorkerCoordinator"],
    "uses": ["TodoStore", "TodoWorkerAgent", "Logger", "Process", "GenServer"],
    "capabilities": ["spawn_swarm/1", "get_status/0", "worker_completed/3", "worker_failed/3"],
    "process_type": "GenServer (named, singleton)",
    "constraints": "max_concurrent_workers (default 10), poll_interval_ms (default 5000)"
  }
  ```

  ### Architecture Diagram (Mermaid)

  ```mermaid
  graph TB
    TodoStore["TodoStore<br/>(ready todos)"]

    Coordinator["TodoSwarmCoordinator<br/>(GenServer)"]

    Coordinator -->|periodic poll<br/>every 5s| TodoStore
    TodoStore -->|get_ready_todos/1| ReadyList["Ready Todos<br/>(pending, deps met)"]

    ReadyList -->|spawn worker per todo| SpawnWorker["spawn_worker_for_todo/1<br/>(start agent)"]

    SpawnWorker -->|start_link| Agent["TodoWorkerAgent #1<br/>(AI solver)"]
    SpawnWorker -->|start_link| Agent2["TodoWorkerAgent #2<br/>(AI solver)"]
    SpawnWorker -->|start_link| Agent3["TodoWorkerAgent #3<br/>(AI solver)"]

    Agent -->|worker_completed| Coordinator
    Agent2 -->|worker_failed| Coordinator
    Agent3 -->|process crash| Coordinator

    Coordinator -->|load balance| LoadCheck{{"Active < Max?"}}

    LoadCheck -->|yes| SpawnWorker
    LoadCheck -->|no| Wait["Wait for slot"]

    Wait -->|worker finishes| SpawnWorker

    Coordinator -->|maintain state| State["state struct<br/>active_workers: Map<br/>completed_count: int<br/>failed_count: int"]

    style Coordinator fill:#E8F4F8
    style State fill:#D0E8F2
    style Agent fill:#B8DCEC
    style ReadyList fill:#D0E8F2
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: TodoStore
      function: get_ready_todos/1
      purpose: Fetch pending todos with dependencies met
      critical: true
      pattern: "Periodic polling via handle_info(:poll_todos)"

    - module: TodoWorkerAgent
      function: start_link/1
      purpose: Spawn worker process to solve individual todo
      critical: true
      pattern: "One agent per todo, with process monitoring"

    - module: Process
      function: monitor/1, send_after/2
      purpose: Monitor worker crashes, schedule periodic polls
      critical: true
      pattern: "Process.monitor(pid), Process.send_after(self(), :poll_todos, interval)"

    - module: Logger
      function: info/2, warning/2, error/2
      purpose: Log swarm events and worker status
      critical: false

    - module: Enum
      function: filter/2, map/2, take/2, find/2, each/2
      purpose: Work with worker lists and todos
      critical: true

  called_by:
    - module: Singularity.Execution.Todos.Supervisor
      function: init/1
      purpose: Manage coordinator lifecycle in supervision tree
      frequency: on_startup

    - module: Singularity.Agents.RuntimeBootstrapper
      function: start_todos_worker_pool/1
      purpose: Bootstrap todo execution swarm
      frequency: on_agent_startup

    - module: External clients
      function: spawn_swarm/1, get_status/0, stop_all_workers/0
      purpose: Manual swarm control
      frequency: on_demand

  state_transitions:
    - name: startup
      from: idle
      to: polling
      trigger: start_link/1 called
      actions:
        - Create GenServer state with counters
        - Schedule first poll via schedule_poll/1
        - Log startup with configuration
        - Return {:ok, state}

    - name: poll_and_spawn
      from: polling
      to: workers_active
      trigger: handle_info(:poll_todos) fires every poll_interval_ms
      guards:
        - map_size(active_workers) < max_concurrent_workers
      actions:
        - Call TodoStore.get_ready_todos/1
        - Filter by complexity if specified
        - For each todo: spawn_worker_for_todo/1
        - Add new worker info to active_workers map
        - Update last_poll_at
        - Reschedule next poll
        - Return {:noreply, new_state}

    - name: worker_completion
      from: workers_active
      to: workers_active
      trigger: handle_cast({:worker_completed, worker_id, todo_id, result})
      actions:
        - Log worker completion
        - Remove worker from active_workers
        - Increment completed_count
        - Call maybe_spawn_more_workers/1 to fill slots
        - Return {:noreply, new_state}

    - name: worker_failure
      from: workers_active
      to: workers_active
      trigger: handle_cast({:worker_failed, worker_id, todo_id, reason})
      actions:
        - Log worker failure with reason
        - Remove worker from active_workers
        - Increment failed_count
        - Call maybe_spawn_more_workers/1 to fill slots
        - Return {:noreply, new_state}

    - name: worker_crash
      from: workers_active
      to: workers_active
      trigger: handle_info({:DOWN, ref, :process, pid, reason}) from Process.monitor
      actions:
        - Find worker by pid
        - Log process crash
        - Update TodoStore to mark todo as failed
        - Remove worker from active_workers
        - Increment failed_count
        - Call maybe_spawn_more_workers/1
        - Return {:noreply, new_state}

    - name: manual_stop
      from: workers_active
      to: all_workers_stopped
      trigger: handle_cast(:stop_all_workers)
      actions:
        - Iterate active_workers
        - Call TodoWorkerAgent.stop/1 on each
        - Clear active_workers map
        - Return {:noreply, state}

  depends_on:
    - Singularity.Execution.Todos.TodoStore (MUST be available)
    - Singularity.Execution.Todos.TodoWorkerAgent (MUST be available)
    - Process monitoring (built-in, no dependency)
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create WorkerPool, SwarmManager, or TodoExecutor duplicates
  **Why:** TodoSwarmCoordinator is the single canonical swarm orchestrator for todo execution.

  ```elixir
  # ❌ WRONG - Duplicate swarm manager
  defmodule MyApp.WorkerPool do
    def spawn_workers(count) do
      # Re-implementing TodoSwarmCoordinator logic
    end
  end

  # ✅ CORRECT - Use TodoSwarmCoordinator
  TodoSwarmCoordinator.spawn_swarm(swarm_size: count)
  ```

  #### ❌ DO NOT spawn workers without capacity checks
  **Why:** Unbounded worker spawning causes resource exhaustion and coordination chaos.

  ```elixir
  # ❌ WRONG - Spawn without checking capacity
  todos |> Enum.each(&spawn_worker_for_todo/1)

  # ✅ CORRECT - Respect max_concurrent_workers limit
  # TodoSwarmCoordinator.spawn_workers/2 checks available_slots
  available_slots = state.max_concurrent_workers - map_size(state.active_workers)
  if available_slots > 0 do
    # Spawn up to available_slots workers
  end
  ```

  #### ❌ DO NOT miss process monitoring on spawned workers
  **Why:** Unmonitored workers can crash silently, leaving coordinator unaware of failures.

  ```elixir
  # ❌ WRONG - Spawn without monitoring
  {:ok, pid} = TodoWorkerAgent.start_link(...)
  # Coordinator won't know if process crashes!

  # ✅ CORRECT - Monitor process lifecycle
  {:ok, pid} = TodoWorkerAgent.start_link(...)
  Process.monitor(pid)  # Will trigger handle_info({:DOWN, ...})
  ```

  #### ❌ DO NOT ignore worker failures - mark todos as failed
  **Why:** Silent failures leave todos in limbo, blocking dependent work.

  ```elixir
  # ❌ WRONG - Just remove worker, leave todo hanging
  {:noreply, %{state | active_workers: Map.delete(...)}}

  # ✅ CORRECT - Update TodoStore to mark todo as failed
  with {:ok, todo} <- TodoStore.get(worker.todo_id) do
    TodoStore.fail(todo, "Worker process crashed")
  end
  ```

  ### Search Keywords

  todo swarm, worker pool, task orchestration, GenServer coordinator, concurrent execution,
  load balancing, worker spawning, swarm intelligence, distributed todos, process monitoring,
  worker lifecycle, task distribution, todo store polling, failure handling, worker capacity,
  autonomous agents, parallel execution, swarm coordination, periodic polling, resource management
  """

  use GenServer
  require Logger

  alias Singularity.Execution.Todos.{TodoStore, TodoWorkerAgent}
  @poll_interval_ms 5_000
  @max_concurrent_workers 10
  @default_swarm_size 3

  defstruct [
    :poll_interval_ms,
    :max_concurrent_workers,
    :active_workers,
    :completed_count,
    :failed_count,
    :last_poll_at
  ]

  # ===========================
  # Client API
  # ===========================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually trigger swarm spawning.
  """
  def spawn_swarm(opts \\ []) do
    GenServer.cast(__MODULE__, {:spawn_swarm, opts})
  end

  @doc """
  Get coordinator status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Force stop all workers.
  """
  def stop_all_workers do
    GenServer.cast(__MODULE__, :stop_all_workers)
  end

  @doc """
  Report worker completion.
  """
  def worker_completed(worker_id, todo_id, result) do
    GenServer.cast(__MODULE__, {:worker_completed, worker_id, todo_id, result})
  end

  @doc """
  Report worker failure.
  """
  def worker_failed(worker_id, todo_id, reason) do
    GenServer.cast(__MODULE__, {:worker_failed, worker_id, todo_id, reason})
  end

  # ===========================
  # Server Callbacks
  # ===========================

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval_ms, @poll_interval_ms)
    max_workers = Keyword.get(opts, :max_concurrent_workers, @max_concurrent_workers)

    state = %__MODULE__{
      poll_interval_ms: poll_interval,
      max_concurrent_workers: max_workers,
      active_workers: %{},
      completed_count: 0,
      failed_count: 0,
      last_poll_at: nil
    }

    # Schedule first poll
    schedule_poll(poll_interval)

    Logger.info("TodoSwarmCoordinator started",
      max_workers: max_workers,
      poll_interval_ms: poll_interval
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      active_workers: map_size(state.active_workers),
      max_workers: state.max_concurrent_workers,
      completed_count: state.completed_count,
      failed_count: state.failed_count,
      last_poll_at: state.last_poll_at,
      workers:
        Enum.map(state.active_workers, fn {id, worker} ->
          %{
            id: id,
            todo_id: worker.todo_id,
            started_at: worker.started_at,
            status: worker.status
          }
        end)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:spawn_swarm, opts}, state) do
    {:noreply, spawn_workers(state, opts)}
  end

  @impl true
  def handle_cast(:stop_all_workers, state) do
    Enum.each(state.active_workers, fn {_id, worker} ->
      TodoWorkerAgent.stop(worker.pid)
    end)

    {:noreply, %{state | active_workers: %{}}}
  end

  @impl true
  def handle_cast({:worker_completed, worker_id, todo_id, result}, state) do
    Logger.info("Worker completed todo",
      worker_id: worker_id,
      todo_id: todo_id
    )

    # Remove from active workers
    new_active_workers = Map.delete(state.active_workers, worker_id)

    new_state = %{
      state
      | active_workers: new_active_workers,
        completed_count: state.completed_count + 1
    }

    # Try to spawn more workers if we have capacity
    {:noreply, maybe_spawn_more_workers(new_state)}
  end

  @impl true
  def handle_cast({:worker_failed, worker_id, todo_id, reason}, state) do
    Logger.warning("Worker failed on todo",
      worker_id: worker_id,
      todo_id: todo_id,
      reason: inspect(reason)
    )

    # Remove from active workers
    new_active_workers = Map.delete(state.active_workers, worker_id)

    new_state = %{
      state
      | active_workers: new_active_workers,
        failed_count: state.failed_count + 1
    }

    # Try to spawn more workers if we have capacity
    {:noreply, maybe_spawn_more_workers(new_state)}
  end

  @impl true
  def handle_info(:poll_todos, state) do
    new_state = poll_and_spawn(state)
    schedule_poll(state.poll_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Handle worker crash
    case find_worker_by_pid(state.active_workers, pid) do
      {worker_id, worker} ->
        Logger.error("Worker process crashed",
          worker_id: worker_id,
          todo_id: worker.todo_id,
          reason: inspect(reason)
        )

        # Mark todo as failed
        with {:ok, todo} <- TodoStore.get(worker.todo_id) do
          TodoStore.fail(todo, "Worker process crashed: #{inspect(reason)}")
        end

        new_active_workers = Map.delete(state.active_workers, worker_id)

        new_state = %{
          state
          | active_workers: new_active_workers,
            failed_count: state.failed_count + 1
        }

        {:noreply, maybe_spawn_more_workers(new_state)}

      nil ->
        {:noreply, state}
    end
  end

  # ===========================
  # Private Helpers
  # ===========================

  defp poll_and_spawn(state) do
    new_state = %{state | last_poll_at: DateTime.utc_now()}

    if map_size(state.active_workers) < state.max_concurrent_workers do
      spawn_workers(new_state, swarm_size: @default_swarm_size)
    else
      new_state
    end
  end

  defp spawn_workers(state, opts) do
    available_slots = state.max_concurrent_workers - map_size(state.active_workers)

    if available_slots > 0 do
      swarm_size = min(Keyword.get(opts, :swarm_size, @default_swarm_size), available_slots)
      complexity = Keyword.get(opts, :complexity)

      {:ok, ready_todos} = TodoStore.get_ready_todos(limit: swarm_size)

      filtered_todos =
        if complexity do
          Enum.filter(ready_todos, &(&1.complexity == complexity))
        else
          ready_todos
        end
        |> Enum.take(swarm_size)

      new_workers =
        filtered_todos
        |> Enum.map(&spawn_worker_for_todo/1)
        |> Enum.filter(&(&1 != nil))
        |> Map.new()

      if map_size(new_workers) > 0 do
        Logger.info("Spawned worker swarm",
          count: map_size(new_workers),
          active_total: map_size(state.active_workers) + map_size(new_workers)
        )
      end

      %{state | active_workers: Map.merge(state.active_workers, new_workers)}
    else
      state
    end
  end

  defp maybe_spawn_more_workers(state) do
    available_slots = state.max_concurrent_workers - map_size(state.active_workers)

    if available_slots > 0 do
      spawn_workers(state, swarm_size: available_slots)
    else
      state
    end
  end

  defp spawn_worker_for_todo(todo) do
    worker_id = generate_worker_id()

    case TodoWorkerAgent.start_link(
           todo_id: todo.id,
           worker_id: worker_id,
           coordinator: self()
         ) do
      {:ok, pid} ->
        # Monitor the worker process
        Process.monitor(pid)

        worker_info = %{
          pid: pid,
          todo_id: todo.id,
          started_at: DateTime.utc_now(),
          status: :running
        }

        {worker_id, worker_info}

      {:error, reason} ->
        Logger.error("Failed to spawn worker",
          todo_id: todo.id,
          reason: inspect(reason)
        )

        nil
    end
  end

  defp find_worker_by_pid(workers, pid) do
    Enum.find(workers, fn {_id, worker} -> worker.pid == pid end)
  end

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll_todos, interval)
  end

  defp generate_worker_id do
    "worker-#{System.system_time(:millisecond)}-#{:rand.uniform(99999)}"
  end
end
