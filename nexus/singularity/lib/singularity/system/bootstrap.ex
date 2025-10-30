defmodule Singularity.System.Bootstrap do
  @moduledoc """
  Bootstrap module that integrates TaskGraph pgmq-LLM self-evolution with existing Singularity infrastructure.

  Provides comprehensive system integration by connecting TaskGraph with existing self-improvement
  systems including SelfImprovingAgent, SafeWorkPlanner, and code generation tools.
  Uses simple incremental learning to understand and auto-repair the codebase.

  ## Integration Points

  This module integrates with:
  - `Singularity.Execution.Planning.TaskGraph` - DAG operations (TaskGraph.decompose/1)
  - `Singularity.Execution.Planning.TaskGraphExecutor` - Task execution (TaskGraphExecutor.execute/3)
  - `Singularity.Execution.Planning.TaskGraphEvolution` - Self-improvement (TaskGraphEvolution integration)
  - `Singularity.Ingestion.ScanRepositoryAndQueueIngestion` - Learning (ScanRepositoryAndQueueIngestion.learn_codebase/1, auto_fix_all/1)
  - `Singularity.Store` - Knowledge storage (Store.all_services/0, query_knowledge/1)
  - `Singularity.SelfImprovingAgent` - Self-improvement (SelfImprovingAgent integration)
  - `Singularity.RAGCodeGenerator` - Code generation (RAGCodeGenerator integration)
  - `Singularity.QualityCodeGenerator` - Quality enforcement (QualityCodeGenerator integration)
  - `Singularity.Execution.SPARC.SPARCOrchestrator` - SPARC methodology integration
  - `Singularity.Execution.Planning.SafeWorkPlanner` - Hierarchical planning (SafeWorkPlanner integration)

  ## Bootstrap Process

  1. **Codebase Understanding** - Analyze codebase database
  2. **Self-Awareness** - Build knowledge graph of system
  3. **Integration** - Connect TaskGraph with existing systems
  4. **Self-Improvement** - Enable autonomous improvements

  ## Usage

      # Bootstrap the system
      {:ok, state} = SystemBootstrap.bootstrap()
      # => {:ok, %{run_id: "bootstrap-123", learning: %{...}, ready_for_features: true}}

      # Get singularity server working
      {:ok, result} = SystemBootstrap.fix_singularity_server()
      # => {:ok, %{fixes_applied: [...], safe_planner_ready: true}}
  """

  require Logger

  # Aliases removed; keep module minimal and focused

  @doc """
  Bootstrap TaskGraph with existing self-improvement infrastructure.

  Now uses simple incremental learning:
  Phase 1: Learn codebase the easy way (scan source files)
  Phase 2: Map everything with inline explanations
  Phase 3: Auto-fix all issues
  Phase 4: Hand over to SafeWorkPlanner/SPARC for features
  """
  def bootstrap(opts \\ []) do
    Logger.info("Starting TaskGraph bootstrap with simple learning...")

    run_id = "bootstrap-#{System.unique_integer([:positive])}"

    # Phase 1: Simple codebase learning
    Logger.info("Phase 1: Learning codebase the easy way...")
    {:ok, learning} = Singularity.Ingestion.ScanRepositoryAndQueueIngestion.learn_codebase()

    # Phase 2: Map all systems with explanations
    Logger.info("Phase 2: Mapping all systems with inline documentation...")
    {:ok, mapping} = Singularity.Ingestion.ScanRepositoryAndQueueIngestion.map_all_systems()

    # Phase 3: Auto-fix everything
    if Keyword.get(opts, :auto_fix, false) do
      Logger.info("Phase 3: Auto-fixing all issues...")
      {:ok, fixes} = Singularity.Ingestion.ScanRepositoryAndQueueIngestion.auto_fix_all()

      {:ok,
       %{
         run_id: run_id,
         learning: learning,
         mapping: mapping,
         fixes: fixes,
         ready_for_features: true
       }}
    else
      Logger.info("Phase 3: Skipping auto-fix (enable with auto_fix: true)")

      {:ok,
       %{
         run_id: run_id,
         learning: learning,
         mapping: mapping,
         ready_for_features: false
       }}
    end
  end

  @doc """
  Fix the Singularity server automatically.

  Simple approach:
  1. Learn what's broken (easy scan)
  2. Auto-fix everything using self-improving loop
  3. Connect all the pieces with RAG + Quality
  4. Hand over to SafeWorkPlanner for features
  5. Self-improving makes everything work (errors, performance, etc.)
  """
  def fix_singularity_server(opts \\ []) do
    Logger.info("Auto-repairing Singularity server...")

    # Use the simple auto-fix approach
    case Singularity.Ingestion.ScanRepositoryAndQueueIngestion.auto_fix_all(Keyword.put(opts, :max_iterations, 20)) do
      {:ok, result} ->
        Logger.info("Auto-repair complete",
          iterations: result.iterations,
          fixes_applied: length(result.fixes)
        )

        # Now hand over to SafeWorkPlanner for feature management
        Logger.info("Ready for SafeWorkPlanner to take over features")
        Logger.info("Self-improving agent will continue fixing errors and performance")

        {:ok,
         %{
           fixes_applied: result.fixes,
           iterations: result.iterations,
           safe_planner_ready: true,
           self_improving_active: true,
           final_state: result.final_state
         }}

      {:error, reason} ->
        Logger.error("Auto-repair failed", reason: reason)
        {:error, reason}
    end
  end

  ## Private helper functions removed as they were unused
end
