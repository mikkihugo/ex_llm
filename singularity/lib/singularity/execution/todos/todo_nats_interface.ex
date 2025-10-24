defmodule Singularity.Execution.Todos.TodoNatsInterface do
  @moduledoc """
  NATS Interface for TODO management system.

  ## NATS Subjects

  - `todos.create` - Create a new todo
  - `todos.get` - Get todo by ID
  - `todos.list` - List todos with filters
  - `todos.search` - Semantic search for todos
  - `todos.update` - Update a todo
  - `todos.delete` - Delete a todo
  - `todos.assign` - Assign todo to agent
  - `todos.complete` - Mark todo as completed
  - `todos.fail` - Mark todo as failed
  - `todos.swarm.spawn` - Trigger swarm spawning
  - `todos.swarm.status` - Get swarm status
  - `todos.stats` - Get todo statistics

  ## Message Format

  ### Create Todo
  ```json
  {
    "title": "Implement user authentication",
    "description": "Add JWT-based auth",
    "priority": 2,
    "complexity": "medium",
    "tags": ["backend", "security"],
    "context": {"framework": "phoenix"}
  }
  ```

  ### Response Format
  Success:
  ```json
  {
    "status": "ok",
    "id": "uuid-here",
    "todo": {...}
  }
  ```

  Error:
  ```json
  {
    "status": "error",
    "message": "Error description",
    "code": "ERROR_CODE"
  }
  ```
  """

  use GenServer
  require Logger

  alias Singularity.Execution.Todos.{TodoStore, TodoSwarmCoordinator}

  @subjects %{
    create: "planning.todo.create",
    get: "planning.todo.get",
    list: "planning.todo.list",
    search: "planning.todo.search",
    update: "planning.todo.update",
    delete: "planning.todo.delete",
    assign: "planning.todo.assign",
    complete: "planning.todo.complete",
    fail: "planning.todo.fail",
    swarm_spawn: "planning.todo.swarm.spawn",
    swarm_status: "planning.todo.swarm.status",
    stats: "planning.todo.stats"
  }

  # ===========================
  # Client API
  # ===========================

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # ===========================
  # Server Callbacks
  # ===========================

  @impl true
  def init(:ok) do
    # Use Singularity.NatsClient for NATS operations
    # Subscribe to all todo subjects
    Enum.each(@subjects, fn {_key, subject} ->
      case Singularity.NATS.Client.subscribe(subject) do
        :ok -> Logger.info("TodoNatsInterface subscribed to: #{subject}")
        {:error, reason} -> Logger.error("Failed to subscribe to #{subject}: #{reason}")
      end
    end)

    {:ok, %{}}
  end

  @impl true
  def handle_info({:msg, %{topic: topic, body: body, reply_to: reply_to}}, state) do
    Logger.debug("TodoNatsInterface received message",
      topic: topic,
      body_size: byte_size(body)
    )

    response = handle_message(topic, body)

    # Send reply if reply_to is present
    if reply_to do
      Singularity.NATS.Client.publish(reply_to, Jason.encode!(response))
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warning("TodoNatsInterface received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ===========================
  # Message Handlers
  # ===========================

  defp handle_message(_topic, body) when byte_size(body) == 0 do
    error_response("Empty message body", "EMPTY_BODY")
  end

  defp handle_message(topic, body) do
    case Jason.decode(body) do
      {:ok, attrs} when is_map(attrs) ->
        route_message(topic, attrs)

      {:ok, _} ->
        error_response("Message body must be a JSON object", "INVALID_STRUCTURE")

      {:error, reason} ->
        error_response("Invalid JSON: #{inspect(reason)}", "JSON_DECODE_ERROR")
    end
  end

  # Create todo
  defp route_message("planning.todo.create", attrs) do
    case TodoStore.create(attrs) do
      {:ok, todo} ->
        success_response(%{
          id: todo.id,
          todo: serialize_todo(todo),
          message: "Todo created successfully"
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        error_response("Validation failed", "VALIDATION_ERROR", %{
          errors: format_changeset_errors(changeset)
        })

      {:error, reason} ->
        error_response(inspect(reason), "CREATE_FAILED")
    end
  end

  # Get todo
  defp route_message("planning.todo.get", %{"id" => id}) do
    case TodoStore.get(id) do
      {:ok, todo} ->
        success_response(%{todo: serialize_todo(todo)})

      {:error, :not_found} ->
        error_response("Todo not found", "NOT_FOUND")
    end
  end

  defp route_message("planning.todo.get", _) do
    error_response("Missing required field: id", "MISSING_FIELD")
  end

  # List todos
  defp route_message("planning.todo.list", attrs) do
    opts = build_list_opts(attrs)
    todos = TodoStore.list(opts)

    success_response(%{
      todos: Enum.map(todos, &serialize_todo/1),
      count: length(todos)
    })
  end

  # Search todos
  defp route_message("planning.todo.search", %{"query" => query} = attrs) do
    opts = Map.take(attrs, ["limit", "status", "min_similarity"]) |> Map.to_list()

    case TodoStore.search(query, opts) do
      {:ok, results} ->
        success_response(%{
          results:
            Enum.map(results, fn %{todo: todo, similarity: sim} ->
              Map.put(serialize_todo(todo), :similarity, sim)
            end),
          count: length(results)
        })

      {:error, reason} ->
        error_response(inspect(reason), "SEARCH_FAILED")
    end
  end

  defp route_message("planning.todo.search", _) do
    error_response("Missing required field: query", "MISSING_FIELD")
  end

  # Complete todo
  defp route_message("planning.todo.complete", %{"id" => id, "result" => result}) do
    with {:ok, todo} <- TodoStore.get(id),
         {:ok, updated_todo} <- TodoStore.complete(todo, result) do
      success_response(%{
        todo: serialize_todo(updated_todo),
        message: "Todo completed successfully"
      })
    else
      {:error, :not_found} ->
        error_response("Todo not found", "NOT_FOUND")

      {:error, reason} ->
        error_response(inspect(reason), "COMPLETE_FAILED")
    end
  end

  defp route_message("planning.todo.complete", _) do
    error_response("Missing required fields: id, result", "MISSING_FIELD")
  end

  # Fail todo
  defp route_message("planning.todo.fail", %{"id" => id, "error_message" => error_msg}) do
    with {:ok, todo} <- TodoStore.get(id),
         {:ok, updated_todo} <- TodoStore.fail(todo, error_msg) do
      success_response(%{
        todo: serialize_todo(updated_todo),
        message: "Todo marked as failed"
      })
    else
      {:error, :not_found} ->
        error_response("Todo not found", "NOT_FOUND")

      {:error, reason} ->
        error_response(inspect(reason), "FAIL_FAILED")
    end
  end

  defp route_message("planning.todo.fail", _) do
    error_response("Missing required fields: id, error_message", "MISSING_FIELD")
  end

  # Spawn swarm
  defp route_message("planning.todo.swarm.spawn", attrs) do
    opts = build_swarm_opts(attrs)
    TodoSwarmCoordinator.spawn_swarm(opts)

    success_response(%{message: "Swarm spawned"})
  end

  # Swarm status
  defp route_message("planning.todo.swarm.status", _attrs) do
    status = TodoSwarmCoordinator.get_status()
    success_response(status)
  end

  # Statistics
  defp route_message("planning.todo.stats", _attrs) do
    stats = TodoStore.get_stats()
    success_response(stats)
  end

  # Unknown subject
  defp route_message(topic, _attrs) do
    Logger.warning("Unknown NATS subject: #{topic}")

    error_response("Unknown subject: #{topic}", "UNKNOWN_SUBJECT", %{
      available_subjects: Map.values(@subjects)
    })
  end

  # ===========================
  # Private Helpers
  # ===========================

  defp success_response(data) do
    Map.put(data, :status, "ok")
  end

  defp error_response(message, code, extra \\ %{}) do
    %{
      status: "error",
      message: message,
      code: code
    }
    |> Map.merge(extra)
  end

  defp serialize_todo(todo) do
    %{
      id: todo.id,
      title: todo.title,
      description: todo.description,
      status: todo.status,
      priority: todo.priority,
      complexity: todo.complexity,
      assigned_agent_id: todo.assigned_agent_id,
      parent_todo_id: todo.parent_todo_id,
      depends_on_ids: todo.depends_on_ids,
      tags: todo.tags,
      context: todo.context,
      result: todo.result,
      error_message: todo.error_message,
      started_at: todo.started_at,
      completed_at: todo.completed_at,
      failed_at: todo.failed_at,
      estimated_duration_seconds: todo.estimated_duration_seconds,
      actual_duration_seconds: todo.actual_duration_seconds,
      retry_count: todo.retry_count,
      max_retries: todo.max_retries,
      inserted_at: todo.inserted_at,
      updated_at: todo.updated_at
    }
  end

  defp build_list_opts(attrs) do
    []
    |> maybe_add_opt(attrs, "status", :status)
    |> maybe_add_opt(attrs, "priority", :priority)
    |> maybe_add_opt(attrs, "complexity", :complexity)
    |> maybe_add_opt(attrs, "assigned_agent_id", :assigned_agent_id)
    |> maybe_add_opt(attrs, "tags", :tags)
    |> maybe_add_opt(attrs, "order_by", :order_by, &String.to_atom/1)
    |> maybe_add_opt(attrs, "limit", :limit)
  end

  defp build_swarm_opts(attrs) do
    []
    |> maybe_add_opt(attrs, "swarm_size", :swarm_size)
    |> maybe_add_opt(attrs, "complexity", :complexity)
  end

  defp maybe_add_opt(opts, attrs, key, opt_key, transform \\ & &1) do
    case Map.get(attrs, key) do
      nil -> opts
      value -> Keyword.put(opts, opt_key, transform.(value))
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
