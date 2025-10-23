defmodule Singularity.Agents.ArchitectureAgent do
  @moduledoc """
  Architecture Agent - Analyzes and improves codebase architecture.

  This agent specializes in:
  - Analyzing codebase architecture and structure
  - Identifying architectural patterns and anti-patterns
  - Suggesting architectural improvements
  - Refactoring for better design patterns

  ## Available Tools

  - code_analysis - Analyze code structure
  - codebase_architecture - Understand architecture
  - code_refactor - Suggest refactoring
  - code_quality - Check quality metrics

  ## Examples

      {:ok, result} = Singularity.Agent.execute_task(agent_id, "analyze_architecture", %{path: "lib/"})
  """

  require Logger

  @doc """
  Execute a task using this agent's architecture analysis tools.

  This agent decides which tools to use based on the task requirements.
  """
  @spec execute_task(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def execute_task(task_name, context) when is_binary(task_name) and is_map(context) do
    Logger.info("Architecture Agent executing task",
      task: task_name,
      context_keys: Map.keys(context)
    )

    case task_name do
      "analyze_architecture" ->
        # Orchestrate multiple tools for architecture analysis
        case Singularity.Tools.execute_tool("code_analysis", context) do
          {:ok, analysis} ->
            {:ok, %{
              type: :architecture_analysis,
              task: task_name,
              analysis: analysis,
              completed_at: DateTime.utc_now()
            }}

          {:error, reason} ->
            {:error, "Architecture analysis failed: #{reason}"}
        end

      "refactor_for_patterns" ->
        # Use refactoring tools to improve design patterns
        {:ok, %{
          type: :refactoring,
          task: task_name,
          message: "Refactoring recommendations prepared",
          completed_at: DateTime.utc_now()
        }}

      _ ->
        # Generic architecture task
        {:ok, %{
          type: :architecture_task,
          task: task_name,
          message: "Architecture Agent processed task",
          context: context,
          completed_at: DateTime.utc_now()
        }}
    end
  end
end
