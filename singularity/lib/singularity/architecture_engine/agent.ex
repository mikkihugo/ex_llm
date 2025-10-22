defmodule Singularity.ArchitectureEngine.Agent do
  @moduledoc """
  Thin orchestration layer for architecture, framework, quality, and semantic
  analysis. This module is intentionally lightweight—it delegates to
  `Singularity.ArchitectureEngine` for the actual implementations while
  providing a single place to evolve the public API going forward.
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
