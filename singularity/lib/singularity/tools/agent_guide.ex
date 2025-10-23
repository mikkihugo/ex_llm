defmodule Singularity.Tools.AgentGuide do
  @moduledoc """
  Comprehensive guide for AI agents on tool usage.

  Provides:
  - Tool selection strategies
  - Usage patterns and workflows
  - Best practices
  - Common mistakes to avoid
  """

  alias Singularity.Tools.{ToolSelector, EnhancedDescriptions}

  @doc """
  Get comprehensive tool usage guide for agents.
  """
  def get_agent_guide do
    %{
      overview: %{
        title: "Singularity Agent Tool Guide",
        description: "Complete guide for using tools effectively as an AI agent",
        total_tools: 28,
        categories: 5
      },
      tool_selection: %{
        strategy: "Role-based tool selection with context awareness",
        max_tools: 6,
        selection_process: [
          "1. Identify your agent role (code_developer, architecture_analyst, etc.)",
          "2. Analyze task requirements (understanding, planning, knowledge, analysis)",
          "3. Select tools based on role and requirements",
          "4. Validate selection for conflicts and performance",
          "5. Use tools in logical sequence"
        ]
      },
      role_guidance: get_role_guidance(),
      common_workflows: get_workflow_guidance(),
      best_practices: get_best_practices(),
      common_mistakes: get_common_mistakes(),
      tool_descriptions: get_tool_descriptions_summary()
    }
  end

  @doc """
  Get role-specific guidance for agents.
  """
  def get_role_guidance do
    %{
      "code_developer" => %{
        focus: "Writing, analyzing, and maintaining code",
        key_tools: ["codebase_search", "code_refactor", "knowledge_packages", "fs_write_file"],
        workflow: "understand → research → implement → analyze",
        tips: [
          "Start with codebase_search to understand existing patterns",
          "Use knowledge_packages to find the right libraries",
          "Always run code_quality after making changes",
          "Use code_refactor to improve code before committing"
        ]
      },
      "architecture_analyst" => %{
        focus: "System architecture and design",
        key_tools: ["codebase_architecture", "codebase_dependencies", "planning_work_plan"],
        workflow: "analyze → plan → design → validate",
        tips: [
          "Use codebase_architecture for high-level understanding",
          "Map dependencies with codebase_dependencies",
          "Plan changes with planning_work_plan",
          "Consider impact on all services when making changes"
        ]
      },
      "quality_engineer" => %{
        focus: "Code quality, security, and maintainability",
        key_tools: ["code_quality", "code_refactor", "quality_sobelow", "code_todos"],
        workflow: "assess → identify → fix → validate",
        tips: [
          "Run code_quality regularly to catch issues early",
          "Use code_refactor to find improvement opportunities",
          "Check security with quality_sobelow",
          "Track technical debt with code_todos"
        ]
      },
      "project_manager" => %{
        focus: "Planning, prioritizing, and coordinating work",
        key_tools: ["planning_work_plan", "planning_decompose", "planning_prioritize"],
        workflow: "plan → decompose → prioritize → execute",
        tips: [
          "Use planning_work_plan to understand current state",
          "Break down large tasks with planning_decompose",
          "Prioritize with planning_prioritize using WSJF",
          "Track progress with planning_summary"
        ]
      },
      "knowledge_curator" => %{
        focus: "Knowledge management and research",
        key_tools: ["knowledge_packages", "knowledge_patterns", "codebase_search"],
        workflow: "research → organize → document → share",
        tips: [
          "Use knowledge_packages for library research",
          "Find patterns with knowledge_patterns",
          "Document findings with knowledge_documentation",
          "Keep knowledge base up to date"
        ]
      }
    }
  end

  @doc """
  Get workflow guidance for common tasks.
  """
  def get_workflow_guidance do
    %{
      "understand_new_codebase" => %{
        description: "Getting familiar with a new codebase",
        steps: [
          "1. codebase_technologies - What tech stack?",
          "2. codebase_architecture - How is it structured?",
          "3. codebase_search - Find specific functionality",
          "4. code_quality - Assess overall health"
        ],
        expected_time: "5-10 minutes",
        tools_needed: 4
      },
      "implement_new_feature" => %{
        description: "Implementing a new feature from scratch",
        steps: [
          "1. planning_decompose - Break down the feature",
          "2. knowledge_packages - Find relevant libraries",
          "3. codebase_search - Find similar implementations",
          "4. fs_write_file - Write the code",
          "5. code_quality - Validate the implementation"
        ],
        expected_time: "30-60 minutes",
        tools_needed: 5
      },
      "debug_production_issue" => %{
        description: "Debugging a production issue",
        steps: [
          "1. codebase_search - Find relevant code",
          "2. code_todos - Check for incomplete work",
          "3. codebase_dependencies - Check for dependency issues",
          "4. code_quality - Look for quality issues"
        ],
        expected_time: "10-20 minutes",
        tools_needed: 4
      },
      "refactor_legacy_code" => %{
        description: "Refactoring legacy or complex code",
        steps: [
          "1. code_refactor - Find refactoring opportunities",
          "2. knowledge_duplicates - Find duplicate code",
          "3. knowledge_patterns - Find better patterns",
          "4. code_quality - Validate improvements"
        ],
        expected_time: "20-40 minutes",
        tools_needed: 4
      },
      "plan_sprint" => %{
        description: "Planning a sprint or iteration",
        steps: [
          "1. planning_work_plan - Get current plan",
          "2. codebase_summary - Understand current state",
          "3. planning_decompose - Break down large tasks",
          "4. planning_prioritize - Prioritize work"
        ],
        expected_time: "15-30 minutes",
        tools_needed: 4
      }
    }
  end

  @doc """
  Get best practices for tool usage.
  """
  def get_best_practices do
    %{
      tool_selection: [
        "Start with understanding tools (codebase_search, codebase_technologies)",
        "Use planning tools for complex tasks",
        "Add analysis tools for quality assurance",
        "Limit to 6 tools maximum to avoid context overflow"
      ],
      tool_usage: [
        "Use tools in logical sequence (understand → plan → implement → analyze)",
        "Read tool descriptions before using them",
        "Check tool performance characteristics (fast/medium/slow)",
        "Validate results before proceeding to next step"
      ],
      context_management: [
        "Use summary tools to get overview before diving deep",
        "Focus on one category of tools at a time",
        "Don't mix conflicting tools (e.g., codebase_analyze + codebase_search)",
        "Use role-appropriate tools only"
      ],
      performance: [
        "Use fast tools for quick exploration (codebase_search, knowledge_packages)",
        "Use medium tools for detailed work (planning_decompose, code_refactor)",
        "Use slow tools sparingly (codebase_analyze, code_quality)",
        "Avoid running multiple slow tools simultaneously"
      ],
      error_handling: [
        "Always check tool results for errors",
        "Use alternative tools if primary tool fails",
        "Fall back to basic tools (fs_read_file, fs_list_directory) if needed",
        "Report tool failures for system improvement"
      ]
    }
  end

  @doc """
  Get common mistakes to avoid.
  """
  def get_common_mistakes do
    %{
      tool_selection: [
        "Selecting too many tools (causes context overflow)",
        "Using tools outside your role (e.g., PM using code_refactor)",
        "Mixing conflicting tools (e.g., codebase_analyze + codebase_search)",
        "Ignoring tool performance characteristics"
      ],
      tool_usage: [
        "Using tools in wrong sequence (e.g., codebase_analyze before codebase_search)",
        "Not reading tool descriptions before use",
        "Ignoring tool output and proceeding anyway",
        "Using tools for tasks they're not designed for"
      ],
      context_management: [
        "Jumping between unrelated tool categories",
        "Not using summary tools for complex tasks",
        "Overwhelming context with too much information",
        "Not validating tool results before next step"
      ],
      performance: [
        "Running multiple slow tools simultaneously",
        "Using codebase_analyze for simple searches",
        "Not considering tool performance for urgent tasks",
        "Ignoring tool timeout warnings"
      ]
    }
  end

  @doc """
  Get summary of all tool descriptions.
  """
  def get_tool_descriptions_summary do
    EnhancedDescriptions.get_all_descriptions()
    |> Enum.map(fn {name, description} ->
      %{
        name: name,
        description: String.slice(description.description, 0, 100) <> "...",
        category: find_tool_category(name),
        performance: get_tool_performance(name)
      }
    end)
  end

  # Private functions

  defp find_tool_category(tool_name) do
    cond do
      String.starts_with?(tool_name, "codebase_") -> "codebase_understanding"
      String.starts_with?(tool_name, "planning_") -> "planning"
      String.starts_with?(tool_name, "knowledge_") -> "knowledge"
      String.starts_with?(tool_name, "code_") -> "code_analysis"
      String.ends_with?(tool_name, "_summary") -> "summary"
      true -> "basic"
    end
  end

  defp get_tool_performance(tool_name) do
    cond do
      tool_name in ["codebase_search", "knowledge_packages", "planning_work_plan"] -> "fast"
      tool_name in ["codebase_technologies", "planning_decompose", "code_refactor"] -> "medium"
      tool_name in ["codebase_analyze", "code_quality", "code_language_analyze"] -> "slow"
      true -> "unknown"
    end
  end
end
