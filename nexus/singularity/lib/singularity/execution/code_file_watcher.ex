defmodule Singularity.Execution.Planning.CodeFileWatcher do
  @moduledoc """
  Real-time Code File Watcher - Auto-ingestion when files change

  **PURPOSE**: Monitor Singularity's lib/ directory and automatically re-ingest
  files into the database when they change.

  ## Architecture

  ```mermaid
  graph TD
      A[File Modified] --> B[FileSystem Event]
      B --> C[CodeFileWatcher]
      C --> D{Is source file?}
      D -->|Yes| E[StartupCodeIngestion.persist_module_to_db]
      D -->|No| F[Ignore]
      E --> G[(PostgreSQL)]
      G --> H[TodoExtractor.extract_after_file_update]
      H --> I[Create todos from comments]
      I --> J[(todos table)]
  ```

  ## Module Identity

  ```json
  {
    "module_name": "Singularity.Execution.Planning.CodeFileWatcher",
    "purpose": "Real-time code ingestion via file-watching",
    "type": "GenServer + FileSystem integration",
    "operates_on": "lib/**/*.ex files",
    "storage": "code_files table (via StartupCodeIngestion)",
    "dependencies": ["FileSystem", "StartupCodeIngestion"]
  }
  ```

  ## Call Graph (YAML)

  ```yaml
  CodeFileWatcher:
    calls:
      - FileSystem.subscribe/1  # Subscribe to file events
      - StartupCodeIngestion.persist_module_to_db/2  # Re-ingest changed file
      - TodoExtractor.extract_after_file_update/1  # Extract TODOs after DB update
    called_by:
      - ApplicationSupervisor  # Started in supervision tree
    triggers:
      - on_file_modified: Re-ingests single file immediately + extracts TODOs
  ```

  ## Anti-Patterns

  **DO NOT create these duplicates:**
  - ❌ `CodeMonitor` - This IS the file monitor
  - ❌ `FileIngestionWatcher` - Same purpose
  - ❌ `AutoIngestion` - StartupCodeIngestion handles startup, this handles runtime

  **Use this module when:**
  - ✅ Need real-time ingestion (file changes detected immediately)
  - ✅ During active development (files changing frequently)

  **Use StartupCodeIngestion when:**
  - ✅ Need startup ingestion (comprehensive scan of all files)
  - ✅ First-time setup or after git pull

  ## Search Keywords

  file-watching, real-time, auto-ingestion, code-monitoring, lib-directory,
  elixir-files, file-system-events, automatic-persistence, development-workflow,
  hot-reload, change-detection
  """

  use GenServer
  require Logger

  alias Singularity.Code.{StartupCodeIngestion, UnifiedIngestionService}
  alias Singularity.Execution.TodoExtractor
  alias Singularity.HotReload.ModuleReloader

  # Configuration - loaded from Application config
  @config Application.get_env(:singularity, :auto_ingestion, %{})

  # Debounce delay (ms) - wait after last change before re-ingesting
  @debounce_delay @config[:debounce_delay_ms] || 500

  # Maximum file age for busy detection (ms) - skip if modified very recently
  @busy_file_threshold @config[:busy_file_threshold_ms] || 100

  # Retry configuration
  @max_retries @config[:max_retries] || 3
  @retry_delay @config[:retry_delay_ms] || 1000

  # Performance tuning
  @max_concurrent @config[:max_concurrent_ingestions] || 5
  @ingestion_timeout @config[:ingestion_timeout_ms] || 30000

  # File filtering
  @include_extensions @config[:include_extensions] ||
                        [
                          ".ex",
                          ".exs",
                          ".rs",
                          ".ts",
                          ".tsx",
                          ".js",
                          ".jsx",
                          ".py",
                          ".go",
                          ".nix",
                          ".sh",
                          ".toml",
                          ".json",
                          ".yaml",
                          ".yml",
                          ".md"
                        ]
  @ignore_patterns @config[:ignore_patterns] ||
                     [
                       "/_build/",
                       "/deps/",
                       "/node_modules/",
                       "/target/",
                       "/.git/",
                       "/.nix/",
                       ".log",
                       ".tmp",
                       ".pid",
                       ".DS_Store",
                       "Thumbs.db"
                     ]

  # Auto-detection settings
  @auto_detect_codebase @config[:auto_detect_codebase] || true
  @default_codebase_id @config[:default_codebase_id] || "singularity"

  # Logging control
  @quiet_mode @config[:quiet_mode] || false

  # ------------------------------------------------------------------------------
  # Client API
  # ------------------------------------------------------------------------------

  @doc """
  Start the file watcher.

  Subscribes to FileSystem events for the `lib/` directory.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ------------------------------------------------------------------------------
  # GenServer Callbacks
  # ------------------------------------------------------------------------------

  @impl true
  def init(opts) do
    Logger.info("Starting CodeFileWatcher with #{@debounce_delay}ms debouncing...")

    # Get project root - monitor entire project, not just lib/
    project_root = File.cwd!()

    # Subscribe to file events in entire project root (recursive)
    {:ok, watcher_pid} = FileSystem.start_link(dirs: [project_root])
    FileSystem.subscribe(watcher_pid)

    Logger.info("CodeFileWatcher monitoring: #{project_root}")

    {:ok,
     %{
       watcher_pid: watcher_pid,
       project_root: project_root,
       # Track pending re-ingestions (file_path => timer_ref)
       pending_ingestions: %{},
       # Track in-progress re-ingestions to prevent duplicates
       in_progress: MapSet.new()
     }}
  end

  @impl true
  def handle_info(
        {:file_event, _watcher_pid, {file_path, events}},
        %{pending_ingestions: pending} = state
      ) do
    # Process source files that were modified or created
    if is_source_file?(file_path) and (:modified in events or :created in events) do
      Logger.debug("File changed: #{file_path}, scheduling debounced re-ingestion...")

      # Cancel any existing timer for this file
      case Map.get(pending, file_path) do
        nil ->
          :ok

        timer_ref ->
          Process.cancel_timer(timer_ref)
      end

      # Schedule new debounced ingestion
      timer_ref =
        Process.send_after(self(), {:debounced_reingest, file_path}, @debounce_delay)

      new_pending = Map.put(pending, file_path, timer_ref)

      {:noreply, %{state | pending_ingestions: new_pending}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:debounced_reingest, file_path}, state) do
    # Debounce period elapsed - now re-ingest the file
    %{
      project_root: project_root,
      pending_ingestions: pending,
      in_progress: in_progress
    } = state

    # Remove from pending
    new_pending = Map.delete(pending, file_path)

    # Check if already in progress (prevent duplicates)
    if MapSet.member?(in_progress, file_path) do
      Logger.debug("Skipping #{file_path} - already in progress")
      {:noreply, %{state | pending_ingestions: new_pending}}
    else
      Logger.info("Re-ingesting: #{file_path} (after #{@debounce_delay}ms debounce)")

      # Mark as in-progress
      new_in_progress = MapSet.put(in_progress, file_path)

      # Re-ingest asynchronously
      Task.start(fn ->
        result = reingest_file_with_retry(file_path, project_root, @max_retries)
        send(self(), {:reingest_complete, file_path, result})
      end)

      {:noreply, %{state | pending_ingestions: new_pending, in_progress: new_in_progress}}
    end
  end

  @impl true
  def handle_info({:reingest_complete, file_path, result}, %{in_progress: in_progress} = state) do
    # Re-ingestion completed (success or failure)
    case result do
      {:ok, _} ->
        Logger.info("✓ Successfully re-ingested: #{file_path}")

        # Auto-update graph for this file (async, non-blocking)
        update_graph_for_file(file_path)

      {:error, :file_busy} ->
        Logger.debug("⏭ Skipped #{file_path} - file is busy (being written)")

      {:error, reason} ->
        Logger.warning("✗ Failed to re-ingest #{file_path}: #{inspect(reason)}")
    end

    # Remove from in-progress
    new_in_progress = MapSet.delete(in_progress, file_path)

    {:noreply, %{state | in_progress: new_in_progress}}
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, :stop}, state) do
    Logger.warning("FileSystem watcher stopped")
    {:noreply, state}
  end

  # ------------------------------------------------------------------------------
  # Private Functions
  # ------------------------------------------------------------------------------

  # Re-ingest a file with retry logic.
  # Retries up to `max_retries` times with exponential backoff.
  # Skips file if it's detected as busy (being written).
  defp reingest_file_with_retry(file_path, project_root, retries_left) do
    case reingest_file(file_path, project_root) do
      {:ok, result} ->
        {:ok, result}

      {:error, :file_busy} ->
        # File is being written - don't retry, just skip
        {:error, :file_busy}

      {:error, reason} when retries_left > 0 ->
        # Transient error - retry with backoff
        Logger.debug(
          "Retry #{@max_retries - retries_left + 1}/#{@max_retries} for #{file_path} after error: #{inspect(reason)}"
        )

        Process.sleep(@retry_delay)
        reingest_file_with_retry(file_path, project_root, retries_left - 1)

      {:error, reason} ->
        # Max retries exceeded
        {:error, reason}
    end
  end

  # Re-ingest a single file into the database.
  # Uses StartupCodeIngestion's persistence logic to:
  # 1. Check if file is busy (being written)
  # 2. Parse file with CodeEngine NIF (tree-sitter)
  # 3. Extract enhanced metadata (dependencies, call graph, etc.)
  # 4. Upsert into code_files table
  defp reingest_file(file_path, project_root) do
    # Check if file is busy (recently modified - likely still being written)
    case check_file_busy(file_path) do
      {:busy, _} ->
        {:error, :file_busy}

      :ready ->
        # File is ready for ingestion
        do_reingest(file_path, project_root)
    end
  end

  defp check_file_busy(file_path) do
    case File.stat(file_path) do
      {:ok, %{mtime: mtime}} ->
        # Convert mtime to milliseconds since epoch
        mtime_ms = :calendar.datetime_to_gregorian_seconds(mtime) * 1000
        now_ms = System.system_time(:millisecond)

        if now_ms - mtime_ms < @busy_file_threshold do
          {:busy, "Modified #{now_ms - mtime_ms}ms ago"}
        else
          :ready
        end

      {:error, reason} ->
        # File doesn't exist or can't stat - skip
        Logger.debug("Could not stat #{file_path}: #{inspect(reason)}")
        {:busy, reason}
    end
  end

  defp do_reingest(file_path, _project_root) do
    # Auto-detect codebase_id from Git (e.g., "mikkihugo/singularity-incubation")
    # Uses default 5-minute cache (no extend_cache needed for single file hot reload)
    codebase_id = Singularity.Code.CodebaseDetector.detect(format: :full)

    # Check if HTDAG auto ingestion is enabled
    htdag_enabled =
      Application.get_env(:singularity, :htdag_auto_ingestion, %{})[:enabled] || false

    if htdag_enabled do
      # Use existing hot reload system with HTDAG integration
      case ModuleReloader.enqueue_file_reload(file_path, "code-file-watcher", %{
             codebase_id: codebase_id,
             source: :file_watcher
           }) do
        {:ok, dag_id} ->
          Logger.debug("Started HTDAG hot reload for file re-ingestion",
            file_path: file_path,
            dag_id: dag_id
          )

          {:ok, %{dag_id: dag_id, method: :htdag_hot_reload}}

        {:error, reason} ->
          Logger.warning("HTDAG hot reload failed, falling back to direct ingestion",
            file_path: file_path,
            reason: reason
          )

          # Fallback to direct ingestion
          fallback_to_direct_ingestion(file_path, codebase_id)
      end
    else
      # Use unified ingestion service directly - parses ONCE, populates BOTH tables
      fallback_to_direct_ingestion(file_path, codebase_id)
    end
  end

  defp fallback_to_direct_ingestion(file_path, codebase_id) do
    Singularity.Code.UnifiedIngestionService.ingest_file(file_path, codebase_id: codebase_id)
  end

  # Check if a file is a source file we want to monitor
  defp is_source_file?(file_path) do
    source_extensions = [
      # Elixir
      ".ex",
      ".exs",
      # Rust
      ".rs",
      # TypeScript
      ".ts",
      ".tsx",
      # JavaScript
      ".js",
      ".jsx",
      # Python
      ".py",
      # Go
      ".go",
      # Nix
      ".nix",
      # Shell
      ".sh",
      # TOML
      ".toml",
      # JSON
      ".json",
      # YAML
      ".yaml",
      ".yml",
      # Markdown
      ".md"
    ]

    # Check if file has a source extension
    has_source_extension =
      Enum.any?(source_extensions, fn ext ->
        String.ends_with?(file_path, ext)
      end)

    # Also check if it's not in ignored directories
    not_ignored = not ignore_file?(file_path)

    has_source_extension and not_ignored
  end

  # Ignore common non-source files and directories
  defp ignore_file?(file_path) do
    ignore_patterns = [
      # Build artifacts
      "/_build/",
      "/deps/",
      "/node_modules/",
      "/target/",
      "/.git/",
      "/.nix/",
      # Logs and temporary files
      ".log",
      ".tmp",
      ".pid",
      # OS files
      ".DS_Store",
      "Thumbs.db",
      # Large binary files
      ".png",
      ".jpg",
      ".jpeg",
      ".gif",
      ".ico",
      ".pdf",
      ".zip",
      ".tar.gz"
    ]

    Enum.any?(ignore_patterns, fn pattern ->
      String.contains?(file_path, pattern)
    end)
  end

  # Extract module name from file path.
  # For Elixir: lib/singularity/foo/bar.ex → Singularity.Foo.Bar
  # For other files: use the file path as identifier
  defp extract_module_name(file_path) do
    cond do
      String.ends_with?(file_path, ".ex") ->
        # Elixir module naming
        file_path
        |> String.replace(~r/^.*\/lib\//, "")
        |> String.replace(".ex", "")
        |> String.split("/")
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(".")

      true ->
        # For non-Elixir files, use the relative path as identifier
        file_path
        |> String.replace(File.cwd!() <> "/", "")
        |> String.replace("/", ".")
        # Remove file extension
        |> String.replace(~r/\.[^.]*$/, "")
    end
  end

  # Update graph for a single file after re-ingestion (async, non-blocking)
  defp update_graph_for_file(file_path) do
    Task.start(fn ->
      alias Singularity.{Repo, Schemas.CodeFile}
      import Ecto.Query

      # Get the updated file's metadata
      case Repo.one(from(c in CodeFile, where: c.file_path == ^file_path, limit: 1)) do
        nil ->
          Logger.debug("Skipping graph update for #{file_path} - not found in DB")

        file ->
          # Note: GraphPopulator functions are private, so we'll just trigger a full rebuild
          # This is acceptable since it uses UPSERT and will be fast for a single file
          Logger.debug("Scheduling graph update for #{file_path}...")

          # Trigger async full population (UPSERT will only update changed nodes/edges)
          Task.start(fn ->
            case Singularity.Graph.GraphPopulator.populate_all("singularity") do
              {:ok, _stats} ->
                Logger.debug("✓ Graph updated after #{file_path} change")

              {:error, reason} ->
                Logger.debug("Graph update failed (non-critical): #{inspect(reason)}")
            end
          end)
      end

      # Extract TODOs from the updated file (after database is updated)
      TodoExtractor.extract_after_file_update(file_path)
    end)
  end
end
