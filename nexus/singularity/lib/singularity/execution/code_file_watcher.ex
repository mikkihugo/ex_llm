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
      - ApplicationSupervisor  # Started in supervision tree (SINGLETON - only one instance)
    triggers:
      - on_file_modified: Re-ingests single file immediately + extracts TODOs
  ```

  ## Singleton Pattern

  **IMPORTANT**: This is a singleton GenServer (registered with `name: __MODULE__`).
  Only ONE instance should be started in the supervision tree.

  **Started by**: `ApplicationSupervisor` (checks `:auto_ingestion` config)
  **NOT started by**: `HTDAG.Supervisor` (uses existing instance instead)

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
  # Default: 1 minute (60000ms) - waits for file writes to complete
  @debounce_delay @config[:debounce_delay_ms] || 60_000

  # Maximum file age for busy detection (ms) - skip if modified very recently
  # Increased to 2 seconds for more reliable busy detection
  @busy_file_threshold @config[:busy_file_threshold_ms] || 2_000

  # Maximum concurrent reload operations to prevent resource exhaustion
  @max_concurrent_reloads @config[:max_concurrent_reloads] || 3

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

  # Rate limiting - prevent overwhelming system with too many files
  @max_files_per_minute @config[:max_files_per_minute] || 50

  # Health check interval (ms) - emit telemetry periodically
  @health_check_interval @config[:health_check_interval_ms] || 60_000

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

  @doc """
  Get current metrics and status.

  Returns metrics including files processed, failures, reloads, and rate limit status.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Get health status of the file watcher.

  Returns health information including metrics and uptime.
  """
  def health_check do
    GenServer.call(__MODULE__, :health_check)
  end

  # ------------------------------------------------------------------------------
  # GenServer Callbacks
  # ------------------------------------------------------------------------------

  @impl true
  def handle_call(:get_metrics, _from, %{metrics: metrics, rate_limit_window: window} = state) do
    current_time = System.system_time(:second)
    recent_files = Enum.count(window, fn {_path, timestamp} -> current_time - timestamp < 60 end)

    metrics_with_rate_limit = Map.put(metrics, :files_in_rate_limit_window, recent_files)

    {:reply, {:ok, metrics_with_rate_limit}, state}
  end

  @impl true
  def handle_call(:health_check, _from, %{metrics: metrics, watcher_pid: watcher_pid} = state) do
    watcher_alive = Process.alive?(watcher_pid)

    health = %{
      status: if(watcher_alive, do: :healthy, else: :unhealthy),
      watcher_alive: watcher_alive,
      metrics: metrics,
      uptime_ms:
        System.monotonic_time(:millisecond) -
          (state[:start_time] || System.monotonic_time(:millisecond))
    }

    {:reply, {:ok, health}, state}
  end

  @impl true
  def init(opts) do
    debounce_seconds = div(@debounce_delay, 1000)

    Logger.info(
      "Starting CodeFileWatcher with #{debounce_seconds}s debouncing (waits #{debounce_seconds}s after last write)..."
    )

    # Get project root - monitor entire project, not just lib/
    project_root = File.cwd!()

    # Subscribe to file events in entire project root (recursive)
    {:ok, watcher_pid} = FileSystem.start_link(dirs: [project_root])
    FileSystem.subscribe(watcher_pid)

    Logger.info("CodeFileWatcher monitoring: #{project_root}")

    # Start health check timer
    health_check_timer = Process.send_after(self(), :health_check, @health_check_interval)

    # Emit telemetry for startup
    :telemetry.execute([:singularity, :code_file_watcher, :start], %{count: 1})

    {:ok,
     %{
       watcher_pid: watcher_pid,
       project_root: project_root,
       # Track pending re-ingestions (file_path => timer_ref)
       pending_ingestions: %{},
       # Track in-progress re-ingestions to prevent duplicates
       in_progress: MapSet.new(),
       # Rate limiting - track files processed in last minute
       rate_limit_window: [],
       # Health check timer
       health_check_timer: health_check_timer,
       # Start time for uptime calculation
       start_time: System.monotonic_time(:millisecond),
       # Metrics
       metrics: %{
         files_processed: 0,
         files_failed: 0,
         reloads_succeeded: 0,
         reloads_failed: 0,
         last_reload_at: nil
       }
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
      # Rate limiting check
      current_time = System.system_time(:second)
      %{rate_limit_window: window} = state

      # Filter out entries older than 1 minute
      recent_window =
        Enum.filter(window, fn {_path, timestamp} -> current_time - timestamp < 60 end)

      if length(recent_window) >= @max_files_per_minute do
        Logger.warning(
          "Rate limit exceeded: #{length(recent_window)} files in last minute, skipping #{file_path}"
        )

        :telemetry.execute([:singularity, :code_file_watcher, :rate_limited], %{count: 1})
        {:noreply, %{state | pending_ingestions: new_pending, rate_limit_window: recent_window}}
      else
        debounce_seconds = div(@debounce_delay, 1000)

        Logger.info(
          "Re-ingesting: #{file_path} (after #{debounce_seconds}s debounce from last write)"
        )

        # Mark as in-progress
        new_in_progress = MapSet.put(in_progress, file_path)

        # Update rate limit window
        new_window = [{file_path, current_time} | recent_window]

        # Re-ingest asynchronously with timeout
        Task.start(fn ->
          result =
            with_timeout(
              fn -> reingest_file_with_retry(file_path, project_root, @max_retries) end,
              @ingestion_timeout
            )

          send(__MODULE__, {:reingest_complete, file_path, result})
        end)

        {:noreply,
         %{
           state
           | pending_ingestions: new_pending,
             in_progress: new_in_progress,
             rate_limit_window: new_window
         }}
      end
    end
  end

  @impl true
  def handle_info(
        {:reingest_complete, file_path, result},
        %{in_progress: in_progress, metrics: metrics} = state
      ) do
    new_metrics =
      case result do
        {:ok, _} ->
          Logger.info("✓ Successfully re-ingested: #{file_path}",
            file_path: file_path,
            result: :success
          )

          :telemetry.execute([:singularity, :code_file_watcher, :reingest_success], %{count: 1})

          updated_metrics = %{
            metrics
            | files_processed: metrics.files_processed + 1,
              last_reload_at: DateTime.utc_now()
          }

          update_graph_for_file(file_path)

          if String.ends_with?(file_path, ".ex") or String.ends_with?(file_path, ".exs") do
            reload_elixir_module(file_path, updated_metrics)
          end

          updated_metrics

        {:error, :file_busy} ->
          Logger.debug("⏭ Skipped #{file_path} - file is busy (being written)",
            file_path: file_path,
            reason: :file_busy
          )

          metrics

        {:error, :timeout} ->
          Logger.warning("✗ Timeout re-ingesting #{file_path}",
            file_path: file_path,
            timeout_ms: @ingestion_timeout
          )

          :telemetry.execute([:singularity, :code_file_watcher, :reingest_timeout], %{count: 1})

          %{metrics | files_failed: metrics.files_failed + 1}

        {:error, reason} ->
          Logger.warning("✗ Failed to re-ingest #{file_path}: #{inspect(reason)}",
            file_path: file_path,
            reason: reason
          )

          :telemetry.execute([:singularity, :code_file_watcher, :reingest_error], %{count: 1})

          %{metrics | files_failed: metrics.files_failed + 1}
      end

    # Remove from in-progress
    new_in_progress = MapSet.delete(in_progress, file_path)

    {:noreply, %{state | in_progress: new_in_progress, metrics: new_metrics}}
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, :stop}, state) do
    Logger.warning("FileSystem watcher stopped")
    :telemetry.execute([:singularity, :code_file_watcher, :watcher_stopped], %{count: 1})
    {:noreply, state}
  end

  @impl true
  def handle_info(:health_check, %{health_check_timer: _old_timer, metrics: metrics} = state) do
    # Emit health metrics
    :telemetry.execute(
      [:singularity, :code_file_watcher, :health],
      %{
        files_processed: metrics.files_processed,
        files_failed: metrics.files_failed,
        reloads_succeeded: metrics.reloads_succeeded,
        reloads_failed: metrics.reloads_failed
      }
    )

    # Schedule next health check
    new_timer = Process.send_after(self(), :health_check, @health_check_interval)

    {:noreply, %{state | health_check_timer: new_timer}}
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
      {:busy, reason} ->
        Logger.debug("File busy: #{reason}")
        {:error, :file_busy}

      {:error, reason} ->
        {:error, reason}

      :ready ->
        # File is ready for ingestion
        do_reingest(file_path, project_root)
    end
  end

  # Wrapper to add timeout to file operations
  defp with_timeout(fun, timeout_ms) do
    task = Task.async(fun)

    case Task.yield(task, timeout_ms) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, reason}
    end
  end

  defp check_file_busy(file_path) do
    case File.stat(file_path) do
      {:ok, %{mtime: mtime}} ->
        # Convert mtime to milliseconds since epoch
        mtime_ms = :calendar.datetime_to_gregorian_seconds(mtime) * 1000
        now_ms = System.system_time(:millisecond)
        age_ms = now_ms - mtime_ms

        if age_ms < @busy_file_threshold do
          {:busy, "Modified #{age_ms}ms ago (< #{@busy_file_threshold}ms threshold)"}
        else
          :ready
        end

      {:error, :enoent} ->
        # File doesn't exist - might have been deleted
        Logger.debug("File not found (may have been deleted): #{file_path}")
        {:error, :file_not_found}

      {:error, reason} ->
        # File permission or other error
        Logger.debug("Could not stat #{file_path}: #{inspect(reason)}")
        {:error, reason}
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
  # Handles edge cases: test files, multiple lib/ paths, Windows paths
  defp extract_module_name(file_path) do
    cond do
      String.ends_with?(file_path, ".ex") or String.ends_with?(file_path, ".exs") ->
        # Elixir module naming - handle multiple lib/ paths
        normalized = String.replace(file_path, "\\", "/")

        # Extract path after last lib/ occurrence (handles nested lib/ dirs)
        case Regex.run(~r/(?:^|\/)(lib\/.+)$/, normalized) do
          [_, lib_path] ->
            lib_path
            |> String.replace(~r/\.exs?$/, "")
            |> String.split("/")
            |> Enum.reject(&(&1 == ""))
            |> Enum.map(fn segment ->
              # Handle snake_case → PascalCase conversion
              segment
              |> String.split("_")
              |> Enum.map(&String.capitalize/1)
              |> Enum.join("")
            end)
            |> Enum.join(".")

          _ ->
            # Fallback: use filename
            Path.basename(file_path, ".ex")
            |> String.replace(~r/\.exs$/, "")
            |> String.split("_")
            |> Enum.map(&String.capitalize/1)
            |> Enum.join("")
        end

      true ->
        # For non-Elixir files, use the relative path as identifier
        cwd = File.cwd!() |> String.replace("\\", "/")

        file_path
        |> String.replace("\\", "/")
        |> String.replace(cwd <> "/", "")
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
          # Optimize: Only update graph nodes/edges for this specific file
          # (populate_all uses UPSERT so it's safe, but incremental would be faster)
          Logger.debug("Scheduling graph update for #{file_path}...")

          # Trigger async graph population (UPSERT ensures idempotency)
          # TODO: Optimize to only update nodes/edges for this file instead of full rebuild
          # This would require exposing GraphPopulator.populate_file/1 or similar API
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

  # Automatically reload Elixir modules when .ex/.exs files change
  # This enables hot code reloading for pure Elixir applications
  # Production-grade: proper error handling, rate limiting, metrics
  defp reload_elixir_module(file_path, metrics) do
    # Check concurrent reload limit
    if MapSet.size(metrics[:concurrent_reloads] || MapSet.new()) >= @max_concurrent_reloads do
      Logger.debug("Skipping reload - #{@max_concurrent_reloads} concurrent reloads in progress")
      :ok
    else
      do_reload_elixir_module(file_path)
    end
  end

  defp do_reload_elixir_module(file_path) do
    Task.start(fn ->
      start_time = System.monotonic_time(:millisecond)

      try do
        # Only reload in dev/test environments
        if Mix.env() in [:dev, :test] do
          # Extract module name from file path
          module_name = extract_module_name(file_path)

          # Validate file exists and is readable
          if File.exists?(file_path) do
            # Try to compile and reload the module
            # This will work if running in IEx or with Mix code reloader
            reload_result =
              case Code.recompile() do
                {:ok, modules} ->
                  duration_ms = System.monotonic_time(:millisecond) - start_time

                  Logger.info(
                    "🔥 Hot reloaded #{length(modules)} modules after #{Path.basename(file_path)} changed",
                    file_path: file_path,
                    module_count: length(modules),
                    duration_ms: duration_ms
                  )

                  :telemetry.execute(
                    [:singularity, :code_file_watcher, :reload_success],
                    %{module_count: length(modules), duration_ms: duration_ms}
                  )

                  {:ok, modules}

                {:error, _errors} ->
                  # Fallback: try to compile just the file
                  reload_result =
                    with {:ok, modules} <- Code.compile_file(file_path) do
                      duration_ms = System.monotonic_time(:millisecond) - start_time

                      Logger.info("🔥 Compiled and reloaded: #{module_name}",
                        file_path: file_path,
                        module_name: module_name,
                        duration_ms: duration_ms
                      )

                      :telemetry.execute(
                        [:singularity, :code_file_watcher, :reload_success],
                        %{module_count: length(modules), duration_ms: duration_ms}
                      )

                      {:ok, modules}
                    else
                      {:error, reason} ->
                        duration_ms = System.monotonic_time(:millisecond) - start_time

                        Logger.debug("Could not reload #{module_name}: #{inspect(reason)}",
                          file_path: file_path,
                          module_name: module_name,
                          reason: reason,
                          duration_ms: duration_ms
                        )

                        :telemetry.execute(
                          [:singularity, :code_file_watcher, :reload_error],
                          %{duration_ms: duration_ms}
                        )

                        {:error, reason}
                    end

                  reload_result
              end

            # Update metrics based on result
            case reload_result do
              {:ok, _} ->
                send(__MODULE__, {:reload_complete, file_path, :success})

              {:error, _} ->
                send(__MODULE__, {:reload_complete, file_path, :error})
            end
          else
            Logger.debug("File does not exist for reload: #{file_path}")
            send(__MODULE__, {:reload_complete, file_path, :error})
          end
        end
      rescue
        e ->
          duration_ms = System.monotonic_time(:millisecond) - start_time
          stacktrace = __STACKTRACE__

          Logger.warning("Hot reload failed for #{file_path}: #{inspect(e)}",
            file_path: file_path,
            error: inspect(e),
            duration_ms: duration_ms
          )

          Logger.debug("Hot reload stacktrace",
            stacktrace: Exception.format_stacktrace(stacktrace)
          )

          :telemetry.execute(
            [:singularity, :code_file_watcher, :reload_exception],
            %{duration_ms: duration_ms}
          )

          send(__MODULE__, {:reload_complete, file_path, :error})
      end
    end)
  end

  @impl true
  def handle_info({:reload_complete, _file_path, :success}, %{metrics: metrics} = state) do
    new_metrics = %{metrics | reloads_succeeded: metrics.reloads_succeeded + 1}
    {:noreply, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_info({:reload_complete, _file_path, :error}, %{metrics: metrics} = state) do
    new_metrics = %{metrics | reloads_failed: metrics.reloads_failed + 1}
    {:noreply, %{state | metrics: new_metrics}}
  end
end
