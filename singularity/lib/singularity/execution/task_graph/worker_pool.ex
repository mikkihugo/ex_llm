defmodule Singularity.Execution.TaskGraph.WorkerPool do
  @moduledoc """
  TaskGraph.WorkerPool - Orchestrates swarm-based todo execution.

  ## Architecture

  User creates todo → Coordinator spawns workers → Workers solve → Report back

  ## Responsibilities

  - Monitor pending todos
  - Spawn TaskGraph.Worker processes
  - Load balance across available agents
  - Track agent status and results
  - Handle failures and retries
  - Coordinate dependencies

  ## Usage

  ```elixir
  # Start coordinator (usually in supervision tree)
  {:ok, pid} = TaskGraph.WorkerPool.start_link([])

  # Manually trigger swarm
  TaskGraph.WorkerPool.spawn_swarm(max_workers: 5)

  # Check swarm status
  TaskGraph.WorkerPool.get_status()
  ```
  """

  use GenServer
  require Logger

  alias Singularity.Execution.Todos.TodoStore
  alias Singularity.Execution.TaskGraph.Worker
  alias Singularity.ProcessRegistry

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

    Logger.info("TaskGraph.WorkerPool started",
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
      TaskGraph.Worker.stop(worker.pid)
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

    case TaskGraph.Worker.start_link(
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
