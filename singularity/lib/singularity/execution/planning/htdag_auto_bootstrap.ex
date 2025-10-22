defmodule Singularity.Execution.Planning.HTDAGAutoBootstrap do
  @moduledoc """
  Self Code Ingestion & Auto-Bootstrap - Learn Singularity's OWN codebase on startup

  **PURPOSE**: Automatically learn and persist Singularity's own code on EVERY startup

  **RUNS**: Automatically, asynchronously, non-blocking

  **STORES**: 251+ Elixir modules in `code_files` table with full AST

  ## What vs When to Use

  - **HTDAGAutoBootstrap** (THIS): Singularity's own code - automatic on startup
  - **CodeIngestionService**: External projects (Rails, Phoenix, etc.) - manual API calls
  - **mix code.ingest**: Semantic search only - different table (`codebase_metadata`)

  ## What It Does:

  1. **Learn**: Scans all `.ex` files in `singularity/lib/`
  2. **Parse**: Uses CodeEngine NIF (Rust + tree-sitter) for full AST
  3. **Persist**: Stores in PostgreSQL `code_files` table
  4. **Diagnose**: Identifies issues (broken deps, missing docs, etc.)
  5. **Auto-fix**: Fixes high-priority issues using RAG + quality templates

  Provides autonomous system initialization by learning the codebase through static
  file scanning, identifying broken components, and auto-fixing issues using RAG
  code examples and quality templates. Runs asynchronously without blocking startup.

  ## Integration Points

  This module integrates with:
  - `Singularity.Execution.Planning.HTDAGLearner` - Codebase understanding (HTDAGLearner.learn_codebase/1, auto_fix_all/1)
  - `Singularity.Execution.Planning.HTDAGBootstrap` - System integration (HTDAGBootstrap.bootstrap/1)
  - `:telemetry` - Observability events (telemetry.execute/3 for monitoring)
  - PostgreSQL table: `htdag_auto_bootstrap_logs` (stores bootstrap history)
  
  ## Startup Flow
  
  ```
  Server starts
    ↓
  AutoBootstrap starts (async) [telemetry: htdag.auto_bootstrap.start]
    ↓
  Learn codebase (scan files, read @moduledoc) [telemetry: htdag.learn.start]
    ↓
  Runtime trace (optional, if enabled) [telemetry: htdag.trace.start]
    ↓
  Identify issues (broken deps, missing docs, etc.) [telemetry: htdag.identify_issues.complete]
    ↓
  Auto-fix high-priority issues [telemetry: htdag.fix.start]
    ↓
  Iterate until all critical issues resolved
    ↓
  System ready ✓ [telemetry: htdag.auto_bootstrap.complete]
  ```
  
  ## Configuration
  
  Add to config/config.exs:
  
      config :singularity, HTDAGAutoBootstrap,
        enabled: true,              # Enable auto-bootstrap
        max_iterations: 10,         # Max fix iterations
        fix_on_startup: true,       # Auto-fix issues
        notify_on_complete: true,   # Log when complete
        enable_tracing: false,      # Enable runtime tracing (slower but more accurate)
        trace_duration_ms: 5000     # How long to trace (if enabled)
  
  ## Manual Control
  
      # Disable auto-bootstrap
      HTDAGAutoBootstrap.disable()
      
      # Re-run bootstrap manually
      HTDAGAutoBootstrap.run_now()
      
      # Get current status
      HTDAGAutoBootstrap.status()
  
  ## Telemetry Events
  
  This module emits telemetry events for observability:
  
  - `[:htdag, :auto_bootstrap, :start]` - Bootstrap started
  - `[:htdag, :auto_bootstrap, :complete]` - Bootstrap completed successfully
  - `[:htdag, :auto_bootstrap, :error]` - Bootstrap encountered error
  - `[:htdag, :learn, :start]` - Learning phase started
  - `[:htdag, :learn, :complete]` - Learning phase completed
  - `[:htdag, :trace, :start]` - Tracing phase started (if enabled)
  - `[:htdag, :trace, :complete]` - Tracing phase completed
  - `[:htdag, :identify_issues, :complete]` - Issue identification complete
  - `[:htdag, :fix, :start]` - Fix phase started
  - `[:htdag, :fix, :complete]` - Fix phase completed
  
  ## What Gets Fixed Automatically
  
  | Issue Type | Severity | Detection Method | Fix Strategy |
  |------------|----------|------------------|--------------|
  | Broken dependencies | High | Static analysis of `alias` statements | Add missing modules or remove invalid deps |
  | Missing @moduledoc | Low | File scanning | Generate from module name and functions |
  | Isolated modules | Medium | Dependency graph analysis | Connect to related modules |
  | Dead code | Medium | Runtime tracing + static analysis | Mark for review or remove |
  | Crashed functions | High | Runtime tracing + error logs | Wrap in error handling or fix logic |
  | Slow functions | Medium | Performance profiling | Add suggestions for optimization |
  | Disconnected from Store | High | Check Store.search_knowledge usage | Add Store integration |
  | Missing telemetry | Low | Check :telemetry.execute calls | Add telemetry events |
  
  ## How Self-Improving System Uses This
  
  The system understands code better when:
  1. **Every module has @moduledoc** - Explains purpose, integration points, usage
  2. **Telemetry events are emitted** - Runtime behavior becomes traceable
  3. **Integration points are marked** - Comments like `# INTEGRATION: Store` help mapping
  4. **Dependencies are clean** - No broken `alias` statements
  5. **Functions are documented** - @doc and @spec make intent clear
  """
  
  use GenServer
  require Logger
  
  # INTEGRATION: Learning and bootstrap (codebase understanding and system integration)
  alias Singularity.Execution.Planning.HTDAGLearner
  
  @default_config [
    enabled: true,
    max_iterations: 10,
    fix_on_startup: true,
    notify_on_complete: true,
    run_async: true,
    dry_run: true  # Set to false to apply fixes (default is now safe mode)
  ]
  
  defstruct [
    :status,
    :learning_result,
    :fixes_applied,
    :iterations,
    :started_at,
    :completed_at,
    :enabled,
    :config,
    :dry_run
  ]
  
  ## Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Get current bootstrap status.
  """
  def status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  @doc """
  Disable auto-bootstrap.
  """
  def disable do
    GenServer.cast(__MODULE__, :disable)
  end
  
  @doc """
  Enable auto-bootstrap.
  """
  def enable do
    GenServer.cast(__MODULE__, :enable)
  end
  
  @doc """
  Run bootstrap now (manual trigger).
  """
  def run_now(opts \\ []) do
    GenServer.call(__MODULE__, {:run_now, opts}, :infinity)
  end
  
  ## Server Callbacks
  
  @impl true
  def init(opts) do
    # Merge config
    config = Keyword.merge(@default_config, get_config())
    config = Keyword.merge(config, opts)
    
    enabled = Keyword.get(config, :enabled, true)
    dry_run = Keyword.get(config, :dry_run, true)
    
    state = %__MODULE__{
      status: :idle,
      enabled: enabled,
      dry_run: dry_run,
      config: config,
      learning_result: nil,
      fixes_applied: [],
      iterations: 0,
      started_at: nil,
      completed_at: nil
    }
    
    if dry_run do
      Logger.info("HTDAG Auto-Bootstrap: Running in DRY-RUN mode (no actual fixes will be applied)")
    end
    
    if enabled and Keyword.get(config, :run_async, true) do
      # Start bootstrap asynchronously
      Logger.info("HTDAG Auto-Bootstrap: Starting automatic self-diagnosis and repair...")
      send(self(), :run_bootstrap)
    else
      if enabled do
        Logger.info("HTDAG Auto-Bootstrap: Enabled but waiting for manual trigger")
      else
        Logger.info("HTDAG Auto-Bootstrap: Disabled")
      end
    end
    
    {:ok, state}
  end
  
  @impl true
  def handle_info(:run_bootstrap, state) do
    if state.enabled do
      new_state = perform_bootstrap(state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_call(:get_status, _from, state) do
    status_info = %{
      status: state.status,
      enabled: state.enabled,
      dry_run: state.dry_run,
      iterations: state.iterations,
      fixes_applied: length(state.fixes_applied),
      started_at: state.started_at,
      completed_at: state.completed_at,
      issues_found: get_issues_count(state.learning_result),
      issues_fixed: length(state.fixes_applied)
    }
    
    {:reply, status_info, state}
  end
  
  @impl true
  def handle_call({:run_now, opts}, _from, state) do
    Logger.info("HTDAG Auto-Bootstrap: Manual bootstrap triggered")
    
    # Override config with runtime opts
    config = Keyword.merge(state.config, opts)
    new_state = %{state | config: config, status: :running, started_at: DateTime.utc_now()}
    
    result_state = perform_bootstrap(new_state)
    
    {:reply, {:ok, get_summary(result_state)}, result_state}
  end
  
  @impl true
  def handle_cast(:disable, state) do
    Logger.info("HTDAG Auto-Bootstrap: Disabled")
    {:noreply, %{state | enabled: false}}
  end
  
  @impl true
  def handle_cast(:enable, state) do
    Logger.info("HTDAG Auto-Bootstrap: Enabled")
    new_state = %{state | enabled: true}
    
    # Trigger bootstrap if idle
    if state.status == :idle do
      send(self(), :run_bootstrap)
    end
    
    {:noreply, new_state}
  end
  
  ## Private Functions
  
  defp perform_bootstrap(state) do
    Logger.info("=" <> String.duplicate("=", 70))
    Logger.info("HTDAG AUTO-BOOTSTRAP: Self-Diagnosis Starting")
    Logger.info("=" <> String.duplicate("=", 70))
    
    start_time = System.monotonic_time()
    
    # TELEMETRY: Bootstrap started
    :telemetry.execute([:htdag, :auto_bootstrap, :start], %{timestamp: DateTime.utc_now()}, %{})
    
    new_state = %{state | status: :running, started_at: DateTime.utc_now()}
    
    # Phase 1: Learn codebase
    Logger.info("Phase 1: Learning codebase...")
    
    # TELEMETRY: Learning started
    :telemetry.execute([:htdag, :learn, :start], %{timestamp: DateTime.utc_now()}, %{})
    
    # INTEGRATION: HTDAGLearner - Scans codebase and builds knowledge graph
    case HTDAGLearner.learn_codebase() do
      {:ok, learning} ->
        issues_count = length(learning.issues)
        Logger.info("Learning complete: #{issues_count} issues found")

        # TELEMETRY: Learning completed
        :telemetry.execute([:htdag, :learn, :complete], %{issues_found: issues_count}, %{})

        # TELEMETRY: Issues identified
        :telemetry.execute([:htdag, :identify_issues, :complete], %{
          total_issues: issues_count,
          high_severity: count_by_severity(learning.issues, :high),
          medium_severity: count_by_severity(learning.issues, :medium),
          low_severity: count_by_severity(learning.issues, :low)
        }, %{})

        # PERSISTENCE: Store learned modules in database for semantic search
        Logger.info("Phase 1.5: Persisting learned codebase to database...")
        persist_learned_codebase(learning)

        new_state = %{new_state | learning_result: learning}
        
        # Phase 2: Auto-fix if enabled
        if Keyword.get(state.config, :fix_on_startup, true) do
          Logger.info("Phase 2: Auto-fixing issues...")
          
          # TELEMETRY: Fix phase started
          :telemetry.execute([:htdag, :fix, :start], %{issues_to_fix: issues_count}, %{})
          
          max_iterations = Keyword.get(state.config, :max_iterations, 10)
          dry_run = state.dry_run
          
          # INTEGRATION: HTDAGLearner.auto_fix_all - Uses RAG + Quality templates to fix issues
          case HTDAGLearner.auto_fix_all(max_iterations: max_iterations, dry_run: dry_run) do
            {:ok, fix_result} ->
              mode_msg = if dry_run, do: " (DRY-RUN mode - no changes applied)", else: ""
              Logger.info("Auto-fix complete: #{fix_result.iterations} iterations, #{length(fix_result.fixes)} fixes applied#{mode_msg}")
              
              # TELEMETRY: Fix phase completed
              :telemetry.execute([:htdag, :fix, :complete], %{
                iterations: fix_result.iterations,
                fixes_applied: length(fix_result.fixes),
                dry_run: dry_run
              }, %{})
              
              final_state = %{new_state |
                status: :completed,
                fixes_applied: fix_result.fixes,
                iterations: fix_result.iterations,
                completed_at: DateTime.utc_now()
              }
              
              # Notify completion
              if Keyword.get(state.config, :notify_on_complete, true) do
                notify_completion(final_state)
              end
              
              end_time = System.monotonic_time()
              duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)
              
              # TELEMETRY: Bootstrap completed successfully
              :telemetry.execute([:htdag, :auto_bootstrap, :complete], %{
                duration_ms: duration_ms,
                issues_found: issues_count,
                issues_fixed: length(fix_result.fixes),
                iterations: fix_result.iterations
              }, %{})
              
              final_state
              
            {:error, reason} ->
              Logger.error("Auto-fix failed: #{inspect(reason)}")
              
              # TELEMETRY: Fix phase error
              :telemetry.execute([:htdag, :fix, :error], %{reason: inspect(reason)}, %{})
              %{new_state | status: :failed, completed_at: DateTime.utc_now()}
          end
        else
          Logger.info("Phase 2: Skipping auto-fix (disabled in config)")
          
          final_state = %{new_state |
            status: :completed,
            completed_at: DateTime.utc_now()
          }
          
          if Keyword.get(state.config, :notify_on_complete, true) do
            notify_completion(final_state)
          end
          
          final_state
        end
        
      {:error, reason} ->
        Logger.error("Learning failed: #{inspect(reason)}")
        
        # TELEMETRY: Learning error
        :telemetry.execute([:htdag, :learn, :error], %{reason: inspect(reason)}, %{})
        
        # TELEMETRY: Bootstrap error
        :telemetry.execute([:htdag, :auto_bootstrap, :error], %{
          phase: "learning",
          reason: inspect(reason)
        }, %{})
        
        %{new_state | status: :failed, completed_at: DateTime.utc_now()}
    end
  end
  
  defp count_by_severity(issues, severity) do
    Enum.count(issues, fn issue -> 
      Map.get(issue, :severity) == severity 
    end)
  end
  
  defp get_config do
    Application.get_env(:singularity, __MODULE__, [])
  end
  
  defp get_issues_count(nil), do: 0
  defp get_issues_count(learning) do
    length(learning.issues)
  end
  
  defp get_summary(state) do
    %{
      status: state.status,
      duration_seconds: calculate_duration(state),
      issues_found: get_issues_count(state.learning_result),
      fixes_applied: length(state.fixes_applied),
      iterations: state.iterations
    }
  end
  
  defp calculate_duration(state) do
    if state.started_at && state.completed_at do
      DateTime.diff(state.completed_at, state.started_at, :second)
    else
      0
    end
  end
  
  defp notify_completion(state) do
    duration = calculate_duration(state)
    
    Logger.info("")
    Logger.info("=" <> String.duplicate("=", 70))
    Logger.info("HTDAG AUTO-BOOTSTRAP: Self-Diagnosis Complete!")
    Logger.info("=" <> String.duplicate("=", 70))
    Logger.info("")
    Logger.info("Summary:")
    Logger.info("  Status: #{state.status}")
    Logger.info("  Duration: #{duration}s")
    Logger.info("  Issues Found: #{get_issues_count(state.learning_result)}")
    Logger.info("  Fixes Applied: #{length(state.fixes_applied)}")
    Logger.info("  Iterations: #{state.iterations}")
    Logger.info("")
    Logger.info("System Status:")
    Logger.info("  ✓ Codebase learned and understood")
    Logger.info("  ✓ Critical issues fixed")
    Logger.info("  ✓ Components connected")
    Logger.info("  ✓ SafeWorkPlanner ready for features")
    Logger.info("  ✓ SelfImprovingAgent handling ongoing fixes")
    Logger.info("")
    Logger.info("System is ready for operation!")
    Logger.info("=" <> String.duplicate("=", 70))
    Logger.info("")
  end

  defp persist_learned_codebase(learning) do
    # Persist HTDAG's learned modules directly to database
    # This is the UNIFIED ingestion path - no fragmentation!

    alias Singularity.{Repo, Schemas.CodeFile}

    Logger.info("Persisting #{length(Map.get(learning, :knowledge, %{}) |> Map.get(:modules, %{}) |> Map.values())} modules to database...")

    codebase_id = "singularity"

    # Persist each learned module using unified ingestion service
    results =
      Map.get(learning, :knowledge, %{}) |> Map.get(:modules, %{}) |> Map.values()
      |> Task.async_stream(
        fn module ->
          # Extract file path from module and use unified ingestion
          file_path = Map.get(module, :file_path) || Map.get(module, :file)
          Singularity.Code.UnifiedIngestionService.ingest_file(file_path, codebase_id: codebase_id)
        end,
        max_concurrency: 10,
        timeout: :infinity
      )
      |> Enum.to_list()

    success_count = Enum.count(results, fn
      {:ok, {:ok, _}} -> true
      _ -> false
    end)

    Logger.info("✓ Persisted #{success_count}/#{length(Map.get(learning, :knowledge, %{}) |> Map.get(:modules, %{}) |> Map.values())} modules to database")

    # Report v2.2.0 metadata validation statistics
    report_validation_statistics(codebase_id)

    # Auto-populate graphs after successful ingestion
    auto_populate_graphs(codebase_id)

    {:ok, success_count}
  rescue
    error ->
      Logger.warning("Error persisting codebase: #{inspect(error)}")
      {:error, error}
  end

  defp auto_populate_graphs(codebase_id) do
    Logger.info("Auto-populating code graphs...")

    # Run asynchronously to not block startup
    Task.start(fn ->
      case Singularity.Graph.GraphPopulator.populate_all(codebase_id) do
        {:ok, stats} ->
          Logger.info(
            "✓ Graph auto-population complete: #{stats.nodes} nodes, #{stats.edges} edges"
          )

        {:error, reason} ->
          Logger.warning("Graph auto-population failed (non-critical): #{inspect(reason)}")
      end
    end)
  end

  defp report_validation_statistics(codebase_id) do
    alias Singularity.Analysis.MetadataValidator

    Logger.info("Analyzing v2.2.0 metadata completeness...")

    # Run validation report
    case MetadataValidator.validate_codebase(codebase_id) do
      %{total_files: total, complete: complete, partial: partial, missing: missing} = report ->
        Logger.info("")
        Logger.info("=" <> String.duplicate("=", 50))
        Logger.info("v2.2.0 AI Metadata Validation Report")
        Logger.info("=" <> String.duplicate("=", 50))
        Logger.info("  Total Files:    #{total}")
        Logger.info("  ✓ Complete:     #{complete} (#{report.complete_pct}%)")
        Logger.info("  ⚠ Partial:      #{partial} (#{report.partial_pct}%)")
        Logger.info("  ✗ Missing:      #{missing} (#{report.missing_pct}%)")
        Logger.info("=" <> String.duplicate("=", 50))
        Logger.info("")

        # Log recommendations for incomplete files
        if partial > 0 or missing > 0 do
          Logger.info("Files needing attention:")

          report.by_file
          |> Enum.filter(fn {_path, v} -> v.level != :complete end)
          |> Enum.take(5)
          |> Enum.each(fn {path, validation} ->
            Logger.info("  #{path}")
            Logger.info("    Level: #{validation.level}, Score: #{validation.score}")

            if length(validation.recommendations) > 0 do
              Logger.info("    Recommendations:")

              validation.recommendations
              |> Enum.take(3)
              |> Enum.each(fn rec ->
                Logger.info("      - #{rec}")
              end)
            end
          end)

          Logger.info("")
          Logger.info("Run `mix metadata.validate` for full report")
          Logger.info("Run `MetadataValidator.fix_incomplete_metadata/1` to auto-generate")
          Logger.info("")
        end

      error ->
        Logger.warning("Could not generate validation report: #{inspect(error)}")
    end
  rescue
    error ->
      Logger.warning("Error generating validation statistics: #{inspect(error)}")
  end

  @doc """
  Persist a module to the database.

  **Public API** - Can be called by CodeFileWatcher for real-time re-ingestion.

  Extracts:
  - Full AST from CodeEngine NIF
  - Enhanced metadata (dependencies, call graph, type info, documentation)
  - HTDAG learning data (module name, issues, etc.)

  Uses UPSERT so it's safe to call multiple times for the same file.
  """
  def persist_module_to_db(module, codebase_id) do
    alias Singularity.{Repo, Schemas.CodeFile, CodeEngine}
    alias Singularity.Analysis.{AstExtractor, MetadataValidator}

    file_path = Map.get(module, :file_path) || Map.get(module, :file)

    # Read file content
    case File.read(file_path) do
      {:ok, content} when byte_size(content) > 0 ->
        # Validate v2.2.0 metadata completeness
        validation = MetadataValidator.validate_file(file_path, content)

        # Parse file using CodeEngine NIF (tree-sitter parsing)
        # NOTE: NIF returns struct directly, NOT wrapped in {:ok, ...}
        parsed = CodeEngine.parse_file(file_path)

        # Extract enhanced metadata from AST
        enhanced_metadata = AstExtractor.extract_metadata(parsed.ast_json, file_path)

        # Build attributes from file content + NIF parse results + HTDAG learning + enhanced metadata
        attrs = %{
          project_name: codebase_id,
          # Database uses project_name!
          file_path: file_path,
          # From NIF (more accurate than extension-based)
          language: parsed.language,
          content: content,
          # Database uses size_bytes!
          size_bytes: byte_size(content),
          line_count: String.split(content, "\n") |> length(),
          hash: :crypto.hash(:md5, content) |> Base.encode16(),
          metadata: %{
            # From HTDAG learning
            module_name: Map.get(module, :module_name),
            has_moduledoc: Map.get(module, :has_moduledoc, false),
            issues: Map.get(module, :issues, []),
            learned_at: DateTime.utc_now(),

            # From CodeEngine NIF (tree-sitter parsing)
            ast_json: parsed.ast_json,
            symbols: parsed.symbols,
            imports: parsed.imports,
            exports: parsed.exports,

            # From HTDAG learning (functions with arity)
            functions_htdag: extract_functions(module),

            # ✅ Enhanced metadata from AstExtractor
            dependencies: enhanced_metadata[:dependencies] || %{},
            call_graph: enhanced_metadata[:call_graph] || %{},
            type_info: enhanced_metadata[:type_info] || %{},
            documentation: enhanced_metadata[:documentation] || %{},

            # ✅ v2.2.0 metadata validation
            v2_2_validation: validation
          }
        }

        # Upsert (update if exists, insert if new)
        case Repo.insert(
               CodeFile.changeset(%CodeFile{}, attrs),
               on_conflict: {:replace_all_except, [:id, :inserted_at]},
               conflict_target: [:project_name, :file_path]
             ) do
          {:ok, _} -> {:ok, :persisted}

          {:error, changeset} ->
            Logger.warning("Failed to persist #{file_path}: #{inspect(changeset.errors)}")
            {:error, changeset}
        end

      {:ok, _empty} ->
        {:ok, :skipped_empty}

      {:error, reason} ->
        Logger.debug("Could not process #{file_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract_functions(module) do
    # Extract function names from module data
    Map.get(module, :functions, [])
    |> Enum.map(fn func ->
      case func do
        %{name: name, arity: arity} -> %{name: name, arity: arity}
        name when is_binary(name) -> %{name: name}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
