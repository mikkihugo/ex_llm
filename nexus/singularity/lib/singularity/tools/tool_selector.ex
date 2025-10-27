defmodule Singularity.Tools.ToolSelector do
  @moduledoc """
  Intelligent tool selection for AI agents.

  Unified tool selector combining workflow-based recommendations
  with requirement-based selection and validation.

  Features:
  - Workflow-based recommendations (predefined task patterns)
  - Requirement-based selection (analyze task needs)
  - Role-based filtering (match agent capabilities)
  - Conflict detection and performance optimization
  - Context-aware tool suggestions

  ## Selection Process:
  1. Analyze task requirements (understanding, planning, execution, etc.)
  2. Match to predefined workflows if applicable
  3. Filter by agent role capabilities
  4. Validate for conflicts and performance issues
  5. Return optimal toolset (max 6 tools)
  """

  alias Singularity.Tools.{AgentRoles, EnhancedDescriptions}

  # Dynamic tool limits based on model context windows
  # Context window -> Max tools mapping (conservative to leave room for task context)
  @tool_limits_by_context %{
    # Tiny models (< 16k tokens) - Very limited
    {0, 16_000} => 4,
    # Small models (16k-64k tokens) - Limited
    {16_000, 64_000} => 8,
    # Medium models (64k-200k tokens) - Standard
    {64_000, 200_000} => 12,
    # Large models (200k-1M tokens) - Extended
    {200_000, 1_000_000} => 20,
    # Huge models (1M+ tokens) - Maximum
    {1_000_000, :infinity} => 30
  }

  # Default for unknown models (medium tier)
  @default_max_tools 12
  # For recommendations (no hard execution limit)
  @max_workflow_recommendations 15
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
      "knowledge_examples",
      "package_search"
    ],
    "analysis" => ["code_refactor", "code_quality", "code_complexity", "code_todos"],
    "execution" => ["fs_write_file", "sh_run_command", "planning_execute"],
    "summary" => ["tools_summary", "codebase_summary", "planning_summary"]
  }

  @tool_workflows %{
    "understand_codebase" => %{
      description: "Understand a new or existing codebase",
      steps: ["codebase_technologies", "codebase_architecture", "codebase_search", "code_quality"],
      context: "Use when starting work on a new codebase or reviewing existing code"
    },
    "implement_feature" => %{
      description: "Implement a new feature from scratch",
      steps: [
        "planning_decompose",
        "knowledge_packages",
        "knowledge_patterns",
        "codebase_search",
        "planning_estimate",
        "planning_execute"
      ],
      context: "Use when implementing new features or functionality"
    },
    "refactor_code" => %{
      description: "Refactor and improve existing code",
      steps: [
        "code_refactor",
        "knowledge_duplicates",
        "code_complexity",
        "code_quality",
        "knowledge_patterns"
      ],
      context: "Use when improving code quality or reducing technical debt"
    },
    "debug_issue" => %{
      description: "Debug and fix issues",
      steps: ["codebase_search", "code_todos", "code_quality", "codebase_dependencies"],
      context: "Use when debugging bugs or investigating issues"
    },
    "plan_project" => %{
      description: "Plan and organize a project",
      steps: [
        "planning_work_plan",
        "codebase_architecture",
        "planning_decompose",
        "planning_prioritize",
        "planning_estimate"
      ],
      context: "Use for project planning, sprint planning, or work organization"
    },
    "research_technology" => %{
      description: "Research and compare technologies",
      steps: [
        "knowledge_packages",
        "knowledge_frameworks",
        "knowledge_examples",
        "codebase_search"
      ],
      context: "Use when researching technologies, libraries, or architectural decisions"
    }
  }

  @tool_relationships %{
    "codebase_search" => ["codebase_analyze", "codebase_technologies", "knowledge_patterns"],
    "planning_decompose" => ["planning_estimate", "planning_prioritize", "planning_execute"],
    "code_refactor" => ["knowledge_duplicates", "code_complexity", "code_quality"],
    "knowledge_packages" => ["knowledge_examples", "knowledge_frameworks"],
    "codebase_analyze" => ["code_quality", "codebase_architecture"]
  }

  @performance_guidelines %{
    "fast" => ["codebase_search", "knowledge_packages", "planning_work_plan", "tools_summary"],
    "medium" => [
      "codebase_technologies",
      "planning_decompose",
      "knowledge_patterns",
      "code_refactor"
    ],
    "slow" => [
      "codebase_analyze",
      "code_quality",
      "code_language_analyze",
      "codebase_architecture"
    ]
  }

  @doc """
  Select the best tools for a given task and agent role.

  Combines workflow-based recommendations with requirement analysis.
  Returns validated, conflict-free toolset optimized for performance.

  ## Options

  - `:model_context_window` - Model's context window size in tokens (for dynamic tool limits)
  - `:max_tools` - Override maximum tool count (defaults to dynamic calculation)

  ## Examples

      iex> ToolSelector.select_tools("implement async worker", :code_developer)
      {:ok, %{
        selected_tools: ["planning_decompose", "knowledge_packages", ...],
        workflow: "implement_feature",
        max_tools_allowed: 12,
        reasoning: ["Added planning tools for task organization", ...],
        alternatives: %{"planning_decompose" => ["planning_estimate"]}
      }}

      # With large context model (Gemini 2.5 Pro)
      iex> ToolSelector.select_tools("complex task", :code_developer, model_context_window: 2_000_000)
      {:ok, %{
        selected_tools: [...],  # Up to 30 tools!
        max_tools_allowed: 30,
        ...
      }}
  """
  def select_tools(task_description, agent_role, context \\ %{}) do
    # Get role-specific tools
    {:ok, role_tools} = AgentRoles.get_tools_for_role(agent_role)

    # Calculate dynamic tool limit based on model context window
    max_tools = calculate_max_tools(context)

    # Find matching workflows
    matching_workflows = find_matching_workflows(task_description)

    # Analyze task requirements
    task_requirements = analyze_task_requirements(task_description)

    # Combine workflow tools with requirement-based tools
    workflow_tools =
      matching_workflows
      |> Enum.flat_map(& &1.steps)
      |> Enum.filter(&(&1 in role_tools))
      |> Enum.uniq()

    requirement_tools = select_tools_by_requirements(task_requirements, role_tools, context)

    # Merge and prioritize (essential tools first, then workflow, then requirement-based)
    essential_tools = get_essential_tools(agent_role)

    combined_tools =
      (essential_tools ++ workflow_tools ++ requirement_tools)
      |> Enum.uniq()
      # Dynamic limit based on model capacity
      |> Enum.take(max_tools)

    # Determine primary workflow
    primary_workflow = List.first(matching_workflows)

    {:ok,
     %{
       task: task_description,
       agent_role: agent_role,
       selected_tools: combined_tools,
       max_tools_allowed: max_tools,
       model_context_window: Map.get(context, :model_context_window),
       workflow: if(primary_workflow, do: primary_workflow.name, else: nil),
       reasoning:
         generate_selection_reasoning(task_requirements, combined_tools, matching_workflows),
       alternatives: get_alternative_tools(combined_tools, role_tools)
     }}
  end

  @doc """
  Get recommended tools for a specific task with workflow suggestions.

  Similar to select_tools/3 but returns workflow-based recommendations
  without strict role filtering. Useful for agent initialization.
  """
  def recommend_tools(task_description, context \\ %{}) do
    # Analyze task
    matching_workflows = find_matching_workflows(task_description)

    # Get role recommendation
    role = AgentRoles.recommend_role(task_description)
    {:ok, role_tools} = AgentRoles.get_tools_for_role(role)

    # Get workflow-based recommendations
    recommended_tools =
      case matching_workflows do
        [] ->
          role_tools

        workflows ->
          workflows
          |> Enum.flat_map(& &1.steps)
          |> Enum.filter(&(&1 in role_tools))
          |> Enum.uniq()
      end

    # Add context-specific tools
    context_tools = get_context_tools(context)

    # Combine and limit
    all_tools =
      (recommended_tools ++ context_tools)
      |> Enum.uniq()
      |> Enum.take(@max_workflow_recommendations)

    {:ok,
     %{
       task: task_description,
       role: role,
       recommended_tools: all_tools,
       workflows: matching_workflows,
       context: context
     }}
  end

  @doc """
  Get tool usage guidance for a specific tool.
  """
  def get_tool_guidance(tool_name) do
    case EnhancedDescriptions.get_description(tool_name) do
      nil -> {:error, "Tool not found: #{tool_name}"}
      description -> {:ok, description}
    end
  end

  @doc """
  Get related tools that work well with the given tool.
  """
  def get_related_tools(tool_name) do
    related = Map.get(@tool_relationships, tool_name, [])
    {:ok, related}
  end

  @doc """
  Get performance characteristics for tools.
  """
  def get_tool_performance(tool_names) when is_list(tool_names) do
    performance_map =
      Enum.reduce(tool_names, %{}, fn tool_name, acc ->
        performance =
          cond do
            tool_name in @performance_guidelines["fast"] -> "fast"
            tool_name in @performance_guidelines["medium"] -> "medium"
            tool_name in @performance_guidelines["slow"] -> "slow"
            true -> "unknown"
          end

        Map.put(acc, tool_name, performance)
      end)

    {:ok, performance_map}
  end

  @doc """
  Get available workflows for common tasks.
  """
  def get_workflows do
    @tool_workflows
  end

  @doc """
  Execute a tool with the given arguments.
  """
  def execute_tool(tool_name, args) do
    case get_tool_guidance(tool_name) do
      %{module: module, function: function} ->
        # Execute the tool via the appropriate module
        apply(module, function, [args])

      _ ->
        {:error, "Tool not found: #{tool_name}"}
    end
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

    # Check for too many tools (using default limit for validation)
    issues =
      if length(tools) > @default_max_tools do
        [
          %{
            type: :too_many_tools,
            message: "Too many tools selected (#{length(tools)} > #{@default_max_tools})"
          }
          | issues
        ]
      else
        issues
      end

    # Check for conflicting tools
    conflicts = find_tool_conflicts(tools)

    issues =
      if conflicts != [] do
        [
          %{type: :tool_conflicts, message: "Conflicting tools: #{Enum.join(conflicts, ", ")}"}
          | issues
        ]
      else
        issues
      end

    # Check for missing essential tools
    missing_essential = find_missing_essential_tools(tools, context)

    issues =
      if missing_essential != [] do
        [
          %{
            type: :missing_essential,
            message: "Missing essential tools: #{Enum.join(missing_essential, ", ")}"
          }
          | issues
        ]
      else
        issues
      end

    # Check for performance issues
    performance_issues = check_performance_issues(tools)

    issues =
      if performance_issues != [] do
        [
          %{
            type: :performance,
            message: "Performance concerns: #{Enum.join(performance_issues, ", ")}"
          }
          | issues
        ]
      else
        issues
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
    |> Enum.take(@default_max_tools)
  end

  defp get_essential_tools(agent_role) do
    # Always include basic file operations for most roles
    case agent_role do
      # Read-only for PMs
      :project_manager -> ["fs_read_file"]
      # Read + list for others
      _ -> ["fs_read_file", "fs_list_directory"]
    end
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

  defp calculate_max_tools(context) do
    # Allow explicit override
    case Map.get(context, :max_tools) do
      max when is_integer(max) and max > 0 ->
        max

      _ ->
        # Calculate based on model context window
        context_window = Map.get(context, :model_context_window)
        get_tool_limit_for_context(context_window)
    end
  end

  defp get_tool_limit_for_context(nil), do: @default_max_tools

  defp get_tool_limit_for_context(context_size) when is_integer(context_size) do
    @tool_limits_by_context
    |> Enum.find(fn {{min, max}, _limit} ->
      context_size >= min and (max == :infinity or context_size < max)
    end)
    |> case do
      {_range, limit} -> limit
      nil -> @default_max_tools
    end
  end

  defp get_tool_limit_for_context(_), do: @default_max_tools

  defp extract_keywords(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/)
    |> Enum.filter(fn word ->
      String.length(word) > 3 and
        word not in ~w[
          the and for are but not you all can had her was one our out
          day get has him his how its may new now old see two way who
          boy did man oil sit try use with this that from they have
          been more when your what were said some into than make like
          time could just know take used work well also made
        ]
    end)
  end

  defp find_matching_workflows(task_description) do
    keywords = extract_keywords(task_description)

    @tool_workflows
    |> Enum.filter(fn {_name, workflow} ->
      workflow_text =
        (workflow.description <> " " <> Enum.join(workflow.steps, " "))
        |> String.downcase()

      Enum.any?(keywords, fn keyword ->
        String.contains?(workflow_text, keyword)
      end)
    end)
    |> Enum.map(fn {name, workflow} -> Map.put(workflow, :name, name) end)
  end

  defp get_context_tools(context) do
    tools = []

    tools =
      if Map.get(context, :needs_summary, false) do
        ["tools_summary", "codebase_summary"] ++ tools
      else
        tools
      end

    tools =
      if Map.get(context, :needs_planning, false) do
        ["planning_work_plan", "planning_summary"] ++ tools
      else
        tools
      end

    tools =
      if Map.get(context, :needs_knowledge, false) do
        ["knowledge_packages", "knowledge_patterns"] ++ tools
      else
        tools
      end

    tools
  end

  defp generate_selection_reasoning(requirements, _tools, matching_workflows) do
    reasoning = []

    # Add workflow-based reasoning
    reasoning =
      if matching_workflows != [] do
        workflow_names = Enum.map(matching_workflows, & &1.name)
        ["Matched workflows: #{Enum.join(workflow_names, ", ")}"] ++ reasoning
      else
        reasoning
      end

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
          (@tool_categories[category] || [])
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

  defp find_missing_essential_tools(tools, _context) do
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

    issues =
      if slow_count > 2 do
        ["Too many slow tools (#{slow_count})"] ++ issues
      else
        issues
      end

    # Check for tool combinations that might be slow
    issues =
      if "codebase_analyze" in tools and "code_quality" in tools do
        ["codebase_analyze + code_quality combination is very slow"] ++ issues
      else
        issues
      end

    issues
  end
end
