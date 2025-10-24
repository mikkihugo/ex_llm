defmodule Singularity.Architecture.Analyzers.RefactoringAnalyzer do
  @moduledoc """
  Refactoring Analyzer - Identifies code quality issues and refactoring needs.

  Analyzes the codebase to detect refactoring opportunities including:
  - Code duplication
  - Complexity hotspots
  - Quality violations
  - Style inconsistencies

  Implements `@behaviour AnalyzerType` for config-driven orchestration.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Architecture.Analyzers.RefactoringAnalyzer",
    "type": "analyzer",
    "purpose": "Identify refactoring opportunities and quality issues",
    "layer": "architecture_engine",
    "behavior": "AnalyzerType",
    "registered_in": "config :singularity, :analyzer_types, refactoring: ..."
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A[analyze/2] --> B[Refactoring.Analyzer]
      B --> C[complexity analysis]
      B --> D[quality violations]
      B --> E[duplication]
      C --> F[format results]
      D --> F
      E --> F
      F --> G[return sorted needs]
  ```

  ## Call Graph (YAML)

  ```yaml
  calls:
    - Singularity.Refactoring.Analyzer (implementation)
    - Singularity.CodeQuality.RefactoringAnalyzer (actual analysis)
    - Logger (error handling)

  called_by:
    - Singularity.Architecture.AnalysisOrchestrator (analyzer discovery)
    - Config-driven analysis pipelines
    - Refactoring agents
  ```

  ## Anti-Patterns

  **DO NOT** create duplicates:
  - ❌ `QualityAnalyzer` - Already exists separately
  - ❌ `RefactoringDetector` - Use this analyzer
  - ❌ Direct calls - Use AnalysisOrchestrator

  ## Refactoring Categories

  - **Duplication**: Repeated code patterns that should be extracted
  - **Complexity**: Functions/modules with high cyclomatic complexity
  - **Quality**: Violations of code quality standards
  - **Style**: Inconsistencies in coding style

  ## Search Keywords

  refactoring, code quality, complexity hotspots, duplication detection,
  technical debt, code smells, style violations, analyzer, orchestration
  """

  @behaviour Singularity.Architecture.AnalyzerType
  require Logger
  alias Singularity.CodeQuality.RefactoringAnalyzer, as: Analyzer

  @impl true
  def analyzer_type, do: :refactoring

  @impl true
  def description, do: "Identify refactoring needs and opportunities"

  @impl true
  def supported_types do
    ["duplication", "complexity", "quality", "style"]
  end

  @impl true
  def analyze(codebase_path, _opts \\ []) when is_binary(codebase_path) do
    try do
      case Analyzer.analyze(codebase_path) do
        {:ok, needs} when is_list(needs) ->
          needs
          |> Enum.map(&format_refactoring_need/1)
          |> Enum.reject(&is_nil/1)

        {:error, _reason} ->
          []
      end
    rescue
      e ->
        Logger.error("Refactoring analysis failed for #{codebase_path}", error: inspect(e))
        []
    end
  end

  @impl true
  def learn_pattern(result) do
    # Update refactoring patterns based on successful refactorings
    case result do
      %{type: type, success: true} ->
        Logger.info("Refactoring of type #{type} was successful")
        :ok

      %{type: type, success: false} ->
        Logger.info("Refactoring of type #{type} was not completed")
        :ok

      _ ->
        :ok
    end
  end

  # Private helpers

  defp format_refactoring_need(need) when is_map(need) do
    %{
      type: need[:type] || "unknown",
      severity: severity_from_need(need),
      message: need[:description] || inspect(need),
      file: need[:file],
      line: need[:location],
      effort: need[:estimated_effort] || "medium",
      timestamp: need[:timestamp] || DateTime.utc_now()
    }
  end

  defp format_refactoring_need(_), do: nil

  defp severity_from_need(need) do
    case need[:severity] do
      :critical -> "critical"
      :high -> "high"
      :medium -> "medium"
      :low -> "low"
      _ -> "medium"
    end
  end
end
