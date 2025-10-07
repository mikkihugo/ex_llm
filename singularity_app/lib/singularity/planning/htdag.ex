defmodule Singularity.Planning.HTDAG do
  @moduledoc """
  Hierarchical Task Directed Acyclic Graph (HTDAG) for recursive task decomposition.
  Based on Deep Agent (2025) research.

  Pure Elixir implementation with LLM integration for task decomposition.
  """

  require Logger

  alias Singularity.LLM.Service
  alias Singularity.Planning.HTDAGCore

  @max_depth 5
  @atomic_threshold 5.0

  ## Public API

  @doc "Decompose a goal into hierarchical tasks"
  def decompose(goal, max_depth \\ @max_depth) do
    # Create initial DAG with root goal
    dag = HTDAGCore.new(goal.description || goal[:description] || "")

    # Create root task
    root_task = create_task_from_goal(goal)

    # Add to DAG
    dag = HTDAGCore.add_task(dag, root_task)

    # Recursively decompose
    decompose_recursive(dag, root_task, max_depth)
  end

  @doc "Select the next task to work on"
  def select_next_task(dag, _agent_score \\ 1.0) do
    HTDAGCore.select_next_task(dag)
  end

  @doc "Mark task as completed"
  def mark_completed(dag, task_id) do
    HTDAGCore.mark_completed(dag, task_id)
  end

  @doc "Mark task as failed"
  def mark_failed(dag, task_id, reason) do
    HTDAGCore.mark_failed(dag, task_id, reason)
  end

  @doc "Count total tasks"
  def count_tasks(dag) do
    HTDAGCore.count_tasks(dag)
  end

  @doc "Count completed tasks"
  def count_completed(dag) do
    HTDAGCore.count_completed(dag)
  end

  @doc "Get current active tasks"
  def current_tasks(dag) do
    HTDAGCore.current_tasks(dag)
  end

  ## Private Functions

  defp decompose_recursive(dag, _task, max_depth) when max_depth <= 0 do
    {:ok, dag}
  end

  defp decompose_recursive(dag, task, max_depth) do
    cond do
      is_atomic?(task) ->
        # Task is atomic, no further decomposition needed
        {:ok, dag}

      true ->
        # Decompose using LLM
        case llm_decompose(task) do
          {:ok, subtasks} ->
            # Add subtasks to DAG
            new_dag =
              Enum.reduce(subtasks, dag, fn subtask, acc_dag ->
                HTDAGCore.add_task(acc_dag, subtask)
              end)

            # Recursively decompose each subtask
            Enum.reduce(subtasks, {:ok, new_dag}, fn subtask, {:ok, acc_dag} ->
              decompose_recursive(acc_dag, subtask, max_depth - 1)
            end)

          {:error, reason} ->
            Logger.error("Failed to decompose task: #{inspect(reason)}")
            {:ok, dag}
        end
    end
  end

  defp is_atomic?(task) do
    complexity = task[:estimated_complexity] || task.estimated_complexity || 10.0
    depth = task[:depth] || task.depth || 0

    complexity < @atomic_threshold and depth > 0
  end

  defp llm_decompose(task) do
    description = task[:description] || task.description || ""

    prompt = """
    Decompose this task into 2-5 independent subtasks.

    Task: #{description}

    Return JSON array of subtasks with:
    - description (string)
    - dependencies (array of task IDs, empty for independent tasks)
    - estimated_complexity (number 1-10)
    - acceptance_criteria (array of strings)

    Example:
    [
      {
        "description": "Design database schema",
        "dependencies": [],
        "estimated_complexity": 3,
        "acceptance_criteria": ["Schema supports all entities", "Indexes defined"]
      }
    ]
    """

    messages = [%{role: "user", content: prompt}]

    case Service.call(:medium, messages,
           task_type: "architect",
           capabilities: [:reasoning, :speed]
         ) do
      {:ok, %{text: text}} ->
        case Jason.decode(text) do
          {:ok, subtasks} ->
            # Enrich subtasks with parent info
            parent_id = task[:id] || task.id || "unknown"
            parent_depth = task[:depth] || task.depth || 0

            enriched =
              Enum.map(subtasks, fn st ->
                %{
                  id: generate_task_id(),
                  description: st["description"],
                  task_type: :implementation,
                  depth: parent_depth + 1,
                  parent_id: parent_id,
                  children: [],
                  dependencies: st["dependencies"] || [],
                  status: :pending,
                  sparc_phase: nil,
                  estimated_complexity: st["estimated_complexity"] || 5.0,
                  actual_complexity: nil,
                  code_files: [],
                  acceptance_criteria: st["acceptance_criteria"] || []
                }
              end)

            {:ok, enriched}

          {:error, reason} ->
            {:error, {:json_decode_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:llm_failed, reason}}
    end
  end

  defp create_task_from_goal(goal) do
    %{
      id: generate_task_id(),
      description: goal[:description] || goal.description || "",
      task_type: :goal,
      depth: goal[:depth] || 0,
      parent_id: nil,
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

  defp generate_task_id do
    "task-#{System.unique_integer([:positive, :monotonic])}"
  end
end
