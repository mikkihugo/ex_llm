defmodule Singularity.Refactoring.Analyzer do
  @moduledoc """
  Refactoring Analyzer - High-level interface for identifying code refactoring opportunities.

  This module provides a clean API for analyzing codebases and identifying refactoring needs,
  delegating to specialized analyzers for the actual analysis work.

  ## Features

  - Code complexity analysis
  - Duplication detection
  - Quality violation identification
  - Maintainability assessment
  - Prioritized refactoring recommendations

  ## Usage

      # Analyze current codebase
      {:ok, needs} = Singularity.Refactoring.Analyzer.analyze_refactoring_need()

      # Analyze specific path
      {:ok, needs} = Singularity.Refactoring.Analyzer.analyze_refactoring_need("lib/my_app")
  """

  alias Singularity.CodeQuality.RefactoringAnalyzer

  @type refactoring_need :: %{
          type: String.t(),
          severity: String.t(),
          description: String.t(),
          file: String.t() | nil,
          location: non_neg_integer() | nil,
          estimated_effort: String.t(),
          timestamp: DateTime.t()
        }

  @doc """
  Analyzes a codebase path for refactoring needs.

  Returns {:ok, list_of_needs} or {:error, reason}.
  """
  @spec analyze(String.t()) :: {:ok, [refactoring_need()]} | {:error, term()}
  def analyze(codebase_path) do
    RefactoringAnalyzer.analyze(codebase_path)
  end

  @doc """
  Analyzes the current codebase for refactoring needs.

  Returns a list of refactoring opportunities sorted by priority.
  """
  @spec analyze_refactoring_need() :: [refactoring_need()]
  def analyze_refactoring_need do
    # Get the current codebase path (assuming we're in the singularity app)
    codebase_path = Application.app_dir(:singularity, "lib")

    case analyze(codebase_path) do
      {:ok, needs} -> needs
      {:error, _reason} -> []
    end
  end

  @doc """
  Analyzes a specific path for refactoring needs.
  """
  @spec analyze_refactoring_need(String.t()) :: {:ok, [refactoring_need()]} | {:error, term()}
  def analyze_refactoring_need(path) do
    analyze(path)
  end
end
