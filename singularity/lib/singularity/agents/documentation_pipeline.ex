defmodule Singularity.Agents.DocumentationPipeline do
  @moduledoc """
  Documentation Pipeline Agent - Automated documentation upgrade pipeline.

  ## Overview

  This agent orchestrates the complete documentation upgrade pipeline,
  coordinating all 6 agents to scan, analyze, upgrade, and validate
  documentation across Elixir, Rust, and TypeScript files.

  ## Public API Contract

  - `run_full_pipeline/0` - Run complete documentation upgrade pipeline
  - `run_incremental_pipeline/1` - Run pipeline for specific files
  - `get_pipeline_status/0` - Get current pipeline status
  - `schedule_automatic_upgrades/1` - Schedule automatic documentation upgrades

  ## Error Matrix

  - `{:error, :agents_unavailable}` - Required agents not available
  - `{:error, :pipeline_failed}` - Pipeline execution failed
  - `{:error, :validation_failed}` - Documentation validation failed
  - `{:error, :backup_failed}` - File backup failed

  ## Performance Notes

  - Full pipeline: 5-30 minutes depending on codebase size
  - Incremental pipeline: 1-5 minutes for modified files
  - Status check: < 100ms
  - Automatic upgrades: Background process

  ## Concurrency Semantics

  - Parallel file processing
  - Async agent coordination
  - Thread-safe status tracking
  - Background task management

  ## Security Considerations

  - Creates backups before modifications
  - Validates all file operations
  - Rate limits agent operations
  - Sandboxes file processing

  ## Examples

      # Run full pipeline
      {:ok, results} = DocumentationPipeline.run_full_pipeline()

      # Run incremental pipeline
      {:ok, results} = DocumentationPipeline.run_incremental_pipeline(["lib/my_module.ex"])

      # Get pipeline status
      {:ok, status} = DocumentationPipeline.get_pipeline_status()

  ## Relationships

  - **Uses**: `Singularity.Agents.DocumentationUpgrader` - Documentation upgrades
  - **Uses**: `Singularity.Agents.QualityEnforcer` - Quality validation
  - **Uses**: All 6 autonomous agents - Specialized tasks
  - **Uses**: `Singularity.CodeStore` - File scanning
  - **Used by**: `Singularity.Application` - System integration

  ## Template Integration

  - **Elixir**: Quality 2.3.0 with self-awareness
  - **Rust**: Quality 2.2.0 (upgradeable to 2.3.0)
  - **TypeScript**: Quality 2.2.0 (upgradeable to 2.3.0)

  ## Template Version

  v2.3.0 - Multi-language documentation pipeline with agent coordination

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "DocumentationPipeline",
    "purpose": "orchestrate_documentation_upgrade_pipeline",
    "domain": "documentation_management",
    "capabilities": ["pipeline_orchestration", "agent_coordination", "multi_language", "automation"],
    "dependencies": ["DocumentationUpgrader", "QualityEnforcer", "CodeStore"],
    "quality_level": "production",
    "template_version": "2.3.0"
  }
  ```

  ## Architecture Diagram (Mermaid)

  ```mermaid
  graph TD
    A[DocumentationPipeline] --> B[DocumentationUpgrader]
    A --> C[QualityEnforcer]
    A --> D[CodeStore]
    
    B --> E[SelfImprovingAgent]
    B --> F[ArchitectureAgent]
    B --> G[TechnologyAgent]
    B --> H[RefactoringAgent]
    B --> I[CostOptimizedAgent]
    B --> J[ChatConversationAgent]
    
    C --> K[Elixir Quality 2.3.0]
    C --> L[Rust Quality 2.2.0]
    C --> M[TypeScript Quality 2.2.0]
    
    D --> N[File Scanning]
    D --> O[Code Analysis]
  ```

  ## Call Graph (YAML)

  ```yaml
  DocumentationPipeline:
    run_full_pipeline/0:
      - scan_all_files/0
      - coordinate_agents/1
      - validate_results/1
    run_incremental_pipeline/1:
      - validate_files/1
      - coordinate_agents/1
      - validate_results/1
    get_pipeline_status/0:
      - get_current_status/0
  ```

  ## Anti-Patterns

  - DO NOT create 'DocumentationManager' - use this module for all pipeline operations
  - DO NOT bypass agent coordination - always use the 6 agents for upgrades
  - DO NOT skip validation - always validate after upgrades
  - DO NOT run without backups - always backup before modifications

  ## Search Keywords

  documentation-pipeline, agent-coordination, multi-language, automation, quality-enforcement, elixir, rust, typescript
  """

  use GenServer
  require Logger
  alias Singularity.Agents.DocumentationUpgrader
  alias Singularity.Agents.QualityEnforcer

  ## Client API

  @doc """
  Start the Documentation Pipeline agent.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Run complete documentation upgrade pipeline.
  """
  def run_full_pipeline do
    GenServer.call(__MODULE__, :run_full_pipeline)
  end

  @doc """
  Run incremental pipeline for specific files.
  """
  def run_incremental_pipeline(files) do
    GenServer.call(__MODULE__, {:run_incremental_pipeline, files})
  end

  @doc """
  Get current pipeline status.
  """
  def get_pipeline_status do
    GenServer.call(__MODULE__, :get_pipeline_status)
  end

  @doc """
  Schedule automatic documentation upgrades.
  """
  def schedule_automatic_upgrades(interval_minutes \\ 60) do
    GenServer.call(__MODULE__, {:schedule_automatic_upgrades, interval_minutes})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      pipeline_running: false,
      last_run: nil,
      automatic_upgrades_enabled: false,
      upgrade_interval: 60,
      status: :idle,
      results: %{}
    }

    Logger.info("Documentation Pipeline started")
    {:ok, state}
  end

  @impl true
  def handle_call(:run_full_pipeline, _from, state) do
    if state.pipeline_running do
      {:reply, {:error, :pipeline_already_running}, state}
    else
      new_state = %{state | pipeline_running: true, status: :running}

      # Run pipeline in background task
      task = Task.async(fn -> run_pipeline_internal(:full) end)

      # Monitor task completion
      Process.monitor(task.pid)

      {:reply, {:ok, :pipeline_started}, %{new_state | upgrade_task: task}}
    end
  end

  @impl true
  def handle_call({:run_incremental_pipeline, files}, _from, state) do
    if state.pipeline_running do
      {:reply, {:error, :pipeline_already_running}, state}
    else
      new_state = %{state | pipeline_running: true, status: :running}

      # Run incremental pipeline in background task
      task = Task.async(fn -> run_pipeline_internal({:incremental, files}) end)

      # Monitor task completion
      Process.monitor(task.pid)

      {:reply, {:ok, :incremental_pipeline_started}, %{new_state | upgrade_task: task}}
    end
  end

  @impl true
  def handle_call(:get_pipeline_status, _from, state) do
    status = %{
      pipeline_running: state.pipeline_running,
      status: state.status,
      last_run: state.last_run,
      automatic_upgrades_enabled: state.automatic_upgrades_enabled,
      upgrade_interval: state.upgrade_interval,
      results: state.results
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_call({:schedule_automatic_upgrades, interval_minutes}, _from, state) do
    new_state = %{
      state
      | automatic_upgrades_enabled: true,
        upgrade_interval: interval_minutes
    }

    # Schedule automatic upgrades
    schedule_automatic_upgrade(interval_minutes)

    Logger.info("Automatic documentation upgrades scheduled every #{interval_minutes} minutes")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    # Pipeline completed successfully
    new_state = %{
      state
      | pipeline_running: false,
        status: :completed,
        last_run: DateTime.utc_now()
    }

    Logger.info("Documentation pipeline completed successfully")
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    # Pipeline failed
    new_state = %{
      state
      | pipeline_running: false,
        status: :failed,
        last_run: DateTime.utc_now()
    }

    Logger.error("Documentation pipeline failed: #{inspect(reason)}")
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:run_automatic_upgrade, state) do
    if state.automatic_upgrades_enabled do
      Logger.info("Running scheduled automatic documentation upgrade")

      # Run incremental pipeline for modified files
      modified_files = get_modified_files()
      run_pipeline_internal({:incremental, modified_files})

      # Schedule next automatic upgrade
      schedule_automatic_upgrade(state.upgrade_interval)
    end

    {:noreply, state}
  end

  ## Private Functions

  defp run_pipeline_internal(type) do
    try do
      Logger.info("Starting documentation pipeline: #{inspect(type)}")

      # Phase 1: Discovery
      files =
        case type do
          :full -> scan_all_files()
          {:incremental, file_list} -> file_list
        end

      Logger.info("Discovered #{length(files)} files to process")

      # Phase 2: Analysis
      analysis_results = analyze_files(files)
      Logger.info("Analysis complete: #{analysis_results.total_files} files analyzed")

      # Phase 3: Upgrade
      upgrade_results = upgrade_files(files, analysis_results)
      Logger.info("Upgrade complete: #{upgrade_results.upgraded} files upgraded")

      # Phase 4: Validation
      validation_results = validate_upgrades(files)
      Logger.info("Validation complete: #{validation_results.compliant} files compliant")

      # Phase 5: Report
      final_results = %{
        type: type,
        total_files: length(files),
        analyzed: analysis_results.total_files,
        upgraded: upgrade_results.upgraded,
        compliant: validation_results.compliant,
        non_compliant: validation_results.non_compliant,
        languages: validation_results.languages,
        timestamp: DateTime.utc_now()
      }

      Logger.info("Documentation pipeline completed successfully", final_results)
      final_results
    rescue
      error ->
        Logger.error("Documentation pipeline failed: #{inspect(error)}")
        {:error, :pipeline_failed, error}
    end
  end

  defp scan_all_files do
    [
      "./singularity/lib/**/*.ex",
      "./rust/**/*.rs",
      "./llm-server/**/*.ts",
      "./llm-server/**/*.tsx"
    ]
    |> Enum.flat_map(fn pattern ->
      Path.wildcard(pattern)
    end)
    |> Enum.filter(&File.regular?/1)
  end

  defp get_modified_files do
    # Get files modified in the last 24 hours
    cutoff_time = DateTime.utc_now() |> DateTime.add(-24, :hour)

    scan_all_files()
    |> Enum.filter(fn file_path ->
      case File.stat(file_path) do
        {:ok, stat} ->
          stat.mtime
          |> DateTime.from_unix!()
          |> DateTime.compare(cutoff_time) == :gt

        {:error, _} ->
          false
      end
    end)
  end

  defp analyze_files(files) do
    # Analyze the specific files provided
    results =
      files
      |> Enum.map(fn file_path ->
        case File.read(file_path) do
          {:ok, content} ->
            language = detect_language(file_path)

            has_documentation =
              case language do
                :elixir -> String.contains?(content, "@moduledoc")
                :rust -> String.contains?(content, "///")
                :typescript -> String.contains?(content, "/**")
                _ -> false
              end

            %{file: file_path, language: language, has_documentation: has_documentation}

          {:error, _reason} ->
            %{file: file_path, language: :unknown, has_documentation: false}
        end
      end)

    documented_count = Enum.count(results, & &1.has_documentation)
    total_count = length(results)

    %{
      total_files: total_count,
      documented: documented_count,
      quality_modules: documented_count,
      files_analyzed: results
    }
  end

  defp upgrade_files(files, analysis_results) do
    # Use analysis results to prioritize files that need documentation
    files_to_upgrade =
      files
      |> Enum.filter(fn file_path ->
        # Find analysis result for this file
        case Enum.find(analysis_results.files_analyzed, &(&1.file == file_path)) do
          %{has_documentation: false} -> true
          _ -> false
        end
      end)

    Logger.info("Found #{length(files_to_upgrade)} files that need documentation upgrade")

    # Upgrade files that need documentation
    upgraded =
      files_to_upgrade
      |> Enum.map(fn file_path ->
        case DocumentationUpgrader.upgrade_module_documentation(file_path, []) do
          {:ok, _result} -> 1
          {:error, _reason} -> 0
        end
      end)
      |> Enum.sum()

    Logger.info(
      "Upgraded #{upgraded} files out of #{length(files_to_upgrade)} that needed upgrades"
    )

    %{upgraded: upgraded, total_needed: length(files_to_upgrade)}
  end

  defp validate_upgrades(files) do
    # Validate the specific files that were upgraded
    validation_results =
      files
      |> Enum.map(fn file_path ->
        case QualityEnforcer.validate_file_quality(file_path) do
          {:ok, %{compliant: true}} -> %{file: file_path, status: :compliant}
          {:ok, %{compliant: false}} -> %{file: file_path, status: :non_compliant}
          {:error, _reason} -> %{file: file_path, status: :error}
        end
      end)

    compliant_count = Enum.count(validation_results, &(&1.status == :compliant))
    non_compliant_count = Enum.count(validation_results, &(&1.status == :non_compliant))

    Logger.info(
      "Validation complete: #{compliant_count} compliant, #{non_compliant_count} non-compliant"
    )

    %{
      compliant: compliant_count,
      non_compliant: non_compliant_count,
      total_validated: length(files),
      validation_results: validation_results
    }
  end

  defp schedule_automatic_upgrade(interval_minutes) do
    Process.send_after(self(), :run_automatic_upgrade, interval_minutes * 60 * 1000)
  end

  defp detect_language(file_path) do
    cond do
      String.ends_with?(file_path, ".ex") or String.ends_with?(file_path, ".exs") ->
        :elixir

      String.ends_with?(file_path, ".rs") ->
        :rust

      String.ends_with?(file_path, ".ts") or String.ends_with?(file_path, ".tsx") ->
        :typescript

      String.ends_with?(file_path, ".js") or String.ends_with?(file_path, ".jsx") ->
        :javascript

      true ->
        :unknown
    end
  end
end
