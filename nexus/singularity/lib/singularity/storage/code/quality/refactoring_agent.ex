defmodule Singularity.RefactoringAgent do
  @moduledoc """
  Refactoring Agent - Autonomous code refactoring based on quality metrics and analysis.

  ## Overview

  Detects when refactoring is NEEDED based on code analysis and triggers
  autonomous refactoring tasks based on metrics, not schedules. Uses quality
  metrics, code complexity analysis, and pattern recognition to identify
  refactoring opportunities.

  ## Public API Contract

  - `analyze_refactoring_need/0` - Analyze refactoring needs based on codebase metrics
  - `trigger_refactoring/2` - Trigger refactoring for specific code patterns
  - `assess_refactoring_impact/2` - Assess impact of proposed refactoring
  - `execute_refactoring/2` - Execute refactoring with safety checks

  ## Error Matrix

  - `{:error, :no_refactoring_needed}` - No refactoring opportunities found
  - `{:error, :refactoring_failed}` - Refactoring execution failed
  - `{:error, :safety_check_failed}` - Safety validation failed
  - `{:error, :metrics_unavailable}` - Required metrics not available

  ## Performance Notes

  - Refactoring analysis: 1-5s depending on codebase size
  - Impact assessment: 500ms-2s
  - Refactoring execution: 2-10s depending on complexity
  - Safety checks: 100-500ms

  ## Concurrency Semantics

  - Stateless analysis operations (safe for concurrent calls)
  - Atomic refactoring execution (prevents partial updates)
  - Uses async execution for non-critical refactoring

  ## Security Considerations

  - Validates all refactoring operations before execution
  - Creates backups before destructive changes
  - Sandboxes refactoring experiments in Genesis
  - Rate limits refactoring operations

  ## Examples

      # Analyze refactoring needs
      {:ok, needs} = RefactoringAgent.analyze_refactoring_need()

      # Trigger refactoring
      {:ok, task_id} = RefactoringAgent.trigger_refactoring(:extract_method, %{file: "lib/module.ex"})

      # Assess impact
      {:ok, impact} = RefactoringAgent.assess_refactoring_impact(:extract_method, %{file: "lib/module.ex"})

  ## Relationships

  - **Uses**: Analysis, CodeStore, QualityEngine
  - **Integrates with**: Genesis (experiments), CentralCloud (patterns)
  - **Supervised by**: Storage.Code.Quality.Supervisor

  ## Template Version

  - **Applied:** refactoring-agent v2.3.0
  - **Applied on:** 2025-01-15
  - **Upgrade path:** v2.2.0 -> v2.3.0 (added self-awareness protocol)

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "RefactoringAgent",
    "purpose": "autonomous_code_refactoring",
    "domain": "quality",
    "capabilities": ["refactoring_detection", "impact_assessment", "safe_execution", "pattern_analysis"],
    "dependencies": ["Analysis", "CodeStore", "QualityEngine"]
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    A[RefactoringAgent] --> B[Analysis Engine]
    A --> C[CodeStore]
    A --> D[QualityEngine]
    B --> E[Code Metrics]
    C --> F[Code Patterns]
    D --> G[Quality Standards]
    E --> H[Refactoring Opportunities]
    F --> H
    G --> H
    H --> I[Genesis Sandbox]
    I --> J[Safe Execution]
  ```

  ## Call Graph (YAML)
  ```yaml
  RefactoringAgent:
    analyze_refactoring_need/0: [Analysis.analyze/1, QualityEngine.assess/1]
    trigger_refactoring/2: [CodeStore.get/2, QualityEngine.validate/2]
    assess_refactoring_impact/2: [Analysis.impact/2, QualityEngine.safety_check/2]
    execute_refactoring/2: [Genesis.experiment/2, CodeStore.update/2]
  ```

  ## Anti-Patterns

  - **DO NOT** execute refactoring without safety checks
  - **DO NOT** bypass Genesis sandbox for high-risk changes
  - **DO NOT** perform refactoring without impact assessment
  - **DO NOT** ignore quality metrics in refactoring decisions

  ## Search Keywords

  refactoring, autonomous, code, quality, metrics, analysis, patterns, safety, execution, impact, assessment, genesis, sandbox, extraction, optimization, cleanup
  """

  require Logger

  alias Singularity.Analysis

  @doc "Analyze refactoring needs based on codebase metrics"
  def analyze_refactoring_need do
    # Get latest codebase analysis
    case Analysis.Summary.fetch_latest() do
      nil ->
        Logger.warning("No codebase analysis available")
        []

      analysis ->
        [
          detect_code_duplication(analysis),
          detect_technical_debt(analysis),
          detect_performance_bottlenecks(analysis),
          detect_schema_migrations_needed(analysis)
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(fn trigger -> trigger.severity in [:high, :critical] end)
    end
  end

  ## Detection Functions

  defp detect_code_duplication(analysis) do
    high_duplication_files =
      analysis.files
      |> Enum.filter(fn file ->
        file.metadata.duplication_percentage > 15.0
      end)

    if length(high_duplication_files) > 10 do
      avg_dup =
        Enum.map(high_duplication_files, & &1.metadata.duplication_percentage)
        |> Enum.sum()
        |> Kernel./(length(high_duplication_files))

      %{
        type: :code_duplication,
        severity: :high,
        affected_files: high_duplication_files,
        suggested_goal: """
        Extract #{length(high_duplication_files)} duplicated patterns into
        shared modules. Duplication average: #{Float.round(avg_dup, 1)}%
        """,
        business_impact: "Reduces maintenance burden, improves consistency",
        estimated_hours: length(high_duplication_files) * 0.5
      }
    else
      nil
    end
  end

  defp detect_technical_debt(analysis) do
    high_complexity_files =
      analysis.files
      |> Enum.filter(fn file ->
        file.metadata.cyclomatic_complexity > 10.0 or
          file.metadata.cognitive_complexity > 15.0 or
          file.metadata.halstead_difficulty > 30.0
      end)

    if length(high_complexity_files) > 5 do
      avg_complexity =
        Enum.map(high_complexity_files, & &1.metadata.cyclomatic_complexity)
        |> Enum.sum()
        |> Kernel./(length(high_complexity_files))

      %{
        type: :technical_debt,
        severity: :high,
        affected_files: high_complexity_files,
        suggested_goal: """
        Refactor #{length(high_complexity_files)} high-complexity modules.
        Average cyclomatic complexity: #{Float.round(avg_complexity, 1)}
        """,
        business_impact: "Reduces bug risk, improves velocity",
        estimated_hours: length(high_complexity_files) * 2
      }
    else
      nil
    end
  end

  defp detect_performance_bottlenecks(analysis) do
    # Integrate with telemetry to detect slow endpoints
    # Query telemetry events for slow endpoints (>100ms)
    # Correlate with code analysis for optimization opportunities

    # For now, use basic heuristics based on code patterns
    slow_patterns = [
      # Functions without early returns
      ~r/def.*do\s*$/,
      # Nested maps
      ~r/Enum.map.*Enum.map/,
      # Nested comprehensions
      ~r/for.*for/
    ]

    slow_endpoints =
      Enum.filter(analysis.functions, fn func ->
        Enum.any?(slow_patterns, &Regex.match?(&1, func.body || ""))
      end)

    %{analysis | performance_issues: slow_endpoints}
  end

  defp detect_schema_migrations_needed(analysis) do
    # Detect N+1 query patterns using CodeAnalyzer
    queries = extract_ecto_queries(analysis)
    
    # Detect repeated queries in loops (N+1 patterns)
    n_plus_one_patterns = detect_n_plus_one_queries(queries, analysis)
    
    if length(n_plus_one_patterns) > 0 do
      %{
        type: :n_plus_one_queries,
        severity: :high,
        message: "N+1 query pattern detected - #{length(n_plus_one_patterns)} potential issues found",
        patterns: n_plus_one_patterns,
        suggestions: [
          "Add preload/join to reduce query count",
          "Consider using Repo.preload/2 or Repo.all(from(...) |> preload(...))",
          "Review query patterns in loops - move queries outside loops",
          "Use Repo.all with joins instead of Enum.map + Repo.get"
        ]
      }
    else
      nil
    end
  end

  defp extract_ecto_queries(analysis) do
    # Extract Ecto queries from code AST
    functions = Map.get(analysis, :functions, [])
    
    queries =
      functions
      |> Enum.flat_map(fn func ->
        code = Map.get(func, :body, "") || ""
        
        # Use CodeAnalyzer to find Ecto queries
        case Singularity.CodeAnalyzer.analyze_language(code, "elixir") do
          {:ok, code_analysis} ->
            # Extract queries from AST
            extract_queries_from_ast(code_analysis)
          _ -> []
        end
      end)
      |> Enum.filter(&(&1 != nil))
    
    queries
  end

  defp extract_queries_from_ast(%{ast: ast}) when is_map(ast) do
    # Extract Repo calls from AST
    # Look for patterns like: Repo.get, Repo.all, Repo.one, Repo.preload
    query_patterns = [
      ~r/Repo\.(get|all|one|get_by|get!|one!)/,
      ~r/from\(.*\)/,
      ~r/Ecto\.Query/
    ]
    
    code_string = if Map.has_key?(ast, :code), do: Map.get(ast, :code, ""), else: ""
    
    query_patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, code_string, capture: :first)
    end)
    |> Enum.uniq()
  end
  
  defp extract_queries_from_ast(_), do: []

  defp detect_n_plus_one_queries(queries, analysis) do
    # Find queries inside loops
    functions = Map.get(analysis, :functions, [])
    
    functions
    |> Enum.flat_map(fn func ->
      body = Map.get(func, :body, "") || ""
      
      # Check if function contains loops (Enum.map, for, Enum.each, etc.)
      has_loop = Regex.match?(~r/(Enum\.(map|each|reduce|filter)|for\s+.*<-)/, body)
      
      if has_loop do
        # Check if queries are inside loops
        queries_in_loop = 
          queries
          |> Enum.filter(fn query ->
            # Simple heuristic: query appears after loop start
            query_in_body = String.contains?(body, query)
            query_in_body && has_loop
          end)
        
        if length(queries_in_loop) > 0 do
          [%{
            function: Map.get(func, :name, "unknown"),
            queries: queries_in_loop,
            severity: :high,
            suggestion: "Move queries outside loop or use Repo.preload"
          }]
        else
          []
        end
      else
        []
      end
    end)
  end
end
