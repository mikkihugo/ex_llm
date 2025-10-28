defmodule Singularity.Execution.RefactorAssimilateSwarmCoordinator do
  @moduledoc """
  Coordinator for orchestration of refactor + assimilate swarms.

  This module provides a safe scaffold to:
  - analyze a codebase for smells and refactor opportunities
  - generate hierarchical tasks (PgFlow/HTDAG compatible maps)
  - spawn dedicated workers to perform transformations and assimilation
  - validate changes, run tests, and rollback on failure

  It's intentionally conservative: workers should operate on branches or dry-run patches by default.
  """

  use GenServer

  alias Singularity.SASL

  @default_max_workers 4

  ## Public API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec spawn_refactor_swarm(map(), keyword()) :: {:ok, term()} | {:error, term()}
  def spawn_refactor_swarm(task_spec, opts \\ []) do
    GenServer.call(__MODULE__, {:spawn_refactor_swarm, task_spec, opts}, :infinity)
  end

  @spec get_status() :: map()
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  ## GenServer callbacks

  def init(opts) do
    state = %{
      active_workers: %{},
      completed: %{},
      failed: %{},
      max_workers: Keyword.get(opts, :max_workers, @default_max_workers),
      created_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  def handle_call(:get_status, _from, state) do
    {:reply,
     %{
       active_workers: map_size(state.active_workers),
       completed: state.completed,
       failed: state.failed
     }, state}
  end

  def handle_call({:spawn_refactor_swarm, task_spec, opts}, _from, state) do
    # Validate task_spec minimally
    if Map.get(task_spec, :codebase_id) == nil do
      {:reply, {:error, :missing_codebase_id}, state}
    else
      # Spawn workers up to max
      spawn_count = min(state.max_workers, Map.get(task_spec, :parallel, state.max_workers))

      workers =
        1..spawn_count
        |> Enum.map(fn i ->
          {:ok, pid} = start_refactor_worker(task_spec, i)
          pid
        end)

      new_active =
        Enum.reduce(workers, state.active_workers, fn pid, acc ->
          Map.put(acc, pid, %{started_at: DateTime.utc_now()})
        end)

      new_state = %{state | active_workers: new_active}

      {:reply, {:ok, %{workers_spawned: length(workers)}}, new_state}
    end
  end

  def handle_info({:worker_completed, pid, result}, state) do
    new_active = Map.delete(state.active_workers, pid)
    new_completed = Map.put(state.completed, pid, %{result: result, at: DateTime.utc_now()})
    {:noreply, %{state | active_workers: new_active, completed: new_completed}}
  end

  def handle_info({:worker_failed, pid, reason}, state) do
    SASL.execution_failure(:refactor_worker_failed, "Refactor worker failed",
      pid: pid,
      reason: reason
    )

    new_active = Map.delete(state.active_workers, pid)
    new_failed = Map.put(state.failed, pid, %{reason: reason, at: DateTime.utc_now()})
    {:noreply, %{state | active_workers: new_active, failed: new_failed}}
  end

  # Internal helpers

  defp start_refactor_worker(task_spec, index) do
    # At this scaffold stage we spawn a simple Task process that executes the worker module
    Task.start(fn ->
      pid = self()

      case Singularity.Execution.RefactorWorker.run(task_spec, index) do
        {:ok, result} ->
          send(__MODULE__, {:worker_completed, pid, result})

        {:error, reason} ->
          send(__MODULE__, {:worker_failed, pid, reason})
      end
    end)
  end
end
