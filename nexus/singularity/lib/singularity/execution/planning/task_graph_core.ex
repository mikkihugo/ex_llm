defmodule Singularity.Execution.Planning.TaskGraphCore do
  @moduledoc """
  Task Graph Core - Pure functional operations for task dependency graphs.

  Provides core algorithms for:
  - Task dependency resolution
  - Topological sorting
  - Task state management
  - Graph traversal operations
  """

  @type task_id :: String.t() | atom()
  @type task_status :: :pending | :in_progress | :completed | :failed
  @type task :: %{
          id: task_id(),
          dependencies: [task_id()],
          status: task_status(),
          data: map()
        }
  @type task_graph :: %{
          tasks: %{task_id() => task()},
          edges: %{task_id() => [task_id()]},
          name: String.t()
        }

  @doc """
  Create a new empty task graph.
  """
  @spec task_graph() :: task_graph()
  def task_graph do
    %{tasks: %{}, edges: %{}, name: ""}
  end

  @doc """
  Create a new task graph with a name.
  """
  @spec new(String.t()) :: task_graph()
  def new(name) do
    %{tasks: %{}, edges: %{}, name: name}
  end

  @doc """
  Add a task to the graph.
  """
  @spec add_task(task_graph(), task()) :: task_graph()
  def add_task(graph, task) do
    tasks = Map.put(graph.tasks, task.id, task)
    edges = Map.put(graph.edges, task.id, task.dependencies)
    %{graph | tasks: tasks, edges: edges}
  end

  @doc """
  Select the next task that can be executed (all dependencies completed).
  """
  @spec select_next_task(task_graph()) :: {:ok, task()} | :none
  def select_next_task(graph) do
    graph.tasks
    |> Enum.filter(fn {_id, task} ->
      task.status == :pending and dependencies_completed?(graph, task)
    end)
    # Prefer tasks with fewer deps
    |> Enum.sort_by(fn {_id, task} -> length(task.dependencies) end)
    |> case do
      [] -> :none
      [{_id, task} | _] -> {:ok, task}
    end
  end

  @doc """
  Mark a task as completed.
  """
  @spec mark_completed(task_graph(), task_id()) :: task_graph()
  def mark_completed(graph, task_id) do
    update_task_status(graph, task_id, :completed)
  end

  @doc """
  Mark a task as failed.
  """
  @spec mark_failed(task_graph(), task_id(), String.t()) :: task_graph()
  def mark_failed(graph, task_id, _reason) do
    update_task_status(graph, task_id, :failed)
  end

  @doc """
  Mark a task as in progress.
  """
  @spec mark_in_progress(task_graph(), task_id()) :: task_graph()
  def mark_in_progress(graph, task_id) do
    update_task_status(graph, task_id, :in_progress)
  end

  @doc """
  Count total tasks in the graph.
  """
  @spec count_tasks(task_graph()) :: non_neg_integer()
  def count_tasks(graph) do
    map_size(graph.tasks)
  end

  @doc """
  Count total tasks in the graph.
  """
  @spec count_tasks(task_graph()) :: non_neg_integer()
  def count_tasks(graph) do
    map_size(graph.tasks)
  end

  @doc """
  Count completed tasks in the graph.
  """
  @spec count_completed(task_graph()) :: non_neg_integer()
  def count_completed(graph) do
    graph.tasks
    |> Enum.count(fn {_id, task} -> task.status == :completed end)
  end

  @doc """
  Get currently executing tasks.
  """
  @spec current_tasks(task_graph()) :: [task()]
  def current_tasks(graph) do
    graph.tasks
    |> Enum.filter(fn {_id, task} -> task.status == :in_progress end)
    |> Enum.map(fn {_id, task} -> task end)
  end

  # Private helpers

  defp update_task_status(graph, task_id, status) do
    case Map.get(graph.tasks, task_id) do
      nil ->
        graph

      task ->
        updated_task = %{task | status: status}
        updated_tasks = Map.put(graph.tasks, task_id, updated_task)
        %{graph | tasks: updated_tasks}
    end
  end

  defp dependencies_completed?(graph, task) do
    Enum.all?(task.dependencies, fn dep_id ->
      case Map.get(graph.tasks, dep_id) do
        nil -> false
        dep_task -> dep_task.status == :completed
      end
    end)
  end
end
