defmodule Singularity.CodeEngine do
  @moduledoc """
  High-level facade for the Rust-backed Code Analyzer.

  This module offers a stable API that other parts of the system depend on.
  It bridges to `Singularity.CodeAnalyzer` (for rich analysis) and
  `Singularity.CodeAnalyzer.Native` (for legacy NIF calls).
  """

  alias Singularity.CodeAnalyzer
  alias Singularity.CodeAnalyzer.Native

  @doc """
  Parse a file on disk using the Rust parser.
  """
  def parse_file(file_path) when is_binary(file_path) do
    Native.parse_file_nif(file_path)
  end

  @doc """
  Analyze code. Accepts either raw source (`code`) or a path (`codebase_path`).
  """
  def analyze_code(code, language) when is_binary(code) and is_binary(language) do
    CodeAnalyzer.analyze_language(code, language)
  end

  def analyze_code(codebase_path, language)
      when is_binary(codebase_path) and is_binary(language) do
    Native.analyze_code_nif(codebase_path, language)
  end

  @doc """
  Analyze a single language snippet.
  """
  def analyze_language(code, language_hint, opts \\ []) do
    CodeAnalyzer.analyze_language(code, language_hint, opts)
  end

  @doc """
  Check language-specific rules.
  """
  def check_language_rules(code, language_hint) do
    CodeAnalyzer.check_language_rules(code, language_hint)
  end

  @doc """
  Get RCA metrics for supported languages.
  """
  def get_rca_metrics(code, language_hint) do
    CodeAnalyzer.get_rca_metrics(code, language_hint)
  end

  @doc """
  Detect cross-language patterns.
  """
  def detect_cross_language_patterns(files) when is_list(files) do
    CodeAnalyzer.detect_cross_language_patterns(files)
  end

  @doc """
  Extract functions from code.
  """
  def extract_functions(code, language_hint) do
    CodeAnalyzer.extract_functions(code, language_hint)
  end

  @doc """
  Extract classes from code.
  """
  def extract_classes(code, language_hint) do
    CodeAnalyzer.extract_classes(code, language_hint)
  end

  @doc """
  Calculate quality metrics via the legacy NIF.
  """
  def calculate_quality_metrics(code, language) do
    Native.calculate_quality_metrics_nif(code, language)
  end

  @doc """
  List of languages supported by the NIF.
  """
  def supported_languages do
    Native.supported_languages()
  end

  def rca_supported_languages do
    Native.rca_supported_languages()
  end

  def ast_grep_supported_languages do
    Native.ast_grep_supported_languages()
  end

  def has_rca_support?(language) do
    Native.has_rca_support(language)
  end

  def has_ast_grep_support?(language) do
    Native.has_ast_grep_support(language)
  end
end
