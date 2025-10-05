defmodule Singularity.Tools.ToolSelector do
  @moduledoc """
  Intelligent tool selection for AI agents.

  Helps agents choose the right tools based on:
  - Task requirements
  - Agent role/specialization
  - Context and constraints
  - Performance considerations
  """

  alias Singularity.Tools.{Registry, AgentRoles, AgentToolSelector}

  @max_tools_per_request 6
  @tool_categories %{
    "understanding" => [
      "codebase_search",
      "codebase_analyze",
      "codebase_technologies",
      "codebase_architecture"
    ],
    "planning" => [
      "planning_work_plan",
      "planning_decompose",
      "planning_prioritize",
      "planning_estimate"
    ],
    "knowledge" => [
      "knowledge_packages",
      "knowledge_patterns",
      "knowledge_frameworks",
      "knowledge_examples"
    ],
    "analysis" => ["code_refactor", "code_quality", "code_complexity", "code_todos"],
    "execution" => ["fs_write_file", "sh_run_command", "planning_execute"],
    "summary" => ["tools_summary", "codebase_summary", "planning_summary"]
  }

  @doc """
  Select the best tools for a given task and agent role.
  """
  def select_tools(task_description, agent_role, context \\ %{}) do
    # Get role-specific tools
    {:ok, role_tools} = AgentRoles.get_tools_for_role(agent_role)

    # Get context recommendations
    {:ok, recommendations} = AgentToolSelector.recommend_tools(task_description, context)

    # Analyze task requirements
    task_requirements = analyze_task_requirements(task_description)

    # Select tools based on requirements and role
    selected_tools = select_tools_by_requirements(task_requirements, role_tools, context)

    # Limit tools to prevent context overflow
    final_tools =
      selected_tools
      |> Enum.take(@max_tools_per_request)
      |> add_essential_tools(agent_role)

    {:ok,
     %{
       task: task_description,
       agent_role: agent_role,
       selected_tools: final_tools,
       reasoning: generate_selection_reasoning(task_requirements, final_tools),
       alternatives: get_alternative_tools(final_tools, role_tools)
     }}
  end

  @doc """
  Get tool selection guidance for a specific scenario.
  """
  def get_selection_guidance(scenario) do
    case scenario do
      "new_codebase" ->
        %{
          description: "Starting work on a new codebase",
          recommended_tools: ["codebase_technologies", "codebase_architecture", "codebase_search"],
          reasoning: "Need to understand tech stack, structure, and find relevant code",
          workflow: "understand_codebase"
        }

      "implement_feature" ->
        %{
          description: "Implementing a new feature",
          recommended_tools: [
            "planning_decompose",
            "knowledge_packages",
            "codebase_search",
            "fs_write_file"
          ],
          reasoning:
            "Need to plan work, find libraries, understand existing code, and write new code",
          workflow: "implement_feature"
        }

      "debug_issue" ->
        %{
          description: "Debugging an issue",
          recommended_tools: [
            "codebase_search",
            "code_todos",
            "code_quality",
            "codebase_dependencies"
          ],
          reasoning: "Need to find relevant code, check for issues, and understand dependencies",
          workflow: "debug_issue"
        }

      "refactor_code" ->
        %{
          description: "Refactoring existing code",
          recommended_tools: [
            "code_refactor",
            "knowledge_duplicates",
            "code_complexity",
            "knowledge_patterns"
          ],
          reasoning: "Need to find refactoring opportunities, duplicates, and better patterns",
          workflow: "refactor_code"
        }

      "plan_project" ->
        %{
          description: "Planning a project or sprint",
          recommended_tools: [
            "planning_work_plan",
            "planning_decompose",
            "planning_prioritize",
            "codebase_summary"
          ],
          reasoning: "Need to understand current plan, break down work, and prioritize tasks",
          workflow: "plan_project"
        }

      _ ->
        %{
          description: "General purpose",
          recommended_tools: ["tools_summary", "codebase_search", "planning_work_plan"],
          reasoning: "Start with overview tools to understand context",
          workflow: "general"
        }
    end
  end

  @doc """
  Validate tool selection for a given context.
  """
  def validate_tool_selection(tools, context) do
    issues = []

    # Check for too many tools
    if length(tools) > @max_tools_per_request do
      issues = [
        %{
          type: :too_many_tools,
          message: "Too many tools selected (#{length(tools)} > #{@max_tools_per_request})"
        }
        | issues
      ]
    end

    # Check for conflicting tools
    conflicts = find_tool_conflicts(tools)

    if conflicts != [] do
      issues = [
        %{type: :tool_conflicts, message: "Conflicting tools: #{Enum.join(conflicts, ", ")}"}
        | issues
      ]
    end

    # Check for missing essential tools
    missing_essential = find_missing_essential_tools(tools, context)

    if missing_essential != [] do
      issues = [
        %{
          type: :missing_essential,
          message: "Missing essential tools: #{Enum.join(missing_essential, ", ")}"
        }
        | issues
      ]
    end

    # Check for performance issues
    performance_issues = check_performance_issues(tools)

    if performance_issues != [] do
      issues = [
        %{
          type: :performance,
          message: "Performance concerns: #{Enum.join(performance_issues, ", ")}"
        }
        | issues
      ]
    end

    if issues == [] do
      {:ok, %{valid: true, tools: tools}}
    else
      {:ok, %{valid: false, issues: issues, tools: tools}}
    end
  end

  # Private functions

  defp analyze_task_requirements(task_description) do
    task_lower = String.downcase(task_description)

    %{
      needs_understanding:
        String.contains?(task_lower, ["understand", "explore", "analyze", "learn", "discover"]),
      needs_planning:
        String.contains?(task_lower, ["plan", "organize", "prioritize", "estimate", "schedule"]),
      needs_knowledge:
        String.contains?(task_lower, ["find", "search", "research", "look", "discover"]),
      needs_analysis:
        String.contains?(task_lower, ["refactor", "improve", "quality", "review", "audit"]),
      needs_execution:
        String.contains?(task_lower, ["implement", "create", "write", "build", "develop"]),
      needs_summary: String.contains?(task_lower, ["summary", "overview", "report", "status"]),
      is_complex:
        String.length(task_description) > 100 or
          String.contains?(task_lower, ["complex", "difficult", "challenging"]),
      is_urgent: String.contains?(task_lower, ["urgent", "asap", "immediately", "critical"])
    }
  end

  defp select_tools_by_requirements(requirements, role_tools, context) do
    selected = []

    # Add tools based on requirements
    selected =
      if requirements.needs_understanding do
        understanding_tools =
          @tool_categories["understanding"]
          |> Enum.filter(&(&1 in role_tools))
          |> Enum.take(2)

        selected ++ understanding_tools
      else
        selected
      end

    selected =
      if requirements.needs_planning do
        planning_tools =
          @tool_categories["planning"]
          |> Enum.filter(&(&1 in role_tools))
          |> Enum.take(2)

        selected ++ planning_tools
      else
        selected
      end

    selected =
      if requirements.needs_knowledge do
        knowledge_tools =
          @tool_categories["knowledge"]
          |> Enum.filter(&(&1 in role_tools))
          |> Enum.take(2)

        selected ++ knowledge_tools
      else
        selected
      end

    selected =
      if requirements.needs_analysis do
        analysis_tools =
          @tool_categories["analysis"]
          |> Enum.filter(&(&1 in role_tools))
          |> Enum.take(2)

        selected ++ analysis_tools
      else
        selected
      end

    selected =
      if requirements.needs_execution do
        execution_tools =
          @tool_categories["execution"]
          |> Enum.filter(&(&1 in role_tools))
          |> Enum.take(1)

        selected ++ execution_tools
      else
        selected
      end

    selected =
      if requirements.needs_summary do
        summary_tools =
          @tool_categories["summary"]
          |> Enum.filter(&(&1 in role_tools))
          |> Enum.take(1)

        selected ++ summary_tools
      else
        selected
      end

    # Add context-specific tools
    context_tools = get_context_specific_tools(context, role_tools)
    selected = selected ++ context_tools

    # Remove duplicates and limit
    selected
    |> Enum.uniq()
    |> Enum.take(@max_tools_per_request)
  end

  defp add_essential_tools(tools, agent_role) do
    # Always include basic file operations for most roles
    essential =
      case agent_role do
        # Read-only for PMs
        :project_manager -> ["fs_read_file"]
        # Read + list for others
        _ -> ["fs_read_file", "fs_list_directory"]
      end

    # Add essential tools if not already present
    essential_tools =
      essential
      |> Enum.reject(&(&1 in tools))

    tools ++ essential_tools
  end

  defp get_context_specific_tools(context, role_tools) do
    tools = []

    # Add tools based on context
    tools =
      if Map.get(context, :needs_web_search, false) and "web_search" in role_tools do
        ["web_search"] ++ tools
      else
        tools
      end

    tools =
      if Map.get(context, :needs_quality_check, false) and "quality_sobelow" in role_tools do
        ["quality_sobelow"] ++ tools
      else
        tools
      end

    tools
  end

  defp generate_selection_reasoning(requirements, tools) do
    reasoning = []

    reasoning =
      if requirements.needs_understanding do
        ["Added understanding tools for codebase exploration"] ++ reasoning
      else
        reasoning
      end

    reasoning =
      if requirements.needs_planning do
        ["Added planning tools for task organization"] ++ reasoning
      else
        reasoning
      end

    reasoning =
      if requirements.needs_knowledge do
        ["Added knowledge tools for research and patterns"] ++ reasoning
      else
        reasoning
      end

    reasoning =
      if requirements.needs_analysis do
        ["Added analysis tools for code quality assessment"] ++ reasoning
      else
        reasoning
      end

    reasoning =
      if requirements.is_complex do
        ["Added comprehensive tool set for complex task"] ++ reasoning
      else
        reasoning
      end

    if reasoning == [] do
      ["Selected basic tools for general task"]
    else
      reasoning
    end
  end

  defp get_alternative_tools(selected_tools, role_tools) do
    # Find alternative tools in the same categories
    alternatives =
      selected_tools
      |> Enum.map(fn tool ->
        category = find_tool_category(tool)

        alternatives =
          @tool_categories[category]
          |> Enum.filter(&(&1 in role_tools and &1 != tool))
          |> Enum.take(2)

        {tool, alternatives}
      end)
      |> Enum.into(%{})

    alternatives
  end

  defp find_tool_category(tool_name) do
    @tool_categories
    |> Enum.find(fn {_category, tools} -> tool_name in tools end)
    |> case do
      {category, _} -> category
      nil -> "unknown"
    end
  end

  defp find_tool_conflicts(tools) do
    # Define conflicting tool pairs
    conflicts = %{
      # analyze is comprehensive, search is specific
      "codebase_analyze" => ["codebase_search"],
      # work_plan is high-level, decompose is detailed
      "planning_work_plan" => ["planning_decompose"]
    }

    tools
    |> Enum.flat_map(fn tool ->
      conflicting = Map.get(conflicts, tool, [])
      Enum.filter(conflicting, &(&1 in tools))
    end)
    |> Enum.uniq()
  end

  defp find_missing_essential_tools(tools, context) do
    essential = []

    # Always need file operations
    essential =
      if not Enum.any?(tools, &String.starts_with?(&1, "fs_")) do
        ["fs_read_file"] ++ essential
      else
        essential
      end

    # Need search capability for most tasks
    essential =
      if not Enum.any?(tools, &String.contains?(&1, "search")) do
        ["codebase_search"] ++ essential
      else
        essential
      end

    essential
  end

  defp check_performance_issues(tools) do
    issues = []

    # Check for too many slow tools
    slow_tools = [
      "codebase_analyze",
      "code_quality",
      "code_language_analyze",
      "codebase_architecture"
    ]

    slow_count = Enum.count(tools, &(&1 in slow_tools))

    if slow_count > 2 do
      issues = ["Too many slow tools (#{slow_count})"] ++ issues
    end

    # Check for tool combinations that might be slow
    if "codebase_analyze" in tools and "code_quality" in tools do
      issues = ["codebase_analyze + code_quality combination is very slow"] ++ issues
    end

    issues
  end
end
