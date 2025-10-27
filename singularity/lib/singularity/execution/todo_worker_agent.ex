defmodule Singularity.Execution.TodoWorkerAgent do
  @moduledoc """
  TodoWorkerAgent - Individual worker that executes a single todo.

  ## Execution Flow

  1. Assigned a todo by TodoSwarmCoordinator
  2. Analyzes todo requirements (title, description, context)
  3. Decomposes task using TaskGraph for hierarchical execution
  4. Executes task DAG with TaskGraph executor
  5. Reports result back to coordinator
  6. Updates todo status in TodoStore

  ## Agent Lifecycle

  spawn → execute → complete/fail → terminate

  ## Template Integration

  Uses Handlebars template for task execution:
  - `todos/execute-task.hbs` - Task execution prompt with context

  ## Usage

  Workers are typically spawned by TodoSwarmCoordinator:

  ```elixir
  {:ok, pid} = TodoWorkerAgent.start_link(
    todo_id: "uuid-here",
    worker_id: "worker-123",
    coordinator: coordinator_pid
  )
  ```
  """

  use GenServer
  require Logger

  alias Singularity.Execution.Todos.{TodoStore, TodoSwarmCoordinator}
  # 5 minutes
  @execution_timeout_ms 300_000

  defstruct [
    :todo_id,
    :worker_id,
    :coordinator,
    :todo,
    :started_at
  ]

  # ===========================
  # Client API
  # ===========================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Stop a worker.
  """
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # ===========================
  # Server Callbacks
  # ===========================

  @impl true
  def init(opts) do
    todo_id = Keyword.fetch!(opts, :todo_id)
    worker_id = Keyword.fetch!(opts, :worker_id)
    coordinator = Keyword.fetch!(opts, :coordinator)

    state = %__MODULE__{
      todo_id: todo_id,
      worker_id: worker_id,
      coordinator: coordinator,
      started_at: DateTime.utc_now()
    }

    # Start execution immediately
    send(self(), :execute)

    Logger.info("TodoWorkerAgent started",
      worker_id: worker_id,
      todo_id: todo_id
    )

    {:ok, state}
  end

  @impl true
  def handle_info(:execute, state) do
    # Load todo
    case TodoStore.get(state.todo_id) do
      {:ok, todo} ->
        new_state = %{state | todo: todo}
        execute_todo(new_state)

      {:error, :not_found} ->
        Logger.error("Todo not found", worker_id: state.worker_id, todo_id: state.todo_id)
        {:stop, :normal, state}
    end
  end

  # ===========================
  # Private Helpers
  # ===========================

  defp execute_todo(state) do
    todo = state.todo

    Logger.info("Executing todo",
      worker_id: state.worker_id,
      todo_id: todo.id,
      title: todo.title,
      complexity: todo.complexity
    )

    # Mark as assigned and started
    with {:ok, todo} <- TodoStore.assign(todo, state.worker_id),
         {:ok, todo} <- TodoStore.start(todo) do
      # Execute the task
      case perform_task(todo) do
        {:ok, result} ->
          handle_success(state, result)

        {:error, reason} ->
          handle_failure(state, reason)
      end
    else
      {:error, reason} ->
        handle_failure(state, reason)
    end
  end

  defp perform_task(todo) do
    try do
      # Use TaskGraph for hierarchical task decomposition
      Logger.debug("Decomposing todo with TaskGraph",
        todo_id: todo.id,
        complexity: todo.complexity
      )

      # Create TaskGraph from todo
      dag =
        Singularity.Execution.Planning.TaskGraph.decompose(%{
          description: todo.title,
          details: todo.description,
          context: todo.context,
          complexity: map_complexity(todo.complexity)
        })

      # Execute with TaskGraph
      run_id = "todo-#{todo.id}-#{System.system_time(:millisecond)}"

      case Singularity.Execution.Planning.TaskGraph.execute(dag,
             run_id: run_id,
             stream: false,
             # Don't evolve for simple todos
             evolve: false
           ) do
        {:ok, result} ->
          Logger.info("TaskGraph execution succeeded",
            todo_id: todo.id,
            run_id: run_id,
            completed: result.completed,
            failed: result.failed
          )

          # Extract final result from TaskGraph execution
          output = extract_result_output(result)

          {:ok,
           %{
             output: output,
             completed_by: "TodoWorkerAgent (via TaskGraph)",
             completed_at: DateTime.utc_now(),
             task_graph_run_id: run_id,
             tasks_completed: result.completed,
             tasks_failed: result.failed
           }}

        {:error, reason} ->
          Logger.error("TaskGraph execution failed",
            todo_id: todo.id,
            run_id: run_id,
            reason: inspect(reason)
          )

          {:error, "TaskGraph execution failed: #{inspect(reason)}"}
      end
    catch
      kind, reason ->
        Logger.error("Task execution crashed",
          todo_id: todo.id,
          kind: kind,
          reason: inspect(reason),
          stacktrace: __STACKTRACE__
        )

        {:error, "Execution crashed: #{kind} #{inspect(reason)}"}
    end
  end

  # Extract meaningful output from TaskGraph execution results
  defp extract_result_output(%{results: results}) when is_map(results) do
    results
    |> Map.values()
    |> Enum.map(fn task_result ->
      case task_result do
        %{output: output} when is_binary(output) -> output
        output when is_binary(output) -> output
        other -> inspect(other)
      end
    end)
    |> Enum.join("\n\n---\n\n")
  end

  defp extract_result_output(_), do: "Task completed successfully"

  defp handle_success(state, result) do
    todo = state.todo

    Logger.info("Todo completed successfully",
      worker_id: state.worker_id,
      todo_id: todo.id
    )

    # Record outcome for self-improving agents
    Singularity.SelfImprovingAgent.record_outcome(state.worker_id, :success)

    # Update todo in store
    case TodoStore.complete(todo, result) do
      {:ok, _updated_todo} ->
        # Notify coordinator
        TodoSwarmCoordinator.worker_completed(state.worker_id, todo.id, result)

      {:error, reason} ->
        Logger.error("Failed to update completed todo",
          worker_id: state.worker_id,
          todo_id: todo.id,
          reason: inspect(reason)
        )
    end

    {:stop, :normal, state}
  end

  defp handle_failure(state, reason) do
    todo = state.todo
    error_message = format_error(reason)

    Logger.warning("Todo execution failed",
      worker_id: state.worker_id,
      todo_id: todo.id,
      error: error_message
    )

    # Record outcome for self-improving agents
    Singularity.SelfImprovingAgent.record_outcome(state.worker_id, :failure)

    # Update todo in store (will auto-retry if under max_retries)
    case TodoStore.fail(todo, error_message) do
      {:ok, _updated_todo} ->
        # Notify coordinator
        TodoSwarmCoordinator.worker_failed(state.worker_id, todo.id, error_message)

      {:error, reason} ->
        Logger.error("Failed to update failed todo",
          worker_id: state.worker_id,
          todo_id: todo.id,
          reason: inspect(reason)
        )
    end

    {:stop, :normal, state}
  end

  defp map_complexity("simple"), do: :simple
  defp map_complexity("medium"), do: :medium
  defp map_complexity("complex"), do: :complex
  defp map_complexity(_), do: :medium

  defp priority_label(1), do: "Critical"
  defp priority_label(2), do: "High"
  defp priority_label(3), do: "Medium"
  defp priority_label(4), do: "Low"
  defp priority_label(5), do: "Backlog"
  defp priority_label(_), do: "Unknown"

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
