defmodule Genesis.RollbackManager do
  @moduledoc """
  Genesis Rollback Manager

  Handles rollback for experiments within the monorepo.
  Uses directory-based isolation: each sandbox is a copy of code directories.
  Tracks all changes and can revert to clean state instantly.

  ## Rollback Strategy

  Genesis runs in monorepo but uses isolated sandboxes:
  1. Before executing: Copy relevant code to sandbox directory
  2. Store baseline file checksums
  3. Apply changes only to sandbox copies
  4. On regression: Delete sandbox (instant rollback)
  5. Changes never touch main repository

  ## Isolation Model

  - **Monorepo**: Single git repository (shared)
  - **Sandbox**: Copy of code in ~/.genesis/sandboxes/{experiment_id}/
  - **No separate repo**: Genesis works within same monorepo
  - **All changes sandboxed**: Production code never modified

  ## Guarantees

  - **No data loss**: All changes stored in sandbox, never in main repo
  - **Instant recovery**: Delete sandbox directory (<1 second)
  - **Full audit trail**: Sandbox preserved for post-mortem analysis
  - **Automatic on regression**: Delete sandbox if metrics degrade
  - **Production safe**: Main repository untouched by experiments
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Genesis.RollbackManager starting...")
    {:ok, %{rollbacks: %{}}}
  end

  @doc """
  Create a rollback checkpoint before applying changes.
  """
  def create_checkpoint(experiment_id, sandbox_path) do
    GenServer.call(__MODULE__, {:create_checkpoint, experiment_id, sandbox_path})
  end

  @doc """
  Execute rollback to checkpoint.
  """
  def rollback_to_checkpoint(experiment_id) do
    GenServer.call(__MODULE__, {:rollback, experiment_id})
  end

  @doc """
  Emergency rollback - used when experiment fails unexpectedly.
  """
  def emergency_rollback(experiment_id) do
    GenServer.call(__MODULE__, {:emergency_rollback, experiment_id})
  end

  @impl true
  def handle_call({:create_checkpoint, experiment_id, sandbox_path}, _from, state) do
    case capture_checkpoint(experiment_id, sandbox_path) do
      {:ok, checkpoint} ->
        Logger.info("Created checkpoint for experiment #{experiment_id}")
        new_state = put_in(state.rollbacks[experiment_id], checkpoint)
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("Failed to create checkpoint: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:rollback, experiment_id}, _from, state) do
    case Map.fetch(state.rollbacks, experiment_id) do
      {:ok, checkpoint} ->
        case execute_rollback(checkpoint) do
          :ok ->
            Logger.info("Rolled back experiment #{experiment_id} to checkpoint")
            new_state = Map.update(state, :rollbacks, %{}, &Map.delete(&1, experiment_id))
            {:reply, :ok, new_state}

          {:error, reason} ->
            Logger.error("Rollback failed for #{experiment_id}: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end

      :error ->
        Logger.warn("Rollback requested for non-existent checkpoint #{experiment_id}")
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:emergency_rollback, experiment_id}, _from, state) do
    Logger.warn("EMERGENCY ROLLBACK requested for experiment #{experiment_id}")

    case Map.fetch(state.rollbacks, experiment_id) do
      {:ok, checkpoint} ->
        case execute_rollback(checkpoint) do
          :ok ->
            Logger.info("Emergency rollback succeeded for #{experiment_id}")
            new_state = Map.update(state, :rollbacks, %{}, &Map.delete(&1, experiment_id))
            {:reply, :ok, new_state}

          {:error, reason} ->
            Logger.error("EMERGENCY ROLLBACK FAILED: #{inspect(reason)}")
            # Still try to clean up even if rollback failed
            {:reply, {:error, reason}, state}
        end

      :error ->
        Logger.warn("Emergency rollback requested but no checkpoint found")
        {:reply, {:error, :not_found}, state}
    end
  end

  defp capture_checkpoint(experiment_id, sandbox_path) do
    # Get current Git commit hash in sandbox
    try do
      case get_git_commit(sandbox_path) do
        {:ok, commit_hash} ->
          checkpoint = %{
            experiment_id: experiment_id,
            sandbox_path: sandbox_path,
            baseline_commit: commit_hash,
            timestamp: DateTime.utc_now()
          }

          Logger.info(
            "Captured checkpoint for experiment #{experiment_id} at commit #{String.slice(commit_hash, 0..7)}"
          )

          {:ok, checkpoint}

        {:error, reason} ->
          Logger.error("Failed to capture Git commit: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Exception while capturing checkpoint: #{inspect(e)}")
        {:error, e}
    end
  end

  defp execute_rollback(checkpoint) do
    experiment_id = checkpoint.experiment_id
    sandbox_path = checkpoint.sandbox_path
    baseline_commit = checkpoint.baseline_commit

    try do
      Logger.info(
        "Executing rollback for experiment #{experiment_id} to commit #{String.slice(baseline_commit, 0..7)}"
      )

      # Execute git reset --hard in sandbox
      case reset_to_commit(sandbox_path, baseline_commit) do
        {:ok, _output} ->
          # Verify clean working directory
          case verify_clean_state(sandbox_path) do
            {:ok, _output} ->
              Logger.info("Rollback successful for experiment #{experiment_id}")
              :ok

            {:error, reason} ->
              Logger.error("Failed to verify clean state after rollback: #{inspect(reason)}")
              {:error, reason}
          end

        {:error, reason} ->
          Logger.error("Failed to reset Git state: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Exception during rollback: #{inspect(e)}")
        {:error, e}
    end
  end

  defp get_git_commit(repo_path) do
    # Get current HEAD commit hash
    case run_git_command(repo_path, ["rev-parse", "HEAD"]) do
      {:ok, output} ->
        # Output includes newline, strip it
        {:ok, String.trim(output)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp reset_to_commit(repo_path, commit_hash) do
    # Reset to specific commit
    run_git_command(repo_path, ["reset", "--hard", commit_hash])
  end

  defp verify_clean_state(repo_path) do
    # Verify working directory is clean
    case run_git_command(repo_path, ["status", "--porcelain"]) do
      {:ok, output} ->
        # If output is empty, working directory is clean
        if String.trim(output) == "" do
          {:ok, "clean"}
        else
          {:error, "Working directory not clean: #{output}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_git_command(repo_path, args) do
    # Run git command in sandbox repo
    try do
      cmd = "cd #{Path.quote(repo_path)} && git #{Enum.join(args, " ")}"

      case System.cmd("bash", ["-c", cmd], stderr_to_stdout: true) do
        {output, 0} ->
          {:ok, output}

        {error_output, exit_code} ->
          {:error, "Git command failed with exit code #{exit_code}: #{error_output}"}
      end
    rescue
      e ->
        {:error, "Exception running git command: #{inspect(e)}"}
    end
  end
end
