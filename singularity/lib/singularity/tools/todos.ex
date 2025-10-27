defmodule Singularity.Tools.Todos do
  @moduledoc """
  MCP Tool for TODO management.

  Allows AI assistants (Claude Desktop, Cursor, etc.) to create and query todos
  that are then solved by the swarm of autonomous agents.

  ## MCP Tools

  - `create_todo` - Create a new todo for the swarm to solve
  - `list_todos` - List todos with filters
  - `search_todos` - Semantic search for similar todos
  - `get_todo_status` - Check status of a specific todo
  - `get_swarm_status` - Check swarm coordinator status
  """

  @behaviour Singularity.Tools.Behaviour

  alias Singularity.Execution.Todos.{TodoStore, TodoSwarmCoordinator}

  require Logger

  # ===========================
  # Behaviour Implementation
  # ===========================

  @impl true
  def tool_definitions do
    [
      %{
        name: "create_todo",
        description: """
        Create a new todo that will be solved by the autonomous agent swarm.

        The swarm coordinator will automatically assign this todo to an available worker agent
        that will use LLM capabilities to complete the task.

        Use this for:
        - Code generation tasks
        - Research and analysis
        - Documentation writing
        - Bug investigation
        - Any task that can be described in natural language

        Priority levels:
        - 1: Critical (do immediately)
        - 2: High (do today)
        - 3: Medium (default, do this week)
        - 4: Low (do when possible)
        - 5: Backlog (someday/maybe)

        Complexity levels:
        - simple: < 5 minutes, single LLM call
        - medium: 5-30 minutes, multiple steps (default)
        - complex: > 30 minutes, multi-agent coordination
        """,
        input_schema: %{
          type: "object",
          properties: %{
            title: %{
              type: "string",
              description: "Short descriptive title for the todo (required, max 500 chars)"
            },
            description: %{
              type: "string",
              description:
                "Detailed description of what needs to be done (optional, max 5000 chars)"
            },
            priority: %{
              type: "integer",
              description: "Priority level (1-5, default 3)",
              minimum: 1,
              maximum: 5
            },
            complexity: %{
              type: "string",
              enum: ["simple", "medium", "complex"],
              description: "Task complexity (default: medium)"
            },
            tags: %{
              type: "array",
              items: %{type: "string"},
              description: "Tags for categorization (e.g., ['backend', 'security'])"
            },
            context: %{
              type: "object",
              description: "Additional context as key-value pairs"
            }
          },
          required: ["title"]
        }
      },
      %{
        name: "list_todos",
        description: """
        List todos with optional filters.

        Useful for checking what todos exist, their statuses, and progress.
        """,
        input_schema: %{
          type: "object",
          properties: %{
            status: %{
              type: "string",
              enum: [
                "pending",
                "assigned",
                "in_progress",
                "completed",
                "failed",
                "blocked",
                "cancelled"
              ],
              description: "Filter by status"
            },
            priority: %{
              type: "integer",
              minimum: 1,
              maximum: 5,
              description: "Filter by priority level"
            },
            complexity: %{
              type: "string",
              enum: ["simple", "medium", "complex"],
              description: "Filter by complexity"
            },
            limit: %{
              type: "integer",
              description: "Maximum number of results (default 20)",
              minimum: 1,
              maximum: 100
            }
          }
        }
      },
      %{
        name: "search_todos",
        description: """
        Search for todos using semantic similarity.

        This uses vector embeddings to find todos that are semantically similar to your query,
        even if they don't contain the exact keywords.

        Examples:
        - "implement authentication" will find related auth tasks
        - "fix slow database queries" will find performance-related todos
        - "add error handling" will find todos about error handling
        """,
        input_schema: %{
          type: "object",
          properties: %{
            query: %{
              type: "string",
              description: "Natural language search query (required)"
            },
            limit: %{
              type: "integer",
              description: "Maximum number of results (default 10)",
              minimum: 1,
              maximum: 50
            },
            min_similarity: %{
              type: "number",
              description: "Minimum similarity score (0.0-1.0, default 0.7)",
              minimum: 0.0,
              maximum: 1.0
            }
          },
          required: ["query"]
        }
      },
      %{
        name: "get_todo_status",
        description: """
        Get detailed status of a specific todo by ID.

        Returns all information about the todo including:
        - Current status
        - Assigned agent (if any)
        - Result (if completed)
        - Error message (if failed)
        - Timing information
        """,
        input_schema: %{
          type: "object",
          properties: %{
            id: %{
              type: "string",
              description: "Todo UUID (required)"
            }
          },
          required: ["id"]
        }
      },
      %{
        name: "get_swarm_status",
        description: """
        Get status of the todo swarm coordinator.

        Shows:
        - Number of active workers
        - Maximum worker capacity
        - Completed todo count
        - Failed todo count
        - Currently running workers and their assigned todos
        """,
        input_schema: %{
          type: "object",
          properties: {}
        }
      }
    ]
  end

  @impl true
  def execute_tool("create_todo", params) do
    Logger.info("Creating todo via MCP", params: params)

    case TodoStore.create(params) do
      {:ok, todo} ->
        # Trigger swarm to pick up the new todo if it's high priority
        if todo.priority <= 2 do
          TodoSwarmCoordinator.spawn_swarm(swarm_size: 1)
        end

        {:ok,
         %{
           success: true,
           todo: serialize_todo(todo),
           message:
             "Todo created successfully. The swarm coordinator will assign it to an agent shortly."
         }}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)

        {:error,
         %{
           success: false,
           message: "Validation failed",
           errors: errors
         }}

      {:error, reason} ->
        {:error,
         %{
           success: false,
           message: "Failed to create todo: #{inspect(reason)}"
         }}
    end
  end

  @impl true
  def execute_tool("list_todos", params) do
    _opts = build_list_opts(params)
    todos = TodoStore.list(_opts)

    {:ok,
     %{
       success: true,
       todos: Enum.map(todos, &serialize_todo/1),
       count: length(todos)
     }}
  end

  @impl true
  def execute_tool("search_todos", %{"query" => query} = params) do
    _opts = build_search_opts(params)

    case TodoStore.search(query, _opts) do
      {:ok, results} ->
        {:ok,
         %{
           success: true,
           results:
             Enum.map(results, fn %{todo: todo, similarity: sim} ->
               todo
               |> serialize_todo()
               |> Map.put(:similarity, Float.round(sim, 3))
             end),
           count: length(results)
         }}

      {:error, reason} ->
        {:error,
         %{
           success: false,
           message: "Search failed: #{inspect(reason)}"
         }}
    end
  end

  @impl true
  def execute_tool("search_todos", _params) do
    {:error,
     %{
       success: false,
       message: "Missing required parameter: query"
     }}
  end

  @impl true
  def execute_tool("get_todo_status", %{"id" => id}) do
    case TodoStore.get(id) do
      {:ok, todo} ->
        {:ok,
         %{
           success: true,
           todo: serialize_todo(todo)
         }}

      {:error, :not_found} ->
        {:error,
         %{
           success: false,
           message: "Todo not found with ID: #{id}"
         }}
    end
  end

  @impl true
  def execute_tool("get_todo_status", _params) do
    {:error,
     %{
       success: false,
       message: "Missing required parameter: id"
     }}
  end

  @impl true
  def execute_tool("get_swarm_status", _params) do
    status = TodoSwarmCoordinator.get_status()

    {:ok,
     %{
       success: true,
       status: status
     }}
  end

  @impl true
  def execute_tool(tool_name, _params) do
    {:error,
     %{
       success: false,
       message: "Unknown tool: #{tool_name}"
     }}
  end

  # ===========================
  # Private Helpers
  # ===========================

  defp serialize_todo(todo) do
    %{
      id: todo.id,
      title: todo.title,
      description: todo.description,
      status: todo.status,
      priority: todo.priority,
      priority_label: priority_label(todo.priority),
      complexity: todo.complexity,
      assigned_agent_id: todo.assigned_agent_id,
      tags: todo.tags,
      context: todo.context,
      result: todo.result,
      error_message: todo.error_message,
      started_at: todo.started_at,
      completed_at: todo.completed_at,
      failed_at: todo.failed_at,
      actual_duration_seconds: todo.actual_duration_seconds,
      retry_count: todo.retry_count,
      max_retries: todo.max_retries,
      inserted_at: todo.inserted_at,
      updated_at: todo.updated_at
    }
  end

  defp priority_label(1), do: "Critical"
  defp priority_label(2), do: "High"
  defp priority_label(3), do: "Medium"
  defp priority_label(4), do: "Low"
  defp priority_label(5), do: "Backlog"
  defp priority_label(_), do: "Unknown"

  defp build_list_opts(params) do
    []
    |> maybe_add_opt(params, "status", :status)
    |> maybe_add_opt(params, "priority", :priority)
    |> maybe_add_opt(params, "complexity", :complexity)
    |> maybe_add_opt(params, "limit", :limit)
    |> Keyword.put_new(:limit, 20)
  end

  defp build_search_opts(params) do
    []
    |> maybe_add_opt(params, "limit", :limit)
    |> maybe_add_opt(params, "min_similarity", :min_similarity)
    |> Keyword.put_new(:limit, 10)
  end

  defp maybe_add_opt(_opts, params, key, opt_key) do
    case Map.get(params, key) do
      nil -> _opts
      value -> Keyword.put(opts, opt_key, value)
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} ->
      Enum.reduce(_opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
