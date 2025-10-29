defmodule Singularity.CodeAnalyzer.CodeAnalysisResult do
  @moduledoc """
  Struct returned from Rust for aggregate code analysis results.
  """

  @enforce_keys [
    :complexity_score,
    :maintainability_score,
    :security_issues,
    :performance_issues,
    :refactoring_suggestions
  ]
  defstruct [
    :complexity_score,
    :maintainability_score,
    security_issues: [],
    performance_issues: [],
    refactoring_suggestions: []
  ]
end

defmodule Singularity.CodeAnalyzer.QualityMetrics do
  @moduledoc """
  Struct returned from Rust for quality metrics.
  """
  @enforce_keys [:cyclomatic_complexity, :lines_of_code, :test_coverage, :documentation_coverage]
  defstruct [
    :cyclomatic_complexity,
    :lines_of_code,
    :test_coverage,
    :documentation_coverage
  ]
end

defmodule Singularity.CodeAnalyzer.ControlFlowResult do
  @moduledoc """
  Control flow analysis result returned from the native layer.
  """
  @enforce_keys [
    :dead_ends,
    :unreachable_code,
    :completeness_score,
    :total_paths,
    :complete_paths,
    :incomplete_paths,
    :has_issues
  ]
  defstruct [
    :dead_ends,
    :unreachable_code,
    :completeness_score,
    :total_paths,
    :complete_paths,
    :incomplete_paths,
    :has_issues
  ]
end

defmodule Singularity.CodeAnalyzer.DeadEnd do
  @moduledoc false
  @enforce_keys [:node_id, :function_name, :line_number, :reason]
  defstruct [:node_id, :function_name, :line_number, :reason]
end

defmodule Singularity.CodeAnalyzer.UnreachableCode do
  @moduledoc false
  @enforce_keys [:node_id, :line_number, :reason]
  defstruct [:node_id, :line_number, :reason]
end

defmodule Singularity.CodeAnalyzer.LanguageAnalysis do
  @moduledoc """
  Per-language analysis metadata supplied by the native engine.
  """
  @enforce_keys [
    :language_id,
    :language_name,
    :family,
    :complexity_score,
    :quality_score,
    :rca_supported,
    :ast_grep_supported
  ]
  defstruct [
    :language_id,
    :language_name,
    :family,
    :complexity_score,
    :quality_score,
    :rca_supported,
    :ast_grep_supported
  ]
end

defmodule Singularity.CodeAnalyzer.RuleViolation do
  @moduledoc """
  Representation of a language-specific rule violation.
  """
  @enforce_keys [:rule_id, :rule_name, :severity, :location, :details]
  defstruct [:rule_id, :rule_name, :severity, :location, :details]
end

defmodule Singularity.CodeAnalyzer.CrossLanguagePattern do
  @moduledoc """
  Cross-language patterns detected across files and languages.
  """
  @enforce_keys [
    :id,
    :name,
    :pattern_type,
    :source_language,
    :target_language,
    :confidence,
    :characteristics
  ]
  defstruct [
    :id,
    :name,
    :pattern_type,
    :source_language,
    :target_language,
    :confidence,
    characteristics: []
  ]
end

defmodule Singularity.CodeAnalyzer.RcaMetrics do
  @moduledoc """
  RCA (Rust Code Analyzer) metrics returned from the native layer.
  """
  @enforce_keys [
    :cyclomatic_complexity,
    :halstead_metrics,
    :maintainability_index,
    :source_lines_of_code,
    :logical_lines_of_code,
    :comment_lines_of_code,
    :blank_lines
  ]
  defstruct [
    :cyclomatic_complexity,
    :halstead_metrics,
    :maintainability_index,
    :source_lines_of_code,
    :logical_lines_of_code,
    :comment_lines_of_code,
    :blank_lines
  ]
end

defmodule Singularity.CodeAnalyzer.FunctionMetadata do
  @moduledoc """
  Function metadata produced by the parser engine via the native layer.
  """
  @enforce_keys [
    :name,
    :line_start,
    :line_end,
    :parameters,
    :return_type,
    :is_async,
    :is_generator,
    :docstring
  ]
  defstruct [
    :name,
    :line_start,
    :line_end,
    :parameters,
    :return_type,
    :is_async,
    :is_generator,
    :docstring
  ]
end

defmodule Singularity.CodeAnalyzer.ClassMetadata do
  @moduledoc """
  Class or struct metadata extracted from the native analyzer.
  """
  @enforce_keys [:name, :line_start, :line_end, :methods, :fields]
  defstruct [:name, :line_start, :line_end, methods: [], fields: []]
end

defmodule Singularity.CodeAnalyzer.ParsedFile do
  @moduledoc """
  Result of parsing a single file through the native parser layer.
  """
  @enforce_keys [:file_path, :language, :ast_json, :symbols, :imports, :exports]
  defstruct [
    :file_path,
    :language,
    :ast_json,
    symbols: [],
    imports: [],
    exports: []
  ]
end

defmodule Singularity.LanguageDetection.Result do
  @moduledoc """
  Result returned from native language detection helpers.
  """
  @enforce_keys [:language, :confidence, :detection_method]
  defstruct [:language, :confidence, :detection_method]
end
