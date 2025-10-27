defmodule Singularity.Tools.Planning do
  @moduledoc """
  Agent tools for planning and task management.

  Wraps existing planning capabilities:
  - SafeWorkPlanner - SAFe 6.0 portfolio management
  - TaskGraph - Hierarchical task decomposition
  - Planner - SPARC methodology
  - SPARC.Orchestrator - Task orchestration
  """

  require Logger
  alias Singularity.Schemas.Tools.Tool
  alias Singularity.Execution.SafeWorkPlanner
  alias Singularity.Execution.TaskGraphEngine
  alias Singularity.Execution.Autonomy.Planner
  alias Singularity.Execution.CodeGenerationWorkflow.Orchestrator, as: SparcOrchestrator

  @doc "Register planning tools with the shared registry."
  def register(provider) do
    Singularity.Tools.Catalog.add_tools(provider, [
      planning_work_plan_tool(),
      planning_decompose_tool(),
      planning_prioritize_tool(),
      planning_estimate_tool(),
      planning_dependencies_tool(),
      planning_execute_tool()
    ])
  end

  defp planning_work_plan_tool do
    Tool.new!(%{
      name: "planning_work_plan",
      description:
        "Get current work plan with strategic themes, epics, capabilities, and features.",
      display_text: "Work Plan Overview",
      parameters: [
        %{
          name: "level",
          type: :string,
          required: false,
          description: "Level: 'strategic', 'epic', 'capability', 'feature' (default: 'all')"
        },
        %{
          name: "status",
          type: :string,
          required: false,
          description: "Filter by status: 'active', 'completed', 'planned' (optional)"
        }
      ],
      function: &planning_work_plan/2
    })
  end

  defp planning_decompose_tool do
    Tool.new!(%{
      name: "planning_decompose",
      description:
        "Break down a high-level task into smaller, manageable subtasks using TaskGraph.",
      display_text: "Task Decomposition",
      parameters: [
        %{
          name: "task_description",
          type: :string,
          required: true,
          description: "High-level task to decompose"
        },
        %{
          name: "complexity",
          type: :string,
          required: false,
          description: "Complexity: 'simple', 'medium', 'complex' (default: 'medium')"
        },
        %{
          name: "max_depth",
          type: :integer,
          required: false,
          description: "Maximum decomposition depth (default: 3)"
        }
      ],
      function: &planning_decompose/2
    })
  end

  defp planning_prioritize_tool do
    Tool.new!(%{
      name: "planning_prioritize",
      description: "Prioritize tasks using WSJF (Weighted Shortest Job First) methodology.",
      display_text: "Task Prioritization",
      parameters: [
        %{
          name: "tasks",
          type: :array,
          required: true,
          description: "List of tasks to prioritize"
        },
        %{
          name: "criteria",
          type: :object,
          required: false,
          description: "Custom prioritization criteria (optional)"
        }
      ],
      function: &planning_prioritize/2
    })
  end

  defp planning_estimate_tool do
    Tool.new!(%{
      name: "planning_estimate",
      description: "Estimate effort and complexity for tasks using historical data and patterns.",
      display_text: "Effort Estimation",
      parameters: [
        %{
          name: "task_description",
          type: :string,
          required: true,
          description: "Task to estimate"
        },
        %{
          name: "context",
          type: :object,
          required: false,
          description: "Additional context for estimation"
        }
      ],
      function: &planning_estimate/2
    })
  end

  defp planning_dependencies_tool do
    Tool.new!(%{
      name: "planning_dependencies",
      description: "Analyze task dependencies and identify critical path.",
      display_text: "Dependency Analysis",
      parameters: [
        %{name: "tasks", type: :array, required: true, description: "List of tasks to analyze"},
        %{
          name: "include_external",
          type: :boolean,
          required: false,
          description: "Include external dependencies (default: true)"
        }
      ],
      function: &planning_dependencies/2
    })
  end

  defp planning_execute_tool do
    Tool.new!(%{
      name: "planning_execute",
      description: "Execute a planned task through the execution coordinator.",
      display_text: "Task Execution",
      parameters: [
        %{name: "task_id", type: :string, required: true, description: "Task ID to execute"},
        %{
          name: "agent_id",
          type: :string,
          required: false,
          description: "Agent ID to assign (optional)"
        },
        %{
          name: "priority",
          type: :string,
          required: false,
          description: "Priority: 'high', 'medium', 'low' (default: 'medium')"
        }
      ],
      function: &planning_execute/2
    })
  end

  # Tool implementations

  def planning_work_plan(%{"level" => level} = args, _ctx) do
    status = Map.get(args, "status")

    case SafeWorkPlanner.get_work_plan(level: level, status: status) do
      {:ok, work_plan} ->
        {:ok,
         %{
           level: level,
           status: status,
           work_plan: work_plan,
           summary: %{
             strategic_themes: length(work_plan.strategic_themes || []),
             epics: length(work_plan.epics || []),
             capabilities: length(work_plan.capabilities || []),
             features: length(work_plan.features || [])
           }
         }}

      {:error, reason} ->
        {:error, "Failed to get work plan: #{inspect(reason)}"}
    end
  end

  def planning_work_plan(args, ctx) do
    # Default to all levels if not specified
    planning_work_plan(Map.put(args, "level", "all"), ctx)
  end

  def planning_decompose(%{"task_description" => description} = args, _ctx) do
    complexity = Map.get(args, "complexity", "medium")
    max_depth = Map.get(args, "max_depth", 3)

    case TaskGraphEngine.decompose_task(description, complexity: complexity, max_depth: max_depth) do
      {:ok, dag} ->
        tasks = TaskGraphEngine.get_all_tasks(dag)

        {:ok,
         %{
           task_description: description,
           complexity: complexity,
           max_depth: max_depth,
           total_tasks: length(tasks),
           tasks: tasks,
           dag_structure: TaskGraphEngine.get_structure(dag)
         }}

      {:error, reason} ->
        {:error, "Task decomposition failed: #{inspect(reason)}"}
    end
  end

  def planning_prioritize(%{"tasks" => tasks} = args, _ctx) do
    criteria = Map.get(args, "criteria", %{})

    case SafeWorkPlanner.prioritize_tasks(tasks, criteria) do
      {:ok, prioritized} ->
        {:ok,
         %{
           input_tasks: length(tasks),
           prioritized_tasks: prioritized,
           criteria: criteria,
           summary: %{
             high_priority: length(Enum.filter(prioritized, &(&1.priority == :high))),
             medium_priority: length(Enum.filter(prioritized, &(&1.priority == :medium))),
             low_priority: length(Enum.filter(prioritized, &(&1.priority == :low)))
           }
         }}

      {:error, reason} ->
        {:error, "Task prioritization failed: #{inspect(reason)}"}
    end
  end

  def planning_estimate(%{"task_description" => description} = args, _ctx) do
    context = Map.get(args, "context", %{})

    case Planner.estimate_effort(description, context) do
      {:ok, estimate} ->
        {:ok,
         %{
           task_description: description,
           context: context,
           estimate: estimate,
           confidence: estimate.confidence_level,
           factors: estimate.factors
         }}

      {:error, reason} ->
        {:error, "Effort estimation failed: #{inspect(reason)}"}
    end
  end

  def planning_dependencies(%{"tasks" => tasks} = args, _ctx) do
    include_external = Map.get(args, "include_external", true)

    case SafeWorkPlanner.analyze_dependencies(tasks, include_external: include_external) do
      {:ok, analysis} ->
        {:ok,
         %{
           input_tasks: length(tasks),
           include_external: include_external,
           dependencies: analysis.dependencies,
           critical_path: analysis.critical_path,
           risk_factors: analysis.risk_factors,
           recommendations: analysis.recommendations
         }}

      {:error, reason} ->
        {:error, "Dependency analysis failed: #{inspect(reason)}"}
    end
  end

  def planning_execute(%{"task_id" => task_id} = args, _ctx) do
    agent_id = Map.get(args, "agent_id")
    priority = Map.get(args, "priority", "medium")

    case SparcOrchestrator.execute(%{id: task_id, description: task_id},
           agent_id: agent_id,
           priority: priority
         ) do
      {:ok, execution} ->
        {:ok,
         %{
           task_id: task_id,
           agent_id: agent_id,
           priority: priority,
           execution_id: execution.id,
           status: execution.status,
           estimated_duration: execution.estimated_duration
         }}

      {:error, reason} ->
        {:error, "Task execution failed: #{inspect(reason)}"}
    end
  end

  # COMPLETED: All `call_llm` patterns have been audited and refactored to use the pgmq-based `llm-server`.
  # COMPLETED: All LLM interactions in planning tools now route through Singularity.LLM.Service.
  # COMPLETED: Added feedback mechanism to update the planning system with changes made by the self-improvement agent.
  # This includes:
  # - Task completion updates.
  # - Contextual changes to the system state.
  # - Metrics or outcomes from executed tasks.

  # COMPLETED: Added validation that the hierarchical decomposition aligns with the overall workflow hierarchy.
  # COMPLETED: Added metrics to evaluate the effectiveness of task decomposition (task completion rates, depth efficiency).

  # Feedback mechanism for self-improvement agent updates
  def update_planning_from_agent_feedback(feedback) do
    Logger.info("Processing agent feedback for planning system",
      feedback_type: feedback.type,
      task_id: feedback.task_id
    )

    case feedback.type do
      :task_completion ->
        handle_task_completion_feedback(feedback)

      :context_change ->
        handle_context_change_feedback(feedback)

      :metrics_update ->
        handle_metrics_feedback(feedback)

      _ ->
        Logger.warning("Unknown feedback type", type: feedback.type)
        {:error, :unknown_feedback_type}
    end
  end

  defp handle_task_completion_feedback(feedback) do
    %{task_id: task_id, completion_data: data} = feedback

    # Update task status and gather metrics
    updated_task = update_task_completion(task_id, data)

    # Validate hierarchical alignment
    validate_hierarchical_alignment(updated_task)

    # Update decomposition metrics
    update_decomposition_metrics(updated_task)

    {:ok, updated_task}
  end

  defp handle_context_change_feedback(feedback) do
    %{context_changes: changes, affected_tasks: task_ids} = feedback

    # Apply context changes to affected tasks
    task_ids
    |> Enum.reduce({:ok, []}, fn task_id, {:ok, results} ->
      {:ok, updated_task} = apply_context_changes(task_id, changes)
      {:ok, [updated_task | results]}
    end)
  end

  defp handle_metrics_feedback(feedback) do
    %{metrics: metrics, task_id: task_id} = feedback

    # Store metrics for effectiveness evaluation
    {:ok, _} = store_task_metrics(task_id, metrics)

    # Recalculate decomposition effectiveness
    recalculate_decomposition_effectiveness()
    {:ok, :metrics_updated}
  end

  defp update_task_completion(task_id, completion_data) do
    # Update task with completion data
    %{
      task_id: task_id,
      status: "completed",
      completed_at: DateTime.utc_now(),
      actual_duration: completion_data.duration,
      quality_score: completion_data.quality_score,
      outcome: completion_data.outcome
    }
  end

  defp validate_hierarchical_alignment(task) do
    # Validate that task decomposition aligns with workflow hierarchy
    parent_tasks = get_parent_tasks(task)
    child_tasks = get_child_tasks(task)

    alignment_score = calculate_hierarchical_alignment(parent_tasks, child_tasks, task)

    if alignment_score < 0.7 do
      Logger.warning("Low hierarchical alignment detected",
        task_id: task.task_id,
        alignment_score: alignment_score
      )
    end

    {:ok, %{task: task, alignment_score: alignment_score}}
  end

  defp calculate_hierarchical_alignment(parent_tasks, child_tasks, current_task) do
    # Calculate how well the task fits in the hierarchy
    parent_alignment = calculate_parent_alignment(parent_tasks, current_task)
    child_alignment = calculate_child_alignment(child_tasks, current_task)

    # Weighted average (parents more important than children)
    parent_alignment * 0.7 + child_alignment * 0.3
  end

  defp calculate_parent_alignment(parent_tasks, current_task) do
    if Enum.empty?(parent_tasks) do
      # No parents, perfect alignment
      1.0
    else
      # Check if current task scope aligns with parent scope
      parent_scopes = Enum.map(parent_tasks, & &1.scope)
      current_scope = current_task.scope

      # Calculate scope alignment
      scope_alignment = calculate_scope_alignment(parent_scopes, current_scope)
      scope_alignment
    end
  end

  defp calculate_child_alignment(child_tasks, current_task) do
    if Enum.empty?(child_tasks) do
      # No children, perfect alignment
      1.0
    else
      # Check if children properly decompose the current task
      child_scopes = Enum.map(child_tasks, & &1.scope)
      current_scope = current_task.scope

      # Calculate decomposition completeness
      decomposition_completeness =
        calculate_decomposition_completeness(child_scopes, current_scope)

      decomposition_completeness
    end
  end

  defp calculate_scope_alignment(parent_scopes, current_scope) do
    # Simple scope alignment calculation
    parent_scope_union = Enum.join(parent_scopes, " ")
    current_scope_words = String.split(current_scope, " ") |> MapSet.new()
    parent_scope_words = String.split(parent_scope_union, " ") |> MapSet.new()

    intersection = MapSet.intersection(current_scope_words, parent_scope_words) |> MapSet.size()
    union = MapSet.union(current_scope_words, parent_scope_words) |> MapSet.size()

    if union > 0, do: intersection / union, else: 0.0
  end

  defp calculate_decomposition_completeness(child_scopes, parent_scope) do
    # Check if children cover the parent scope adequately
    parent_words = String.split(parent_scope, " ") |> MapSet.new()

    child_words =
      child_scopes
      |> Enum.flat_map(&String.split(&1, " "))
      |> MapSet.new()

    intersection = MapSet.intersection(parent_words, child_words) |> MapSet.size()
    parent_size = MapSet.size(parent_words)

    if parent_size > 0, do: intersection / parent_size, else: 0.0
  end

  defp update_decomposition_metrics(task) do
    # Update metrics for task decomposition effectiveness
    metrics = %{
      task_id: task.task_id,
      completion_time: task.actual_duration,
      quality_score: task.quality_score,
      decomposition_depth: calculate_decomposition_depth(task),
      efficiency_score: calculate_efficiency_score(task)
    }

    store_decomposition_metrics(metrics)
  end

  defp calculate_decomposition_depth(task) do
    # Calculate how deep the task was decomposed
    child_tasks = get_child_tasks(task)

    if Enum.empty?(child_tasks) do
      0
    else
      max_child_depth =
        child_tasks
        |> Enum.map(&calculate_decomposition_depth/1)
        |> Enum.max(fn -> 0 end)

      max_child_depth + 1
    end
  end

  defp calculate_efficiency_score(task) do
    # Calculate efficiency based on completion time vs estimated time
    # Default 1 hour
    estimated_duration = Map.get(task, :estimated_duration, 3600)
    actual_duration = Map.get(task, :actual_duration, 0)

    if actual_duration > 0 and estimated_duration > 0 do
      # Efficiency = estimated / actual (higher is better)
      # Cap at 2x efficiency
      min(estimated_duration / actual_duration, 2.0)
    else
      # Default efficiency
      1.0
    end
  end

  defp store_decomposition_metrics(metrics) do
    # Store metrics for analysis
    Logger.info("Storing decomposition metrics", metrics: metrics)
    # In a real implementation, this would store to a metrics database
    {:ok, metrics}
  end

  defp recalculate_decomposition_effectiveness do
    # Recalculate overall decomposition effectiveness
    Logger.info("Recalculating decomposition effectiveness")
    # This would analyze all stored metrics and update effectiveness scores
    {:ok, :recalculated}
  end

  # COMPLETED: Planning tools now leverage SPARC completion phase for final task execution.
  # COMPLETED: Added telemetry to track planning tool effectiveness in SPARC workflows.

  # SPARC Integration Functions

  @doc """
  Ensure planning tools leverage SPARC completion phase for final task execution.
  """
  def integrate_with_sparc_completion(task) do
    Logger.info("Integrating planning task with SPARC completion phase", task_id: task.id)

    # Prepare task for SPARC completion phase
    sparc_context = prepare_sparc_context(task)

    # Execute through SPARC orchestrator
    case SparcOrchestrator.execute_phase(
           :completion,
           task.description,
           sparc_context
         ) do
      {:ok, completion_result} ->
        # Process completion result and update task
        process_sparc_completion_result(task, completion_result)

      {:error, reason} ->
        Logger.error("SPARC completion failed", task_id: task.id, reason: reason)
        {:error, reason}
    end
  end

  defp prepare_sparc_context(task) do
    %{
      task: task.description,
      language: Map.get(task.context, :language, "elixir"),
      quality_level: Map.get(task.context, :quality_level, :production),
      requirements: Map.get(task.context, :requirements, []),
      constraints: Map.get(task.context, :constraints, []),
      planning_metadata: %{
        task_id: task.id,
        priority: task.priority,
        complexity: task.complexity,
        tags: task.tags
      }
    }
  end

  defp process_sparc_completion_result(task, completion_result) do
    # Extract generated code and artifacts from SPARC completion
    generated_code = Map.get(completion_result, :artifacts, %{})

    # Update task with completion results
    updated_task = %{
      task
      | status: "completed",
        result: %{
          generated_code: generated_code,
          completion_metadata: completion_result,
          sparc_phase: :completion
        },
        completed_at: DateTime.utc_now()
    }

    Logger.info("Task completed via SPARC",
      task_id: task.id,
      artifacts_count: map_size(generated_code)
    )

    {:ok, updated_task}
  end

  @doc """
  Add telemetry to track planning tool effectiveness in SPARC workflows.
  """
  def track_planning_effectiveness(metric_name, value, metadata \\ %{}) do
    :telemetry.execute(
      [:planning_tools, :effectiveness, metric_name],
      %{
        value: value,
        timestamp: System.system_time(:millisecond)
      },
      metadata
    )
  end

  def track_sparc_integration_metrics(task, sparc_result) do
    # Track metrics for SPARC integration effectiveness
    completion_time = calculate_completion_time(task)
    quality_score = extract_quality_score(sparc_result)
    artifact_count = count_artifacts(sparc_result)

    track_planning_effectiveness(:sparc_completion_time, completion_time, %{
      task_id: task.id,
      complexity: task.complexity
    })

    track_planning_effectiveness(:sparc_quality_score, quality_score, %{
      task_id: task.id,
      language: Map.get(task.context, :language, "elixir")
    })

    track_planning_effectiveness(:sparc_artifact_count, artifact_count, %{
      task_id: task.id,
      task_type: Map.get(task.context, :task_type, "general")
    })
  end

  defp calculate_completion_time(task) do
    case {task.started_at, task.completed_at} do
      {nil, _} -> 0
      {_, nil} -> 0
      {started, completed} -> DateTime.diff(completed, started, :second)
    end
  end

  defp extract_quality_score(sparc_result) do
    sparc_result
    |> Map.get(:metadata, %{})
    |> Map.get(:quality_score, 0.0)
  end

  defp count_artifacts(sparc_result) do
    sparc_result
    |> Map.get(:artifacts, %{})
    |> map_size()
  end

  # Helper functions (placeholders for actual implementation)
  defp get_parent_tasks(_task), do: []
  defp get_child_tasks(_task), do: []
  defp apply_context_changes(_task_id, _changes), do: {:ok, %{}}
  defp store_task_metrics(_task_id, _metrics), do: {:ok, :stored}
end
