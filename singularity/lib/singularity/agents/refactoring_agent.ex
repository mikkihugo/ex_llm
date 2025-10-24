defmodule Singularity.Agents.RefactoringAgent do
  @moduledoc """
  Refactoring Agent Adapter - Delegates to real RefactoringAgent implementation.

  This module exists to maintain the agent specialization API while delegating
  all real work to `Singularity.RefactoringAgent` which has the full implementation.

  ## Agent Specialization

  This is registered as the `:refactoring` agent type in `Singularity.Agent`.

  ## Available Tasks

  - `analyze_refactoring_need` - Analyze codebase for refactoring opportunities
  - `trigger_refactoring` - Execute specific refactoring patterns
  - `assess_impact` - Assess impact of proposed refactoring

  ## Examples

      {:ok, result} = Singularity.Agents.RefactoringAgent.execute_task("analyze_refactoring_need", %{})
  """

  alias Singularity.RefactoringAgent
  require Logger

  @doc """
  Execute a task using the real RefactoringAgent implementation.

  Delegates to `Singularity.RefactoringAgent` which has the full implementation.
  """
  @spec execute_task(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def execute_task(task_name, context) when is_binary(task_name) and is_map(context) do
    Logger.info("Refactoring Agent adapter delegating task",
      task: task_name,
      context_keys: Map.keys(context)
    )

    case task_name do
      "analyze_refactoring_need" ->
        RefactoringAgent.analyze_refactoring_need()

      "trigger_refactoring" ->
        pattern = Map.get(context, :pattern, :extract_method)
        RefactoringAgent.trigger_refactoring(pattern, context)

      "assess_impact" ->
        pattern = Map.get(context, :pattern, :extract_method)
        RefactoringAgent.assess_refactoring_impact(pattern, context)

      "execute_refactoring" ->
        pattern = Map.get(context, :pattern, :extract_method)
        RefactoringAgent.execute_refactoring(pattern, context)

      # Legacy task names (for backward compatibility)
      "refactor_complexity" ->
        RefactoringAgent.trigger_refactoring(:reduce_complexity, context)

      "improve_quality" ->
        RefactoringAgent.trigger_refactoring(:improve_quality, context)

      _ ->
        Logger.warning("Unknown refactoring task", task: task_name)
        {:error, :unknown_task}
    end
  end
end
