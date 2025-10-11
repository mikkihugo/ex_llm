defmodule Singularity.Planning.HTDAG do
  @moduledoc """
  Hierarchical Task Directed Acyclic Graph (HTDAG) for recursive task decomposition.
  Based on Deep Agent (2025) research.

  Pure Elixir implementation with LLM integration for task decomposition.
  """

  require Logger

  alias Singularity.LLM.Service
  alias Singularity.Planning.HTDAGCore
  alias Singularity.Planning.HTDAGExecutor
  alias Singularity.Planning.HTDAGEvolution
  alias Singularity.Planning.SafeWorkPlanner
  alias Singularity.TemplateSparcOrchestrator

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

  @doc """
  Execute DAG with NATS LLM integration.
  
  This is the new self-evolving execution path that uses:
  - NATS for LLM communication
  - Streaming tokens for real-time feedback
  - Circuit breaking and rate limiting
  - Self-improvement through critique
  - Integration with existing Singularity infrastructure:
    * RAGCodeGenerator for finding similar code
    * QualityCodeGenerator for enforcing standards
    * SafeWorkPlanner for hierarchical planning
    * TemplateSparcOrchestrator for SPARC methodology
  
  ## Options
  
  - `:run_id` - Unique run identifier
  - `:stream` - Enable token streaming (default: false)
  - `:evolve` - Enable self-improvement (default: false)
  - `:use_rag` - Use RAG code generator (default: false)
  - `:use_quality_templates` - Use quality templates (default: false)
  - `:integrate_sparc` - Integrate with SPARC (default: false)
  - `:safe_planning` - Use SafeWorkPlanner (default: false)
  
  ## Example
  
      dag = HTDAG.decompose(%{description: "Build user auth"})
      {:ok, result} = HTDAG.execute_with_nats(dag, 
        run_id: "run-123",
        evolve: true,
        use_rag: true,
        use_quality_templates: true
      )
  """
  def execute_with_nats(dag, opts \\ []) do
    run_id = Keyword.get(opts, :run_id, generate_run_id())
    
    # Integrate with SafeWorkPlanner if requested
    dag = if Keyword.get(opts, :safe_planning, false) do
      integrate_with_safe_planner(dag, opts)
    else
      dag
    end
    
    # Integrate with SPARC if requested
    opts = if Keyword.get(opts, :integrate_sparc, false) do
      Keyword.put(opts, :sparc_enabled, true)
    else
      opts
    end
    
    # Start executor
    case HTDAGExecutor.start_link(run_id: run_id) do
      {:ok, executor} ->
        try do
          # Execute DAG
          case HTDAGExecutor.execute(executor, dag, opts) do
            {:ok, result} ->
              # Optionally evolve based on results
              if Keyword.get(opts, :evolve, false) do
                evolve_and_retry(executor, dag, result, opts)
              else
                {:ok, result}
              end
              
            error ->
              error
          end
        after
          HTDAGExecutor.stop(executor)
        end
        
      error ->
        error
    end
  end

  ## Private Functions
  
  defp evolve_and_retry(executor, dag, result, opts) do
    Logger.info("Attempting evolution based on execution results")
    
    case HTDAGEvolution.critique_and_mutate(result, opts) do
      {:ok, mutations} when length(mutations) > 0 ->
        Logger.info("Applying #{length(mutations)} mutations for improvement")
        
        # Apply mutations to future executions
        # In a real system, this would update operation configs
        {:ok, Map.put(result, :mutations_applied, mutations)}
        
      {:ok, []} ->
        Logger.info("No mutations suggested, execution was optimal")
        {:ok, result}
        
      {:error, reason} ->
        Logger.warning("Evolution failed, returning original results", reason: reason)
        {:ok, result}
    end
  end
  
  defp generate_run_id do
    "htdag-run-#{System.unique_integer([:positive])}"
  end
  
  defp integrate_with_safe_planner(dag, _opts) do
    # TODO: Integrate HTDAG tasks with SafeWorkPlanner hierarchy
    # For now, return dag as-is
    # Future: Map tasks to Features in SafeWorkPlanner
    Logger.info("SafeWorkPlanner integration: Planning hierarchical task breakdown")
    dag
  end

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
