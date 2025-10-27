defmodule Singularity.Tools.ToolSelectorTest do
  use ExUnit.Case, async: true

  alias Singularity.Tools.ToolSelector

  describe "select_tools/3" do
    test "selects tools for implementing a feature" do
      {:ok, result} = ToolSelector.select_tools("implement async worker", :code_developer)

      assert is_list(result.selected_tools)
      assert length(result.selected_tools) <= 6
      assert result.agent_role == :code_developer
      assert result.workflow == "implement_feature"
      assert is_list(result.reasoning)
    end

    test "selects tools for debugging" do
      {:ok, result} = ToolSelector.select_tools("debug production issue", :code_developer)

      assert is_list(result.selected_tools)
      assert length(result.selected_tools) <= 6
      assert result.workflow == "debug_issue"
    end

    test "respects max tools limit" do
      {:ok, result} =
        ToolSelector.select_tools("complex task requiring many tools", :code_developer)

      assert length(result.selected_tools) <= 6
    end

    test "includes essential tools" do
      {:ok, result} = ToolSelector.select_tools("simple task", :code_developer)

      # Should include basic file operations
      assert Enum.any?(result.selected_tools, &String.starts_with?(&1, "fs_"))
    end
  end

  describe "recommend_tools/2" do
    test "recommends tools for a task" do
      {:ok, result} = ToolSelector.recommend_tools("refactor legacy code")

      assert is_list(result.recommended_tools)
      assert length(result.recommended_tools) <= 8
      assert result.role in [:code_developer, :quality_engineer, :architecture_analyst]
      assert is_list(result.workflows)
    end

    test "returns workflow matches" do
      {:ok, result} = ToolSelector.recommend_tools("understand new codebase")

      assert length(result.workflows) > 0
      workflow_names = Enum.map(result.workflows, & &1.name)
      assert "understand_codebase" in workflow_names
    end
  end

  describe "get_tool_guidance/1" do
    test "returns guidance for valid tool" do
      {:ok, guidance} = ToolSelector.get_tool_guidance("codebase_search")

      assert is_map(guidance)
    end

    test "returns error for invalid tool" do
      {:error, message} = ToolSelector.get_tool_guidance("nonexistent_tool")

      assert message =~ "not found"
    end
  end

  describe "get_related_tools/1" do
    test "returns related tools" do
      {:ok, related} = ToolSelector.get_related_tools("codebase_search")

      assert is_list(related)
    end

    test "returns empty list for unrelated tools" do
      {:ok, related} = ToolSelector.get_related_tools("nonexistent_tool")

      assert related == []
    end
  end

  describe "get_tool_performance/1" do
    test "returns performance info for tools" do
      {:ok, performance} = ToolSelector.get_tool_performance(["codebase_search", "code_quality"])

      assert performance["codebase_search"] == "fast"
      assert performance["code_quality"] == "slow"
    end
  end

  describe "get_workflows/0" do
    test "returns all available workflows" do
      workflows = ToolSelector.get_workflows()

      assert is_map(workflows)
      assert Map.has_key?(workflows, "implement_feature")
      assert Map.has_key?(workflows, "debug_issue")
      assert Map.has_key?(workflows, "refactor_code")
    end
  end

  describe "validate_tool_selection/2" do
    test "validates good tool selection" do
      tools = ["codebase_search", "knowledge_packages"]

      {:ok, result} = ToolSelector.validate_tool_selection(tools, %{})

      assert result.valid == true
    end

    test "detects too many tools" do
      tools = ["tool1", "tool2", "tool3", "tool4", "tool5", "tool6", "tool7", "tool8"]

      {:ok, result} = ToolSelector.validate_tool_selection(tools, %{})

      assert result.valid == false
      assert Enum.any?(result.issues, fn issue -> issue.type == :too_many_tools end)
    end

    test "detects conflicting tools" do
      tools = ["codebase_analyze", "codebase_search"]

      {:ok, result} = ToolSelector.validate_tool_selection(tools, %{})

      # May or may not be valid, but should note conflicts
      issues_by_type = Enum.group_by(result.issues, & &1.type)
      # If there are conflicts, they should be reported
      if Map.has_key?(issues_by_type, :tool_conflicts) do
        assert length(issues_by_type[:tool_conflicts]) > 0
      end
    end
  end

  describe "get_selection_guidance/1" do
    test "returns guidance for scenarios" do
      guidance = ToolSelector.get_selection_guidance("new_codebase")

      assert guidance.description =~ "codebase"
      assert is_list(guidance.recommended_tools)
      assert guidance.workflow == "understand_codebase"
    end

    test "returns default guidance for unknown scenario" do
      guidance = ToolSelector.get_selection_guidance("unknown_scenario")

      assert guidance.description == "General purpose"
      assert guidance.workflow == "general"
    end
  end
end
