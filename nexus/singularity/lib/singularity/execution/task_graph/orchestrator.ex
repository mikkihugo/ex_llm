defmodule Singularity.Execution.TaskGraph.Orchestrator do
  @moduledoc """
  TaskGraph.Orchestrator - Dependency-aware task orchestration for self-improving agents.

  ## Purpose

  Provides high-level API for enqueueing tasks with dependencies, automatically:
  - Resolves task dependencies via TaskGraph (Hierarchical Temporal DAG)
  - Delegates worker spawning to TaskGraph.WorkerPool
  - Enforces role-based security policies via TaskGraph.Toolkit
  - Tracks task execution and results

  ## Architecture

  ```
  TaskGraph.Orchestrator (high-level API)
       ↓
  TaskGraphCore (dependency resolution) + TodoStore (persistence)
       ↓
  TaskGraph.WorkerPool (worker spawning - polls for ready tasks)
       ↓
  AgentSupervisor (process management)
       ↓
  TaskGraph.Toolkit (policy-enforced tool execution)
  ```

  ## Key Differences from Direct TodoStore Usage

  **Without Orchestrator:**
  ```elixir
  # Manual dependency management
  TodoStore.create(%{id: "test", status: "pending"})
  TodoStore.create(%{id: "deploy", status: "pending"})  # Oops! Should wait for test
  ```

  **With Orchestrator:**
  ```elixir
  # Automatic dependency resolution
  Orchestrator.enqueue(%{id: "test", depends_on: []})
  Orchestrator.enqueue(%{id: "deploy", depends_on: ["test"]})  # ✅ Waits for test
  ```

  ## Usage

  ```elixir
  alias Singularity.Execution.TaskGraph.Orchestrator

  # Enqueue task with dependencies
  {:ok, task_id} = Orchestrator.enqueue(%{
    id: "implement-feature",
    title: "Implement user registration",
    role: :coder,
    depends_on: [],
    context: %{"spec" => "..."}
  })

  # Check status
  {:ok, status} = Orchestrator.get_status(task_id)
  # => {:ok, :in_progress}

  # Get result
  {:ok, result} = Orchestrator.get_result(task_id)
  # => {:ok, %{files_created: [...], tests_passed: true}}

  # Visualize task graph
  graph = Orchestrator.get_task_graph()
  # => %{
  #   "implement-feature" => :completed,
  #   "test-feature" => :in_progress,
  #   "deploy-feature" => :pending
  # }
  ```

  ## Roles and Policies

  - `:coder` - Can write code, run shell commands, commit to git (no network)
  - `:tester` - Can run tests in Docker sandbox (no code modification)
  - `:critic` - Can read code and execute Lua validators (read-only)
  - `:researcher` - Can fetch from whitelisted documentation sites
  - `:admin` - Full access (deployment, dangerous operations)

  ## Integration with Existing Infrastructure

  Orchestrator **reuses** existing Singularity components:
  - `TodoStore` - Persists tasks to PostgreSQL with `depends_on_ids`
  - `TaskGraph.WorkerPool` (formerly TodoSwarmCoordinator) - Spawns workers
  - `TaskGraphCore` - Dependency resolution (pure functions)
  - `AgentSupervisor` - Process supervision

  ## Dependencies

  Depends on:
  - `Singularity.Execution.TodoSupervisor` - For TaskGraph.WorkerPool
  - `Singularity.Agents.Supervisor` - For AgentSupervisor
  - `Singularity.Execution.Planning.TaskGraphCore` - For dependency graphs
  - `Singularity.Repo` - For todos table persistence
  """

  use GenServer
  require Logger

  alias Singularity.Execution.{TodoStore, TodoSwarmCoordinator}
  alias Singularity.Execution.Planning.TaskGraphCore
  alias Singularity.AgentSupervisor
  alias Singularity.ProcessRegistry

  @type task :: %{
          required(:id) => String.t(),
          required(:title) => String.t(),
          required(:role) => atom(),
          required(:depends_on) => list(String.t()),
          required(:context) => map(),
          optional(:priority) => integer(),
          optional(:timeout) => integer()
        }

  defstruct [
    :dag,
    # TaskGraph graph for dependency resolution
    :tasks,
    # Map of task_id => task metadata
    # Map of task_id => result
    :results
  ]

  ## Public API

  @doc """
  Start the Orchestrator GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Enqueue a task with dependencies.

  ## Arguments

  - `task` - Map with:
    - `:id` - Unique task identifier (string)
    - `:title` - Human-readable title
    - `:role` - Agent role (`:coder`, `:tester`, `:critic`, `:researcher`, `:admin`)
    - `:depends_on` - List of task IDs this task depends on
    - `:context` - Map of contextual data for the agent
    - `:priority` (optional) - Priority (default: 5)
    - `:timeout` (optional) - Timeout in milliseconds

  ## Returns

  - `{:ok, task_id}` - Task enqueued successfully
  - `{:error, reason}` - Failed to enqueue

  ## Examples

      iex> Orchestrator.enqueue(%{
        id: "write-code",
        title: "Implement feature X",
        role: :coder,
        depends_on: [],
        context: %{"spec" => "..."}
      })
      {:ok, "write-code"}
  """
  @spec enqueue(task()) :: {:ok, String.t()} | {:error, term()}
  def enqueue(task) do
    GenServer.call(__MODULE__, {:enqueue, task})
  end

  @doc """
  Get task status.

  Returns `:pending`, `:in_progress`, `:completed`, `:failed`, or `{:error, :not_found}`.
  """
  @spec get_status(String.t()) :: {:ok, atom()} | {:error, term()}
  def get_status(task_id) do
    case TodoStore.get(task_id) do
      {:ok, todo} -> {:ok, String.to_atom(todo.status)}
      error -> error
    end
  end

  @doc """
  Get task result.

  Returns result map if task completed, error otherwise.
  """
  @spec get_result(String.t()) :: {:ok, map()} | {:error, term()}
  def get_result(task_id) do
    GenServer.call(__MODULE__, {:get_result, task_id})
  end

  @doc """
  Get entire task graph with statuses.

  Returns map of task_id => status for visualization.
  """
  @spec get_task_graph() :: map()
  def get_task_graph do
    GenServer.call(__MODULE__, :get_task_graph)
  end

  @doc """
  Get next ready task (for manual execution or debugging).

  Returns task that has all dependencies satisfied, or nil if none ready.
  """
  @spec get_next_ready() :: {:ok, task()} | {:error, :no_ready_tasks}
  def get_next_ready do
    GenServer.call(__MODULE__, :get_next_ready)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    Logger.info("Starting TaskGraph.Orchestrator...")

    # Use AgentSupervisor to register this orchestrator as a managed agent
    case AgentSupervisor.register_orchestrator(__MODULE__, opts) do
      {:ok, _} ->
        Logger.info("TaskGraph.Orchestrator registered with AgentSupervisor")

      {:error, reason} ->
        Logger.warning("Failed to register with AgentSupervisor", reason: inspect(reason))
    end

    # Register process with Registry
    case Registry.register(ProcessRegistry, __MODULE__, nil) do
      {:ok, _} ->
        Logger.info("TaskGraph.Orchestrator registered successfully")

      {:error, reason} ->
        Logger.warning("Failed to register TaskGraph.Orchestrator",
          reason: inspect(reason)
        )
    end

    state = %__MODULE__{
      dag: TaskGraphCore.new("task-graph"),
      tasks: %{},
      results: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:enqueue, task}, _from, state) do
    with :ok <- validate_task(task),
         {:ok, new_state} <- do_enqueue(task, state) do
      {:reply, {:ok, task.id}, new_state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_result, task_id}, _from, state) do
    result =
      case Map.get(state.results, task_id) do
        nil ->
          case TodoStore.get(task_id) do
            {:ok, todo} when todo.status == "completed" ->
              {:ok, todo.result || %{}}

            {:ok, _todo} ->
              {:error, :not_completed}

            error ->
              error
          end

        cached_result ->
          {:ok, cached_result}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_task_graph, _from, state) do
    # Build graph from current TaskGraph state
    graph =
      Enum.reduce(state.tasks, %{}, fn {task_id, _task}, acc ->
        status =
          case TodoStore.get(task_id) do
            {:ok, todo} -> String.to_atom(todo.status)
            _ -> :unknown
          end

        Map.put(acc, task_id, status)
      end)

    {:reply, graph, state}
  end

  @impl true
  def handle_call(:get_next_ready, _from, state) do
    result =
      case TaskGraphCore.select_next_task(state.dag) do
        {:ok, task_graph_task} ->
          {:ok, Map.get(state.tasks, task_graph_task.id)}

        {:error, :no_ready_tasks} ->
          {:error, :no_ready_tasks}
      end

    {:reply, result, state}
  end

  ## Private Helpers

  defp validate_task(%{id: id, title: title, role: role, depends_on: deps, context: ctx})
       when is_binary(id) and is_binary(title) and is_atom(role) and is_list(deps) and
              is_map(ctx) do
    valid_roles = [:coder, :tester, :critic, :researcher, :admin, :architect]

    if role in valid_roles do
      :ok
    else
      {:error, {:invalid_role, role}}
    end
  end

  defp validate_task(task) do
    {:error, {:invalid_task, "Missing required fields", task}}
  end

  defp do_enqueue(task, state) do
    # 1. Create todo in PostgreSQL
    todo_attrs = %{
      id: task.id,
      title: task.title,
      status: "pending",
      complexity: task[:complexity] || :medium,
      priority: task[:priority] || 5,
      depends_on_ids: task.depends_on,
      context: task.context,
      metadata: %{
        "role" => to_string(task.role),
        "enqueued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      },
      max_retries: task[:max_retries] || 3,
      timeout_ms: task[:timeout] || 300_000
    }

    case TodoStore.create(todo_attrs) do
      {:ok, _todo} ->
        # 2. Add to TaskGraph graph
        task_graph_task = %{
          id: task.id,
          title: task.title,
          complexity: task[:complexity] || :medium,
          dependencies: task.depends_on
        }

        new_dag = TaskGraphCore.add_task(state.dag, task_graph_task)

        # 3. Store task metadata
        new_tasks = Map.put(state.tasks, task.id, task)

        new_state = %{state | dag: new_dag, tasks: new_tasks}

        Logger.info("Task enqueued",
          task_id: task.id,
          role: task.role,
          dependencies: length(task.depends_on)
        )

        {:ok, new_state}

      {:error, reason} ->
        {:error, {:todo_creation_failed, reason}}
    end
  end
end
