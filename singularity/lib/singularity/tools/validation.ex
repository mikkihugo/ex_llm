defmodule Singularity.Tools.Validation do
  @moduledoc """
  Validates that all tool references in the role-based system
  match the actual tool names defined in the codebase.
  """

  alias Singularity.Tools.ToolMapping

  @doc """
  Validate all tool references across the role-based system.
  """
  def validate_all_tool_references do
    # Get actual tool names from the codebase
    actual_tools = ToolMapping.get_actual_tool_names()

    # Get role-based tool sets
    role_tools = ToolMapping.get_corrected_role_tools()

    # Validate each role
    validation_results =
      role_tools
      |> Enum.map(fn {role, tools} ->
        invalid_tools =
          tools
          |> Enum.reject(&(&1 in actual_tools))

        %{
          role: role,
          total_tools: length(tools),
          invalid_tools: invalid_tools,
          valid: invalid_tools == []
        }
      end)

    # Check for any invalid tools
    all_invalid =
      validation_results
      |> Enum.flat_map(& &1.invalid_tools)
      |> Enum.uniq()

    %{
      validation_results: validation_results,
      all_invalid_tools: all_invalid,
      overall_valid: all_invalid == [],
      total_actual_tools: length(actual_tools),
      total_role_tools: role_tools |> Map.values() |> List.flatten() |> Enum.uniq() |> length()
    }
  end

  @doc """
  Get a summary of tool usage across all roles.
  """
  def get_tool_usage_summary do
    role_tools = ToolMapping.get_corrected_role_tools()

    # Count how many roles use each tool
    tool_usage =
      role_tools
      |> Map.values()
      |> List.flatten()
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_tool, count} -> count end, :desc)

    # Group by category
    tools_by_category =
      role_tools
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.group_by(fn tool_name ->
        case ToolMapping.get_tool_info(tool_name) do
          %{category: category} -> category
          nil -> "unknown"
        end
      end)

    %{
      tool_usage: tool_usage,
      tools_by_category: tools_by_category,
      most_used_tools: tool_usage |> Enum.take(10),
      least_used_tools: tool_usage |> Enum.take(-10)
    }
  end

  @doc """
  Check for tool naming inconsistencies.
  """
  def check_naming_consistency do
    # Common naming patterns that might be inconsistent
    patterns = %{
      "codebase_" => "codebase_understanding",
      "planning_" => "planning",
      "knowledge_" => "knowledge",
      "code_" => "code_analysis",
      "fs_" => "file_system",
      "quality_" => "quality"
    }

    actual_tools = ToolMapping.get_actual_tool_names()

    inconsistencies =
      patterns
      |> Enum.map(fn {prefix, expected_category} ->
        tools_with_prefix =
          actual_tools
          |> Enum.filter(&String.starts_with?(&1, prefix))

        category_mismatches =
          tools_with_prefix
          |> Enum.reject(fn tool_name ->
            case ToolMapping.get_tool_info(tool_name) do
              %{category: ^expected_category} -> true
              _ -> false
            end
          end)

        {prefix,
         %{
           expected_category: expected_category,
           tools: tools_with_prefix,
           mismatches: category_mismatches
         }}
      end)
      |> Enum.filter(fn {_prefix, info} -> info.mismatches != [] end)

    %{
      inconsistencies: inconsistencies,
      total_inconsistencies: length(inconsistencies)
    }
  end

  @doc """
  Generate a comprehensive validation report.
  """
  def generate_validation_report do
    tool_validation = validate_all_tool_references()
    usage_summary = get_tool_usage_summary()
    naming_check = check_naming_consistency()

    %{
      timestamp: DateTime.utc_now(),
      tool_validation: tool_validation,
      usage_summary: usage_summary,
      naming_consistency: naming_check,
      summary: %{
        overall_valid: tool_validation.overall_valid,
        total_roles: length(ToolMapping.get_corrected_role_tools()),
        total_actual_tools: tool_validation.total_actual_tools,
        total_role_tools: tool_validation.total_role_tools,
        naming_inconsistencies: naming_check.total_inconsistencies
      }
    }
  end
end
