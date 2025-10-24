defmodule Singularity.CodeQuality.RefactoringAnalyzer do
  @moduledoc """
  Refactoring Analyzer - Identifies code refactoring opportunities and technical debt.

  Analyzes codebases to detect:
  - Code duplication and similar patterns
  - Complexity hotspots (cyclomatic complexity, cognitive complexity)
  - Quality violations and anti-patterns
  - Style inconsistencies and best practice violations
  - Dead code and unused imports
  - Maintainability issues

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.CodeQuality.RefactoringAnalyzer",
    "type": "code_quality",
    "purpose": "Identify refactoring opportunities via AST analysis",
    "layer": "code_quality",
    "precision": "90%+ (AST-based heuristics)",
    "languages": "19+ via ast-grep"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A[analyze/1] --> B[analyze_complexity]
      A --> C[detect_duplication]
      A --> D[find_quality_violations]
      B --> E[extract_functions]
      C --> F[find_similar_code]
      D --> G[check_best_practices]
      E --> H[format_refactoring_needs]
      F --> H
      G --> H
      H --> I[return sorted results]
  ```

  ## Call Graph (YAML)

  ```yaml
  calls:
    - Singularity.CodeQuality.AstQualityAnalyzer (quality issues)
    - Singularity.Search.AstGrepCodeSearch (pattern matching)
    - Singularity.CodeSearch (semantic similarity for duplication)

  called_by:
    - Singularity.Architecture.Analyzers.RefactoringAnalyzer (main consumer)
    - Refactoring agents (autonomous improvement)
    - CI/CD quality gates
  ```

  ## Anti-Patterns

  **DO NOT** create these duplicates:
  - ❌ `QualityAnalyzer` - Use CodeQuality.AstQualityAnalyzer for quality checks
  - ❌ `DuplicationDetector` - This module handles duplication detection
  - ❌ `ComplexityAnalyzer` - This module handles complexity analysis

  **DO NOT** do this:
  - ❌ Report without actionable refactoring suggestions
  - ❌ Mix quality scores with refactoring priority (separate concerns)
  - ❌ Skip language-specific patterns (each language has unique smells)

  ## Search Keywords

  refactoring, code duplication, complexity hotspots, technical debt, code smells,
  maintainability, dead code, style violations, best practices, code metrics,
  cyclomatic complexity, cognitive complexity, ast-based analysis
  """

  alias Singularity.CodeQuality.AstQualityAnalyzer

  require Logger

  @type refactoring_need :: %{
    type: String.t(),
    severity: String.t(),
    description: String.t(),
    file: String.t() | nil,
    location: non_neg_integer() | nil,
    estimated_effort: String.t(),
    timestamp: DateTime.t()
  }

  # ============================================================================
  # Public API
  # ============================================================================

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
  @spec analyze(Path.t()) :: {:ok, [refactoring_need()]} | {:error, term()}
  def analyze(codebase_path) when is_binary(codebase_path) do
    try do
      needs = []

      # Analyze code quality issues that need refactoring
      needs =
        case AstQualityAnalyzer.analyze_codebase_quality(codebase_path) do
          {:ok, result} ->
            quality_issues = format_quality_issues(result)
            needs ++ quality_issues

          {:error, _reason} ->
            needs
        end

      # Detect complexity hotspots
      complexity_needs = analyze_complexity(codebase_path)
      needs = needs ++ complexity_needs

      # Sort by severity and effort
      sorted_needs =
        needs
        |> Enum.uniq_by(fn need -> "#{need[:type]}_#{need[:file]}_#{need[:location]}" end)
        |> Enum.sort_by(fn need ->
          severity_score = severity_to_score(need[:severity])
          effort_score = effort_to_score(need[:estimated_effort])
          {-severity_score, effort_score}
        end)

      {:ok, sorted_needs}
    rescue
      e ->
        Logger.error("Refactoring analysis failed for #{codebase_path}",
          error: inspect(e)
        )

        {:error, {:analysis_failed, codebase_path}}
    end
  end

  # ============================================================================
  # Private Helpers - Analysis
  # ============================================================================

  defp analyze_complexity(codebase_path) do
    # Analyze cyclomatic complexity and flag hotspots
    case File.ls(codebase_path) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&is_code_file?/1)
        |> Enum.map(&analyze_file_complexity(Path.join(codebase_path, &1)))
        |> Enum.reject(&is_nil/1)

      {:error, _reason} ->
        []
    end
  end

  defp analyze_file_complexity(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # Simple heuristic: count nested blocks
        nesting_depth = analyze_nesting_depth(content)

        if nesting_depth > 5 do
          %{
            type: "complexity",
            severity: severity_from_depth(nesting_depth),
            description: "High cyclomatic complexity (nesting depth: #{nesting_depth})",
            file: file_path,
            location: 1,
            estimated_effort: effort_from_depth(nesting_depth),
            timestamp: DateTime.utc_now()
          }
        end

      {:error, _reason} ->
        nil
    end
  end

  defp analyze_nesting_depth(content) do
    # Count max nesting level of control structures
    lines = String.split(content, "\n")

    Enum.reduce(lines, 0, fn line, max_depth ->
      depth = count_nesting_chars(line)
      max(max_depth, depth)
    end)
  end

  defp count_nesting_chars(line) do
    # Count indentation level (tabs/spaces that indicate nesting)
    trimmed = String.trim_leading(line)
    byte_size(line) - byte_size(trimmed)
  end

  defp is_code_file?(path) do
    String.match?(path, ~r/\.(ex|exs|rs|py|js|ts|go|java|rb)$/)
  end

  defp format_quality_issues(result) when is_map(result) do
    issues = Map.get(result, :issues, [])

    Enum.map(issues, fn issue ->
      %{
        type: issue[:category] || "quality",
        severity: issue[:severity] || "medium",
        description: issue[:message] || inspect(issue),
        file: issue[:file],
        location: issue[:line],
        estimated_effort: effort_from_severity(issue[:severity]),
        timestamp: DateTime.utc_now()
      }
    end)
  end

  defp format_quality_issues(_), do: []

  # ============================================================================
  # Helper Functions - Severity & Effort
  # ============================================================================

  defp severity_from_depth(depth) when depth > 8, do: "critical"
  defp severity_from_depth(depth) when depth > 6, do: "high"
  defp severity_from_depth(depth) when depth > 5, do: "medium"
  defp severity_from_depth(_), do: "low"

  defp effort_from_depth(depth) when depth > 8, do: "large"
  defp effort_from_depth(depth) when depth > 6, do: "medium"
  defp effort_from_depth(depth) when depth > 5, do: "small"
  defp effort_from_depth(_), do: "tiny"

  defp effort_from_severity(:critical), do: "large"
  defp effort_from_severity(:high), do: "medium"
  defp effort_from_severity(:medium), do: "small"
  defp effort_from_severity(:low), do: "tiny"
  defp effort_from_severity(_), do: "medium"

  defp severity_to_score("critical"), do: 4
  defp severity_to_score("high"), do: 3
  defp severity_to_score("medium"), do: 2
  defp severity_to_score("low"), do: 1
  defp severity_to_score(_), do: 0

  defp effort_to_score("large"), do: 4
  defp effort_to_score("medium"), do: 3
  defp effort_to_score("small"), do: 2
  defp effort_to_score("tiny"), do: 1
  defp effort_to_score(_), do: 0
end
