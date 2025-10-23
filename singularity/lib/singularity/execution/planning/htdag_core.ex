defmodule Singularity.Execution.Planning.HTDAGCore do
  @moduledoc """
  Pure Elixir Hierarchical Task Directed Acyclic Graph (HTDAG) for autonomous task decomposition.

  Provides core data structures and algorithms for managing hierarchical task graphs
  with dependency resolution, status tracking, and complexity-based decomposition.
  Migrated from Gleam singularity/htdag.gleam based on Deep Agent 2025 research.

  ## Integration Points

  This module integrates with:
  - `Singularity.Execution.Planning.HTDAGExecutor` - Task execution (HTDAGExecutor.execute_task/2)
  - `Singularity.Code.FullRepoScanner` - Learning integration (FullRepoScanner.learn_from_execution/2)
  - `Singularity.Execution.Planning.HTDAGTracer` - Execution tracing (HTDAGTracer.trace_task_start/2)
  - `Singularity.LLM.Service` - Task decomposition (Service.call/3 for decomposition)
  - PostgreSQL table: `htdag_executions` (stores task execution history)

  ## Task Structure

  Tasks contain:
  - `id` - Unique identifier
  - `description` - What needs to be done
  - `task_type` - :goal | :milestone | :implementation
  - `depth` - Hierarchy depth (0 = root)
  - `parent_id` - Parent task ID (nil for root)
  - `children` - List of child task IDs
  - `dependencies` - List of dependency task IDs
  - `status` - :pending | :active | :blocked | :completed | :failed
  - `sparc_phase` - Optional SPARC phase
  - `estimated_complexity` - Complexity estimate (1.0-10.0)
  - `actual_complexity` - Actual complexity after completion
  - `code_files` - Related file paths
  - `acceptance_criteria` - Success criteria

  ## Usage

      # Create new DAG and add tasks
      dag = HTDAGCore.new("root-goal")
      task = HTDAGCore.create_goal_task("Build user auth", 0, nil)
      dag = HTDAGCore.add_task(dag, task)

      # Mark as completed
      dag = HTDAGCore.mark_completed(dag, task.id)
      # => %{root_id: "root-goal", tasks: %{...}, completed_tasks: ["goal-task-123"]}
  """

  @type task_type :: :goal | :milestone | :implementation
  @type task_status :: :pending | :active | :blocked | :completed | :failed
  @type sparc_phase ::
          :specification | :pseudocode | :architecture | :refinement | :completion_phase

  @type task :: %{
          id: String.t(),
          description: String.t(),
          task_type: task_type(),
          depth: non_neg_integer(),
          parent_id: String.t() | nil,
          children: [String.t()],
          dependencies: [String.t()],
          status: task_status(),
          sparc_phase: sparc_phase() | nil,
          estimated_complexity: float(),
          actual_complexity: float() | nil,
          code_files: [String.t()],
          acceptance_criteria: [String.t()]
        }

  @type htdag :: %{
          root_id: String.t(),
          tasks: %{String.t() => task()},
          dependency_graph: %{String.t() => [String.t()]},
          completed_tasks: [String.t()],
          failed_tasks: [String.t()]
        }

  @doc """
  Create a new empty HTDAG.
  """
  @spec new(String.t()) :: htdag()
  def new(root_id) do
    %{
      root_id: root_id,
      tasks: %{},
      dependency_graph: %{},
      completed_tasks: [],
      failed_tasks: []
    }
  end

  @doc """
  Add a task to the DAG.
  """
  @spec add_task(htdag(), task()) :: htdag()
  def add_task(dag, task) do
    tasks = Map.put(dag.tasks, task.id, task)

    # Update dependency graph
    dep_graph =
      case task.dependencies do
        [] -> dag.dependency_graph
        deps -> Map.put(dag.dependency_graph, task.id, deps)
      end

    %{dag | tasks: tasks, dependency_graph: dep_graph}
  end

  @doc """
  Check if a task is atomic (small enough to implement directly).
  """
  @spec is_atomic(task()) :: boolean()
  def is_atomic(task) do
    task.estimated_complexity < 5.0 and task.depth > 0
  end

  @doc """
  Mark task as in progress.
  """
  @spec mark_in_progress(htdag(), String.t()) :: htdag()
  def mark_in_progress(dag, task_id) do
    case Map.get(dag.tasks, task_id) do
      nil ->
        dag

      task ->
        updated_task = %{task | status: :active}
        tasks = Map.put(dag.tasks, task_id, updated_task)

        %{dag | tasks: tasks}
    end
  end

  @doc """
  Mark task as completed.
  """
  @spec mark_completed(htdag(), String.t()) :: htdag()
  def mark_completed(dag, task_id) do
    case Map.get(dag.tasks, task_id) do
      nil ->
        dag

      task ->
        updated_task = %{task | status: :completed}
        tasks = Map.put(dag.tasks, task_id, updated_task)
        completed = [task_id | dag.completed_tasks]

        %{dag | tasks: tasks, completed_tasks: completed}
    end
  end

  @doc """
  Mark task as failed.
  """
  @spec mark_failed(htdag(), String.t(), String.t()) :: htdag()
  def mark_failed(dag, task_id, _reason) do
    case Map.get(dag.tasks, task_id) do
      nil ->
        dag

      task ->
        updated_task = %{task | status: :failed}
        tasks = Map.put(dag.tasks, task_id, updated_task)
        failed = [task_id | dag.failed_tasks]

        %{dag | tasks: tasks, failed_tasks: failed}
    end
  end

  @doc """
  Get all tasks with no unmet dependencies (ready to execute).
  """
  @spec get_ready_tasks(htdag()) :: [task()]
  def get_ready_tasks(dag) do
    dag.tasks
    |> Enum.filter(fn {_id, task} ->
      task.status == :pending and are_dependencies_met(dag, task)
    end)
    |> Enum.map(fn {_id, task} -> task end)
  end

  @doc """
  Select the next task to execute based on priority.

  Priority: lowest depth first (top-level goals), then by complexity.
  """
  @spec select_next_task(htdag()) :: task() | nil
  def select_next_task(dag) do
    dag
    |> get_ready_tasks()
    |> Enum.sort_by(fn task ->
      {task.depth, task.estimated_complexity}
    end)
    |> List.first()
  end

  @doc """
  Count total tasks in DAG.
  """
  @spec count_tasks(htdag()) :: non_neg_integer()
  def count_tasks(dag) do
    map_size(dag.tasks)
  end

  @doc """
  Count completed tasks.
  """
  @spec count_completed(htdag()) :: non_neg_integer()
  def count_completed(dag) do
    length(dag.completed_tasks)
  end

  @doc """
  Get current active tasks.
  """
  @spec current_tasks(htdag()) :: [task()]
  def current_tasks(dag) do
    dag.tasks
    |> Enum.filter(fn {_id, task} -> task.status == :active end)
    |> Enum.map(fn {_id, task} -> task end)
  end

  @doc """
  Generate a unique task ID.
  """
  @spec generate_task_id(String.t()) :: String.t()
  def generate_task_id(prefix) do
    "#{prefix}-task-#{System.unique_integer([:positive, :monotonic])}"
  end

  @doc """
  Create a task from a goal description.
  """
  @spec create_goal_task(String.t(), non_neg_integer(), String.t() | nil) :: task()
  def create_goal_task(description, depth, parent_id) do
    %{
      id: generate_task_id("goal"),
      description: description,
      task_type: :goal,
      depth: depth,
      parent_id: parent_id,
      children: [],
      dependencies: [],
      status: :pending,
      sparc_phase: nil,
      estimated_complexity: 10.0,
      actual_complexity: nil,
      code_files: [],
      acceptance_criteria: []
    }
  end

  @doc """
  Decompose a task into subtasks if it's too complex.

  Returns updated DAG. In real implementation, this would call LLM to decompose.
  For now, marks task as needing decomposition.
  """
  @spec decompose_if_needed(htdag(), task(), non_neg_integer()) :: htdag()
  def decompose_if_needed(dag, task, max_depth) do
    cond do
      is_atomic(task) ->
        dag

      task.depth >= max_depth ->
        dag

      true ->
        # Task needs decomposition - mark as blocked
        updated_task = %{task | status: :blocked}
        tasks = Map.put(dag.tasks, task.id, updated_task)
        %{dag | tasks: tasks}
    end
  end

  ## Private Functions

  # Check if all dependencies for a task are completed
  defp are_dependencies_met(dag, task) do
    case task.dependencies do
      [] ->
        true

      deps ->
        Enum.all?(deps, fn dep_id ->
          dep_id in dag.completed_tasks
        end)
    end
  end
end
