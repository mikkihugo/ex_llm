defmodule Singularity.Tools.FinalValidation do
  @moduledoc """
  Final validation of tool names and role-based system.
  """

  @actual_tools %{
    # Basic Tools
    "fs_list_directory" => true,
    "fs_search_content" => true,
    "fs_write_file" => true,
    "fs_read_file" => true,
    "sh_run_command" => true,
    "net_http_fetch" => true,
    "gh_graphql_query" => true,
    "web_search" => true,

    # Codebase Understanding Tools
    "codebase_search" => true,
    "codebase_analyze" => true,
    "codebase_technologies" => true,
    "codebase_dependencies" => true,
    "codebase_services" => true,
    "codebase_architecture" => true,

    # Planning Tools
    "planning_work_plan" => true,
    "planning_decompose" => true,
    "planning_prioritize" => true,
    "planning_estimate" => true,
    "planning_dependencies" => true,
    "planning_execute" => true,

    # Knowledge Tools
    "knowledge_packages" => true,
    "knowledge_patterns" => true,
    "knowledge_frameworks" => true,
    "knowledge_examples" => true,
    "knowledge_duplicates" => true,
    "knowledge_documentation" => true,

    # Code Analysis Tools
    "code_refactor" => true,
    "code_complexity" => true,
    "code_todos" => true,
    "code_consolidate" => true,
    # Updated from code_rust_analyze
    "code_language_analyze" => true,
    "code_quality" => true,

    # Summary Tools
    "tools_summary" => true,
    "codebase_summary" => true,
    "planning_summary" => true,
    "knowledge_summary" => true,

    # Quality Tools
    "quality_sobelow" => true,
    "quality_mix_audit" => true
  }

  @corrected_roles %{
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
    language_specialist: [
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

  @doc """
  Validate all tool names are correct and exist.
  """
  def validate_tool_names do
    all_role_tools =
      @corrected_roles
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()

    invalid_tools =
      all_role_tools
      |> Enum.reject(&Map.has_key?(@actual_tools, &1))

    %{
      total_tools: length(@actual_tools),
      total_role_tools: length(all_role_tools),
      invalid_tools: invalid_tools,
      valid: invalid_tools == []
    }
  end

  @doc """
  Get tool prefix analysis.
  """
  def analyze_tool_prefixes do
    @actual_tools
    |> Map.keys()
    |> Enum.group_by(fn tool_name ->
      cond do
        String.starts_with?(tool_name, "codebase_") -> "codebase_"
        String.starts_with?(tool_name, "planning_") -> "planning_"
        String.starts_with?(tool_name, "knowledge_") -> "knowledge_"
        String.starts_with?(tool_name, "code_") -> "code_"
        String.starts_with?(tool_name, "fs_") -> "fs_"
        String.starts_with?(tool_name, "quality_") -> "quality_"
        String.ends_with?(tool_name, "_summary") -> "_summary"
        true -> "other"
      end
    end)
  end

  @doc """
  Get role tool counts.
  """
  def get_role_tool_counts do
    @corrected_roles
    |> Enum.map(fn {role, tools} -> {role, length(tools)} end)
    |> Enum.into(%{})
  end

  @doc """
  Generate final validation report.
  """
  def generate_report do
    tool_validation = validate_tool_names()
    prefix_analysis = analyze_tool_prefixes()
    role_counts = get_role_tool_counts()

    %{
      timestamp: DateTime.utc_now(),
      tool_validation: tool_validation,
      prefix_analysis: prefix_analysis,
      role_counts: role_counts,
      summary: %{
        all_tools_valid: tool_validation.valid,
        total_actual_tools: tool_validation.total_tools,
        total_role_tools: tool_validation.total_role_tools,
        role_count: length(@corrected_roles),
        # Exclude "other"
        prefixed_tools: length(prefix_analysis) - 1,
        # code_language_analyze supports multiple languages
        polyglot_support: true
      }
    }
  end
end
