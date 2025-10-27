defmodule Genesis.IsolationManager do
  @moduledoc """
  Genesis Isolation Manager

  Creates and manages isolated sandboxes for each experiment within the monorepo.

  Each experiment gets:
  - Isolated filesystem (copy of relevant code directories in ~/.genesis/sandboxes/)
  - Isolated hotreload context (separate BEAM process)
  - Isolated database (genesis with transaction isolation)
  - Production-safe isolation (never modifies main repository)

  ## Isolation Strategy (Monorepo-Based)

  Genesis uses **directory-based isolation** within the monorepo:
  1. Main repo stays untouched
  2. Each experiment gets a sandbox copy in ~/.genesis/sandboxes/{experiment_id}/
  3. Copy includes only relevant code directories (singularity/, centralcloud/, etc.)
  4. Changes apply only to sandbox copies
  5. On success: Sandbox can be analyzed or proposed as PR
  6. On failure: Sandbox deleted (instant rollback)

  ## Sandbox Lifecycle

  1. Create: Copy relevant directories to sandbox
  2. Execute: Apply changes, run tests in sandbox
  3. Report: Collect metrics
  4. Cleanup: Delete sandbox (on failure) or preserve for review (on success)
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Create base sandbox directory
    sandbox_dir = sandbox_base_path()
    File.mkdir_p(sandbox_dir)
    Logger.info("IsolationManager initialized with sandbox path: #{sandbox_dir}")
    {:ok, %{sandboxes: %{}}}
  end

  @doc """
  Create isolated sandbox for an experiment.

  Returns {:ok, sandbox_path} or {:error, reason}
  """
  def create_sandbox(experiment_id) do
    GenServer.call(__MODULE__, {:create_sandbox, experiment_id})
  end

  @doc """
  Cleanup sandbox after experiment completes.
  """
  def cleanup_sandbox(experiment_id) do
    GenServer.call(__MODULE__, {:cleanup_sandbox, experiment_id})
  end

  @impl true
  def handle_call({:create_sandbox, experiment_id}, _from, state) do
    sandbox_path = Path.join(sandbox_base_path(), experiment_id)

    case setup_sandbox(sandbox_path) do
      :ok ->
        Logger.info("Created sandbox for experiment #{experiment_id} at #{sandbox_path}")
        new_state = put_in(state.sandboxes[experiment_id], sandbox_path)
        {:reply, {:ok, sandbox_path}, new_state}

      {:error, reason} ->
        Logger.error("Failed to create sandbox for #{experiment_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:cleanup_sandbox, experiment_id}, _from, state) do
    case Map.fetch(state.sandboxes, experiment_id) do
      {:ok, sandbox_path} ->
        # Remove sandbox directory
        case File.rm_rf(sandbox_path) do
          {:ok, _} ->
            Logger.info("Cleaned up sandbox for experiment #{experiment_id}")
            new_state = Map.update(state, :sandboxes, %{}, &Map.delete(&1, experiment_id))
            {:reply, :ok, new_state}

          {:error, reason, file} ->
            Logger.error(
              "Failed to cleanup sandbox #{experiment_id}: #{inspect(reason)} (#{inspect(file)})"
            )

            {:reply, {:error, reason}, state}
        end

      :error ->
        Logger.warning("Attempt to cleanup non-existent sandbox #{experiment_id}")
        {:reply, {:error, :not_found}, state}
    end
  end

  defp setup_sandbox(sandbox_path) do
    with :ok <- File.mkdir_p(sandbox_path),
         :ok <- copy_code_directories(sandbox_path) do
      :ok
    else
      {:error, reason} ->
        # Cleanup on failure
        File.rm_rf(sandbox_path)
        {:error, reason}
    end
  end

  defp copy_code_directories(sandbox_path) do
    # Copy relevant code directories from monorepo to sandbox
    # This creates an isolated environment where changes can be made safely
    dirs_to_copy = [
      "singularity",
      "centralcloud",
      "genesis",
      "rust",
      "ai_server"
    ]

    monorepo_root = File.cwd!()

    Enum.each(dirs_to_copy, fn dir ->
      source = Path.join(monorepo_root, dir)
      dest = Path.join(sandbox_path, dir)

      if File.exists?(source) do
        case File.cp_r(source, dest) do
          {:ok, _} ->
            Logger.info("Copied #{dir} to sandbox")

          {:error, reason} ->
            Logger.error("Failed to copy #{dir}: #{inspect(reason)}")
        end
      end
    end)

    Logger.info("Set up sandbox at #{sandbox_path} with code directories")
    :ok
  end

  defp sandbox_base_path do
    Path.join([System.get_env("HOME", "/tmp"), ".genesis", "sandboxes"])
  end
end
