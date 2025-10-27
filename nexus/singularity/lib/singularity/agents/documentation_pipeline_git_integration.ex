defmodule Singularity.Agents.DocumentationPipelineGitIntegration do
  @moduledoc """
  Git Integration Layer for DocumentationPipeline

  Coordinates git tree branch isolation with agent task assignment.
  Each agent's work happens in isolated git branch, tracked as PRs.

  ## Usage in DocumentationPipeline

  Instead of:
      {:ok, result} = agent.process_task(task)

  Use:
      {:ok, task_with_git} = GitIntegration.assign_agent_task(agent_id, task)
      {:ok, result} = agent.process_task(task_with_git)
      {:ok, pr_info} = GitIntegration.submit_agent_work(agent_id, result)

  ## Features

  - Each agent works in isolated git branch
  - LLM tasks create branches + PRs
  - Rule-based tasks work on main directly
  - All changes tracked in git (full audit trail)
  - Automatic PR coordination on completion
  - Easy rollback (revert PR or delete branch)
  """

  require Logger
  alias Singularity.Startup.GitTreeBootstrap
  alias Singularity.Autonomy.Correlation

  @doc """
  Assign agent task with git branch coordination.

  If git coordination enabled:
  - Creates isolated git branch for agent
  - Agent work won't touch main codebase
  - All changes tracked in git

  If git coordination disabled:
  - Returns task as-is
  - Works directly on codebase

  Returns `{:ok, task_with_git_context}` or `{:error, reason}`.
  """
  @spec assign_agent_task(atom() | String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def assign_agent_task(agent_id, task, opts \\ []) do
    Logger.debug("[GitIntegration] Assigning task to agent #{agent_id}",
      task_id: task[:id],
      use_llm: Keyword.get(opts, :use_llm, true)
    )

    GitTreeBootstrap.assign_task_with_git(agent_id, task, opts)
  end

  @doc """
  Submit agent work to git coordination.

  Creates PR from agent's branch with all changes.
  PR is ready for review/merge by epic merge coordinator.

  Returns `{:ok, pr_info}` with PR number and merge status, or error.
  """
  @spec submit_agent_work(atom() | String.t(), map()) :: {:ok, map()} | {:error, term()}
  def submit_agent_work(agent_id, result) do
    Logger.info("[GitIntegration] Submitting work from agent #{agent_id}",
      result_files: map_size(result[:files] || %{}),
      correlation_id: Correlation.current()
    )

    GitTreeBootstrap.submit_work_to_git(agent_id, result)
  end

  @doc """
  Get all pending PRs for current upgrade epic.

  Returns `{:ok, status}` with:
  - `pending_merge_count`: Number of open PRs
  - `agents_completed`: Which agents finished
  - `epic_ready_to_merge`: true when all PRs ready
  """
  @spec get_epic_status() :: {:ok, map()} | {:error, term()}
  def get_epic_status do
    Logger.debug("[GitIntegration] Checking epic merge status",
      correlation_id: Correlation.current()
    )

    GitTreeBootstrap.get_epic_merge_status()
  end

  @doc """
  Finalize upgrade by merging all agent PRs.

  Coordinates all pending PRs into single commit.
  All agents' changes combined and applied together.

  Returns `{:ok, merge_result}` with commit hash, or error.
  """
  @spec finalize_epic_upgrade() :: {:ok, map()} | {:error, term()}
  def finalize_epic_upgrade do
    Logger.info("[GitIntegration] Finalizing epic upgrade - merging all PRs",
      correlation_id: Correlation.current()
    )

    with {:ok, status} <- get_epic_status() do
      if status[:epic_ready_to_merge] do
        GitTreeBootstrap.merge_all_epic_changes()
      else
        pending = status[:pending_merge_count] || 0

        Logger.warning(
          "[GitIntegration] Epic not ready for merge - #{pending} PRs still pending"
        )

        {:error, :not_ready_for_merge}
      end
    end
  end

  @doc """
  Process full pipeline with git coordination.

  Wrapper that coordinates:
  1. Agent task assignment with git branches
  2. Agent work submission as PRs
  3. Quality validation in git context
  4. Final epic merge

  Example:
      {:ok, pipeline_result} =
        DocumentationPipelineGitIntegration.run_with_git_coordination([
          {:agent_self_improving, SelfImprovingAgent},
          {:agent_architecture, ArchitectureAgent},
          # ... more agents
        ])
  """
  @spec run_with_git_coordination([{atom(), module()}]) :: {:ok, map()} | {:error, term()}
  def run_with_git_coordination(agents) do
    correlation_id = Correlation.current()
    Logger.info("[GitIntegration] Starting pipeline with git coordination", correlation_id: correlation_id)

    # Process each agent with git coordination
    results =
      agents
      |> Enum.map(fn {agent_id, agent_module} ->
        run_agent_with_git(agent_id, agent_module)
      end)

    # Check for errors
    case Enum.find(results, fn {status, _} -> status == :error end) do
      {:error, reason} ->
        Logger.error("[GitIntegration] Pipeline failed during agent execution", reason: reason)
        {:error, reason}

      nil ->
        # All agents succeeded - finalize epic
        Logger.info("[GitIntegration] All agents completed - finalizing epic merge")
        finalize_epic_upgrade()
    end
  end

  ## Private Functions

  defp run_agent_with_git(agent_id, agent_module) do
    Logger.debug("[GitIntegration] Running agent #{agent_id} with git coordination")

    try do
      # Create task for agent
      task = %{
        id: "task_#{agent_id}_#{System.unique_integer()}",
        agent_id: agent_id,
        type: :upgrade
      }

      # Assign with git branch
      with {:ok, task_with_git} <- assign_agent_task(agent_id, task, use_llm: true) do
        # Run agent
        case agent_module.process(task_with_git) do
          {:ok, result} ->
            # Submit work to git
            case submit_agent_work(agent_id, result) do
              {:ok, pr_info} ->
                Logger.info("[GitIntegration] Agent #{agent_id} completed with PR",
                  pr_number: pr_info[:pr_number]
                )

                {:ok, pr_info}

              error ->
                error
            end

          error ->
            error
        end
      end
    rescue
      error ->
        Logger.error("[GitIntegration] Agent execution failed: #{inspect(error)}")
        {:error, error}
    end
  end
end
