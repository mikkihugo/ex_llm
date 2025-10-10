defmodule Singularity.Todos.TodoWorkerAgent do
  @moduledoc """
  TodoWorkerAgent - Individual worker that executes a single todo.

  ## Execution Flow

  1. Assigned a todo by TodoSwarmCoordinator
  2. Analyzes todo requirements (title, description, context)
  3. Selects appropriate complexity level for LLM
  4. Executes the task using LLM.Service
  5. Reports result back to coordinator
  6. Updates todo status in TodoStore

  ## Agent Lifecycle

  spawn → execute → complete/fail → terminate

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

  alias Singularity.Todos.{TodoStore, TodoSwarmCoordinator}
  alias Singularity.LLM.Service, as: LLMService

  @execution_timeout_ms 300_000  # 5 minutes

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
      # Determine complexity for LLM call
      complexity = map_complexity(todo.complexity)

      # Build task prompt
      prompt = build_task_prompt(todo)

      # Call LLM via NATS
      Logger.debug("Calling LLM service",
        todo_id: todo.id,
        complexity: complexity
      )

      case LLMService.call_with_prompt(complexity, prompt, task_type: :general) do
        {:ok, response} ->
          Logger.info("LLM call succeeded",
            todo_id: todo.id,
            response_length: String.length(response)
          )

          {:ok, %{
            output: response,
            completed_by: "TodoWorkerAgent",
            completed_at: DateTime.utc_now()
          }}

        {:error, reason} ->
          Logger.error("LLM call failed",
            todo_id: todo.id,
            reason: inspect(reason)
          )

          {:error, "LLM service failed: #{inspect(reason)}"}
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

  defp handle_success(state, result) do
    todo = state.todo

    Logger.info("Todo completed successfully",
      worker_id: state.worker_id,
      todo_id: todo.id
    )

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

  defp build_task_prompt(todo) do
    context_str =
      if map_size(todo.context) > 0 do
        "\n\n**Context:**\n#{Jason.encode!(todo.context, pretty: true)}"
      else
        ""
      end

    tags_str =
      if length(todo.tags) > 0 do
        "\n\n**Tags:** #{Enum.join(todo.tags, ", ")}"
      else
        ""
      end

    """
    # Task: #{todo.title}

    #{todo.description || "No description provided"}#{context_str}#{tags_str}

    **Priority:** #{priority_label(todo.priority)}
    **Complexity:** #{todo.complexity}

    Please complete this task and provide:
    1. A summary of what you did
    2. Any relevant code, commands, or outputs
    3. Any issues encountered
    4. Next steps or recommendations (if applicable)

    Be concise but thorough. Focus on actionable results.
    """
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
