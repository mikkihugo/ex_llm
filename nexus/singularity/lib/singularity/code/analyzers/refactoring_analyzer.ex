defmodule Singularity.Code.Analyzers.RefactoringAnalyzer do
  @moduledoc """
  Refactoring Analyzer - Identifies code refactoring opportunities.

  Delegates to existing refactoring analysis infrastructure via
  Singularity.Refactoring.Analyzer and Architecture.Analyzers.RefactoringAnalyzer.

  ## Usage

      {:ok, analysis} = RefactoringAnalyzer.analyze_refactoring_need()

  ## Returns

      {:ok, %{
        duplicates: [...],
        complexity: [...],
        cyclomatic_complexity: [...],
        patterns: [...],
        anti_patterns: [...]
      }}
  """

  require Logger

  @doc """
  Analyze codebase for refactoring opportunities.

  Returns a map with detected refactoring needs categorized by type.
  """
  def analyze_refactoring_need do
    try do
      # Aggregate results from multiple analysis sources
      duplicates = detect_duplicates()
      complexity = detect_complexity()
      patterns = detect_patterns()
      anti_patterns = detect_anti_patterns()

      analysis = %{
        duplicates: duplicates,
        complexity: complexity,
        cyclomatic_complexity: extract_cyclomatic(complexity),
        patterns: patterns,
        anti_patterns: anti_patterns,
        analyzed_at: DateTime.utc_now()
      }

      {:ok, analysis}
    rescue
      error ->
        Logger.error("RefactoringAnalyzer error: #{inspect(error)}")
        {:error, "Refactoring analysis failed: #{inspect(error)}"}
    end
  end

  @doc """
  Analyze specific codebase path for refactoring needs.
  """
  def analyze_refactoring_need(path) when is_binary(path) do
    try do
      # Call the internal refactoring analyzer with path context
      case Singularity.Refactoring.Analyzer.analyze(path) do
        {:ok, results} ->
          # Transform results to standard format
          analysis = %{
            duplicates: Map.get(results, :duplicates, []),
            complexity: Map.get(results, :complexity, []),
            cyclomatic_complexity: Map.get(results, :cyclomatic_complexity, []),
            patterns: Map.get(results, :patterns, []),
            anti_patterns: Map.get(results, :anti_patterns, []),
            path: path,
            analyzed_at: DateTime.utc_now()
          }

          {:ok, analysis}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("RefactoringAnalyzer.analyze error for #{path}: #{inspect(error)}")
        {:error, "Failed to analyze refactoring needs at #{path}"}
    end
  end

  # Private helpers ===================================================

  defp detect_duplicates do
    # Placeholder for duplicate detection
    # Could integrate with code similarity analysis
    []
  end

  defp detect_complexity do
    # Placeholder for complexity detection
    # Would call code metrics from parser_engine or quality_engine NIFs
    []
  end

  defp extract_cyclomatic(complexity) do
    # Extract cyclomatic complexity metrics from general complexity results
    complexity
    |> Enum.filter(&(Map.get(&1, :type) == "cyclomatic_complexity"))
  end

  defp detect_patterns do
    # Placeholder for pattern detection
    # Would identify design patterns that could be improved
    []
  end

  defp detect_anti_patterns do
    # Placeholder for anti-pattern detection
    # Would identify problematic patterns
    []
  end
end
