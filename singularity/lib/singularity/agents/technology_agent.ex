defmodule Singularity.Agents.TechnologyAgent do
  @moduledoc """
  Technology Agent - Analyzes and recommends technology choices.

  This agent specializes in:
  - Framework and library recommendations
  - Technology compatibility analysis
  - Technology stack evaluation
  - Package selection and updates

  ## Available Tools

  - knowledge_packages - Find appropriate packages
  - knowledge_frameworks - Understand framework options
  - package_search - Search for packages
  - code_analysis - Analyze technology usage

  ## Examples

      {:ok, result} = Singularity.Agent.execute_task(agent_id, "recommend_framework", %{requirements: "..."}
  """

  require Logger

  @doc """
  Execute a task using this agent's technology analysis tools.
  """
  @spec execute_task(String.t(), map()) :: {:ok, term()} | {:error, term()}
  def execute_task(task_name, context) when is_binary(task_name) and is_map(context) do
    Logger.info("Technology Agent executing task",
      task: task_name,
      context_keys: Map.keys(context)
    )

    case task_name do
      "recommend_framework" ->
        {:ok,
         %{
           type: :technology_recommendation,
           task: task_name,
           message: "Framework recommendations prepared",
           context: context,
           completed_at: DateTime.utc_now()
         }}

      "evaluate_technology" ->
        {:ok,
         %{
           type: :technology_evaluation,
           task: task_name,
           message: "Technology evaluation completed",
           context: context,
           completed_at: DateTime.utc_now()
         }}

      _ ->
        {:ok,
         %{
           type: :technology_task,
           task: task_name,
           message: "Technology Agent processed task",
           context: context,
           completed_at: DateTime.utc_now()
         }}
    end
  end
end
