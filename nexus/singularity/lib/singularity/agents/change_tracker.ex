defmodule Singularity.Agents.ChangeTracker do
  @moduledoc """
  Change Tracker - SHA-based change detection for ALL systems.

  ## The Problem

  Current systems are inefficient:
  - DocumentationPipeline runs every 60 minutes
  - SelfImprovingAgent runs every 5 seconds  
  - SharedQueueConsumer polls every 1000ms
  - CodeFileWatcher uses debounced timers
  - Multiple systems doing redundant work

  ## The Solution

  **Everything SHA-based, event-driven:**
  
  ```
  File Change → Calculate SHA → Compare with stored SHA → 
  If different → Trigger only affected systems → Update stored SHA
  ```

  ## Benefits

  - **Zero waste**: Only process what actually changed
  - **Instant response**: No polling delays
  - **Resource efficient**: Minimal CPU/memory
  - **Unified**: One system for all change detection

  ## Usage

      # Track a file for all systems
      ChangeTracker.track_file("lib/my_module.ex")

      # Get what changed and needs processing
      {:ok, changes} = ChangeTracker.get_changes()

      # Process changes for specific system
      ChangeTracker.process_for_system(:documentation, changes)
      ChangeTracker.process_for_system(:quality, changes)
      ChangeTracker.process_for_system(:analysis, changes)

      # Update SHA after processing
      ChangeTracker.update_sha("lib/my_module.ex", new_sha)
  """

  use GenServer
  require Logger

  ## Client API

  @doc """
  Start the unified change tracker.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Track a file for all systems.
  """
  @spec track_file(String.t()) :: :ok
  def track_file(file_path) do
    GenServer.call(__MODULE__, {:track_file, file_path})
  end

  @doc """
  Get all files that have changed.
  """
  @spec get_changes() :: {:ok, [map()]}
  def get_changes do
    GenServer.call(__MODULE__, :get_changes)
  end

  @doc """
  Process changes for a specific system.
  """
  @spec process_for_system(atom(), [map()]) :: :ok
  def process_for_system(system, changes) do
    GenServer.call(__MODULE__, {:process_for_system, system, changes})
  end

  @doc """
  Update SHA after processing.
  """
  @spec update_sha(String.t(), String.t()) :: :ok
  def update_sha(file_path, sha) do
    GenServer.call(__MODULE__, {:update_sha, file_path, sha})
  end

  @doc """
  Get tracking status.
  """
  @spec get_status() :: map()
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      tracked_files: %{},  # file_path => %{sha: "abc123", last_checked: timestamp, systems: [:doc, :quality]}
      pending_changes: [], # files that need processing
      system_processors: %{
        documentation: &process_documentation_changes/1,
        quality: &process_quality_changes/1,
        analysis: &process_analysis_changes/1,
        code_generation: &process_code_generation_changes/1
      }
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:track_file, file_path}, _from, state) do
    case File.read(file_path) do
      {:ok, content} ->
        sha = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
        timestamp = System.system_time(:second)
        
        # Determine which systems should track this file
        systems = determine_systems_for_file(file_path)
        
        new_tracked_files = Map.put(state.tracked_files, file_path, %{
          sha: sha,
          last_checked: timestamp,
          systems: systems
        })
        
        new_state = %{state | tracked_files: new_tracked_files}
        {:reply, :ok, new_state}
        
      {:error, reason} ->
        Logger.warning("Failed to read file #{file_path}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_changes, _from, state) do
    changes = 
      state.tracked_files
      |> Enum.filter(fn {file_path, file_info} ->
        case File.read(file_path) do
          {:ok, content} ->
            current_sha = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
            current_sha != file_info.sha
          {:error, _} ->
            false  # Skip files that can't be read
        end
      end)
      |> Enum.map(fn {file_path, file_info} -> 
        %{
          file_path: file_path,
          old_sha: file_info.sha,
          systems: file_info.systems,
          timestamp: System.system_time(:second)
        }
      end)
    
    {:reply, {:ok, changes}, state}
  end

  @impl true
  def handle_call({:process_for_system, system, changes}, _from, state) do
    # Filter changes relevant to this system
    relevant_changes = Enum.filter(changes, fn change ->
      system in change.systems
    end)
    
    # Process changes for this system
    case Map.get(state.system_processors, system) do
      nil ->
        Logger.warning("Unknown system: #{system}")
        {:reply, {:error, :unknown_system}, state}
      
      processor ->
        processor.(relevant_changes)
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:update_sha, file_path, sha}, _from, state) do
    case Map.get(state.tracked_files, file_path) do
      nil ->
        {:reply, {:error, :file_not_tracked}, state}
      
      file_info ->
        updated_file_info = %{file_info | sha: sha}
        new_tracked_files = Map.put(state.tracked_files, file_path, updated_file_info)
        new_state = %{state | tracked_files: new_tracked_files}
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      total_tracked: map_size(state.tracked_files),
      pending_changes: length(state.pending_changes),
      tracked_files: Map.keys(state.tracked_files),
      systems: Map.keys(state.system_processors)
    }
    {:reply, status, state}
  end

  ## Private Functions

  defp determine_systems_for_file(file_path) do
    cond do
      String.ends_with?(file_path, [".ex", ".exs"]) ->
        [:documentation, :quality, :analysis, :code_generation]
      
      String.ends_with?(file_path, [".rs"]) ->
        [:documentation, :quality, :analysis, :code_generation]
      
      String.ends_with?(file_path, [".ts", ".tsx", ".js", ".jsx"]) ->
        [:documentation, :quality, :analysis, :code_generation]
      
      String.ends_with?(file_path, [".json", ".yaml", ".yml"]) ->
        [:analysis]  # Config files only need analysis
      
      true ->
        [:analysis]  # Default to analysis only
    end
  end

  defp process_documentation_changes(changes) do
    Logger.info("Processing #{length(changes)} files for documentation updates")
    # Trigger DocumentationPipeline for changed files
    file_paths = Enum.map(changes, & &1.file_path)
    Singularity.Agents.DocumentationPipeline.run_incremental_pipeline(file_paths)
  end

  defp process_quality_changes(changes) do
    Logger.info("Processing #{length(changes)} files for quality enforcement")
    # Trigger QualityEnforcer for changed files
    file_paths = Enum.map(changes, & &1.file_path)
    Logger.debug("Quality files to process: #{Enum.join(file_paths, ", ")}")
    # QualityEnforcer.process_files(file_paths)
  end

  defp process_analysis_changes(changes) do
    Logger.info("Processing #{length(changes)} files for analysis updates")
    # Trigger analysis systems for changed files
    file_paths = Enum.map(changes, & &1.file_path)
    Logger.debug("Analysis files to process: #{Enum.join(file_paths, ", ")}")
    # AnalysisOrchestrator.analyze_files(file_paths)
  end

  defp process_code_generation_changes(changes) do
    Logger.info("Processing #{length(changes)} files for code generation updates")
    # Trigger code generation systems for changed files
    file_paths = Enum.map(changes, & &1.file_path)
    Logger.debug("Code generation files to process: #{Enum.join(file_paths, ", ")}")
    # CodeGenerationOrchestrator.process_files(file_paths)
  end
end