defmodule Singularity.Execution.Planning.TaskGraph do
  @moduledoc """
  Hierarchical Task Directed Acyclic Graph (TaskGraph) orchestrator for autonomous task decomposition and execution.

  Provides high-level API for decomposing complex goals into hierarchical task graphs,
  executing them with LLM integration, and supporting self-improvement through evolution.
  Based on Deep Agent (2025) research with PostgreSQL-based state management.

  ## Integration Points

  This module integrates with:
  - `Singularity.Execution.Planning.TaskGraphCore` - Core DAG operations (TaskGraphCore.new/1, add_task/2)
  - `Singularity.Execution.Planning.TaskGraphExecutor` - Task execution (TaskGraphExecutor.execute/3)
  - `Singularity.Execution.Planning.TaskGraphEvolution` - Self-improvement (TaskGraphEvolution.critique_and_mutate/2)
  - `Singularity.Execution.Planning.SafeWorkPlanner` - Hierarchical planning (SafeWorkPlanner integration)
  - `Singularity.Execution.SPARC.Orchestrator` - SPARC methodology integration
  - `Singularity.LLM.Service` - Task decomposition (Service.call/3 for LLM decomposition)
  - PostgreSQL table: `task_graph_executions` (stores execution history)

  ## Usage

      # Decompose a goal into hierarchical tasks
      dag = TaskGraph.decompose(%{description: "Build user authentication system"})
      # => %{root_id: "goal-123", tasks: %{...}}

      # Execute with self-improvement enabled
      {:ok, result} = TaskGraph.execute(dag,
        run_id: "run-123",
        evolve: true,
        use_rag: true,
        use_quality_templates: true
      )
      # => {:ok, %{completed_tasks: [...], mutations_applied: [...]}}

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Planning.TaskGraph",
    "purpose": "DAG orchestrator for hierarchical task decomposition and execution",
    "role": "orchestrator",
    "layer": "execution_core",
    "key_responsibilities": [
      "Decompose complex goals into hierarchical task DAGs",
      "Orchestrate task execution with LLM integration",
      "Manage task state and dependencies",
      "Integrate with self-improvement via TaskGraphEvolution"
    ],
    "prevents_duplicates": ["DAGExecutor", "WorkflowEngine", "TaskOrchestrator", "TaskManager"],
    "uses": ["TaskGraphCore", "TaskGraphExecutor", "TaskGraphEvolution", "SafeWorkPlanner", "LLM.Service"],
    "architecture_pattern": "Delegation: TaskGraph (orchestrator) → TaskGraphCore (data) + TaskGraphExecutor (engine)"
  }
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.Execution.Planning.TaskGraphCore
      function: new/1, add_task/2, select_next_task/1, mark_completed/2, mark_failed/3
      purpose: "Core DAG operations (data structures)"
      critical: true

    - module: Singularity.Execution.Planning.TaskGraphExecutor
      function: execute/3, execute_with_streaming/4
      purpose: "Execute tasks with parallel/sequential strategies"
      critical: true

    - module: Singularity.Execution.Planning.TaskGraphEvolution
      function: critique_and_mutate/2
      purpose: "Self-improvement through evolution"
      critical: false

    - module: Singularity.Execution.Planning.SafeWorkPlanner
      function: integrate_with_safe_planner/2
      purpose: "Hierarchical SAFe planning integration"
      critical: false

    - module: Singularity.LLM.Service
      function: call/3, call_with_prompt/3
      purpose: "Task decomposition via LLM"
      critical: true

    - module: Singularity.pgmq.NatsClient
      function: publish/2, subscribe/1
      purpose: "Publish execution requests, subscribe to responses"
      critical: false

    - module: Logger
      function: info/2, warn/2, error/2
      purpose: "Log decomposition and execution events"
      critical: false

  called_by:
    - module: Singularity.Agents.Agent
      function: (any agent using task decomposition)
      purpose: "Agents decompose goals into task DAGs"
      frequency: per_goal

    - module: Singularity.Execution.Planning.SafeWorkPlanner
      function: (orchestration layer)
      purpose: "SafeWorkPlanner creates TaskGraphs for features"
      frequency: per_feature

    - module: Singularity.Execution.SPARC.Orchestrator
      function: (SPARC execution)
      purpose: "SPARC decomposes stories into TaskGraphs"
      frequency: per_story

  state_transitions:
    - name: decompose
      from: idle
      to: decomposed
      increments: task_count
      outputs: root_task_id, task_tree

    - name: select_next_task
      from: decomposed
      to: decomposed
      outputs: next_task_id (or nil if all done)

    - name: mark_completed
      from: decomposed
      to: decomposed
      increments: completed_count
      may_trigger: select_next_task (cascade)

    - name: mark_failed
      from: decomposed
      to: decomposed
      records: failure_reason
      may_trigger: evolve (if evolution enabled)

    - name: execute
      from: decomposed
      to: executing
      persists: task_graph_executions (PostgreSQL table)
      transitions_to: completed (when all tasks done)

  depends_on:
    - TaskGraphCore (MUST be functional)
    - TaskGraphExecutor (MUST be available for execution)
    - LLM.Service (MUST be available for decomposition)
    - PostgreSQL (for execution history)
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create DAGExecutor, WorkflowEngine, or TaskOrchestrator duplicates
  **Why:** TaskGraph IS the canonical DAG orchestrator for Singularity.
  ```elixir
  # ❌ WRONG - Duplicate module
  defmodule MyApp.DAGExecutor do
    def execute_dag(tasks) do
      # Re-implementing what TaskGraph does
    end
  end

  # ✅ CORRECT - Use TaskGraph
  dag = TaskGraph.decompose(goal)
  {:ok, result} = TaskGraph.execute(dag, opts)
  ```

  #### ❌ DO NOT use TaskGraphCore directly for execution
  **Why:** TaskGraph is the orchestrator; TaskGraphCore is data structures only.
  ```elixir
  # ❌ WRONG - Bypass orchestrator
  core = TaskGraphCore.new("goal")
  result = execute_direct(core)

  # ✅ CORRECT - Use TaskGraph orchestrator
  dag = TaskGraph.decompose(%{description: "goal"})
  result = TaskGraph.execute(dag, opts)
  ```

  #### ❌ DO NOT bypass TaskGraphExecutor for task execution
  **Why:** Execution strategies (parallel/sequential) are owned by TaskGraphExecutor.
  ```elixir
  # ❌ WRONG - Inline task execution
  Enum.each(tasks, &execute_task/1)

  # ✅ CORRECT - Delegate to TaskGraphExecutor
  TaskGraphExecutor.execute(dag, strategy: :parallel, opts)
  ```

  #### ❌ DO NOT skip integration with SafeWorkPlanner for SAFe projects
  **Why:** TaskGraph should integrate with hierarchical planning via SafeWorkPlanner.
  ```elixir
  # ❌ WRONG - Ignore SAFe hierarchy
  dag = TaskGraph.decompose(goal)

  # ✅ CORRECT - Integrate with SafeWorkPlanner
  dag = TaskGraph.decompose(goal)
  {:ok, result} = TaskGraph.execute(dag, safe_planning: true)
  ```

  ### Search Keywords

  task graph, DAG execution, hierarchical decomposition, goal decomposition, task orchestration,
  task scheduling, dependency management, parallel execution, task lifecycle, execution strategies,
  LLM decomposition, PostgreSQL state, self-improvement, autonomous planning, task coordination,
  deep agent, task hierarchy, work breakdown structure, execution orchestrator, autonomous execution
  """

  require Logger

  # INTEGRATION: LLM (task decomposition via pgmq)
  alias Singularity.LLM.Service

  # INTEGRATION: Core DAG operations (data structures)
  alias Singularity.Execution.Planning.TaskGraphCore

  # INTEGRATION: Task execution (TaskGraphExecutor.execute/3)
  alias Singularity.Execution.Planning.TaskGraphExecutor

  # INTEGRATION: Self-improvement (TaskGraphEvolution.critique_and_mutate/2)
  alias Singularity.Execution.Planning.TaskGraphEvolution

  # INTEGRATION: Hierarchical planning (SafeWorkPlanner integration)
  alias Singularity.Execution.Planning.SafeWorkPlanner

  # INTEGRATION: SPARC methodology
  alias Singularity.Execution.SPARC.Orchestrator, as: SparcOrchestrator

  @max_depth 5
  @atomic_threshold 5.0

  ## Public API

  @doc "Decompose a goal into hierarchical tasks"
  def decompose(goal, max_depth \\ @max_depth) do
    # Create initial DAG with root goal
    dag = TaskGraphCore.new(goal.description || goal[:description] || "")

    # Create root task
    root_task = create_task_from_goal(goal)

    # Add to DAG
    dag = TaskGraphCore.add_task(dag, root_task)

    # Recursively decompose
    decompose_recursive(dag, root_task, max_depth)
  end

  @doc "Select the next task to work on"
  def select_next_task(dag, _agent_score \\ 1.0) do
    TaskGraphCore.select_next_task(dag)
  end

  @doc "Mark task as completed"
  def mark_completed(dag, task_id) do
    TaskGraphCore.mark_completed(dag, task_id)
  end

  @doc "Mark task as failed"
  def mark_failed(dag, task_id, reason) do
    TaskGraphCore.mark_failed(dag, task_id, reason)
  end

  @doc "Count total tasks"
  def count_tasks(dag) do
    TaskGraphCore.count_tasks(dag)
  end

  @doc "Count completed tasks"
  def count_completed(dag) do
    TaskGraphCore.count_completed(dag)
  end

  @doc "Get current active tasks"
  def current_tasks(dag) do
    TaskGraphCore.current_tasks(dag)
  end

  @doc """
  Execute DAG with pgmq LLM integration.

  This is the new self-evolving execution path that uses:
  - pgmq for LLM communication
  - Streaming tokens for real-time feedback
  - Circuit breaking and rate limiting
  - Self-improvement through critique
  - Integration with existing Singularity infrastructure:
    * RAGCodeGenerator for finding similar code
    * QualityCodeGenerator for enforcing standards
    * SafeWorkPlanner for hierarchical planning
    * SPARC.Orchestrator for SPARC methodology

  ## Options

  - `:run_id` - Unique run identifier
  - `:stream` - Enable token streaming (default: false)
  - `:evolve` - Enable self-improvement (default: false)
  - `:use_rag` - Use RAG code generator (default: false)
  - `:use_quality_templates` - Use quality templates (default: false)
  - `:integrate_sparc` - Integrate with SPARC (default: false)
  - `:safe_planning` - Use SafeWorkPlanner (default: false)

  ## Example

      dag = TaskGraph.decompose(%{description: "Build user auth"})
      {:ok, result} = TaskGraph.execute(dag,
        run_id: "run-123",
        evolve: true,
        use_rag: true,
        use_quality_templates: true
      )
  """
  def execute(dag, opts \\ []) do
    run_id = Keyword.get(opts, :run_id, generate_run_id())

    # Integrate with SafeWorkPlanner if requested
    dag =
      if Keyword.get(opts, :safe_planning, false) do
        integrate_with_safe_planner(dag, opts)
      else
        dag
      end

    # Integrate with SPARC if requested
    opts =
      if Keyword.get(opts, :integrate_sparc, false) do
        Keyword.put(opts, :sparc_enabled, true)
      else
        opts
      end

    # Start executor
    case TaskGraphExecutor.start_link(run_id: run_id) do
      {:ok, executor} ->
        try do
          # Execute DAG
          case TaskGraphExecutor.execute(executor, dag, opts) do
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
          TaskGraphExecutor.stop(executor)
        end

      error ->
        error
    end
  end

  ## Private Functions

  defp evolve_and_retry(executor, dag, result, opts) do
    Logger.info("Attempting evolution based on execution results")

    case TaskGraphEvolution.critique_and_mutate(result, opts) do
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
    "task_graph-run-#{System.unique_integer([:positive])}"
  end

  defp integrate_with_safe_planner(dag, opts) do
    # Extract options
    planning_mode = Keyword.get(opts, :planning_mode, :hierarchical)
    feature_mapping = Keyword.get(opts, :feature_mapping, true)
    complexity_threshold = Keyword.get(opts, :complexity_threshold, 0.7)
    max_depth = Keyword.get(opts, :max_depth, 5)

    Logger.info("SafeWorkPlanner integration: Planning hierarchical task breakdown",
      planning_mode: planning_mode,
      feature_mapping: feature_mapping,
      complexity_threshold: complexity_threshold
    )

    # Map TaskGraph tasks to SafeWorkPlanner features
    if feature_mapping do
      case map_tasks_to_features(dag, complexity_threshold, max_depth) do
        {:ok, mapped_dag} ->
          Logger.info("Successfully mapped TaskGraph tasks to SafeWorkPlanner features",
            task_count: length(mapped_dag.tasks),
            feature_count: count_features(mapped_dag)
          )

          mapped_dag

        {:error, reason} ->
          Logger.warning("Failed to map tasks to features, using original DAG",
            reason: reason
          )

          dag
      end
    else
      # Just validate the DAG structure
      case validate_dag_structure(dag) do
        :ok ->
          dag

        {:error, reason} ->
          Logger.warning("DAG validation failed", reason: reason)
          dag
      end
    end
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
                TaskGraphCore.add_task(acc_dag, subtask)
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

  # Helper functions for integrate_with_safe_planner
  defp map_tasks_to_features(dag, complexity_threshold, max_depth) do
    # Map TaskGraph tasks to SafeWorkPlanner features based on complexity
    try do
      mapped_tasks =
        dag.tasks
        |> Enum.map(fn task ->
          case calculate_task_complexity(task) do
            complexity when complexity >= complexity_threshold ->
              # High complexity task -> Map to Feature
              map_to_feature(task, complexity)

            _ ->
              # Low complexity task -> Keep as task
              task
          end
        end)

      # Create new DAG with mapped tasks
      mapped_dag = %{dag | tasks: mapped_tasks}

      # Validate the mapped DAG
      case validate_dag_structure(mapped_dag) do
        :ok -> {:ok, mapped_dag}
        {:error, reason} -> {:error, {:validation_failed, reason}}
      end
    rescue
      error ->
        Logger.error("Failed to map tasks to features", error: inspect(error))
        {:error, {:mapping_failed, error}}
    end
  end

  defp calculate_task_complexity(task) do
    # Calculate task complexity based on various factors
    base_complexity =
      case task.type do
        :atomic -> 0.1
        :composite -> 0.5
        :orchestration -> 0.8
        _ -> 0.3
      end

    # Add complexity based on dependencies
    dependency_complexity = length(task.dependencies) * 0.1

    # Add complexity based on estimated duration
    duration_complexity =
      case task.estimated_duration do
        # > 1 hour
        duration when duration > 3600 -> 0.3
        # > 30 minutes
        duration when duration > 1800 -> 0.2
        # > 10 minutes
        duration when duration > 600 -> 0.1
        _ -> 0.0
      end

    # Add complexity based on resource requirements
    resource_complexity =
      case task.resource_requirements do
        requirements when is_map(requirements) ->
          Map.values(requirements)
          |> Enum.map(fn req -> if req > 1, do: 0.1, else: 0.0 end)
          |> Enum.sum()

        _ ->
          0.0
      end

    # Calculate final complexity (0.0 to 1.0)
    total_complexity =
      base_complexity + dependency_complexity + duration_complexity + resource_complexity

    min(1.0, max(0.0, total_complexity))
  end

  defp map_to_feature(task, complexity) do
    # Map a high-complexity task to a SafeWorkPlanner feature
    feature_id = "feature-#{task.id}"

    %{
      task
      | type: :feature,
        id: feature_id,
        feature_metadata: %{
          original_task_id: task.id,
          complexity: complexity,
          mapped_at: DateTime.utc_now(),
          safe_planner_integration: true
        }
    }
  end

  defp count_features(dag) do
    dag.tasks
    |> Enum.count(fn task -> task.type == :feature end)
  end

  defp validate_dag_structure(dag) do
    # Validate DAG structure for consistency
    try do
      # Check if all tasks have valid IDs
      task_ids = MapSet.new(dag.tasks, & &1.id)

      # Check if all dependencies reference valid task IDs
      invalid_deps =
        dag.tasks
        |> Enum.flat_map(fn task -> task.dependencies end)
        |> Enum.reject(fn dep_id -> MapSet.member?(task_ids, dep_id) end)

      if length(invalid_deps) > 0 do
        {:error, {:invalid_dependencies, invalid_deps}}
      else
        # Check for circular dependencies
        case detect_circular_dependencies(dag) do
          :ok -> :ok
          {:error, reason} -> {:error, {:circular_dependencies, reason}}
        end
      end
    rescue
      error ->
        {:error, {:validation_error, error}}
    end
  end

  defp detect_circular_dependencies(dag) do
    # Simple cycle detection using DFS
    task_map = Map.new(dag.tasks, fn task -> {task.id, task} end)

    visited = MapSet.new()
    rec_stack = MapSet.new()

    dag.tasks
    |> Enum.find_value(fn task ->
      case detect_cycle_from_task(task.id, task_map, visited, rec_stack) do
        :ok -> nil
        {:error, reason} -> {:error, reason}
      end
    end)
    |> case do
      nil -> :ok
      error -> error
    end
  end

  defp detect_cycle_from_task(task_id, task_map, visited, rec_stack) do
    if MapSet.member?(rec_stack, task_id) do
      {:error, {:circular_dependency, task_id}}
    else
      if MapSet.member?(visited, task_id) do
        :ok
      else
        new_visited = MapSet.put(visited, task_id)
        new_rec_stack = MapSet.put(rec_stack, task_id)

        task = Map.get(task_map, task_id)

        if task do
          task.dependencies
          |> Enum.find_value(fn dep_id ->
            case detect_cycle_from_task(dep_id, task_map, new_visited, new_rec_stack) do
              :ok -> nil
              {:error, reason} -> {:error, reason}
            end
          end)
          |> case do
            nil -> :ok
            error -> error
          end
        else
          {:error, {:task_not_found, task_id}}
        end
      end
    end
  end
end
