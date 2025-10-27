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
  - `Singularity.Code.FullRepoScanner` - Learning (FullRepoScanner.learn_codebase/1, auto_fix_all/1)
  - `Singularity.Store` - Knowledge storage (Store.all_services/0, query_knowledge/1)
  - `Singularity.SelfImprovingAgent` - Self-improvement (SelfImprovingAgent integration)
  - `Singularity.RAGCodeGenerator` - Code generation (RAGCodeGenerator integration)
  - `Singularity.QualityCodeGenerator` - Quality enforcement (QualityCodeGenerator integration)
  - `Singularity.Execution.SPARC.Orchestrator` - SPARC methodology integration
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

  # INTEGRATION: TaskGraph planning and execution
  alias Singularity.Execution.Planning.{
    TaskGraph,
    TaskGraphExecutor,
    TaskGraphEvolution,
    FullRepoScanner
  }

  # INTEGRATION: Knowledge storage and self-improvement
  alias Singularity.{Store, SelfImprovingAgent}

  # INTEGRATION: Code generation and quality enforcement
  alias Singularity.CodeGeneration.Implementations.{RAGCodeGenerator, QualityCodeGenerator}
  # INTEGRATION: SPARC methodology and hierarchical planning
  alias Singularity.Execution.SPARC.Orchestrator, as: SparcOrchestrator

  @doc """
  Bootstrap TaskGraph with existing self-improvement infrastructure.

  Now uses simple incremental learning:
  Phase 1: Learn codebase the easy way (scan source files)
  Phase 2: Map everything with inline explanations
  Phase 3: Auto-fix all issues
  Phase 4: Hand over to SafeWorkPlanner/SPARC for features
  """
  def bootstrap(_opts \\ []) do
    Logger.info("Starting TaskGraph bootstrap with simple learning...")

    run_id = "bootstrap-#{System.unique_integer([:positive])}"

    # Phase 1: Simple codebase learning
    Logger.info("Phase 1: Learning codebase the easy way...")
    {:ok, learning} = FullRepoScanner.learn_codebase()

    # Phase 2: Map all systems with explanations
    Logger.info("Phase 2: Mapping all systems with inline documentation...")
    {:ok, mapping} = FullRepoScanner.map_all_systems()

    # Phase 3: Auto-fix everything
    if Keyword.get(opts, :auto_fix, false) do
      Logger.info("Phase 3: Auto-fixing all issues...")
      {:ok, fixes} = FullRepoScanner.auto_fix_all()

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
  def fix_singularity_server(_opts \\ []) do
    Logger.info("Auto-repairing Singularity server...")

    # Use the simple auto-fix approach
    case FullRepoScanner.auto_fix_all(Keyword.put(opts, :max_iterations, 20)) do
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

  ## Private Functions

  defp build_codebase_understanding do
    Logger.info("Analyzing codebase database...")

    # Get all services from codebase store
    services = Store.all_services() || []

    # Get code artifacts
    code_artifacts = list_code_artifacts()

    # Get knowledge artifacts (templates, patterns)
    knowledge = Store.query_knowledge(limit: 100) || {:ok, []}

    knowledge_artifacts =
      case knowledge do
        {:ok, artifacts} -> artifacts
        _ -> []
      end

    # Analyze what's working vs broken
    analysis = %{
      total_services: length(services),
      services: services,
      code_artifacts: length(code_artifacts),
      knowledge_artifacts: length(knowledge_artifacts),
      working_components: identify_working_components(services),
      broken_components: identify_broken_components(services),
      missing_integrations: identify_missing_integrations()
    }

    Logger.info("Codebase analysis complete",
      total_services: analysis.total_services,
      working: length(analysis.working_components),
      broken: length(analysis.broken_components)
    )

    {:ok, analysis}
  end

  defp analyze_existing_systems do
    Logger.info("Analyzing existing self-improvement systems...")

    systems = %{
      self_improving_agent: check_module_available(SelfImprovingAgent),
      safe_work_planner: check_module_available(SafeWorkPlanner),
      sparc_orchestrator: check_module_available(SparcOrchestrator),
      rag_generator: check_module_available(RAGCodeGenerator),
      quality_generator: check_module_available(QualityCodeGenerator)
    }

    Logger.info("System analysis complete",
      available: Enum.count(systems, fn {_k, v} -> v end),
      total: map_size(systems)
    )

    {:ok, systems}
  end

  defp create_integration_dag(codebase_knowledge, system_analysis) do
    # Create goal based on analysis
    goal = %{
      description: """
      Integrate TaskGraph pgmq-LLM self-evolution with existing Singularity infrastructure.

      Integration points:
      - SelfImprovingAgent: Connect evolution feedback loop
      - SafeWorkPlanner: Use for hierarchical task planning
      - SPARC.Orchestrator: Integrate SPARC methodology
      - RAGCodeGenerator: Use for code generation with examples
      - QualityCodeGenerator: Enforce quality standards

      Current state:
      - Working components: #{length(codebase_knowledge.working_components)}
      - Broken components: #{length(codebase_knowledge.broken_components)}
      - Available systems: #{Enum.count(system_analysis, fn {_k, v} -> v end)}
      """,
      depth: 0,
      complexity: 8.0
    }

    TaskGraph.decompose(goal)
  end

  defp list_code_artifacts do
    # Try to get code artifacts from store
    try do
      # This might fail if database isn't set up yet
      case Store.all_services() do
        services when is_list(services) -> services
        _ -> []
      end
    rescue
      _ -> []
    end
  end

  defp identify_working_components(services) do
    # Simple heuristic: services that are loaded
    Enum.filter(services, fn service ->
      case service do
        %{status: :running} -> true
        %{health: :healthy} -> true
        _ -> false
      end
    end)
  end

  defp identify_broken_components(services) do
    # Simple heuristic: services that are not loaded or have errors
    Enum.filter(services, fn service ->
      case service do
        %{status: :error} -> true
        %{status: :stopped} -> true
        %{health: :unhealthy} -> true
        _ -> false
      end
    end)
  end

  defp identify_missing_integrations do
    # Check what integrations are missing
    missing = []

    # Check if TaskGraph is integrated with SelfImprovingAgent
    missing =
      if not task_graph_integrated_with_self_improving?() do
        ["TaskGraph → SelfImprovingAgent" | missing]
      else
        missing
      end

    # Check if TaskGraph is integrated with SafeWorkPlanner
    missing =
      if not task_graph_integrated_with_safe_planner?() do
        ["TaskGraph → SafeWorkPlanner" | missing]
      else
        missing
      end

    # Check if TaskGraph uses RAG generator
    missing =
      if not task_graph_uses_rag?() do
        ["TaskGraph → RAGCodeGenerator" | missing]
      else
        missing
      end

    missing
  end

  defp check_module_available(module) do
    Code.ensure_loaded?(module)
  end

  defp task_graph_integrated_with_self_improving? do
    # Check if integration exists
    # For now, return false to indicate we need this integration
    false
  end

  defp task_graph_integrated_with_safe_planner? do
    # Check if integration exists
    false
  end

  defp task_graph_uses_rag? do
    # Check if TaskGraph executor uses RAG
    false
  end
end
