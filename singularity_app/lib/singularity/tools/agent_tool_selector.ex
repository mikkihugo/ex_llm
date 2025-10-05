defmodule Singularity.Tools.AgentToolSelector do
  @moduledoc """
  Agent Tool Selector - Recommends optimal tools for AI agents based on context.

  Provides:
  - Tool selection guidance
  - Context-aware tool recommendations
  - Tool usage patterns
  - Performance optimization
  """

  alias Singularity.Tools.{Registry, AgentRoles, EnhancedDescriptions}

  @tool_workflows %{
    # Common development workflows
    "understand_codebase" => %{
      description: "Understand a new or existing codebase",
      steps: [
        # What tech stack?
        "codebase_technologies",
        # How is it structured?
        "codebase_architecture",
        # Find specific functionality
        "codebase_search",
        # How good is the code?
        "code_quality"
      ],
      context: "Use when starting work on a new codebase or reviewing existing code"
    },
    "implement_feature" => %{
      description: "Implement a new feature from scratch",
      steps: [
        # Break down the feature
        "planning_decompose",
        # Find relevant libraries
        "knowledge_packages",
        # Look for similar implementations
        "knowledge_patterns",
        # Find existing similar code
        "codebase_search",
        # Estimate effort
        "planning_estimate",
        # Execute the work
        "planning_execute"
      ],
      context: "Use when implementing new features or functionality"
    },
    "refactor_code" => %{
      description: "Refactor and improve existing code",
      steps: [
        # Find refactoring opportunities
        "code_refactor",
        # Find duplicate code
        "knowledge_duplicates",
        # Identify complex areas
        "code_complexity",
        # Assess overall quality
        "code_quality",
        # Find better patterns
        "knowledge_patterns"
      ],
      context: "Use when improving code quality or reducing technical debt"
    },
    "debug_issue" => %{
      description: "Debug and fix issues",
      steps: [
        # Find relevant code
        "codebase_search",
        # Check for incomplete work
        "code_todos",
        # Look for quality issues
        "code_quality",
        # Check for dependency issues
        "codebase_dependencies"
      ],
      context: "Use when debugging bugs or investigating issues"
    },
    "plan_project" => %{
      description: "Plan and organize a project",
      steps: [
        # Get current plan
        "planning_work_plan",
        # Understand current state
        "codebase_architecture",
        # Break down work
        "planning_decompose",
        # Prioritize tasks
        "planning_prioritize",
        # Estimate effort
        "planning_estimate"
      ],
      context: "Use for project planning, sprint planning, or work organization"
    },
    "research_technology" => %{
      description: "Research and compare technologies",
      steps: [
        # Find packages/libraries
        "knowledge_packages",
        # Compare frameworks
        "knowledge_frameworks",
        # Look at examples
        "knowledge_examples",
        # See how it's used in codebase
        "codebase_search"
      ],
      context: "Use when researching technologies, libraries, or architectural decisions"
    }
  }

  @tool_relationships %{
    # Tools that work well together
    "codebase_search" => ["codebase_analyze", "codebase_technologies", "knowledge_patterns"],
    "planning_decompose" => ["planning_estimate", "planning_prioritize", "planning_execute"],
    "code_refactor" => ["knowledge_duplicates", "code_complexity", "code_quality"],
    "knowledge_packages" => ["knowledge_examples", "knowledge_frameworks"],
    "codebase_analyze" => ["code_quality", "codebase_architecture"]
  }

  @performance_guidelines %{
    # Tool performance characteristics
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
  Get recommended tools for a specific task or context.
  """
  def recommend_tools(task_description, context \\ %{}) do
    # Analyze task description for keywords
    keywords = extract_keywords(task_description)

    # Find matching workflows
    matching_workflows = find_matching_workflows(keywords)

    # Get role-based recommendations
    role = AgentRoles.recommend_role(task_description)
    {:ok, role_tools} = AgentRoles.get_tools_for_role(role)

    # Combine recommendations
    recommended_tools =
      case matching_workflows do
        [] ->
          # Fallback to role-based tools
          role_tools

        workflows ->
          # Use workflow tools, filtered by role
          workflow_tools =
            workflows
            |> Enum.flat_map(& &1.steps)
            |> Enum.uniq()

          # Intersect with role tools
          Enum.filter(workflow_tools, &(&1 in role_tools))
      end

    # Add context-specific tools
    context_tools = get_context_tools(context)

    # Combine and deduplicate
    all_tools =
      (recommended_tools ++ context_tools)
      |> Enum.uniq()
      # Limit to prevent context overflow
      |> Enum.take(8)

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
    performance_map = %{}

    performance_map =
      Enum.reduce(tool_names, performance_map, fn tool_name, acc ->
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

  # Private functions

  defp extract_keywords(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/)
    |> Enum.filter(fn word ->
      String.length(word) > 3 and
        word not in [
          "the",
          "and",
          "for",
          "are",
          "but",
          "not",
          "you",
          "all",
          "can",
          "had",
          "her",
          "was",
          "one",
          "our",
          "out",
          "day",
          "get",
          "has",
          "him",
          "his",
          "how",
          "its",
          "may",
          "new",
          "now",
          "old",
          "see",
          "two",
          "way",
          "who",
          "boy",
          "did",
          "man",
          "oil",
          "sit",
          "try",
          "use"
        ]
    end)
  end

  defp find_matching_workflows(keywords) do
    @tool_workflows
    |> Enum.filter(fn {_name, workflow} ->
      # Check if any keywords match workflow description or steps
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

    # Add tools based on context
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
end
