defmodule Singularity.Planning.HTDAG do
  @moduledoc """
  Hierarchical Task Directed Acyclic Graph (HTDAG) for recursive task decomposition.
  Based on Deep Agent (2025) research.

  Uses Gleam for type-safe task management, Elixir for LLM integration.
  """

  require Logger

  alias Singularity.Integration.Claude

  @max_depth 5
  @atomic_threshold 5.0

  ## Public API

  @doc "Decompose a goal into hierarchical tasks"
  def decompose(goal, max_depth \\ @max_depth) do
    # Create initial DAG with root goal
    dag = :singularity@htdag.new(goal.description)

    # Create root task
    root_task = create_task_from_goal(goal)

    # Add to DAG
    dag = :singularity@htdag.add_task(dag, root_task)

    # Recursively decompose
    decompose_recursive(dag, root_task, max_depth)
  end

  @doc "Select the next task to work on"
  def select_next_task(dag, _agent_score \\ 1.0) do
    case :singularity@htdag.select_next_task(dag) do
      {:some, task} -> gleam_task_to_map(task)
      :none -> nil
    end
  end

  @doc "Mark task as completed"
  def mark_completed(dag, task_id) do
    :singularity@htdag.mark_completed(dag, task_id)
  end

  @doc "Mark task as failed"
  def mark_failed(dag, task_id, reason) do
    :singularity@htdag.mark_failed(dag, task_id, reason)
  end

  @doc "Count total tasks"
  def count_tasks(dag) do
    :singularity@htdag.count_tasks(dag)
  end

  @doc "Count completed tasks"
  def count_completed(dag) do
    :singularity@htdag.count_completed(dag)
  end

  @doc "Get current active tasks"
  def current_tasks(dag) do
    :singularity@htdag.current_tasks(dag)
    |> Enum.map(&gleam_task_to_map/1)
  end

  ## Private Functions

  defp decompose_recursive(dag, task, max_depth) when max_depth <= 0 do
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
                gleam_task = map_to_gleam_task(subtask)
                :singularity@htdag.add_task(acc_dag, gleam_task)
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

    case Claude.chat(prompt) do
      {:ok, response} ->
        case Jason.decode(response["content"] || response.content || "[]") do
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

  defp map_to_gleam_task(task_map) do
    %{
      id: task_map.id,
      description: task_map.description,
      task_type: map_task_type(task_map.task_type),
      depth: task_map.depth,
      parent_id:
        case task_map.parent_id do
          nil -> :none
          id -> {:some, id}
        end,
      children: task_map.children,
      dependencies: task_map.dependencies,
      status: map_status(task_map.status),
      sparc_phase:
        case task_map.sparc_phase do
          nil -> :none
          phase -> {:some, map_sparc_phase(phase)}
        end,
      estimated_complexity: task_map.estimated_complexity,
      actual_complexity:
        case task_map.actual_complexity do
          nil -> :none
          val -> {:some, val}
        end,
      code_files: task_map.code_files,
      acceptance_criteria: task_map.acceptance_criteria
    }
  end

  defp gleam_task_to_map(task) do
    %{
      id: task.id,
      description: task.description,
      task_type: task.task_type,
      depth: task.depth,
      parent_id:
        case task.parent_id do
          :none -> nil
          {:some, id} -> id
        end,
      children: task.children,
      dependencies: task.dependencies,
      status: task.status,
      sparc_phase:
        case task.sparc_phase do
          :none -> nil
          {:some, phase} -> phase
        end,
      estimated_complexity: task.estimated_complexity,
      actual_complexity:
        case task.actual_complexity do
          :none -> nil
          {:some, val} -> val
        end,
      code_files: task.code_files,
      acceptance_criteria: task.acceptance_criteria
    }
  end

  defp map_task_type(:goal), do: {:goal}
  defp map_task_type(:milestone), do: {:milestone}
  defp map_task_type(:implementation), do: {:implementation}
  defp map_task_type(_), do: {:implementation}

  defp map_status(:pending), do: {:pending}
  defp map_status(:active), do: {:active}
  defp map_status(:blocked), do: {:blocked}
  defp map_status(:completed), do: {:completed}
  defp map_status(:failed), do: {:failed}
  defp map_status(_), do: {:pending}

  defp map_sparc_phase(:specification), do: {:specification}
  defp map_sparc_phase(:pseudocode), do: {:pseudocode}
  defp map_sparc_phase(:architecture), do: {:architecture}
  defp map_sparc_phase(:refinement), do: {:refinement}
  defp map_sparc_phase(:completion), do: {:completion_phase}
  defp map_sparc_phase(_), do: {:specification}

  defp generate_task_id do
    "task-#{System.unique_integer([:positive, :monotonic])}"
  end
end
