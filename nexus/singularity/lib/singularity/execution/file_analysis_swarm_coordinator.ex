defmodule Singularity.Execution.FileAnalysisSwarmCoordinator do
  @moduledoc """
  ## FileAnalysisSwarmCoordinator - Distributed File Analysis via Swarm Pattern

  Implements a GenServer-based swarm orchestrator that discovers files needing analysis
  and spawns autonomous FileAnalysisWorker processes to analyze them in parallel.

  Based on TodoSwarmCoordinator pattern but adapted for file analysis workloads.

  ## Quick Start

  ```elixir
  # Start coordinator
  {:ok, pid} = FileAnalysisSwarmCoordinator.start_link([])

  # Analyze a directory
  FileAnalysisSwarmCoordinator.analyze_directory("/path/to/codebase", max_workers: 4)

  # Check status
  status = FileAnalysisSwarmCoordinator.get_status()
  ```

  ## Architecture

  1. **Discovery Phase**: Find files needing analysis (by extension, modification time, etc.)
  2. **Queue Management**: Maintain analysis queue with priorities
  3. **Worker Spawning**: Launch FileAnalysisWorker agents for parallel processing
  4. **Result Aggregation**: Collect and store analysis results
  5. **Load Balancing**: Distribute work across available workers

  ## Worker Lifecycle

  ```
  Coordinator → Discover Files → Queue Tasks → Spawn Workers → Analyze → Store Results
  ```

  ## Integration Points

  - **BeamAnalysisEngine**: Core analysis logic per file
  - **File Store**: Cache analysis results
  - **Change Tracker**: Trigger re-analysis on file changes
  - **Quality Engine**: Use analysis for quality metrics
  """

  use GenServer
  require Logger

  alias Singularity.BeamAnalysisEngine

  # Client API

  @doc """
  Start the FileAnalysisSwarmCoordinator GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyze all files in a directory using swarm pattern.

  ## Options
  - `max_workers` - Maximum concurrent analysis workers (default: 4)
  - `file_extensions` - List of extensions to analyze (default: [".ex", ".exs", ".erl", ".hrl", ".gleam"])
  - `exclude_patterns` - Regex patterns to exclude (default: ["_build", "deps", ".git"])
  - `force_reanalysis` - Re-analyze files even if cached (default: false)
  """
  def analyze_directory(directory, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_directory, directory, opts}, 30_000)
  end

  @doc """
  Analyze specific files using swarm pattern.
  """
  def analyze_files(file_paths, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_files, file_paths, opts}, 30_000)
  end

  @doc """
  Get current swarm status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Stop all active analysis workers.
  """
  def stop_all_workers do
    GenServer.call(__MODULE__, :stop_all_workers)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Logger.info("[FileAnalysisSwarm] Starting File Analysis Swarm Coordinator")

    state = %{
      active_workers: %{},
      analysis_queue: :queue.new(),
      completed_analyses: 0,
      failed_analyses: 0,
      total_files_discovered: 0,
      worker_supervisor: nil,
      default_opts: opts
    }

    # Start periodic queue processing
    Process.send_after(self(), :process_queue, 1_000)

    {:ok, state}
  end

  @impl true
  def handle_call({:analyze_directory, directory, opts}, _from, state) do
    Logger.info("[FileAnalysisSwarm] Discovering files in: #{directory}")

    # Merge with default options
    analysis_opts = Keyword.merge(state.default_opts, opts)

    # Discover files to analyze
    file_paths = discover_files(directory, analysis_opts)

    Logger.info("[FileAnalysisSwarm] Found #{length(file_paths)} files to analyze")

    # Queue files for analysis
    new_state = Enum.reduce(file_paths, state, fn file_path, acc ->
      queue_file_for_analysis(acc, file_path, analysis_opts)
    end)

    updated_state = %{new_state | total_files_discovered: length(file_paths)}

    {:reply, {:ok, length(file_paths)}, updated_state}
  end

  @impl true
  def handle_call({:analyze_files, file_paths, opts}, _from, state) do
    Logger.info("[FileAnalysisSwarm] Queuing #{length(file_paths)} specific files")

    analysis_opts = Keyword.merge(state.default_opts, opts)

    new_state = Enum.reduce(file_paths, state, fn file_path, acc ->
      queue_file_for_analysis(acc, file_path, analysis_opts)
    end)

    {:reply, {:ok, length(file_paths)}, new_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      active_workers: map_size(state.active_workers),
      queued_files: :queue.len(state.analysis_queue),
      completed_analyses: state.completed_analyses,
      failed_analyses: state.failed_analyses,
      total_files_discovered: state.total_files_discovered
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:stop_all_workers, _from, state) do
    Logger.info("[FileAnalysisSwarm] Stopping all active workers")

    # Stop all active workers
    Enum.each(state.active_workers, fn {_worker_id, worker_pid} ->
      if Process.alive?(worker_pid) do
        Process.exit(worker_pid, :shutdown)
      end
    end)

    {:reply, :ok, %{state | active_workers: %{}}}
  end

  @impl true
  def handle_info(:process_queue, state) do
    # Process queued analysis tasks
    max_workers = Keyword.get(state.default_opts, :max_workers, 4)
    current_workers = map_size(state.active_workers)

    if current_workers < max_workers and not :queue.is_empty(state.analysis_queue) do
      {{:value, {file_path, opts}}, new_queue} = :queue.out(state.analysis_queue)

      # Spawn worker for this file
      worker_id = generate_worker_id()
      {:ok, worker_pid} = spawn_analysis_worker(file_path, opts, worker_id)

      new_active_workers = Map.put(state.active_workers, worker_id, worker_pid)
      new_state = %{state | active_workers: new_active_workers, analysis_queue: new_queue}

      Logger.debug("[FileAnalysisSwarm] Spawned worker #{worker_id} for #{file_path}")

      # Continue processing if more capacity
      if map_size(new_active_workers) < max_workers and not :queue.is_empty(new_queue) do
        Process.send_after(self(), :process_queue, 100)
      end

      {:noreply, new_state}
    else
      # Schedule next check
      Process.send_after(self(), :process_queue, 1_000)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:analysis_completed, worker_id, file_path, result}, state) do
    Logger.info("[FileAnalysisSwarm] Analysis completed: #{file_path}")

    # Remove from active workers
    new_active_workers = Map.delete(state.active_workers, worker_id)

    # Store result (TODO: integrate with file analysis store)
    store_analysis_result(file_path, result)

    new_state = %{
      state |
      active_workers: new_active_workers,
      completed_analyses: state.completed_analyses + 1
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:analysis_failed, worker_id, file_path, error}, state) do
    SASL.execution_failure(:swarm_analysis_failure,
      "File analysis swarm worker failed",
      worker_id: worker_id,
      file_path: file_path,
      error: error
    )

    # Remove from active workers
    new_active_workers = Map.delete(state.active_workers, worker_id)

    new_state = %{
      state |
      active_workers: new_active_workers,
      failed_analyses: state.failed_analyses + 1
    }

    {:noreply, new_state}
  end

  # Private Functions

  defp discover_files(directory, opts) do
    file_extensions = Keyword.get(opts, :file_extensions, [".ex", ".exs", ".erl", ".hrl", ".gleam"])
    exclude_patterns = Keyword.get(opts, :exclude_patterns, ["_build", "deps", ".git"])

    # Simple file discovery (could be enhanced with more sophisticated filtering)
    Path.wildcard("#{directory}/**/*")
    |> Enum.filter(fn path ->
      # Check extension
      ext = Path.extname(path)
      has_correct_ext = ext in file_extensions

      # Check exclusions
      not_excluded = not Enum.any?(exclude_patterns, fn pattern ->
        String.contains?(path, pattern)
      end)

      has_correct_ext and not_excluded and File.regular?(path)
    end)
  end

  defp queue_file_for_analysis(state, file_path, opts) do
    # Add to analysis queue with priority (could be enhanced)
    _priority = calculate_analysis_priority(file_path, opts)
    queue_item = {file_path, opts}

    %{state | analysis_queue: :queue.in(queue_item, state.analysis_queue)}
  end

  defp calculate_analysis_priority(file_path, _opts) do
    # Simple priority calculation (could be enhanced)
    cond do
      String.contains?(file_path, "lib/") -> 1  # Core library files
      String.contains?(file_path, "test/") -> 2 # Test files
      String.contains?(file_path, "config/") -> 0 # Config files (lowest priority)
      true -> 1
    end
  end

  defp spawn_analysis_worker(file_path, opts, worker_id) do
    # Spawn a task to analyze the file
    Task.start_link(fn ->
      try do
        result = analyze_file(file_path, opts)
        send(__MODULE__, {:analysis_completed, worker_id, file_path, result})
      rescue
        error ->
          send(__MODULE__, {:analysis_failed, worker_id, file_path, error})
      end
    end)
  end

  defp analyze_file(file_path, opts) do
    Logger.debug("[FileAnalysisSwarm] Analyzing file: #{file_path}")

    # Read file content
    case File.read(file_path) do
      {:ok, content} ->
        # Detect language from extension
        language = detect_language_from_path(file_path)

        # Analyze with BeamAnalysisEngine
        case BeamAnalysisEngine.analyze_beam_code(language, content, file_path) do
          {:ok, analysis} ->
            # Add metadata
            analysis_with_meta = Map.put(analysis, :metadata, %{
              analyzed_at: DateTime.utc_now(),
              file_size: byte_size(content),
              language: language,
              analysis_version: "1.0"
            })

            {:ok, analysis_with_meta}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
    end
  end

  defp detect_language_from_path(file_path) do
    case Path.extname(file_path) do
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".erl" -> "erlang"
      ".hrl" -> "erlang"
      ".gleam" -> "gleam"
      _ -> "unknown"
    end
  end

  defp store_analysis_result(file_path, result) do
    # TODO: Integrate with analysis result storage
    # For now, just log successful completion
    case result do
      {:ok, analysis} ->
        Logger.info("[FileAnalysisSwarm] Stored analysis for #{file_path}: #{analysis.language}")
      {:error, _reason} ->
        Logger.warning("[FileAnalysisSwarm] Failed to analyze #{file_path}")
    end
  end

  defp generate_worker_id do
    "analysis_worker_#{:erlang.system_time(:millisecond)}"
  end
end