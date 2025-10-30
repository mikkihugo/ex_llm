defmodule Singularity.Workflows.Analysis do
  @moduledoc """
  Analysis workflows using ex_quantum_flow for orchestration.
  """

  alias Singularity.Analysis

  @doc """
  Run code analysis workflow.
  """
  def run(%{
    type: type,
    installation_id: installation_id,
    repo_owner: repo_owner,
    repo_name: repo_name,
    commit_sha: commit_sha
  } = params) do
    # Create analysis workflow using ex_quantum_flow
    workflow_params = %{
      "type" => Atom.to_string(type),
      "installation_id" => installation_id,
      "repo_owner" => repo_owner,
      "repo_name" => repo_name,
      "commit_sha" => commit_sha,
      "pr_number" => params[:pr_number],
      "check_run_id" => params[:check_run_id]
    }

    # Start workflow
    case Singularity.Workflows.CodeAnalysis.execute(workflow_params) do
      {:ok, workflow_run} ->
        # Monitor workflow completion
        Task.start(fn ->
          monitor_workflow(workflow_run.id)
        end)

        {:ok, workflow_run.id}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Monitor workflow completion and handle results.
  """
  def monitor_workflow(workflow_id) do
    # Poll workflow status (in production, use webhooks)
    case wait_for_completion(workflow_id) do
      {:completed, results} ->
        Analysis.handle_analysis_complete(%{
          workflow_id: workflow_id,
          results: results,
          error: nil
        })

      {:failed, error} ->
        Analysis.handle_analysis_complete(%{
          workflow_id: workflow_id,
          results: nil,
          error: error
        })
    end
  end

  defp wait_for_completion(workflow_id) do
    # Simple polling - in production use ex_quantum_flow webhooks
    Enum.reduce_while(1..60, nil, fn _attempt, _acc ->
      case check_workflow_status(workflow_id) do
        {:completed, results} -> {:halt, {:completed, results}}
        {:failed, error} -> {:halt, {:failed, error}}
        :running -> {:cont, :running}
      end

      # Wait 5 seconds between checks
      :timer.sleep(5000)
    end)
  end

  defp check_workflow_status(workflow_id) do
    # Check ex_quantum_flow workflow status
    case Singularity.Workflows.get_status(workflow_id) do
      {:ok, %{status: "completed", results: results}} ->
        {:completed, results}

      {:ok, %{status: "failed", error: error}} ->
        {:failed, error}

      {:ok, %{status: "running"}} ->
        :running

      _ ->
        :running
    end
  end
end