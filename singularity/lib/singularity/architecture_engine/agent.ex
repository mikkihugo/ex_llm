defmodule Singularity.ArchitectureEngine.Agent do
  @moduledoc """
  Architecture Agent - Orchestrates architecture, framework, quality, and semantic analysis.

  ## Overview

  Thin orchestration layer for architecture, framework, quality, and semantic
  analysis. This module is intentionally lightweight—it delegates to
  `Singularity.ArchitectureEngine` for the actual implementations while
  providing a single place to evolve the public API going forward.

  ## Public API Contract

  - `analyze_codebase/2` - Analyze codebase architecture and patterns
  - `detect_frameworks/2` - Detect frameworks and technologies
  - `assess_quality/2` - Assess code quality and standards
  - `semantic_search/3` - Perform semantic code search

  ## Error Matrix

  - `{:error, :codebase_not_found}` - Codebase path doesn't exist
  - `{:error, :analysis_failed}` - Analysis engine failed
  - `{:error, :invalid_parameters}` - Invalid analysis parameters

  ## Performance Notes

  - Codebase analysis: 1-10s depending on size
  - Framework detection: 100-500ms
  - Quality assessment: 500ms-2s
  - Semantic search: 50-200ms per query

  ## Concurrency Semantics

  - Stateless operations (safe for concurrent calls)
  - Uses async analysis engines where possible
  - Caches results for repeated queries

  ## Security Considerations

  - Validates all file paths before analysis
  - Sandboxes analysis operations
  - Rate limits analysis requests

  ## Examples

      # Analyze codebase
      {:ok, analysis} = ArchitectureAgent.analyze_codebase("path/to/code", %{depth: :deep})

      # Detect frameworks
      {:ok, frameworks} = ArchitectureAgent.detect_frameworks("path/to/code", [:elixir, :rust])

      # Semantic search
      {:ok, results} = ArchitectureAgent.semantic_search("async patterns", "path/to/code", %{limit: 10})

  ## Relationships

  - **Uses**: ArchitectureEngine, FrameworkRegistry, QualityEngine
  - **Integrates with**: CentralCloud (pattern learning), Genesis (experiments)
  - **Supervised by**: ArchitectureEngine.Supervisor

  ## Template Version

  - **Applied:** architecture-agent v2.3.0
  - **Applied on:** 2025-01-15
  - **Upgrade path:** v2.2.0 -> v2.3.0 (added self-awareness protocol)

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "ArchitectureAgent",
    "purpose": "architecture_analysis_orchestration",
    "domain": "architecture",
    "capabilities": ["codebase_analysis", "framework_detection", "quality_assessment", "semantic_search"],
    "dependencies": ["ArchitectureEngine", "FrameworkRegistry", "QualityEngine"]
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    A[ArchitectureAgent] --> B[ArchitectureEngine]
    A --> C[FrameworkRegistry]
    A --> D[QualityEngine]
    B --> E[Codebase Analysis]
    C --> F[Framework Detection]
    D --> G[Quality Assessment]
    E --> H[CentralCloud Learning]
    F --> H
    G --> H
  ```

  ## Call Graph (YAML)
  ```yaml
  ArchitectureAgent:
    analyze_codebase/2: [ArchitectureEngine.analyze/2]
    detect_frameworks/2: [FrameworkRegistry.detect/2]
    assess_quality/2: [QualityEngine.assess/2]
    semantic_search/3: [SemanticEngine.search/3]
  ```

  ## Anti-Patterns

  - **DO NOT** perform synchronous analysis on large codebases
  - **DO NOT** bypass validation of analysis parameters
  - **DO NOT** cache sensitive or temporary analysis results
  - **DO NOT** call analysis engines directly (use this agent)

  ## Search Keywords

  architecture, analysis, framework, quality, semantic, codebase, patterns, detection, assessment, orchestration, lightweight, delegation, api, evolution
  """

  alias Singularity.ArchitectureEngine

  @typedoc "Opaque identifier for a codebase or repository"
  @type codebase_id :: String.t()

  @doc """
  Run the full architecture analysis pipeline for the given `codebase_id`.
  """
  @spec analyze_codebase(codebase_id(), keyword()) :: term()
  def analyze_codebase(codebase_id, opts \\ []) do
    ArchitectureEngine.analyze_codebase(codebase_id, opts)
  end

  @doc """
  Execute architecture pattern detection using the underlying engines.
  """
  @spec analyze_architecture_patterns(Path.t()) :: term()
  def analyze_architecture_patterns(codebase_path) do
    ArchitectureEngine.analyze_architecture_patterns(codebase_path)
  end

  @doc """
  Detect active frameworks and tooling in a codebase.
  """
  @spec detect_frameworks(Path.t()) :: term()
  def detect_frameworks(codebase_path) do
    ArchitectureEngine.detect_frameworks(codebase_path)
  end

  @doc """
  Run quality analysis (linting, static checks, AI heuristics).
  """
  @spec run_quality_analysis(Path.t(), keyword()) :: term()
  def run_quality_analysis(codebase_path, opts \\ []) do
    ArchitectureEngine.run_quality_analysis(codebase_path, opts)
  end

  @doc """
  Perform semantic search against the analyzed code artifacts.
  """
  @spec semantic_search(String.t(), keyword()) :: term()
  def semantic_search(query, opts \\ []) do
    ArchitectureEngine.semantic_search(query, opts)
  end
end
