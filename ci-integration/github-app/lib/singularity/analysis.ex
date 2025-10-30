defmodule Singularity.Analysis do
  @moduledoc """
  Handles code analysis workflows for GitHub repositories.
  """

  alias Singularity.{Github, Repositories, Workflows}

  @doc """
  Analyze a pull request.
  """
  def analyze_pull_request(%{
    installation_id: installation_id,
    repo_owner: repo_owner,
    repo_name: repo_name,
    pr_number: pr_number,
    head_sha: head_sha,
    base_sha: base_sha
  }) do
    # Create GitHub check run
    {:ok, check_run} = Github.create_check_run(installation_id, repo_owner, repo_name, %{
      name: "Singularity Code Quality",
      head_sha: head_sha,
      status: "in_progress",
      output: %{
        title: "Analyzing code quality...",
        summary: "Singularity is analyzing your code for quality issues and patterns."
      }
    })

    # Start analysis workflow
    case Workflows.Analysis.run(%{
      type: :pull_request,
      installation_id: installation_id,
      repo_owner: repo_owner,
      repo_name: repo_name,
      pr_number: pr_number,
      commit_sha: head_sha,
      check_run_id: check_run["id"]
    }) do
      {:ok, workflow_id} ->
        # Store workflow reference
        Repositories.store_analysis_workflow(%{
          repo_owner: repo_owner,
          repo_name: repo_name,
          pr_number: pr_number,
          workflow_id: workflow_id,
          check_run_id: check_run["id"]
        })

      {:error, error} ->
        # Update check run with failure
        Github.update_check_run(installation_id, repo_owner, repo_name, check_run["id"], %{
          status: "completed",
          conclusion: "failure",
          output: %{
            title: "Analysis failed",
            summary: "Failed to start code analysis: #{inspect(error)}"
          }
        })
    end
  end

  @doc """
  Analyze a commit push.
  """
  def analyze_commit(%{
    installation_id: installation_id,
    repo_owner: repo_owner,
    repo_name: repo_name,
    commit_sha: commit_sha
  }) do
    # Start analysis workflow (no check run for pushes)
    Workflows.Analysis.run(%{
      type: :commit,
      installation_id: installation_id,
      repo_owner: repo_owner,
      repo_name: repo_name,
      commit_sha: commit_sha
    })
  end

  @doc """
  Handle analysis completion.
  """
  def handle_analysis_complete(%{
    workflow_id: workflow_id,
    results: results,
    error: nil
  }) do
    # Get analysis metadata
    case Repositories.get_analysis_workflow(workflow_id) do
      {:ok, metadata} ->
        post_results(metadata, results)
      {:error, _} ->
        Logger.error("Could not find analysis metadata for workflow #{workflow_id}")
    end
  end

  def handle_analysis_complete(%{
    workflow_id: workflow_id,
    results: _results,
    error: error
  }) do
    # Get analysis metadata
    case Repositories.get_analysis_workflow(workflow_id) do
      {:ok, metadata} ->
        post_error(metadata, error)
      {:error, _} ->
        Logger.error("Could not find analysis metadata for workflow #{workflow_id}")
    end
  end

  defp post_results(metadata, results) do
    %{
      "installation_id" => installation_id,
      "repo_owner" => repo_owner,
      "repo_name" => repo_name,
      "check_run_id" => check_run_id,
      "pr_number" => pr_number
    } = metadata

    # Update GitHub check run
    Github.update_check_run(installation_id, repo_owner, repo_name, check_run_id, %{
      status: "completed",
      conclusion: conclusion_from_score(results["quality_score"]),
      output: format_check_output(results)
    })

    # Post PR comment if this is a PR
    if pr_number do
      Github.create_pr_comment(installation_id, repo_owner, repo_name, pr_number, %{
        body: format_pr_comment(results)
      })
    end

    # Store results in database
    Repositories.store_analysis_results(metadata, results)
  end

  defp post_error(metadata, error) do
    %{
      "installation_id" => installation_id,
      "repo_owner" => repo_owner,
      "repo_name" => repo_name,
      "check_run_id" => check_run_id
    } = metadata

    # Update check run with error
    Github.update_check_run(installation_id, repo_owner, repo_name, check_run_id, %{
      status: "completed",
      conclusion: "failure",
      output: %{
        title: "Analysis Error",
        summary: "Code analysis failed: #{inspect(error)}"
      }
    })
  end

  defp conclusion_from_score(score) when score >= 8.0, do: "success"
  defp conclusion_from_score(score) when score >= 6.0, do: "neutral"
  defp conclusion_from_score(_score), do: "failure"

  defp format_check_output(results) do
    %{
      title: "Singularity Code Quality Analysis",
      summary: """
      **Quality Score:** #{results["quality_score"]}/10
      **Issues Found:** #{results["issues_count"]}
      **Recommendations:** #{length(results["recommendations"] || [])}
      """,
      text: format_detailed_output(results)
    }
  end

  defp format_pr_comment(results) do
    """
    ## 🔍 Singularity Code Quality Analysis

    **Quality Score:** #{results["quality_score"]}/10
    **Issues Found:** #{results["issues_count"]}

    ### Top Recommendations
    #{format_recommendations(results["recommendations"] || [])}

    ### Patterns Detected
    #{format_patterns(results["patterns_detected"] || [])}

    ---
    *Analysis powered by [Singularity](https://singularity.dev)*
    """
  end

  defp format_recommendations(recommendations) do
    recommendations
    |> Enum.take(5)
    |> Enum.map(fn rec -> "- #{rec["message"]}" end)
    |> Enum.join("\n")
  end

  defp format_patterns(patterns) do
    patterns
    |> Enum.map(fn pattern -> "- #{pattern}" end)
    |> Enum.join("\n")
  end

  defp format_detailed_output(results) do
    """
    ### Detailed Analysis

    **Quality Score:** #{results["quality_score"]}/10

    **Issues Found:** #{results["issues_count"]}

    **Recommendations:**
    #{format_recommendations(results["recommendations"] || [])}

    **Patterns Detected:**
    #{format_patterns(results["patterns_detected"] || [])}

    **Metrics:**
    #{format_metrics(results["metrics"] || %{})}
    """
  end

  defp format_metrics(metrics) do
    metrics
    |> Enum.map(fn {key, value} -> "- #{key}: #{value}" end)
    |> Enum.join("\n")
  end
end