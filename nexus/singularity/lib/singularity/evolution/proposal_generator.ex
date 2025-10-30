defmodule Singularity.Evolution.ProposalGenerator do
  @moduledoc """
  ProposalGenerator - Automatically generate proposals from codebase analysis.

  Analyzes the codebase using existing analysis engines (FullRepoScanner, PatternDetector,
  AnalysisOrchestrator) and automatically generates proposals for improvements.

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Evolution.ProposalGenerator",
    "purpose": "Analyze codebase and generate evolution proposals",
    "role": "service",
    "layer": "domain",
    "features": ["automated_analysis", "proposal_generation", "impact_estimation"]
  }
  ```

  ### Architecture Diagram
  ```mermaid
  graph TD
    A[ProposalGenerator] --> B[FullRepoScanner]
    A --> C[PatternDetector]
    A --> D[AnalysisOrchestrator]
    A --> E[ProposalQueue]

    B --> B1[Identify Issues]
    C --> C1[Framework Patterns]
    D --> D1[Code Quality]

    B1 --> F[Create Proposals]
    C1 --> F
    D1 --> F
    F --> G[Score & Queue]
  ```

  ### Call Graph (YAML)
  ```yaml
  ProposalGenerator:
    analyze_and_generate/2:
      - FullRepoScanner.learn_codebase
      - FullRepoScanner.learn_with_tracing
      - PatternDetector.detect
      - AnalysisOrchestrator.analyze
      - create_proposals_from_analysis
      - ProposalQueue.submit_proposal
    score_proposal/1:
      - estimate_impact
      - estimate_risk
      - estimate_cost
      - calculate_priority_score
  ```

  ### Anti-Patterns
  - ❌ DO NOT generate low-impact proposals (min 10 impact score)
  - ❌ DO NOT skip risk assessment (all proposals must have risk_score)
  - ✅ DO validate proposals before submitting to queue
  - ✅ DO estimate code change impact before proposing
  - ✅ DO provide detailed reasoning for each proposal

  ### Search Keywords
  analysis, proposal_generation, issue_detection, pattern_discovery, codebase_scanning,
  impact_estimation, risk_assessment, quality_improvement

  ## Analysis Sources

  ProposalGenerator sources proposals from:
  1. **FullRepoScanner** - Missing docs, broken dependencies, isolated modules
  2. **PatternDetector** - Framework patterns, technology patterns
  3. **AnalysisOrchestrator** - Code quality issues, refactoring opportunities
  4. **Runtime Tracing** - Unused code, performance bottlenecks

  ## Proposal Types

  - `documentation` - Add missing @moduledoc, @doc, comments
  - `refactoring` - Extract functions, simplify logic, improve naming
  - `quality` - Add type specs, error handling, tests
  - `optimization` - Fix N+1 queries, cache computations, optimize algorithms
  - `pattern_adoption` - Adopt proven patterns from other parts of codebase
  - `framework_upgrade` - Update to newer framework patterns

  ## Usage

  ```elixir
  # Analyze codebase and auto-generate proposals
  {:ok, stats} = ProposalGenerator.analyze_and_generate(
    scope: :full_repo,
    min_impact_score: 20,
    max_proposals: 10
  )

  # Get analysis summary without generating proposals
  {:ok, analysis} = ProposalGenerator.analyze_codebase()

  # Manually create proposal from analysis result
  {:ok, proposal_id} = ProposalGenerator.create_proposal_from_analysis(
    analysis_result,
    type: :refactoring,
    target_module: "Singularity.Store"
  )
  ```
  """

  require Logger

  alias Singularity.Code.FullRepoScanner
  alias Singularity.Analysis.PatternDetector
  alias Singularity.Analysis.AnalysisOrchestrator
  alias Singularity.Evolution.ProposalQueue
  alias Singularity.Repo
  alias Singularity.Schemas.Evolution.Proposal

  @doc """
  Analyze codebase and automatically generate proposals.

  Scans the full codebase using all available analysis engines and generates
  evolution proposals for issues found.

  ## Options
    - `:scope` - `:full_repo` (default), `:lib_only`, `:specific_module`
    - `:min_impact_score` - Minimum impact to include proposal (default: 10)
    - `:max_proposals` - Maximum proposals to generate (default: 20)
    - `:include_types` - Proposal types to generate (default: all)
    - `:use_tracing` - Include runtime tracing analysis (default: true)

  ## Returns
    `{:ok, %{proposals_created: N, total_analyzed: M, ...}} | {:error, reason}`
  """
  def analyze_and_generate(opts \\ []) do
    start_time = System.monotonic_time(:millisecond)

    scope = Keyword.get(opts, :scope, :full_repo)
    min_impact = Keyword.get(opts, :min_impact_score, 10)
    max_proposals = Keyword.get(opts, :max_proposals, 20)
    use_tracing = Keyword.get(opts, :use_tracing, true)

    Logger.info("Starting codebase analysis for proposal generation",
      scope: scope,
      min_impact: min_impact,
      max_proposals: max_proposals
    )

    with {:ok, analysis} <- analyze_codebase(scope, use_tracing),
         proposals <- create_proposals_from_analysis(analysis, opts),
         filtered <- filter_proposals_by_impact(proposals, min_impact),
         limited <- Enum.take(filtered, max_proposals),
         results <- submit_proposals(limited) do
      elapsed = System.monotonic_time(:millisecond) - start_time

      stats = %{
        proposals_created: Enum.count(results, fn {status, _} -> status == :ok end),
        total_analyzed: length(analysis.modules),
        issues_found: length(analysis.issues),
        proposals_rejected: Enum.count(results, fn {status, _} -> status == :error end),
        min_impact_filtered: length(proposals) - length(filtered),
        elapsed_ms: elapsed
      }

      Logger.info("Proposal generation complete", stats: stats)

      :telemetry.execute(
        [:evolution, :proposal_generation, :completed],
        %{
          duration_ms: elapsed,
          proposals_created: stats.proposals_created,
          issues_analyzed: stats.total_analyzed
        },
        %{scope: scope, min_impact: min_impact}
      )

      {:ok, stats}
    else
      {:error, reason} ->
        Logger.error("Proposal generation failed", reason: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Analyze codebase without generating proposals.

  Returns comprehensive analysis including modules, issues, patterns, and metrics.
  """
  def analyze_codebase(scope \\ :full_repo, use_tracing \\ true) do
    Logger.info("Starting codebase analysis", scope: scope, use_tracing: use_tracing)

    # Phase 1: Static analysis (file scanning)
    Logger.info("Phase 1: Static analysis...")

    static_analysis =
      case FullRepoScanner.learn_codebase() do
        {:ok, learning} -> learning
        {:error, reason} -> return_error("Static analysis failed", reason)
      end

    # Phase 2: Runtime tracing (if enabled)
    runtime_analysis =
      if use_tracing do
        Logger.info("Phase 2: Runtime tracing...")

        case FullRepoScanner.learn_with_tracing(trace_duration_ms: 5000) do
          {:ok, tracing_results} -> tracing_results
          {:error, _reason} -> nil  # Tracing is optional
        end
      else
        nil
      end

    # Phase 3: Pattern detection
    Logger.info("Phase 3: Pattern detection...")

    patterns =
      case PatternDetector.detect("lib/", types: [:framework, :technology]) do
        {:ok, found_patterns} -> found_patterns
        {:error, _reason} -> []
      end

    # Phase 4: Code quality analysis
    Logger.info("Phase 4: Code quality analysis...")

    quality_analysis =
      case AnalysisOrchestrator.analyze("lib/", analyzers: [:quality, :refactoring]) do
        {:ok, results} -> results
        {:error, _reason} -> %{}
      end

    # Combine all analyses
    combined = %{
      modules: static_analysis.knowledge.modules,
      issues: static_analysis.issues,
      patterns: patterns,
      quality_analysis: quality_analysis,
      runtime_analysis: runtime_analysis,
      timestamp: DateTime.utc_now()
    }

    Logger.info("Codebase analysis complete",
      modules: map_size(combined.modules),
      issues: length(combined.issues),
      patterns: length(patterns)
    )

    {:ok, combined}
  end

  defp return_error(msg, reason) do
    Logger.error(msg, reason: inspect(reason))
    {:error, reason}
  end

  @doc """
  Create proposals from analysis results.

  Converts analysis findings into actionable proposals with impact/risk scoring.
  """
  def create_proposals_from_analysis(analysis, opts \\ []) do
    Logger.info("Creating proposals from analysis results")

    proposals = []

    # Convert issues to proposals
    issue_proposals =
      analysis.issues
      |> Enum.map(&issue_to_proposal/1)
      |> Enum.filter(& &1)

    proposals = proposals ++ issue_proposals

    # Convert patterns to proposals
    pattern_proposals =
      analysis.patterns
      |> Enum.map(&pattern_to_proposal/1)
      |> Enum.filter(& &1)

    proposals = proposals ++ pattern_proposals

    # Convert quality findings to proposals
    quality_proposals =
      analysis.quality_analysis
      |> Map.values()
      |> Enum.flat_map(fn result ->
        case result do
          %{findings: findings} ->
            findings |> Enum.map(&quality_finding_to_proposal/1)
          _ ->
            []
        end
      end)
      |> Enum.filter(& &1)

    proposals = proposals ++ quality_proposals

    # Score all proposals
    scored_proposals =
      proposals
      |> Enum.map(&score_proposal/1)
      |> Enum.filter(& &1)

    Logger.info("Created proposals from analysis",
      total: length(scored_proposals),
      from_issues: length(issue_proposals),
      from_patterns: length(pattern_proposals),
      from_quality: length(quality_proposals)
    )

    scored_proposals
  end

  defp issue_to_proposal(issue) do
    case issue.type do
      :missing_docs ->
        %{
          type: :documentation,
          description: "Add missing documentation to #{issue.module}",
          target_module: issue.module,
          change_type: :documentation,
          details: %{
            issue_type: :missing_docs,
            affected_module: issue.module,
            severity: issue.severity
          }
        }

      :broken_dependency ->
        %{
          type: :refactoring,
          description: "Fix broken dependency in #{issue.module}: missing #{issue.missing}",
          target_module: issue.module,
          change_type: :bug_fix,
          details: %{
            issue_type: :broken_dependency,
            affected_module: issue.module,
            missing_dependency: issue.missing,
            severity: issue.severity
          }
        }

      :isolated_module ->
        %{
          type: :refactoring,
          description: "Analyze and integrate isolated module: #{issue.module}",
          target_module: issue.module,
          change_type: :integration,
          details: %{
            issue_type: :isolated_module,
            affected_module: issue.module,
            severity: issue.severity
          }
        }

      _ ->
        nil
    end
  end

  defp pattern_to_proposal(pattern) do
    case pattern do
      %{type: type, name: name, recommendation: recommendation} ->
        %{
          type: :pattern_adoption,
          description: "Adopt #{type} pattern: #{name}. #{recommendation}",
          target_module: get_pattern_target(pattern),
          change_type: :pattern_adoption,
          details: %{
            pattern_type: type,
            pattern_name: name,
            recommendation: recommendation
          }
        }

      _ ->
        nil
    end
  end

  defp quality_finding_to_proposal(finding) do
    case finding do
      %{type: type, module: module, description: desc} ->
        %{
          type: :quality,
          description: "Fix quality issue in #{module}: #{desc}",
          target_module: module,
          change_type: :quality,
          details: %{
            finding_type: type,
            module: module,
            description: desc
          }
        }

      _ ->
        nil
    end
  end

  defp get_pattern_target(%{modules: modules}) when is_list(modules) do
    List.first(modules, "lib/")
  end

  defp get_pattern_target(%{module: module}) when is_binary(module) do
    module
  end

  defp get_pattern_target(_), do: "lib/"

  @doc """
  Score a proposal based on impact, risk, and other factors.

  Returns proposal with impact_score, risk_score, priority_score calculated.
  """
  def score_proposal(proposal) do
    impact_score = estimate_impact(proposal)
    risk_score = estimate_risk(proposal)
    cost_estimate = estimate_cost(proposal)

    priority_score = calculate_priority_score(impact_score, risk_score, cost_estimate)

    proposal
    |> Map.put(:impact_score, impact_score)
    |> Map.put(:risk_score, risk_score)
    |> Map.put(:cost_estimate, cost_estimate)
    |> Map.put(:priority_score, priority_score)
  end

  defp estimate_impact(%{type: type, details: details}) do
    case type do
      :documentation ->
        # Documentation has moderate impact
        15 + bonus_for_severity(details)

      :refactoring ->
        # Refactoring depends on the issue type
        case details.issue_type do
          :broken_dependency -> 40  # High impact - broken dependency
          :isolated_module -> 25     # Medium impact - unused module
          _ -> 20
        end

      :quality ->
        # Quality improvements have variable impact
        case details.finding_type do
          :performance -> 35
          :security -> 50  # High impact - security issues
          :maintainability -> 20
          _ -> 15
        end

      :pattern_adoption ->
        # Pattern adoption has moderate impact
        25

      _ ->
        10
    end
  end

  defp bonus_for_severity(%{severity: :high}), do: 15
  defp bonus_for_severity(%{severity: :medium}), do: 10
  defp bonus_for_severity(%{severity: :low}), do: 5
  defp bonus_for_severity(_), do: 0

  defp estimate_risk(%{type: type, details: details}) do
    case type do
      :documentation ->
        # Documentation changes are low risk
        5

      :refactoring ->
        # Refactoring is medium risk
        case details.issue_type do
          :broken_dependency -> 35  # High risk - could break things
          :isolated_module -> 15     # Low risk - isolated
          _ -> 25
        end

      :quality ->
        # Quality fixes are medium risk
        20

      :pattern_adoption ->
        # Pattern adoption is medium risk
        25

      _ ->
        15
    end
  end

  defp estimate_cost(%{type: type}) do
    case type do
      :documentation -> 1
      :refactoring -> 3
      :quality -> 2
      :pattern_adoption -> 4
      _ -> 2
    end
  end

  defp calculate_priority_score(impact, risk, cost) do
    # Priority = Impact / (Risk + Cost)
    # Higher priority = higher impact, lower risk, lower cost
    (impact / (risk + cost)) |> Float.round(2)
  end

  defp filter_proposals_by_impact(proposals, min_impact) do
    Enum.filter(proposals, &(&1.impact_score >= min_impact))
  end

  defp submit_proposals(proposals) do
    Enum.map(proposals, fn proposal ->
      Logger.debug("Submitting proposal",
        type: proposal.type,
        description: proposal.description,
        impact_score: proposal.impact_score
      )

      result =
        ProposalQueue.submit_proposal(
          proposal.type,
          proposal.description,
          %{
            target_module: proposal.target_module,
            change_type: proposal.change_type,
            details: proposal.details,
            impact_score: proposal.impact_score,
            risk_score: proposal.risk_score,
            cost_estimate: proposal.cost_estimate,
            priority_score: proposal.priority_score,
            auto_generated: true,
            generation_timestamp: DateTime.utc_now()
          }
        )

      {result, proposal}
    end)
  end
end
