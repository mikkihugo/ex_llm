defmodule Singularity.QualityAnalyzer do
  @moduledoc """
  Code Quality Analyzer (RustNif) - Comprehensive code quality analysis and metrics
  
  Provides detailed code quality analysis:
  - Calculate complexity metrics (cyclomatic, cognitive, etc.)
  - Detect code smells and anti-patterns
  - Measure maintainability and technical debt
  - Identify duplications and suggest refactoring
  - Calculate test coverage and quality scores
  """

  use Rustler, otp_app: :singularity_app, crate: :singularity_unified

  # Quality analysis functions
  def calculate_complexity(_file_path), do: :erlang.nif_error(:nif_not_loaded)
  def detect_code_smells(_file_path), do: :erlang.nif_error(:nif_not_loaded)
  def calculate_maintainability_index(_file_path), do: :erlang.nif_error(:nif_not_loaded)
  def detect_duplications(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def calculate_test_coverage(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def detect_technical_debt(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def suggest_refactoring(_file_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Calculate code complexity metrics
  
  ## Examples
  
      iex> Singularity.QualityAnalyzer.calculate_complexity("src/app.js")
      %{
        cyclomatic_complexity: 8,
        cognitive_complexity: 12,
        halstead_difficulty: 15.2,
        halstead_effort: 304.0,
        lines_of_code: 45,
        comment_ratio: 0.15
      }
  """
  def calculate_complexity(file_path) do
    calculate_complexity(file_path)
  end

  @doc """
  Detect code smells and anti-patterns
  
  ## Examples
  
      iex> Singularity.QualityAnalyzer.detect_code_smells("src/app.js")
      [
        %{
          type: "long_method",
          severity: "medium",
          description: "Method has 45 lines (threshold: 30)",
          line: 15,
          suggestion: "Consider breaking into smaller methods"
        },
        %{
          type: "duplicate_code",
          severity: "high",
          description: "Similar code blocks found in lines 25-30 and 45-50",
          suggestion: "Extract common functionality"
        }
      ]
  """
  def detect_code_smells(file_path) do
    detect_code_smells(file_path)
  end

  @doc """
  Calculate maintainability index (0-100)
  
  ## Examples
  
      iex> Singularity.QualityAnalyzer.calculate_maintainability_index("src/app.js")
      75.5
  """
  def calculate_maintainability_index(file_path) do
    calculate_maintainability_index(file_path)
  end

  @doc """
  Detect code duplications across codebase
  
  ## Examples
  
      iex> Singularity.QualityAnalyzer.detect_duplications("/path/to/project")
      [
        %{
          type: "exact_duplication",
          files: ["src/utils.js", "src/helpers.js"],
          lines: [15, 20],
          similarity: 1.0,
          suggestion: "Extract to shared utility"
        }
      ]
  """
  def detect_duplications(codebase_path) do
    detect_duplications(codebase_path)
  end

  @doc """
  Calculate test coverage percentage
  
  ## Examples
  
      iex> Singularity.QualityAnalyzer.calculate_test_coverage("/path/to/project")
      %{
        line_coverage: 85.5,
        branch_coverage: 78.2,
        function_coverage: 92.1,
        statement_coverage: 87.3,
        uncovered_lines: [45, 67, 89]
      }
  """
  def calculate_test_coverage(codebase_path) do
    calculate_test_coverage(codebase_path)
  end

  @doc """
  Detect and quantify technical debt
  
  ## Examples
  
      iex> Singularity.QualityAnalyzer.detect_technical_debt("/path/to/project")
      %{
        total_debt: 125.5,
        debt_items: [
          %{
            type: "todo_comments",
            count: 15,
            estimated_hours: 30.0,
            priority: "medium"
          },
          %{
            type: "code_smells",
            count: 8,
            estimated_hours: 16.0,
            priority: "high"
          }
        ],
        remediation_effort: "2.5 days"
      }
  """
  def detect_technical_debt(codebase_path) do
    detect_technical_debt(codebase_path)
  end

  @doc """
  Suggest refactoring improvements for file
  
  ## Examples
  
      iex> Singularity.QualityAnalyzer.suggest_refactoring("src/app.js")
      [
        %{
          type: "extract_method",
          description: "Extract validation logic from handleSubmit",
          lines: [25, 35],
          confidence: 0.85,
          effort: "medium"
        },
        %{
          type: "rename_variable",
          description: "Rename 'data' to 'userData' for clarity",
          line: 42,
          confidence: 0.95,
          effort: "low"
        }
      ]
  """
  def suggest_refactoring(file_path) do
    suggest_refactoring(file_path)
  end
end
