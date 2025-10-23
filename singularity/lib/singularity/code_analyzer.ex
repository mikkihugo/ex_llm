defmodule Singularity.CodeAnalyzer do
  @moduledoc """
  Multi-Language Code Analyzer - Wrapper for Rust CodebaseAnalyzer NIF

  Provides comprehensive code analysis for 20 languages using the language registry
  and CodebaseAnalyzer from rust/code_engine.

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.CodeAnalyzer",
    "purpose": "Multi-language code analysis with 20-language support",
    "type": "NIF wrapper module",
    "operates_on": "Code strings with language hints",
    "output": "Language analysis, RCA metrics, AST extraction, rule violations"
  }
  ```

  ## Supported Languages (20)

  - **BEAM**: Elixir, Erlang, Gleam
  - **Systems**: Rust, C, C++, C#, Go
  - **Web**: JavaScript, TypeScript
  - **High-Level**: Python, Java
  - **Scripting**: Lua, Bash
  - **Data**: JSON, YAML, TOML
  - **Documentation**: Markdown
  - **Infrastructure**: Dockerfile, SQL

  ## Capabilities

  ### 1. Language Analysis
  - Semantic tokenization
  - Complexity scoring
  - Quality metrics
  - Registry-derived metadata

  ### 2. RCA Metrics (9 languages)
  Rust, C, C++, C#, JavaScript, TypeScript, Python, Java, Go
  - Cyclomatic Complexity
  - Halstead metrics
  - Maintainability Index
  - SLOC, PLOC, LLOC, CLOC, BLANK

  ### 3. AST Extraction (All 20 languages)
  - Functions with signatures
  - Classes with methods
  - Imports and exports

  ### 4. Rule Checking
  - Family-based best practices
  - Language-specific style rules

  ### 5. Cross-Language Patterns
  - API Integration patterns
  - Error handling patterns
  - Logging, messaging, testing patterns

  ## Usage

  ```elixir
  # Analyze a language file
  {:ok, analysis} = CodeAnalyzer.analyze_language(code, "elixir")
  # => %{language_id: "elixir", complexity_score: 0.72, quality_score: 0.85}

  # Get RCA metrics (for supported languages)
  {:ok, metrics} = CodeAnalyzer.get_rca_metrics(code, "rust")
  # => %{cyclomatic_complexity: "8", maintainability_index: "75", ...}

  # Extract functions
  {:ok, functions} = CodeAnalyzer.extract_functions(code, "python")
  # => [%{name: "process_data", line_start: 42, parameters: ["data", "opts"]}]

  # Check language rules
  {:ok, violations} = CodeAnalyzer.check_language_rules(code, "typescript")
  # => [%{rule_id: "naming", severity: "warning", location: "line 10"}]

  # Detect cross-language patterns
  files = [{"elixir", elixir_code}, {"rust", rust_code}]
  {:ok, patterns} = CodeAnalyzer.detect_cross_language_patterns(files)
  # => [%{pattern_type: "ErrorHandling", source_language: "elixir", target_language: "rust"}]
  ```

  ## Database Integration

  ```elixir
  # Read from database and analyze
  def analyze_from_database(file_id) do
    with {:ok, code_file} <- Repo.get(CodeFile, file_id),
         {:ok, analysis} <- CodeAnalyzer.analyze_language(code_file.content, code_file.language) do
      {:ok, %{code_file: code_file, analysis: analysis}}
    end
  end

  # Batch analyze files from database
  def analyze_codebase_from_db(codebase_id) do
    Repo.all(from c in CodeFile, where: c.codebase_id == ^codebase_id)
    |> Enum.map(fn file ->
      {:ok, analysis} = analyze_language(file.content, file.language)
      {file.file_path, analysis}
    end)
  end
  ```

  ## Call Graph (YAML)

  ```yaml
  CodeAnalyzer:
    calls:
      - Singularity.RustAnalyzer (NIF)
      - Singularity.Repo (database access)
    called_by:
      - HTDAGAutoBootstrap (for module analysis)
      - QualityCodeGenerator (for quality checking)
      - CodeFileWatcher (for reanalysis)
  ```

  ## Anti-Patterns

  **DO NOT create these duplicates:**
  - ❌ `LanguageAnalyzer` - This IS the language analyzer
  - ❌ `MultiLanguageAnalysis` - Same purpose
  - ❌ `CodeQualityChecker` - Subset of this module

  ## Search Keywords

  multi-language-analysis, code-quality, ast-extraction, rca-metrics,
  language-registry, complexity-scoring, cross-language-patterns,
  20-language-support, tree-sitter, rust-nif
  """

  alias Singularity.Repo
  alias Singularity.Schemas.CodeFile

  require Logger

  # ===========================
  # Language Analysis
  # ===========================

  @doc """
  Analyze a single language file.

  Returns complete language analysis with registry-derived metadata.

  ## Parameters
  - `code`: Source code string
  - `language_hint`: Language ID, alias, or file extension (e.g., "elixir", "rs", "javascript")

  ## Returns
  - `{:ok, analysis}` - Language analysis result
  - `{:error, reason}` - If language unsupported or analysis fails
  """
  def analyze_language(code, language_hint) when is_binary(code) and is_binary(language_hint) do
    case Singularity.RustAnalyzer.analyze_language(code, language_hint) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, reason} ->
        Logger.warning("analyze_language failed for #{language_hint}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Check code against language-specific rules and best practices.

  ## Parameters
  - `code`: Source code string
  - `language_hint`: Language ID or alias

  ## Returns
  - `{:ok, violations}` - List of rule violations (empty if compliant)
  - `{:error, reason}` - If analysis fails
  """
  def check_language_rules(code, language_hint) when is_binary(code) and is_binary(language_hint) do
    case Singularity.RustAnalyzer.check_language_rules(code, language_hint) do
      {:ok, violations} -> {:ok, violations}
      {:error, reason} ->
        Logger.warning("check_language_rules failed for #{language_hint}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ===========================
  # RCA Metrics
  # ===========================

  @doc """
  Get RCA (Rust Code Analysis) metrics for code.

  Works for: Rust, C, C++, C#, JavaScript, TypeScript, Python, Java, Go

  ## Parameters
  - `code`: Source code string
  - `language_hint`: Language ID

  ## Returns
  - `{:ok, metrics}` - RCA metrics with CC, Halstead, MI, SLOC
  - `{:error, reason}` - If language unsupported or analysis fails
  """
  def get_rca_metrics(code, language_hint) when is_binary(code) and is_binary(language_hint) do
    case Singularity.RustAnalyzer.get_rca_metrics(code, language_hint) do
      {:ok, metrics} -> {:ok, metrics}
      {:error, reason} ->
        Logger.warning("get_rca_metrics failed for #{language_hint}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ===========================
  # AST Extraction
  # ===========================

  @doc """
  Extract function metadata from code using AST.

  ## Returns
  - `{:ok, functions}` - List of function metadata
  """
  def extract_functions(code, language_hint) when is_binary(code) and is_binary(language_hint) do
    case Singularity.RustAnalyzer.extract_functions(code, language_hint) do
      {:ok, functions} -> {:ok, functions}
      {:error, reason} ->
        Logger.warning("extract_functions failed for #{language_hint}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Extract class metadata from code using AST.

  ## Returns
  - `{:ok, classes}` - List of class metadata
  """
  def extract_classes(code, language_hint) when is_binary(code) and is_binary(language_hint) do
    case Singularity.RustAnalyzer.extract_classes(code, language_hint) do
      {:ok, classes} -> {:ok, classes}
      {:error, reason} ->
        Logger.warning("extract_classes failed for #{language_hint}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Extract imports and exports from code.

  ## Returns
  - `{:ok, {imports, exports}}` - Tuple of imports and exports lists
  """
  def extract_imports_exports(code, language_hint) when is_binary(code) and is_binary(language_hint) do
    case Singularity.RustAnalyzer.extract_imports_exports(code, language_hint) do
      {:ok, {imports, exports}} -> {:ok, {imports, exports}}
      {:error, reason} ->
        Logger.warning("extract_imports_exports failed for #{language_hint}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ===========================
  # Cross-Language Patterns
  # ===========================

  @doc """
  Detect cross-language patterns in polyglot codebases.

  ## Parameters
  - `files`: List of `{language_hint, code}` tuples

  ## Returns
  - `{:ok, patterns}` - Detected cross-language patterns with confidence scores
  """
  def detect_cross_language_patterns(files) when is_list(files) do
    case Singularity.RustAnalyzer.detect_cross_language_patterns(files) do
      {:ok, patterns} -> {:ok, patterns}
      {:error, reason} ->
        Logger.warning("detect_cross_language_patterns failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ===========================
  # Language Support Queries
  # ===========================

  @doc """
  Get all supported languages (20 languages).

  ## Returns
  - List of language IDs
  """
  def supported_languages do
    Singularity.RustAnalyzer.supported_languages()
  end

  @doc """
  Get RCA-supported languages (9 languages).

  ## Returns
  - List of language IDs with RCA metrics support
  """
  def rca_supported_languages do
    Singularity.RustAnalyzer.rca_supported_languages()
  end

  @doc """
  Get AST-Grep supported languages (all 20 languages).

  ## Returns
  - List of language IDs with AST-Grep support
  """
  def ast_grep_supported_languages do
    Singularity.RustAnalyzer.ast_grep_supported_languages()
  end

  @doc """
  Check if language has RCA support.

  ## Returns
  - `true` if RCA metrics available, `false` otherwise
  """
  def has_rca_support?(language_id) when is_binary(language_id) do
    Singularity.RustAnalyzer.has_rca_support(language_id)
  end

  @doc """
  Check if language has AST-Grep support.

  ## Returns
  - `true` if AST-Grep available, `false` otherwise
  """
  def has_ast_grep_support?(language_id) when is_binary(language_id) do
    Singularity.RustAnalyzer.has_ast_grep_support(language_id)
  end

  # ===========================
  # Database Integration
  # ===========================

  @doc """
  Analyze a code file from the database.

  Loads the file from PostgreSQL and runs analysis.

  ## Parameters
  - `file_id`: CodeFile primary key

  ## Returns
  - `{:ok, %{code_file: CodeFile.t(), analysis: map()}}` - File and analysis
  - `{:error, reason}` - If file not found or analysis fails
  """
  def analyze_from_database(file_id) do
    case Repo.get(CodeFile, file_id) do
      nil ->
        {:error, :not_found}

      code_file ->
        case analyze_language(code_file.content, code_file.language) do
          {:ok, analysis} ->
            {:ok, %{code_file: code_file, analysis: analysis}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Analyze all files in a codebase from the database.

  ## Parameters
  - `codebase_id`: Codebase identifier

  ## Returns
  - List of `{file_path, analysis}` tuples
  """
  def analyze_codebase_from_db(codebase_id) do
    import Ecto.Query

    Repo.all(from c in CodeFile, where: c.codebase_id == ^codebase_id)
    |> Enum.map(fn file ->
      case analyze_language(file.content, file.language) do
        {:ok, analysis} ->
          {file.file_path, {:ok, analysis}}

        {:error, reason} ->
          {file.file_path, {:error, reason}}
      end
    end)
  end

  @doc """
  Batch analyze files from database with RCA metrics.

  Only analyzes files with RCA-supported languages.

  ## Returns
  - List of `{file_path, metrics}` tuples for RCA-supported files
  """
  def batch_rca_metrics_from_db(codebase_id) do
    import Ecto.Query

    rca_languages = rca_supported_languages()

    Repo.all(from c in CodeFile,
      where: c.codebase_id == ^codebase_id and c.language in ^rca_languages)
    |> Enum.map(fn file ->
      case get_rca_metrics(file.content, file.language) do
        {:ok, metrics} ->
          {file.file_path, {:ok, metrics}}

        {:error, reason} ->
          {file.file_path, {:error, reason}}
      end
    end)
  end
end
