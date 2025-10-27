defmodule Singularity.Refactoring.Analyzer do
  @moduledoc """
  Refactoring Analyzer - Identifies code refactoring opportunities and technical debt.

  This module analyzes codebases to detect refactoring needs including:
  - Code complexity issues
  - Duplication patterns
  - Quality violations
  - Maintainability concerns
  """

  alias Singularity.CodeQuality.RefactoringAnalyzer

  @doc """
  Analyzes a codebase path for refactoring needs.

  Returns {:ok, list_of_needs} or {:error, reason}.
  """
  @spec analyze(String.t()) :: {:ok, list(map())} | {:error, term()}
  def analyze(codebase_path) do
    RefactoringAnalyzer.analyze(codebase_path)
  end

  @doc """
  Analyzes the current codebase for refactoring needs.

  Returns a list of refactoring opportunities sorted by priority.
  """
  @spec analyze_refactoring_need() :: list(map())
  def analyze_refactoring_need do
    # Get the current codebase path (assuming we're in the singularity app)
    codebase_path = Application.app_dir(:singularity, "lib")

    case RefactoringAnalyzer.analyze(codebase_path) do
      {:ok, analysis} ->
        # Transform the analysis into refactoring needs
        format_refactoring_needs(analysis)

      {:error, _reason} ->
        []
    end
  end

  @doc """
  Analyzes a specific path for refactoring needs.
  """
  @spec analyze_refactoring_need(String.t()) :: {:ok, list(map())} | {:error, term()}
  def analyze_refactoring_need(path) do
    case RefactoringAnalyzer.analyze(path) do
      {:ok, analysis} ->
        refactoring_needs = format_refactoring_needs(analysis)
        {:ok, refactoring_needs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_refactoring_needs(analysis) do
    # Extract refactoring opportunities from the analysis
    complexity_issues = Map.get(analysis, :complexity_issues, [])
    duplication_patterns = Map.get(analysis, :duplication, [])
    quality_violations = Map.get(analysis, :quality_violations, [])

    # Combine and prioritize refactoring needs
    refactoring_needs =
      (format_complexity_issues(complexity_issues) ++
       format_duplication_patterns(duplication_patterns) ++
       format_quality_violations(quality_violations))
      |> Enum.sort_by(&severity_priority(&1.severity), :desc)

    refactoring_needs
  end

  defp severity_priority(:critical), do: 3
  defp severity_priority(:high), do: 2
  defp severity_priority(:medium), do: 1
  defp severity_priority(:low), do: 0

  defp format_complexity_issues(issues) do
    Enum.map(issues, fn issue ->
      %{
        type: :complexity,
        severity: :high,
        file: issue.file,
        line: issue.line,
        description: "High complexity: #{issue.complexity_type}",
        affected_files: [issue.file]
      }
    end)
  end

  defp format_duplication_patterns(patterns) do
    Enum.map(patterns, fn pattern ->
      %{
        type: :duplication,
        severity: :medium,
        files: pattern.files,
        description: "Code duplication detected across #{length(pattern.files)} files",
        affected_files: pattern.files
      }
    end)
  end

  defp format_quality_violations(violations) do
    Enum.map(violations, fn violation ->
      %{
        type: :quality,
        severity: :low,
        file: violation.file,
        line: violation.line,
        description: violation.message,
        affected_files: [violation.file]
      }
    end)
  end
end