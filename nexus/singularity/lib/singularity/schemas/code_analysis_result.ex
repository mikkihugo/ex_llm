defmodule Singularity.Schemas.CodeAnalysisResult do
  @moduledoc """
  Code Analysis Result - Persistent storage for code analysis results.

  ## Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.CodeAnalysisResult",
    "layer": "data",
    "purpose": "Persist code analysis results for historical tracking and trend analysis",
    "data_source": "Singularity.CodeAnalysis.Analyzer",
    "storage": "PostgreSQL with JSONB",
    "primary_use_case": "Quality tracking, regression detection, performance monitoring"
  }
  ```

  ## Schema Design

  This schema stores comprehensive code analysis results including:

  - **Basic Metrics**: Complexity, quality, maintainability scores
  - **RCA Metrics**: Cyclomatic complexity, Halstead metrics, SLOC
  - **AST Data**: Functions, classes, imports/exports
  - **Rule Violations**: Language-specific rule checks
  - **Pattern Detection**: Cross-language patterns
  - **Performance Data**: Analysis duration, cache hits

  ## Relationships

  - **Belongs To**: `CodeFile` - The source code file analyzed
  - **Can Query**: Historical trend analysis by code_file_id + inserted_at

  ## JSONB Fields

  ### analysis_data
  Full analysis result from CodeAnalysis.Analyzer.analyze_language/2

  ### functions
  Array of function definitions from extract_functions/2:
  ```json
  [
    {"name": "hello", "line_start": 10, "line_end": 15, "signature": "def hello(x)"}
  ]
  ```

  ### classes
  Array of class definitions from extract_classes/2

  ### imports_exports
  Imports and exports from extract_imports_exports/2

  ### rule_violations
  Language rule violations from check_language_rules/2:
  ```json
  [
    {"rule": "max_line_length", "severity": "warning", "line": 42}
  ]
  ```

  ### patterns_detected
  Cross-language patterns from detect_cross_language_patterns/1

  ## Indexes

  - **Primary**: code_file_id - Find all analyses for a file
  - **Trending**: (code_file_id, inserted_at) - Historical analysis
  - **Quality**: quality_score - Find low-quality files
  - **Search**: GIN indexes on JSONB fields for fast queries

  ## Usage Examples

  ### Store Analysis Result
  ```elixir
  {:ok, analysis} = CodeAnalyzer.analyze_language(code, "elixir")
  {:ok, result} = CodeAnalyzer.store_result(file_id, analysis)
  ```

  ### Query Historical Trend
  ```elixir
  import Ecto.Query
  alias Singularity.{Repo, Schemas.CodeAnalysisResult}

  results = Repo.all(
    from r in CodeAnalysisResult,
    where: r.code_file_id == ^file_id,
    order_by: [asc: r.inserted_at],
    select: {r.inserted_at, r.quality_score}
  )
  ```

  ### Find Degraded Files
  ```elixir
  # Files with declining quality (last score < first score)
  query = from r in CodeAnalysisResult,
    join: latest in subquery(
      from r2 in CodeAnalysisResult,
      group_by: r2.code_file_id,
      select: %{
        code_file_id: r2.code_file_id,
        latest_at: max(r2.inserted_at)
      }
    ),
    on: r.code_file_id == latest.code_file_id and r.inserted_at == latest.latest_at,
    where: r.quality_score < 0.7,
    order_by: [asc: r.quality_score]
  ```

  ## Anti-Patterns

  ❌ **DO NOT** query without indexes:
  ```elixir
  # Bad - full table scan on JSONB
  Repo.all(from r in CodeAnalysisResult, where: fragment("analysis_data->>'foo' = ?", "bar"))
  ```

  ✅ **DO** use indexed fields for filtering:
  ```elixir
  # Good - uses quality_score index
  Repo.all(from r in CodeAnalysisResult, where: r.quality_score < 0.7)
  ```

  ## Search Keywords

  code_analysis_results, analysis_persistence, quality_tracking,
  trend_analysis, regression_detection, RCA_metrics, Halstead_metrics,
  code_quality_history, performance_monitoring, JSONB_storage
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "code_analysis_results" do
    # Relationships
    belongs_to :code_file, Singularity.Schemas.CodeFile

    # Analysis metadata
    field :language_id, :string
    field :analyzer_version, :string, default: "1.0.0"
    field :analysis_type, :string

    # Basic analysis results
    field :complexity_score, :float
    field :quality_score, :float
    field :maintainability_score, :float

    # RCA metrics (nullable for non-RCA languages)
    field :cyclomatic_complexity, :integer
    field :cognitive_complexity, :integer
    field :maintainability_index, :integer
    field :source_lines_of_code, :integer
    field :physical_lines_of_code, :integer
    field :logical_lines_of_code, :integer
    field :comment_lines_of_code, :integer

    # Halstead metrics
    field :halstead_difficulty, :float
    field :halstead_volume, :float
    field :halstead_effort, :float
    field :halstead_bugs, :float

    # AST extraction results
    field :functions_count, :integer
    field :classes_count, :integer
    field :imports_count, :integer
    field :exports_count, :integer

    # Full analysis data (JSONB for flexible storage)
    field :analysis_data, :map
    field :functions, {:array, :map}
    field :classes, {:array, :map}
    field :imports_exports, :map
    field :rule_violations, {:array, :map}
    field :patterns_detected, {:array, :map}

    # Error tracking
    field :has_errors, :boolean, default: false
    field :error_message, :string
    field :error_details, :map

    # Performance tracking
    field :analysis_duration_ms, :integer
    field :cache_hit, :boolean, default: false

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates a changeset for storing analysis results.

  ## Required Fields
  - code_file_id
  - language_id
  - analysis_type

  ## Optional Fields
  - All metric and analysis data fields
  """
  def changeset(result, attrs) do
    result
    |> cast(attrs, [
      :code_file_id,
      :language_id,
      :analyzer_version,
      :analysis_type,
      :complexity_score,
      :quality_score,
      :maintainability_score,
      :cyclomatic_complexity,
      :cognitive_complexity,
      :maintainability_index,
      :source_lines_of_code,
      :physical_lines_of_code,
      :logical_lines_of_code,
      :comment_lines_of_code,
      :halstead_difficulty,
      :halstead_volume,
      :halstead_effort,
      :halstead_bugs,
      :functions_count,
      :classes_count,
      :imports_count,
      :exports_count,
      :analysis_data,
      :functions,
      :classes,
      :imports_exports,
      :rule_violations,
      :patterns_detected,
      :has_errors,
      :error_message,
      :error_details,
      :analysis_duration_ms,
      :cache_hit
    ])
    |> validate_required([:code_file_id, :language_id, :analysis_type])
    |> validate_inclusion(:analysis_type, ["full", "rca_only", "ast_only"])
    |> validate_number(:complexity_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:quality_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:maintainability_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> foreign_key_constraint(:code_file_id)
  end
end
