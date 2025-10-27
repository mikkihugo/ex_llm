defmodule Singularity.Execution.TodoStore do
  @moduledoc """
  TodoStore - Storage and retrieval for todos with semantic search.

  Provides CRUD operations, semantic search, dependency resolution,
  and prioritization for swarm-based task execution.

  ## Usage

  ### Create
  ```elixir
  {:ok, todo} = TodoStore.create(%{
    title: "Implement user authentication",
    description: "Add JWT-based auth with refresh tokens",
    priority: 2,
    complexity: "medium",
    tags: ["backend", "security"]
  })
  ```

  ### Semantic Search
  ```elixir
  {:ok, todos} = TodoStore.search("implement async worker pattern", limit: 5)
  ```

  ### Get Next Work (Prioritized)
  ```elixir
  {:ok, todo} = TodoStore.get_next_available()
  ```

  ### Dependencies
  ```elixir
  {:ok, ready_todos} = TodoStore.get_ready_todos()  # No blocking dependencies
  ```
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Execution.Todo
  alias Singularity.CodeGeneration.Implementations.EmbeddingGenerator

  require Logger

  # ===========================
  # CRUD Operations
  # ===========================

  @doc """
  Create a new todo with optional embedding generation.
  """
  def create(attrs) do
    with {:ok, todo} <- create_todo(attrs),
         {:ok, todo_with_embedding} <- maybe_generate_embedding(todo) do
      Logger.info("Created todo", todo_id: todo.id, title: todo.title)

      # Check if this todo is immediately ready and notify swarm
      if todo_ready?(todo_with_embedding) do
        notify_ready_todos([todo_with_embedding])
      end

      {:ok, todo_with_embedding}
    end
  end

  @doc """
  Get a todo by ID.
  """
  def get(id) when is_binary(id) do
    case Repo.get(Todo, id) do
      nil -> {:error, :not_found}
      todo -> {:ok, todo}
    end
  end

  @doc """
  Update a todo.
  """
  def update(todo, attrs) do
    todo
    |> Todo.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a todo.
  """
  def delete(todo) do
    Repo.delete(todo)
  end

  @doc """
  List all todos with optional filters.
  """
  def list(opts \\ []) do
    Todo
    |> apply_filters(opts)
    |> apply_order(opts)
    |> apply_limit(opts)
    |> Repo.all()
  end

  # ===========================
  # Status Management
  # ===========================

  @doc """
  Assign a todo to an agent.
  """
  def assign(todo, agent_id) do
    todo
    |> Todo.status_changeset(%{
      status: "assigned",
      assigned_agent_id: agent_id
    })
    |> Repo.update()
  end

  @doc """
  Mark todo as started.
  """
  def start(todo) do
    todo
    |> Todo.status_changeset(%{
      status: "in_progress",
      started_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Mark todo as completed with result.
  """
  def complete(todo, result) do
    changeset = todo |> Todo.complete_changeset(%{result: result})

    case Repo.update(changeset) do
      {:ok, completed_todo} ->
        Logger.info("Completed todo", todo_id: todo.id, title: todo.title)

        # Check if completing this todo makes others ready
        case get_todos_unblocked_by(completed_todo) do
          {:ok, newly_ready_todos} when length(newly_ready_todos) > 0 ->
            notify_ready_todos(newly_ready_todos)

            Logger.info("Unblocked todos are now ready",
              completed_todo_id: todo.id,
              newly_ready_count: length(newly_ready_todos)
            )

          _ ->
            :ok
        end

        {:ok, completed_todo}

      error ->
        error
    end
  end

  @doc """
  Mark todo as failed with error message.
  """
  def fail(todo, error_message) do
    changeset = Todo.fail_changeset(todo, %{error_message: error_message})

    case Repo.update(changeset) do
      {:ok, updated_todo} ->
        # Check if we should retry
        if should_retry?(updated_todo) do
          retry(updated_todo)
        else
          {:ok, updated_todo}
        end

      error ->
        error
    end
  end

  @doc """
  Retry a failed todo.
  """
  def retry(todo) do
    if should_retry?(todo) do
      todo
      |> Todo.retry_changeset()
      |> Repo.update()
    else
      {:error, :max_retries_reached}
    end
  end

  @doc """
  Mark todo as blocked.
  """
  def block(todo, reason) do
    todo
    |> Todo.status_changeset(%{
      status: "blocked",
      context: Map.put(todo.context, "blocked_reason", reason)
    })
    |> Repo.update()
  end

  # ===========================
  # Semantic Search
  # ===========================

  @doc """
  Search for similar todos using semantic search.

  ## Options
  - `:limit` - Maximum number of results (default: 10)
  - `:status` - Filter by status
  - `:min_similarity` - Minimum similarity score (0.0-1.0, default: 0.7)
  """
  def search(query, opts \\ []) do
    with {:ok, embedding} <- EmbeddingGenerator.embed(query) do
      limit = Keyword.get(opts, :limit, 10)
      min_similarity = Keyword.get(opts, :min_similarity, 0.7)

      results =
        Todo
        |> where([t], fragment("1 - (? <=> ?) > ?", t.embedding, ^embedding, ^min_similarity))
        |> apply_filters(opts)
        |> order_by([t], fragment("? <=> ?", t.embedding, ^embedding))
        |> limit(^limit)
        |> Repo.all()
        |> Enum.map(fn todo ->
          similarity = 1.0 - cosine_distance(todo.embedding, embedding)
          %{todo: todo, similarity: similarity}
        end)

      {:ok, results}
    end
  end

  @doc """
  Find related todos (similar by embedding).
  """
  def find_related(todo, opts \\ []) do
    if todo.embedding do
      limit = Keyword.get(opts, :limit, 5)

      results =
        Todo
        |> where([t], t.id != ^todo.id)
        |> where([t], not is_nil(t.embedding))
        |> order_by([t], fragment("? <=> ?", t.embedding, ^todo.embedding))
        |> limit(^limit)
        |> Repo.all()

      {:ok, results}
    else
      {:ok, []}
    end
  end

  # ===========================
  # Work Prioritization
  # ===========================

  @doc """
  Get the next available todo for execution.

  Prioritizes by:
  1. Priority (lower number = higher priority)
  2. No blocking dependencies
  3. Not currently assigned
  4. Oldest first (created_at)
  """
  def get_next_available(opts \\ []) do
    complexity = Keyword.get(opts, :complexity)

    query =
      Todo
      |> where([t], t.status == "pending")
      |> order_by([t], asc: t.priority, asc: t.inserted_at)

    query =
      if complexity do
        where(query, [t], t.complexity == ^complexity)
      else
        query
      end

    case query |> limit(10) |> Repo.all() |> filter_ready_todos() |> List.first() do
      nil -> {:error, :no_available_todos}
      todo -> {:ok, todo}
    end
  end

  @doc """
  Get all todos that are ready to execute (no blocking dependencies).
  """
  def get_ready_todos(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    todos =
      Todo
      |> where([t], t.status == "pending")
      |> order_by([t], asc: t.priority, asc: t.inserted_at)
      |> limit(^limit)
      |> Repo.all()
      |> filter_ready_todos()

    {:ok, todos}
  end

  @doc """
  Get todos by status with optional prioritization.
  """
  def get_by_status(status, opts \\ []) do
    Todo
    |> where([t], t.status == ^status)
    |> apply_order(opts)
    |> apply_limit(opts)
    |> Repo.all()
  end

  # ===========================
  # Dependency Management
  # ===========================

  @doc """
  Check if a todo's dependencies are satisfied.
  """
  def dependencies_satisfied?(todo) do
    if Enum.empty?(todo.depends_on_ids) do
      true
    else
      completed_count =
        Todo
        |> where([t], t.id in ^todo.depends_on_ids)
        |> where([t], t.status == "completed")
        |> Repo.aggregate(:count)

      completed_count == length(todo.depends_on_ids)
    end
  end

  @doc """
  Get all dependencies for a todo.
  """
  def get_dependencies(todo) do
    if Enum.empty?(todo.depends_on_ids) do
      {:ok, []}
    else
      deps =
        Todo
        |> where([t], t.id in ^todo.depends_on_ids)
        |> Repo.all()

      {:ok, deps}
    end
  end

  @doc """
  Get all todos that depend on this todo.
  """
  def get_dependents(todo) do
    dependents =
      Todo
      |> where([t], fragment("? = ANY(?)", ^todo.id, t.depends_on_ids))
      |> Repo.all()

    {:ok, dependents}
  end

  # ===========================
  # Statistics
  # ===========================

  @doc """
  Get todo statistics.
  """
  def get_stats do
    %{
      total: count_by_status(nil),
      by_status: %{
        pending: count_by_status("pending"),
        assigned: count_by_status("assigned"),
        in_progress: count_by_status("in_progress"),
        completed: count_by_status("completed"),
        failed: count_by_status("failed"),
        blocked: count_by_status("blocked")
      },
      by_priority: %{
        critical: count_by_priority(1),
        high: count_by_priority(2),
        medium: count_by_priority(3),
        low: count_by_priority(4),
        backlog: count_by_priority(5)
      },
      by_complexity: %{
        simple: count_by_complexity("simple"),
        medium: count_by_complexity("medium"),
        complex: count_by_complexity("complex")
      }
    }
  end

  @doc """
  List recent todos ordered by insertion time.
  """
  def list_recent(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    Todo
    |> order_by([t], desc: t.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  # ===========================
  # Real-time Notifications (Mesos Resource Offers)
  # ===========================

  @doc """
  Send NOTIFY when todos become ready for execution.
  This enables real-time swarm coordination instead of polling.
  """
  def notify_ready_todos(todos) when is_list(todos) do
    if length(todos) > 0 do
      # Send general notification that todos are ready (not specific IDs for efficiency)
      case Pgflow.Notifications.send_with_notify(
             "todo_ready",
             %{type: "todos_ready", count: length(todos)},
             Singularity.Repo
           ) do
        {:ok, message_id} ->
          Logger.info("Notified swarm of ready todos",
            count: length(todos),
            message_id: message_id
          )

          {:ok, message_id}

        {:error, reason} ->
          Logger.warning("Failed to notify swarm of ready todos",
            count: length(todos),
            error: inspect(reason)
          )

          {:error, reason}
      end
    else
      {:ok, nil}
    end
  end

  # ===========================
  # Private Helpers
  # ===========================

  defp create_todo(attrs) do
    attrs
    |> Todo.create_changeset()
    |> Repo.insert()
  end

  defp maybe_generate_embedding(todo) do
    text = "#{todo.title} #{todo.description || ""}"

    case EmbeddingGenerator.embed(text) do
      {:ok, embedding} ->
        todo
        |> Ecto.Changeset.change(embedding: embedding)
        |> Repo.update()

      {:error, reason} ->
        Logger.warning("Failed to generate embedding for todo",
          todo_id: todo.id,
          reason: inspect(reason)
        )

        {:ok, todo}
    end
  end

  defp filter_ready_todos(todos) do
    Enum.filter(todos, &dependencies_satisfied?/1)
  end

  defp should_retry?(todo) do
    todo.retry_count < todo.max_retries
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:status, status}, q -> where(q, [t], t.status == ^status)
      {:priority, priority}, q -> where(q, [t], t.priority == ^priority)
      {:complexity, complexity}, q -> where(q, [t], t.complexity == ^complexity)
      {:assigned_agent_id, agent_id}, q -> where(q, [t], t.assigned_agent_id == ^agent_id)
      {:tags, tags}, q when is_list(tags) -> where(q, [t], fragment("? && ?", t.tags, ^tags))
      _, q -> q
    end)
  end

  defp apply_order(query, opts) do
    case Keyword.get(opts, :order_by) do
      :priority -> order_by(query, [t], asc: t.priority, asc: t.inserted_at)
      :created -> order_by(query, [t], desc: t.inserted_at)
      :updated -> order_by(query, [t], desc: t.updated_at)
      _ -> query
    end
  end

  defp apply_limit(query, opts) do
    case Keyword.get(opts, :limit) do
      nil -> query
      limit -> limit(query, ^limit)
    end
  end

  defp cosine_distance(nil, _), do: 1.0
  defp cosine_distance(_, nil), do: 1.0

  defp cosine_distance(vec1, vec2) when is_list(vec1) and is_list(vec2) do
    # Calculate cosine distance
    dot_product = Enum.zip(vec1, vec2) |> Enum.map(fn {a, b} -> a * b end) |> Enum.sum()
    mag1 = :math.sqrt(Enum.map(vec1, &(&1 * &1)) |> Enum.sum())
    mag2 = :math.sqrt(Enum.map(vec2, &(&1 * &1)) |> Enum.sum())

    if mag1 == 0.0 or mag2 == 0.0 do
      1.0
    else
      1.0 - dot_product / (mag1 * mag2)
    end
  end

  defp cosine_distance(_vec1, _vec2), do: 1.0

  defp count_by_status(nil), do: Repo.aggregate(Todo, :count)
  defp count_by_status(status), do: Repo.aggregate(where(Todo, status: ^status), :count)

  defp count_by_priority(priority), do: Repo.aggregate(where(Todo, priority: ^priority), :count)

  defp count_by_complexity(complexity),
    do: Repo.aggregate(where(Todo, complexity: ^complexity), :count)

  # ===========================
  # Notification Helpers
  # ===========================

  defp todo_ready?(todo) do
    todo.status == "pending" && dependencies_satisfied?(todo)
  end

  @doc """
  Get todos that become ready when the given todo is completed.
  Used for dependency chain notifications.
  """
  def get_todos_unblocked_by(completed_todo) do
    # Find todos that depend on the completed todo
    dependent_todos =
      Todo
      |> where([t], t.status == "pending")
      |> where([t], fragment("? = ANY(?)", ^completed_todo.id, t.depends_on))
      |> Repo.all()
      |> Enum.filter(&dependencies_satisfied?/1)

    {:ok, dependent_todos}
  end
end
