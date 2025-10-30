defmodule Singularity.CodeAnalyzer.Native do
  @moduledoc """
  Native bridge to the Rust code_quality_engine crate for multi-language code analysis.

  This module loads the Rust NIF from `rust/code_quality_engine` which provides:
  - Multi-language code analysis (20+ languages)
  - Code parsing via tree-sitter
  - Quality metrics calculation (RCA, Halstead, etc.)
  - AST extraction (functions, classes, imports/exports)
  - Cross-language pattern detection
  - Language-specific rule checking

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.CodeAnalyzer.Native",
    "type": "NIF wrapper",
    "purpose": "Elixir bindings to Rust code_quality_engine NIF for multi-language analysis",
    "rust_crate": "code_quality_engine",
    "analyzes": "All languages (Elixir, Rust, Python, JS, TypeScript, Go, Java, etc.)",
    "capabilities": [
      "Multi-language analysis (20+ languages)",
      "RCA metrics (9 languages)",
      "AST extraction",
      "Pattern detection",
      "Rule checking"
    ]
  }
  ```

  ## NIF Functions

  All functions return results directly or raise `:nif_not_loaded` if NIF fails to load.

  ### Multi-Language Analysis (NEW)
  - `analyze_language/2` - Analyze code with language registry metadata
  - `check_language_rules/2` - Check code against language-specific rules
  - `detect_cross_language_patterns/1` - Find patterns across multiple languages
  - `get_rca_metrics/2` - Get RCA metrics (cyclomatic complexity, Halstead, etc.)
  - `extract_functions/2` - Extract function metadata from AST
  - `extract_classes/2` - Extract class metadata from AST
  - `extract_imports_exports/2` - Extract imports and exports

  ### Language Support Queries
  - `supported_languages/0` - Get all supported languages (20+)
  - `rca_supported_languages/0` - Get RCA-supported languages (9)
  - `ast_grep_supported_languages/0` - Get AST-Grep supported languages
  - `has_rca_support/1` - Check if language has RCA support
  - `has_ast_grep_support/1` - Check if language has AST-Grep support

  ### Tree-sitter Parsing
  - `parse_file_nif/1` - Parse a single file using tree-sitter
  - `supported_languages_nif/0` - Get list of supported languages
  - `analyze_code_nif/2` - Analyze code quality and patterns
  - `calculate_quality_metrics_nif/2` - Calculate quality metrics

  ### Knowledge/Asset Management (placeholder)
  - `load_asset_nif/1` - Load asset from local cache
  - `query_asset_nif/1` - Query asset from central service

  ## NIF Loading

  The NIF is loaded from `priv/native/libcode_quality_engine.so` (compiled from rust/code_quality_engine).
  If the NIF fails to load, functions will return `:nif_not_loaded` errors.

  ## Examples

      # Multi-language analysis
      iex> Singularity.CodeAnalyzer.analyze_language("def hello, do: :world", "elixir")
      {:ok, %{language_id: "elixir", complexity_score: 0.1, quality_score: 0.9}}

      # RCA metrics
      iex> Singularity.CodeAnalyzer.get_rca_metrics(rust_code, "rust")
      {:ok, %{cyclomatic_complexity: "5", maintainability_index: "75"}}

      # AST extraction
      iex> Singularity.CodeAnalyzer.extract_functions(code, "python")
      {:ok, [%{name: "process_data", line_start: 10, parameters: ["data"]}]}

      # Language support
      iex> Singularity.CodeAnalyzer.supported_languages()
      ["elixir", "rust", "python", "javascript", ...]

  ## Anti-Patterns

  **DO NOT create these duplicates:**
  - ❌ `CodeAnalysisNIF` - This IS the NIF module
  - ❌ `RustAnalyzer` - Deprecated name (use Singularity.CodeAnalyzer.Native)
  - ❌ Direct NIF calls - Use `Singularity.CodeAnalyzer` wrapper instead

  **DO NOT call this module directly:**
  - ❌ Use `Singularity.CodeAnalyzer` instead (proper wrapper with caching, error handling)
  - ✅ This module should ONLY be called by `CodeAnalyzer`

  ## Search Keywords

  rust-nif, code-analysis, multi-language, tree-sitter, rca-metrics,
  halstead-metrics, ast-extraction, pattern-detection, rustler, nif-bindings
  """

  use Rustler,
    otp_app: :singularity,
    crate: "code_quality_engine",
    path: "../../packages/code_quality_engine"

  # ===========================
  # Multi-Language Analysis NIFs (NEW - CodebaseAnalyzer)
  # ===========================

  @doc """
  Analyze a single language file with registry-derived metadata.

  Returns language analysis including complexity, quality scores, and language metadata.

  ## Parameters
  - `code` - Source code string
  - `language_hint` - Language ID, alias, or file extension

  ## Returns
  - `{:ok, analysis}` - Language analysis result
  - `{:error, reason}` - Analysis failed
  """
  def analyze_language(_code, _language_hint), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Analyze control flow of code (AST-based flow analysis).

  ## Parameters
  - `file_path` - Path to file to analyze

  ## Returns
  - `{:ok, control_flow}` - Control flow analysis
  - `{:error, reason}` - Analysis failed
  """
  def analyze_control_flow(_file_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Check code against language-specific rules and best practices.

  ## Parameters
  - `code` - Source code string
  - `language_hint` - Language ID or alias

  ## Returns
  - `{:ok, violations}` - List of rule violations (empty if compliant)
  - `{:error, reason}` - Analysis failed
  """
  def check_language_rules(_code, _language_hint), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Detect cross-language patterns in polyglot codebases.

  ## Parameters
  - `files` - List of `{language_hint, code}` tuples

  ## Returns
  - `{:ok, patterns}` - Detected cross-language patterns with confidence scores
  - `{:error, reason}` - Analysis failed
  """
  def detect_cross_language_patterns(_files), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Get RCA metrics for code (cyclomatic complexity, Halstead, maintainability index).

  Works for: Rust, C, C++, C#, JavaScript, TypeScript, Python, Java, Go

  ## Parameters
  - `code` - Source code string
  - `language_hint` - Language ID

  ## Returns
  - `{:ok, metrics}` - RCA metrics with CC, Halstead, MI, SLOC
  - `{:error, reason}` - Language unsupported or analysis failed
  """
  def get_rca_metrics(_code, _language_hint), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Extract function metadata from code using AST.

  ## Parameters
  - `code` - Source code string
  - `language_hint` - Language ID

  ## Returns
  - `{:ok, functions}` - List of function metadata (name, line range, params, etc.)
  - `{:error, reason}` - Extraction failed
  """
  def extract_functions(_code, _language_hint), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Extract class metadata from code using AST.

  ## Parameters
  - `code` - Source code string
  - `language_hint` - Language ID

  ## Returns
  - `{:ok, classes}` - List of class metadata (name, methods, fields)
  - `{:error, reason}` - Extraction failed
  """
  def extract_classes(_code, _language_hint), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Extract imports and exports from code.

  ## Parameters
  - `code` - Source code string
  - `language_hint` - Language ID

  ## Returns
  - `{:ok, {imports, exports}}` - Tuple of imports and exports lists
  - `{:error, reason}` - Extraction failed
  """
  def extract_imports_exports(_code, _language_hint), do: :erlang.nif_error(:nif_not_loaded)

  # ===========================
  # Language Support Query NIFs
  # ===========================

  @doc """
  Get all supported languages (20+ languages).

  Returns list of language IDs (e.g., ["elixir", "rust", "python", ...])
  """
  def supported_languages(), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Get RCA-supported languages (9 languages).

  Returns list of language IDs where RCA metrics are available.
  """
  def rca_supported_languages(), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Get AST-Grep supported languages (all 20+ languages).

  Returns list of language IDs where AST-Grep pattern matching works.
  """
  def ast_grep_supported_languages(), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Check if language has RCA support.

  ## Parameters
  - `language_id` - Language identifier

  ## Returns
  - `true` if RCA metrics available, `false` otherwise
  """
  def has_rca_support(_language_id), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Check if language has AST-Grep support.

  ## Parameters
  - `language_id` - Language identifier

  ## Returns
  - `true` if AST-Grep available, `false` otherwise
  """
  def has_ast_grep_support(_language_id), do: :erlang.nif_error(:nif_not_loaded)

  # ===========================
  # Tree-sitter Parsing NIFs
  # ===========================

  @doc """
  Parse a single file using tree-sitter.

  **Note:** Consider using `analyze_language/2` instead for richer analysis.

  ## Parameters
  - `file_path` - Path to the file to parse

  ## Returns
  - `{:ok, parsed_file}` - Parsed file with AST, symbols, imports, exports
  - `{:error, reason}` - Parse failed
  """
  def parse_file_nif(file_path) do
    # Delegate to modern analyze_language/2 for richer analysis
    case File.read(file_path) do
      {:ok, content} -> analyze_language(content, nil)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get list of supported languages.

  **Note:** Use `supported_languages/0` instead (returns proper list).
  """
  def supported_languages_nif() do
    # Delegate to modern supported_languages/0 for proper list
    supported_languages()
  end

  @doc """
  Analyze code quality and patterns.

  **Note:** Use `analyze_language/2` instead for modern analysis.
  """
  def analyze_code_nif(codebase_path, language) do
    # Delegate to modern analyze_language/2 for modern analysis
    case File.read(codebase_path) do
      {:ok, content} -> analyze_language(content, language)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculate quality metrics.

  **Note:** Use `get_rca_metrics/2` for comprehensive metrics.
  """
  def calculate_quality_metrics_nif(code, language) do
    # Delegate to modern get_rca_metrics/2 for comprehensive metrics
    get_rca_metrics(code, language)
  end

  # ===========================
  # Knowledge/Asset NIFs (placeholder)
  # ===========================

  @doc """
  Load asset from local cache.

  ## Parameters
  - `id` - Asset ID

  ## Returns
  - `{:ok, asset}` - Asset data
  - `{:error, :not_found}` - Asset not in cache
  """
  def load_asset_nif(_id), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Query asset from central service.

  ## Parameters
  - `id` - Asset ID

  ## Returns
  - `{:ok, asset}` - Asset data from central service
  - `{:error, reason}` - Query failed
  """
  def query_asset_nif(_id), do: :erlang.nif_error(:nif_not_loaded)

  # ===========================
  # AI Calculation NIFs (NEW)
  # ===========================

  @doc """
  Calculate AI-optimized complexity score for learning.

  ## Parameters
  - `code` - Source code string
  - `language_hint` - Language ID

  ## Returns
  - `{:ok, score}` - AI complexity score (0.0-10.0)
  - `{:error, reason}` - Calculation failed
  """
  def calculate_ai_complexity_score(_code, _language_hint), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Extract complexity features from code.

  ## Parameters
  - `code` - Source code string
  - `language_hint` - Language ID

  ## Returns
  - `{:ok, features}` - Complexity features map
  - `{:error, reason}` - Extraction failed
  """
  def extract_complexity_features(_code, _language_hint), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Calculate code evolution trends.

  ## Parameters
  - `before_metrics` - Previous code metrics
  - `after_metrics` - Current code metrics

  ## Returns
  - `{:ok, trends}` - Evolution trend analysis
  - `{:error, reason}` - Calculation failed
  """
  def calculate_evolution_trends(_before_metrics, _after_metrics),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Predict AI-generated code quality.

  ## Parameters
  - `code_features` - Code features map
  - `language_hint` - Language ID
  - `model_name` - AI model name

  ## Returns
  - `{:ok, prediction}` - Quality prediction
  - `{:error, reason}` - Prediction failed
  """
  def predict_ai_code_quality(_code_features, _language_hint, _model_name),
    do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Calculate pattern effectiveness for AI learning.

  ## Parameters
  - `pattern` - Code pattern string
  - `metrics` - Complexity metrics

  ## Returns
  - `{:ok, effectiveness}` - Pattern effectiveness score (0.0-1.0)
  - `{:error, reason}` - Calculation failed
  """
  def calculate_pattern_effectiveness(_pattern, _metrics), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Calculate supervision complexity for BEAM languages.

  ## Parameters
  - `modules` - List of module names

  ## Returns
  - `{:ok, complexity}` - Supervision complexity score
  - `{:error, reason}` - Calculation failed
  """
  def calculate_supervision_complexity(_modules), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Calculate actor complexity for BEAM languages.

  ## Parameters
  - `functions` - List of function names

  ## Returns
  - `{:ok, complexity}` - Actor complexity score
  - `{:error, reason}` - Calculation failed
  """
  def calculate_actor_complexity(_functions), do: :erlang.nif_error(:nif_not_loaded)

  # ===========================
  # Language Detection NIFs
  # ===========================

  @doc """
  Detect language by file extension.

  ## Parameters
  - `extension` - File extension (e.g., "ex", "rs", "py")

  ## Returns
  - `{:ok, result}` - Detection result with language, confidence, method
  - `{:error, reason}` - Detection failed
  """
  def detect_language_by_extension_nif(_extension), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Detect language by manifest file (package.json, Cargo.toml, mix.exs, etc.).

  ## Parameters
  - `manifest_path` - Path to manifest file

  ## Returns
  - `{:ok, result}` - Detection result with language, confidence, method
  - `{:error, reason}` - Detection failed
  """
  def detect_language_by_manifest_nif(_manifest_path), do: :erlang.nif_error(:nif_not_loaded)
end
