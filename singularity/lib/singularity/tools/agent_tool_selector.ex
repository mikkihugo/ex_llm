defmodule Singularity.Tools.AgentToolSelector do
  @moduledoc """
  DEPRECATED: Use `Singularity.Tools.ToolSelector` instead.

  This module has been consolidated into ToolSelector for better
  organization and to eliminate duplication.

  All functions now forward to ToolSelector. This wrapper will be
  removed in a future version.

  ## Migration Guide

  Replace all imports:
  ```elixir
  # Old
  alias Singularity.Tools.AgentToolSelector
  AgentToolSelector.recommend_tools(task, context)

  # New
  alias Singularity.Tools.ToolSelector
  ToolSelector.recommend_tools(task, context)
  ```

  ## Function Mapping

  - `AgentToolSelector.recommend_tools/2` → `ToolSelector.recommend_tools/2`
  - `AgentToolSelector.get_tool_guidance/1` → `ToolSelector.get_tool_guidance/1`
  - `AgentToolSelector.get_related_tools/1` → `ToolSelector.get_related_tools/1`
  - `AgentToolSelector.get_tool_performance/1` → `ToolSelector.get_tool_performance/1`
  - `AgentToolSelector.get_workflows/0` → `ToolSelector.get_workflows/0`
  """

  alias Singularity.Tools.ToolSelector

  @deprecated "Use Singularity.Tools.ToolSelector.recommend_tools/2 instead"
  def recommend_tools(task_description, context \\ %{}) do
    ToolSelector.recommend_tools(task_description, context)
  end

  @deprecated "Use Singularity.Tools.ToolSelector.get_tool_guidance/1 instead"
  def get_tool_guidance(tool_name) do
    ToolSelector.get_tool_guidance(tool_name)
  end

  @deprecated "Use Singularity.Tools.ToolSelector.get_related_tools/1 instead"
  def get_related_tools(tool_name) do
    ToolSelector.get_related_tools(tool_name)
  end

  @deprecated "Use Singularity.Tools.ToolSelector.get_tool_performance/1 instead"
  def get_tool_performance(tool_names) do
    ToolSelector.get_tool_performance(tool_names)
  end

  @deprecated "Use Singularity.Tools.ToolSelector.get_workflows/0 instead"
  def get_workflows do
    ToolSelector.get_workflows()
  end
end
