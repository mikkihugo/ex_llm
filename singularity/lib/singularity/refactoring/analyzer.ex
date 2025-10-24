defmodule Singularity.Refactoring.Analyzer do
  @moduledoc """
  Refactoring Analyzer - Identifies code quality issues and refactoring needs.

  This module delegates to CodeQuality.RefactoringAnalyzer for implementation.

  ## Responsibilities

  - Detects code duplication patterns
  - Identifies complexity hotspots (cyclomatic complexity, nesting depth)
  - Finds quality violations and anti-patterns
  - Recommends refactoring opportunities
  - Prioritizes issues by severity and effort

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Refactoring.Analyzer",
    "purpose": "Analyze codebase for refactoring needs and quality issues",
    "role": "analyzer",
    "layer": "refactoring",
    "implementation": "Delegates to CodeQuality.RefactoringAnalyzer",
    "relationships": {
      "RefactoringAnalyzer": "Uses implementation in code_quality",
      "RefactoringAgent": "Provides analysis results",
      "Autonomy.Planner": "Feeds refactoring opportunities"
    }
  }
  ```

  ## Anti-Patterns

  - ❌ **DO NOT** create duplicate refactoring analyzers
  - ❌ **DO NOT** mix quality analysis with refactoring recommendations (separate concerns)
  - ✅ **DO** use CodeQuality.RefactoringAnalyzer for actual implementation
  """

  require Logger

  alias Singularity.CodeQuality.RefactoringAnalyzer, as: Impl

  @doc """
  Analyze codebase for refactoring opportunities.

  Returns a list of refactoring needs sorted by severity and effort.

  ## Parameters
  - `codebase_path` - Root directory to analyze

  ## Returns
  - `{:ok, needs}` - List of refactoring opportunities
  - `{:error, reason}` - Analysis failed

  ## Examples

      iex> Singularity.Refactoring.Analyzer.analyze("lib/")
      {:ok, [
        %{type: "duplication", severity: "high", description: "..."},
        %{type: "complexity", severity: "medium", description: "..."}
      ]}
  """
  @spec analyze(Path.t()) :: {:ok, list()} | {:error, term()}
  def analyze(codebase_path) when is_binary(codebase_path) do
    try do
      case Impl.analyze(codebase_path) do
        {:ok, needs} when is_list(needs) ->
          {:ok, needs}

        {:error, reason} ->
          Logger.error("Refactoring analysis failed for #{codebase_path}",
            error: inspect(reason)
          )

          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Refactoring analysis failed for #{codebase_path}",
          error: inspect(e)
        )

        {:error, {:analysis_failed, codebase_path}}
    end
  end
end
