defmodule Singularity.Startup.GitTreeBootstrap do
  @moduledoc """
  Git Tree Bootstrap - Initializes and wires git tree coordination into auto-upgrade system.

  Integrates GitTreeSyncCoordinator with DocumentationPipeline so that:
  - Each agent works in isolated git branches
  - All LLM-generated changes are tracked via git
  - Changes auto-merge via PR coordination
  - Full audit trail of all auto-upgrades

  ## Configuration

  Enable in config/config.exs:

      config :singularity, :git_coordinator,
        enabled: true,
        repo_path: "~/.singularity/git-coordinator",
        base_branch: "main",
        remote: "origin"

  ## Integration Points

  1. DocumentationBootstrap calls bootstrap_git_tree_coordination/0
  2. Each agent task assignment creates git branch via GitTreeSyncProxy
  3. Agent work submitted to git workspace (not main codebase)
  4. QualityEnforcer validates changes in git workspace
  5. Genesis sandbox syncs with git workspace
  6. PRs created automatically for all changes
  7. Final merge coordination orchestrates all PRs into single commit

  ## Architecture

  ```
  Auto-Upgrade Startup
    ↓
  DocumentationBootstrap.bootstrap_documentation_system()
    ↓
  GitTreeBootstrap.bootstrap_git_tree_coordination()
    ├─ Ensure Git.Supervisor started
    ├─ Create git coordination context
    ├─ Initialize correlation for epic merge
    └─ Ready for agent tasks
    ↓
  DocumentationPipeline.run_full_pipeline()
    ├─ For each agent:
    │  ├─ GitTreeSyncProxy.assign_task(agent_id, task, use_llm: true)
    │  ├─ Agent works in isolated branch
    │  ├─ QualityEnforcer validates in branch
    │  ├─ Genesis sandbox mirrors branch state
    │  └─ GitTreeSyncProxy.submit_work(agent_id, result)
    ├─ All changes committed to git
    └─ GitTreeSyncProxy.merge_all_for_epic(correlation_id)
  ```

  ## Search Keywords

  git-tree, coordination, auto-upgrade, branch-isolation, pr-coordination, epic-merge
  """

  use GenServer
  require Logger

  alias Singularity.Git.{GitTreeSyncProxy, Supervisor}
  alias Singularity.Autonomy.Correlation

  @doc """
  Bootstrap git tree coordination on startup.

  Ensures Git.Supervisor is running and initializes context for
  auto-upgrade integration with git tree branches.

  Returns :ok if successful, {:error, reason} otherwise.
  """
  @spec bootstrap_git_tree_coordination() :: :ok | {:error, term()}
  def bootstrap_git_tree_coordination do
    try do
      # Check if git coordination is enabled
      if Supervisor.enabled?() do
        Logger.info("[GitTreeBootstrap] Git tree coordination enabled")

        # Ensure Git.Supervisor is started
        case ensure_git_supervisor_started() do
          :ok ->
            Logger.info("[GitTreeBootstrap] Git.Supervisor verified running")
            :ok

          {:error, reason} ->
            Logger.warning(
              "[GitTreeBootstrap] Failed to start Git.Supervisor: #{inspect(reason)}"
            )

            {:error, reason}
        end
      else
        Logger.debug("[GitTreeBootstrap] Git tree coordination disabled in config")
        :ok
      end
    rescue
      error ->
        Logger.error("[GitTreeBootstrap] Bootstrap failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Assign task to agent with git branch coordination.

  Creates a git branch for the agent's work, isolated from main codebase.
  Returns task context with branch info, or error if git coordination disabled.

  ## Options

    * `:use_llm` - Whether this is LLM work (default: true)
      - true: Creates branch + workspace (LLM tasks)
      - false: Works on main directly (rule-based tasks)

  Returns `{:ok, task_context}` with branch info or `{:error, :disabled}`.
  """
  @spec assign_task_with_git(term(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def assign_task_with_git(agent_id, task, opts \\ []) do
    use_llm = Keyword.get(opts, :use_llm, true)

    case GitTreeSyncProxy.assign_task(agent_id, task, use_llm: use_llm) do
      {:error, :disabled} ->
        # Git coordination disabled - return task as-is
        {:ok, task}

      {:ok, result} ->
        # Git coordination enabled - return task with git context
        {:ok, Map.put(task, :git_context, result)}

      error ->
        error
    end
  end

  @doc """
  Submit completed work to git.

  Creates PR from agent's branch and returns merge status.
  Requires prior call to assign_task_with_git/3.

  Returns `{:ok, pr_info}` or `{:error, reason}`.
  """
  @spec submit_work_to_git(term(), map()) :: {:ok, map()} | {:error, term()}
  def submit_work_to_git(agent_id, result) do
    case GitTreeSyncProxy.submit_work(agent_id, result) do
      {:error, :disabled} ->
        # Git coordination disabled - just return result
        {:ok, result}

      {:ok, pr_info} ->
        # Git coordination enabled - return PR info
        {:ok, pr_info}

      error ->
        error
    end
  end

  @doc """
  Get merge status for the upgrade epic.

  Returns how many PRs are pending merge and their status.

  Returns `{:ok, status}` or `{:error, reason}`.
  """
  @spec get_epic_merge_status() :: {:ok, map()} | {:error, term()}
  def get_epic_merge_status do
    correlation_id = Correlation.current()

    case GitTreeSyncProxy.merge_status(correlation_id) do
      {:error, :disabled} ->
        {:ok, %{status: :no_git, pending_merges: 0}}

      {:ok, status} ->
        {:ok, status}

      error ->
        error
    end
  end

  @doc """
  Merge all PRs for the upgrade epic.

  Coordinates all agent PRs into a single merge commit.
  All changes from all agents combined and applied together.

  Returns `{:ok, result}` with final commit hash or `{:error, reason}`.
  """
  @spec merge_all_epic_changes() :: {:ok, map()} | {:error, term()}
  def merge_all_epic_changes do
    correlation_id = Correlation.current()

    case GitTreeSyncProxy.merge_all_for_epic(correlation_id) do
      {:error, :disabled} ->
        {:ok, %{status: :no_git, commit_hash: nil}}

      {:ok, result} ->
        Logger.info("[GitTreeBootstrap] Epic merge complete",
          commit_hash: result[:commit_hash],
          files_changed: result[:files_changed]
        )

        {:ok, result}

      error ->
        error
    end
  end

  ## Private Functions

  defp ensure_git_supervisor_started do
    case Supervisor.enabled?() do
      true ->
        # Git supervisor should be in application supervision tree
        # Just verify it's running
        if Process.whereis(Supervisor) do
          :ok
        else
          Logger.warning("[GitTreeBootstrap] Git.Supervisor not found in supervision tree")
          {:error, :not_started}
        end

      false ->
        :ok
    end
  end
end
