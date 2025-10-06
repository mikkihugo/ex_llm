defmodule Singularity.Tools.AgentRoles do
  @moduledoc """
  Role-based tool management for AI agents.

  Different agent specializations get different tool sets to:
  1. Reduce cognitive load
  2. Improve context management
  3. Focus on relevant capabilities
  4. Prevent tool confusion
  """

  alias Singularity.Tools.Catalog

  @agent_roles %{
    # Core development roles
    :code_developer => %{
      description: "Full-stack developer agent - writes, analyzes, and maintains code",
      tools: [
        # Code understanding
        "codebase_search",
        "codebase_analyze",
        "codebase_technologies",
        "codebase_architecture",
        # Code analysis  
        "code_refactor",
        "code_complexity",
        "code_todos",
        "code_quality",
        # Knowledge
        "knowledge_packages",
        "knowledge_patterns",
        "knowledge_examples",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_write_file",
        "fs_read_file"
      ]
    },
    :architecture_analyst => %{
      description: "System architecture specialist - analyzes and designs system architecture",
      tools: [
        # Architecture focus
        "codebase_architecture",
        "codebase_dependencies",
        "codebase_services",
        "codebase_analyze",
        "codebase_technologies",
        # Planning
        "planning_work_plan",
        "planning_estimate",
        "planning_dependencies",
        # Knowledge
        "knowledge_frameworks",
        "knowledge_patterns",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ]
    },
    :quality_engineer => %{
      description:
        "Code quality specialist - ensures code quality, security, and maintainability",
      tools: [
        # Quality focus
        "code_quality",
        "code_refactor",
        "code_complexity",
        "code_consolidate",
        "code_todos",
        "code_language_analyze",
        # Code understanding
        "codebase_search",
        "codebase_analyze",
        # Knowledge
        "knowledge_duplicates",
        "knowledge_patterns",
        # Quality tools
        "quality_sobelow",
        "quality_mix_audit",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ]
    },
    :project_manager => %{
      description: "Project management specialist - plans, prioritizes, and coordinates work",
      tools: [
        # Planning focus
        "planning_work_plan",
        "planning_decompose",
        "planning_prioritize",
        "planning_estimate",
        "planning_dependencies",
        "planning_execute",
        # High-level understanding
        "codebase_architecture",
        "codebase_technologies",
        # Knowledge
        "knowledge_packages",
        "knowledge_frameworks",
        # Summary tools
        "planning_summary",
        "codebase_summary",
        # Basic tools
        "fs_list_directory",
        "fs_read_file"
      ]
    },
    :knowledge_curator => %{
      description: "Knowledge management specialist - maintains and searches knowledge base",
      tools: [
        # Knowledge focus
        "knowledge_packages",
        "knowledge_patterns",
        "knowledge_frameworks",
        "knowledge_examples",
        "knowledge_duplicates",
        "knowledge_documentation",
        # Search
        "codebase_search",
        "web_search",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ]
    },
    :devops_engineer => %{
      description: "DevOps specialist - handles deployment, monitoring, and infrastructure",
      tools: [
        # Infrastructure focus
        "codebase_services",
        "codebase_technologies",
        "codebase_dependencies",
        # Analysis
        "code_language_analyze",
        "code_quality",
        # Knowledge
        "knowledge_packages",
        "knowledge_frameworks",
        # Shell tools
        "sh_run_command",
        "fs_list_directory",
        "fs_search_content",
        "fs_read_file"
      ]
    },

    # Language specialist (polyglot)
    :language_specialist => %{
      description:
        "Language specialist - focuses on code analysis and optimization across all supported languages",
      tools: [
        # Language analysis focus
        "code_language_analyze",
        "code_quality",
        "code_complexity",
        # Code understanding
        "codebase_search",
        "codebase_analyze",
        "codebase_technologies",
        # Knowledge
        "knowledge_packages",
        "knowledge_patterns",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_write_file",
        "fs_read_file"
      ]
    },
    :generalist => %{
      description: "General purpose agent - has access to most tools for broad tasks",
      tools: [
        # Core understanding
        "codebase_search",
        "codebase_analyze",
        "codebase_technologies",
        # Planning
        "planning_work_plan",
        "planning_decompose",
        "planning_estimate",
        # Knowledge
        "knowledge_packages",
        "knowledge_patterns",
        "knowledge_examples",
        # Analysis
        "code_quality",
        "code_refactor",
        "code_todos",
        # Summary
        "tools_summary",
        "codebase_summary",
        "planning_summary",
        # Basic tools
        "fs_list_directory",
        "fs_search_content",
        "fs_write_file",
        "fs_read_file"
      ]
    }
  }

  @doc """
  Get available agent roles and their descriptions.
  """
  def get_roles do
    @agent_roles
  end

  @doc """
  Get tools for a specific agent role.
  """
  def get_tools_for_role(role) when is_atom(role) do
    case Map.get(@agent_roles, role) do
      nil -> {:error, "Unknown role: #{role}"}
      role_info -> {:ok, role_info.tools}
    end
  end

  @doc """
  Get role description and tool count.
  """
  def get_role_info(role) when is_atom(role) do
    case Map.get(@agent_roles, role) do
      nil ->
        {:error, "Unknown role: #{role}"}

      role_info ->
        {:ok,
         %{
           role: role,
           description: role_info.description,
           tool_count: length(role_info.tools),
           tools: role_info.tools
         }}
    end
  end

  @doc """
  Register tools for a specific agent role.
  """
  def add_tools_for_role(provider, role) when is_atom(role) do
    case get_tools_for_role(role) do
      {:ok, tool_names} ->
        # Register only the tools for this role
        tools = load_tools_by_names(tool_names)
        Singularity.Tools.Catalog.add_tools(provider, tools)
        {:ok, length(tools)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get recommended role based on task description.
  """
  def recommend_role(task_description) when is_binary(task_description) do
    task_lower = String.downcase(task_description)

    cond do
      # Architecture keywords
      String.contains?(task_lower, ["architecture", "design", "system", "microservice", "service"]) ->
        :architecture_analyst

      # Quality keywords  
      String.contains?(task_lower, ["quality", "refactor", "clean", "security", "audit", "review"]) ->
        :quality_engineer

      # Planning keywords
      String.contains?(task_lower, [
        "plan",
        "prioritize",
        "estimate",
        "project",
        "manage",
        "coordinate"
      ]) ->
        :project_manager

      # Knowledge keywords
      String.contains?(task_lower, [
        "document",
        "search",
        "find",
        "pattern",
        "example",
        "knowledge"
      ]) ->
        :knowledge_curator

      # DevOps keywords
      String.contains?(task_lower, [
        "deploy",
        "infrastructure",
        "monitor",
        "ops",
        "devops",
        "ci/cd"
      ]) ->
        :devops_engineer

      # Language analysis keywords
      String.contains?(task_lower, [
        "analyze",
        "optimize",
        "performance",
        "security",
        "dependencies",
        "language"
      ]) ->
        :language_specialist

      # Default to generalist
      true ->
        :generalist
    end
  end

  # Private functions

  defp load_tools_by_names(tool_names) do
    # This would load actual tool definitions by name
    # For now, return placeholder tool names
    Enum.map(tool_names, fn name ->
      %{name: name, description: "Tool: #{name}"}
    end)
  end
end
