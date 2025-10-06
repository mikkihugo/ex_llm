defmodule Singularity.Tools.Planning do
  @moduledoc """
  Agent tools for planning and task management.

  Wraps existing planning capabilities:
  - SafeWorkPlanner - SAFe 6.0 portfolio management
  - HTDAG - Hierarchical task decomposition
  - Planner - SPARC methodology
  - TemplateSparcOrchestrator - Task orchestration
  """

  alias Singularity.Tools.Tool
  alias Singularity.Planning.{SafeWorkPlanner, HTDAGCore}
  alias Singularity.Autonomy.Planner
  alias Singularity.Agents.TemplateSparcOrchestrator

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
      description: "Break down a high-level task into smaller, manageable subtasks using HTDAG.",
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

    case HTDAGCore.decompose_task(description, complexity: complexity, max_depth: max_depth) do
      {:ok, dag} ->
        tasks = HTDAGCore.get_all_tasks(dag)

        {:ok,
         %{
           task_description: description,
           complexity: complexity,
           max_depth: max_depth,
           total_tasks: length(tasks),
           tasks: tasks,
           dag_structure: HTDAGCore.get_structure(dag)
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
           confidence: estimate.confidence,
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

    case TemplateSparcOrchestrator.execute(%{id: task_id, description: task_id},
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
end
