defmodule Singularity.Tools.ToolMapping do
  @moduledoc """
  Maps actual tool names to their descriptions and categories.

  This ensures the role-based system uses the correct tool names
  that are actually defined in the codebase.
  """

  @actual_tools %{
    # Basic Tools (from basic.ex and default.ex)
    "fs_list_directory" => %{
      category: "file_system",
      description: "List files and folders within a directory",
      performance: "fast"
    },
    "fs_search_content" => %{
      category: "file_system",
      description: "Search source files for a pattern and return matching lines",
      performance: "medium"
    },
    "fs_write_file" => %{
      category: "file_system",
      description: "Write text to a file under the repository root",
      performance: "fast"
    },
    "fs_read_file" => %{
      category: "file_system",
      description: "Read a text file relative to the workspace root",
      performance: "fast"
    },
    "net_http_fetch" => %{
      category: "network",
      description: "Fetch an HTTP(s) URL and return status, headers, and body text",
      performance: "medium"
    },
    "gh_graphql_query" => %{
      category: "network",
      description: "Use GitHub's GraphQL API to read repository metadata or file contents",
      performance: "medium"
    },
    "sh_run_command" => %{
      category: "shell",
      description: "Execute a whitelisted shell command (ls, cat, pwd)",
      performance: "fast"
    },

    # Codebase Understanding Tools (from codebase_understanding.ex)
    "codebase_search" => %{
      category: "codebase_understanding",
      description:
        "Search codebase using semantic similarity. Find code by natural language description",
      performance: "fast"
    },
    "codebase_analyze" => %{
      category: "codebase_understanding",
      description:
        "Perform comprehensive codebase analysis including architecture, patterns, and quality metrics",
      performance: "slow"
    },
    "codebase_technologies" => %{
      category: "codebase_understanding",
      description: "Detect technologies, frameworks, and tools used in the codebase",
      performance: "medium"
    },
    "codebase_dependencies" => %{
      category: "codebase_understanding",
      description: "Analyze dependencies and coupling between services/modules",
      performance: "medium"
    },
    "codebase_services" => %{
      category: "codebase_understanding",
      description: "Analyze microservices and their structure, dependencies, and health",
      performance: "medium"
    },
    "codebase_architecture" => %{
      category: "codebase_understanding",
      description: "Get high-level architecture overview and patterns",
      performance: "slow"
    },

    # Planning Tools (from planning.ex)
    "planning_work_plan" => %{
      category: "planning",
      description:
        "Get current work plan with strategic themes, epics, capabilities, and features",
      performance: "fast"
    },
    "planning_decompose" => %{
      category: "planning",
      description: "Break down a high-level task into smaller, manageable subtasks using TaskGraph",
      performance: "medium"
    },
    "planning_prioritize" => %{
      category: "planning",
      description: "Prioritize tasks using WSJF (Weighted Shortest Job First) methodology",
      performance: "fast"
    },
    "planning_estimate" => %{
      category: "planning",
      description: "Estimate effort and complexity for tasks using historical data and patterns",
      performance: "medium"
    },
    "planning_dependencies" => %{
      category: "planning",
      description: "Analyze task dependencies and identify critical path",
      performance: "medium"
    },
    "planning_execute" => %{
      category: "planning",
      description: "Execute a planned task through the execution coordinator",
      performance: "fast"
    },

    # Knowledge Tools (from knowledge.ex)
    "knowledge_packages" => %{
      category: "knowledge",
      description: "Search package registries (npm, cargo, hex, pypi) for libraries and tools",
      performance: "fast"
    },
    "knowledge_patterns" => %{
      category: "knowledge",
      description: "Find code patterns and templates from existing codebases",
      performance: "medium"
    },
    "knowledge_frameworks" => %{
      category: "knowledge",
      description: "Search framework patterns and best practices",
      performance: "fast"
    },
    "knowledge_examples" => %{
      category: "knowledge",
      description: "Find code examples and usage patterns from package registries",
      performance: "fast"
    },
    "knowledge_duplicates" => %{
      category: "knowledge",
      description: "Find duplicate or similar code patterns in the codebase",
      performance: "medium"
    },
    "knowledge_documentation" => %{
      category: "knowledge",
      description: "Generate or find documentation for code, patterns, or frameworks",
      performance: "medium"
    },

    # Code Analysis Tools (from code_analysis.ex)
    "code_refactor" => %{
      category: "code_analysis",
      description: "Analyze code for refactoring opportunities and suggest improvements",
      performance: "medium"
    },
    "code_complexity" => %{
      category: "code_analysis",
      description: "Analyze code complexity metrics and identify overly complex areas",
      performance: "medium"
    },
    "code_todos" => %{
      category: "code_analysis",
      description: "Find TODO items, incomplete implementations, and missing components",
      performance: "fast"
    },
    "code_consolidate" => %{
      category: "code_analysis",
      description: "Find opportunities to consolidate duplicate or similar code",
      performance: "medium"
    },
    "code_language_analyze" => %{
      category: "code_analysis",
      description:
        "Perform comprehensive language-specific code analysis including security, performance, and dependencies for any supported language",
      performance: "slow"
    },
    "code_quality" => %{
      category: "code_analysis",
      description:
        "Comprehensive code quality assessment including metrics, patterns, and best practices",
      performance: "slow"
    },

    # Summary Tools (from summary.ex)
    "tools_summary" => %{
      category: "summary",
      description: "Get a summary of all available tools and their capabilities",
      performance: "fast"
    },
    "codebase_summary" => %{
      category: "summary",
      description: "Get a high-level summary of the current codebase state and health",
      performance: "medium"
    },
    "planning_summary" => %{
      category: "summary",
      description: "Get a summary of current work plan, priorities, and progress",
      performance: "fast"
    },
    "knowledge_summary" => %{
      category: "summary",
      description: "Get a summary of available knowledge, patterns, and examples",
      performance: "fast"
    },

    # Quality Tools (from quality.ex)
    "quality_sobelow" => %{
      category: "quality",
      description: "Run Sobelow security scan and store results",
      performance: "medium"
    },
    "quality_mix_audit" => %{
      category: "quality",
      description: "Run Hex package vulnerability audit",
      performance: "medium"
    },

    # Web Search Tools (from web_search.ex)
    "web_search" => %{
      category: "network",
      description: "Web search tool that uses LLM provider APIs with built-in search",
      performance: "medium"
    }
  }

  @doc """
  Get all actual tool names that are defined in the codebase.
  """
  def get_actual_tool_names do
    Map.keys(@actual_tools)
  end

  @doc """
  Get tool information by name.
  """
  def get_tool_info(tool_name) do
    Map.get(@actual_tools, tool_name)
  end

  @doc """
  Get tools by category.
  """
  def get_tools_by_category(category) do
    @actual_tools
    |> Enum.filter(fn {_name, info} -> info.category == category end)
    |> Enum.map(fn {name, info} -> Map.put(info, :name, name) end)
  end

  @doc """
  Get tools by performance level.
  """
  def get_tools_by_performance(performance) do
    @actual_tools
    |> Enum.filter(fn {_name, info} -> info.performance == performance end)
    |> Enum.map(fn {name, info} -> Map.put(info, :name, name) end)
  end

  @doc """
  Validate that tool names exist in the actual codebase.
  """
  def validate_tool_names(tool_names) when is_list(tool_names) do
    actual_tools = get_actual_tool_names()

    invalid_tools =
      tool_names
      |> Enum.reject(&(&1 in actual_tools))

    if invalid_tools == [] do
      {:ok, %{valid: true, tools: tool_names}}
    else
      {:error,
       %{valid: false, invalid_tools: invalid_tools, valid_tools: tool_names -- invalid_tools}}
    end
  end

  @doc """
  Get corrected role-based tool sets using actual tool names.
  """
  def get_corrected_role_tools do
    %{
      code_developer: [
        "codebase_search",
        "codebase_analyze",
        "codebase_technologies",
        "codebase_architecture",
        "code_refactor",
        "code_complexity",
        "code_todos",
        "code_quality",
        "knowledge_packages",
        "knowledge_patterns",
        "knowledge_examples",
        "fs_list_directory",
        "fs_search_content",
        "fs_write_file",
        "fs_read_file"
      ],
      architecture_analyst: [
        "codebase_architecture",
        "codebase_dependencies",
        "codebase_services",
        "codebase_analyze",
        "codebase_technologies",
        "planning_work_plan",
        "planning_estimate",
        "planning_dependencies",
        "knowledge_frameworks",
        "knowledge_patterns",
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ],
      quality_engineer: [
        "code_quality",
        "code_refactor",
        "code_complexity",
        "code_consolidate",
        "code_todos",
        "code_language_analyze",
        "codebase_search",
        "codebase_analyze",
        "knowledge_duplicates",
        "knowledge_patterns",
        "quality_sobelow",
        "quality_mix_audit",
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ],
      project_manager: [
        "planning_work_plan",
        "planning_decompose",
        "planning_prioritize",
        "planning_estimate",
        "planning_dependencies",
        "planning_execute",
        "codebase_architecture",
        "codebase_technologies",
        "knowledge_packages",
        "knowledge_frameworks",
        "planning_summary",
        "codebase_summary",
        "fs_list_directory",
        "fs_read_file"
      ],
      knowledge_curator: [
        "knowledge_packages",
        "knowledge_patterns",
        "knowledge_frameworks",
        "knowledge_examples",
        "knowledge_duplicates",
        "knowledge_documentation",
        "codebase_search",
        "web_search",
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ],
      devops_engineer: [
        "codebase_services",
        "codebase_technologies",
        "codebase_dependencies",
        "code_language_analyze",
        "code_quality",
        "knowledge_packages",
        "knowledge_frameworks",
        "sh_run_command",
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ],
      rust_specialist: [
        "code_language_analyze",
        "code_quality",
        "code_complexity",
        "codebase_search",
        "codebase_analyze",
        "codebase_technologies",
        "knowledge_packages",
        "knowledge_patterns",
        "fs_list_directory",
        "fs_search_content",
        "fs_write_file",
        "fs_read_file"
      ],
      frontend_specialist: [
        "codebase_search",
        "codebase_technologies",
        "code_quality",
        "knowledge_packages",
        "knowledge_frameworks",
        "knowledge_examples",
        "code_refactor",
        "code_todos",
        "fs_list_directory",
        "fs_search_content",
        "fs_write_file",
        "fs_read_file"
      ],
      generalist: [
        "codebase_search",
        "codebase_analyze",
        "codebase_technologies",
        "planning_work_plan",
        "planning_decompose",
        "planning_estimate",
        "knowledge_packages",
        "knowledge_patterns",
        "knowledge_examples",
        "code_quality",
        "code_refactor",
        "code_todos",
        "tools_summary",
        "codebase_summary",
        "planning_summary",
        "fs_list_directory",
        "fs_search_content",
        "fs_write_file",
        "fs_read_file"
      ]
    }
  end

  @doc """
  Get tool count by category.
  """
  def get_tool_counts_by_category do
    @actual_tools
    |> Enum.group_by(fn {_name, info} -> info.category end)
    |> Enum.map(fn {category, tools} -> {category, length(tools)} end)
    |> Enum.into(%{})
  end

  @doc """
  Get performance distribution.
  """
  def get_performance_distribution do
    @actual_tools
    |> Enum.group_by(fn {_name, info} -> info.performance end)
    |> Enum.map(fn {performance, tools} -> {performance, length(tools)} end)
    |> Enum.into(%{})
  end
end
