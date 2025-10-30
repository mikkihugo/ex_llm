defmodule Singularity.CodeAnalyzer do
  @moduledoc """
  Multi-Language Code Analyzer - Wrapper for Rust CodebaseAnalyzer NIF

  Provides comprehensive code analysis for **26 languages** using the language registry
  and CodebaseAnalyzer from rust/code_quality_engine.

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.CodeAnalyzer",
    "purpose": "Multi-language code analysis with 26-language support (all with RCA metrics)",
    "type": "NIF wrapper module",
    "operates_on": "Code strings with language hints",
    "output": "Language analysis, RCA metrics, AST extraction, rule violations",
    "rca_metrics_languages": 26,
    "ast_analysis_languages": 26
  }
  ```

  ## Supported Languages (26 - All with Full RCA Metrics)

  - **BEAM**: Elixir, Erlang, Gleam (✅ Full RCA + BEAM patterns)
  - **Systems**: Rust, C, C++, Go, Swift (✅ Full RCA)
  - **Web**: JavaScript, TypeScript, PHP, Dart (✅ Full RCA)
  - **JVM**: Java, Scala, Clojure (✅ Full RCA)
  - **Scripting**: Python, Ruby, Lua, Bash (✅ Full RCA)
  - **CLR**: C# (✅ Full RCA)
  - **Data**: JSON, YAML, TOML, SQL (✅ AST + Metrics)
  - **Documentation**: Markdown (✅ AST + Metrics)
  - **Infrastructure**: Dockerfile (✅ AST + Metrics)

  ## Capabilities

  ### 1. Language Analysis (All 26 Languages)
  - Semantic tokenization
  - Complexity scoring
  - Quality metrics
  - Registry-derived metadata
  - Language family detection

  ### 2. RCA Metrics (All 26 Languages)
  Rust, C, C++, C#, JavaScript, TypeScript, Python, Java, Go, **Ruby, PHP, Dart, Swift, Clojure, Scala**
  - Cyclomatic Complexity
  - Halstead metrics (program length, vocabulary, difficulty, effort)
  - Maintainability Index
  - SLOC, PLOC, LLOC, CLOC, BLANK
  - Complexity scoring

  ### 3. AST Extraction (All 26 Languages)
  - Functions with signatures
  - Classes with methods
  - Imports and exports
  - Language-specific patterns

  ### 4. Rule Checking
  - Family-based best practices
  - Language-specific style rules
  - Quality heuristics

  ### 5. BEAM-Specific Analysis (Elixir, Erlang, Gleam)
  - GenServer/gen_server detection
  - Supervisor pattern detection
  - OTP behavior analysis
  - Process spawning patterns
  - Message passing analysis
  - Actor complexity scoring

  ### 6. Cross-Language Patterns
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
      - Native (NIF)
      - Singularity.Repo (database access)
    called_by:
      - StartupCodeIngestion (for module analysis)
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
  26-language-support, tree-sitter, rust-nif
  """

  alias Singularity.CodeAnalyzer.Native
  alias Cache
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
  - `opts`: Options
    - `:cache` - Use caching (default: true if Cache is running)

  ## Returns
  - `{:ok, analysis}` - Language analysis result
  - `{:error, reason}` - If language unsupported or analysis fails
  """
  def analyze_language(code, language_hint, opts \\ [])
      when is_binary(code) and is_binary(language_hint) do
    use_cache = Keyword.get(opts, :cache, cache_enabled?())

    if use_cache do
      Cache.get_or_analyze(code, language_hint, fn ->
        do_analyze_language(code, language_hint)
      end)
    else
      do_analyze_language(code, language_hint)
    end
  end

  defp do_analyze_language(code, language_hint) do
    case Native.analyze_language(code, language_hint) do
      {:ok, analysis} ->
        {:ok, analysis}

      {:error, reason} ->
        Logger.warning("analyze_language failed for #{language_hint}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp cache_enabled? do
    Process.whereis(Cache) != nil
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
  def check_language_rules(code, language_hint)
      when is_binary(code) and is_binary(language_hint) do
    case Native.check_language_rules(code, language_hint) do
      {:ok, violations} ->
        {:ok, violations}

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
    case Native.get_rca_metrics(code, language_hint) do
      {:ok, metrics} ->
        {:ok, metrics}

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
    case Native.extract_functions(code, language_hint) do
      {:ok, functions} ->
        {:ok, functions}

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
    case Native.extract_classes(code, language_hint) do
      {:ok, classes} ->
        {:ok, classes}

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
  def extract_imports_exports(code, language_hint)
      when is_binary(code) and is_binary(language_hint) do
    case Native.extract_imports_exports(code, language_hint) do
      {:ok, {imports, exports}} ->
        {:ok, {imports, exports}}

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
    case Native.detect_cross_language_patterns(files) do
      {:ok, patterns} ->
        {:ok, patterns}

      {:error, reason} ->
        Logger.warning("detect_cross_language_patterns failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ===========================
  # Language Support Queries
  # ===========================

  @doc """
  Get all supported languages (26 languages).

  ## Returns
  - List of language IDs
  """
  def supported_languages do
    Native.supported_languages()
  end

  @doc """
  Get RCA-supported languages (9 languages).

  ## Returns
  - List of language IDs with RCA metrics support
  """
  def rca_supported_languages do
    Native.rca_supported_languages()
  end

  @doc """
  Get AST-Grep supported languages (all 26 languages).

  ## Returns
  - List of language IDs with AST-Grep support
  """
  def ast_grep_supported_languages do
    Native.ast_grep_supported_languages()
  end

  @doc """
  Check if language has RCA support.

  ## Returns
  - `true` if RCA metrics available, `false` otherwise
  """
  def has_rca_support?(language_id) when is_binary(language_id) do
    Native.has_rca_support(language_id)
  end

  @doc """
  Check if language has AST-Grep support.

  ## Returns
  - `true` if AST-Grep available, `false` otherwise
  """
  def has_ast_grep_support?(language_id) when is_binary(language_id) do
    Native.has_ast_grep_support(language_id)
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

  Uses parallel processing with controlled concurrency to avoid overwhelming the host.

  ## Parameters
  - `codebase_id`: Codebase identifier
  - `opts`: Options
    - `:max_concurrency` - Maximum parallel tasks (default: 4, safe for analysis)
    - `:timeout` - Per-file timeout in ms (default: 30000ms = 30 seconds)

  ## Returns
  - List of `{file_path, analysis}` tuples

  ## Examples

      # Default (4 parallel tasks)
      CodeAnalyzer.analyze_codebase_from_db("my-project")

      # More aggressive (8 parallel tasks)
      CodeAnalyzer.analyze_codebase_from_db("my-project", max_concurrency: 8)

      # Conservative (2 parallel tasks, slower machine)
      CodeAnalyzer.analyze_codebase_from_db("my-project", max_concurrency: 2)
  """
  def analyze_codebase_from_db(codebase_id, opts \\ []) do
    import Ecto.Query

    # Conservative default
    max_concurrency = Keyword.get(opts, :max_concurrency, 4)
    # 30 seconds per file
    timeout = Keyword.get(opts, :timeout, 30_000)

    Repo.all(from c in CodeFile, where: c.codebase_id == ^codebase_id)
    |> Task.async_stream(
      fn file ->
        case analyze_language(file.content, file.language) do
          {:ok, analysis} ->
            {file.file_path, {:ok, analysis}}

          {:error, reason} ->
            {file.file_path, {:error, reason}}
        end
      end,
      max_concurrency: max_concurrency,
      timeout: timeout,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, "Task killed: #{inspect(reason)}"}
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

    Repo.all(
      from c in CodeFile,
        where: c.codebase_id == ^codebase_id and c.language in ^rca_languages
    )
    |> Enum.map(fn file ->
      case get_rca_metrics(file.content, file.language) do
        {:ok, metrics} ->
          {file.file_path, {:ok, metrics}}

        {:error, reason} ->
          {file.file_path, {:error, reason}}
      end
    end)
  end

  # ===========================
  # Result Storage (Persistence)
  # ===========================

  @doc """
  Store analysis result in the database.

  Persists analysis results for historical tracking, trend analysis,
  and quality regression detection.

  ## Parameters
  - `file_id`: CodeFile ID (binary_id or integer)
  - `analysis_result`: Analysis result map from analyze_language/2
  - `opts`: Options
    - `:analysis_type` - "full" (default), "rca_only", "ast_only"
    - `:duration_ms` - Analysis duration in milliseconds
    - `:cache_hit` - Whether result was from cache (default: false)

  ## Returns
  - `{:ok, code_analysis_result}` - Stored result
  - `{:error, changeset}` - Validation error

  ## Examples

      {:ok, analysis} = CodeAnalyzer.analyze_language(code, "elixir")
      {:ok, stored} = CodeAnalyzer.store_result(file_id, analysis, duration_ms: 125)

  """
  def store_result(file_id, analysis_result, opts \\ []) do
    alias Singularity.Schemas.CodeAnalysisResult

    analysis_type = Keyword.get(opts, :analysis_type, "full")
    duration_ms = Keyword.get(opts, :duration_ms)
    cache_hit = Keyword.get(opts, :cache_hit, false)

    # Extract metrics from analysis result
    attrs = %{
      code_file_id: file_id,
      language_id: Map.get(analysis_result, :language_id),
      analyzer_version: "1.0.0",
      analysis_type: analysis_type,
      complexity_score: Map.get(analysis_result, :complexity_score),
      quality_score: Map.get(analysis_result, :quality_score),
      maintainability_score: Map.get(analysis_result, :maintainability_score),
      analysis_data: analysis_result,
      analysis_duration_ms: duration_ms,
      cache_hit: cache_hit,
      has_errors: false
    }

    # Add RCA metrics if available
    attrs =
      if Map.has_key?(analysis_result, :rca_metrics) do
        rca = analysis_result.rca_metrics

        Map.merge(attrs, %{
          cyclomatic_complexity: Map.get(rca, :cyclomatic_complexity),
          cognitive_complexity: Map.get(rca, :cognitive_complexity),
          maintainability_index: Map.get(rca, :maintainability_index),
          source_lines_of_code: Map.get(rca, :source_lines_of_code),
          physical_lines_of_code: Map.get(rca, :physical_lines_of_code),
          logical_lines_of_code: Map.get(rca, :logical_lines_of_code),
          comment_lines_of_code: Map.get(rca, :comment_lines_of_code),
          halstead_difficulty: get_in(rca, [:halstead, :difficulty]),
          halstead_volume: get_in(rca, [:halstead, :volume]),
          halstead_effort: get_in(rca, [:halstead, :effort]),
          halstead_bugs: get_in(rca, [:halstead, :bugs])
        })
      else
        attrs
      end

    # Add AST extraction counts if available
    attrs =
      if Map.has_key?(analysis_result, :functions) do
        Map.put(attrs, :functions_count, length(analysis_result.functions))
      else
        attrs
      end

    attrs =
      if Map.has_key?(analysis_result, :classes) do
        Map.put(attrs, :classes_count, length(analysis_result.classes))
      else
        attrs
      end

    # Store full AST data
    attrs =
      attrs
      |> maybe_put(:functions, Map.get(analysis_result, :functions))
      |> maybe_put(:classes, Map.get(analysis_result, :classes))
      |> maybe_put(:imports_exports, Map.get(analysis_result, :imports_exports))
      |> maybe_put(:rule_violations, Map.get(analysis_result, :rule_violations))
      |> maybe_put(:patterns_detected, Map.get(analysis_result, :patterns_detected))

    %CodeAnalysisResult{}
    |> CodeAnalysisResult.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Store error result in the database.

  Used when analysis fails to track failure patterns.

  ## Parameters
  - `file_id`: CodeFile ID
  - `language_id`: Language identifier
  - `error`: Error reason or message
  - `opts`: Options (same as store_result/3)

  ## Returns
  - `{:ok, code_analysis_result}` - Stored error result
  - `{:error, changeset}` - Validation error
  """
  def store_error(file_id, language_id, error, opts \\ []) do
    alias Singularity.Schemas.CodeAnalysisResult

    analysis_type = Keyword.get(opts, :analysis_type, "full")
    duration_ms = Keyword.get(opts, :duration_ms)
    cache_hit = Keyword.get(opts, :cache_hit, false)

    error_message =
      case error do
        msg when is_binary(msg) -> msg
        atom when is_atom(atom) -> Atom.to_string(atom)
        _ -> inspect(error)
      end

    attrs = %{
      code_file_id: file_id,
      language_id: language_id,
      analyzer_version: "1.0.0",
      analysis_type: analysis_type,
      has_errors: true,
      error_message: error_message,
      error_details: %{error: error},
      analysis_duration_ms: duration_ms,
      cache_hit: cache_hit
    }

    %CodeAnalysisResult{}
    |> CodeAnalysisResult.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Analyze file from database and store result.

  Combines analyze_from_database/1 with store_result/3.

  ## Parameters
  - `file_id`: CodeFile ID
  - `opts`: Options for store_result/3

  ## Returns
  - `{:ok, %{analysis: analysis, stored: stored_result}}` - Success
  - `{:error, reason}` - Analysis or storage failed

  ## Examples

      {:ok, result} = CodeAnalyzer.analyze_and_store(file_id)
      IO.inspect(result.analysis.quality_score)
      IO.inspect(result.stored.id)

  """
  def analyze_and_store(file_id, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)

    case analyze_from_database(file_id) do
      {:ok, %{analysis: analysis, code_file: _file}} ->
        duration_ms = System.monotonic_time(:millisecond) - start_time

        opts = Keyword.merge(opts, duration_ms: duration_ms)

        case store_result(file_id, analysis, opts) do
          {:ok, stored} ->
            {:ok, %{analysis: analysis, stored: stored}}

          {:error, changeset} ->
            {:error, {:storage_failed, changeset}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Analyze entire codebase from database and store all results.

  ## Parameters
  - `codebase_id`: Codebase identifier
  - `opts`: Options
    - `:only_rca` - Only analyze RCA-supported languages (default: false)
    - `:skip_errors` - Don't store error results (default: false)

  ## Returns
  - List of `{file_path, result}` tuples where result is:
    - `{:ok, %{analysis: ..., stored: ...}}` - Success
    - `{:error, reason}` - Failure

  ## Examples

      results = CodeAnalyzer.analyze_and_store_codebase("my-project")
      success_count = Enum.count(results, fn {_, res} -> match?({:ok, _}, res) end)
      IO.puts("Analyzed and stored \#{success_count}/\#{length(results)} files")

  """
  def analyze_and_store_codebase(codebase_id, opts \\ []) do
    import Ecto.Query

    only_rca = Keyword.get(opts, :only_rca, false)
    skip_errors = Keyword.get(opts, :skip_errors, false)

    query =
      if only_rca do
        rca_languages = rca_supported_languages()

        from c in CodeFile,
          where: c.codebase_id == ^codebase_id and c.language in ^rca_languages
      else
        from c in CodeFile,
          where: c.codebase_id == ^codebase_id
      end

    Repo.all(query)
    |> Enum.map(fn file ->
      result =
        case analyze_and_store(file.id, opts) do
          {:ok, _} = success ->
            success

          {:error, reason} = error ->
            # Optionally store error
            unless skip_errors do
              store_error(file.id, file.language, reason, opts)
            end

            error
        end

      {file.file_path, result}
    end)
  end

  # ===========================
  # AI Calculation Functions (NEW)
  # ===========================

  @doc """
  Calculate AI-optimized complexity score for learning.

  ## Parameters
  - `code` - Source code string
  - `language` - Language identifier

  ## Returns
  - `{:ok, score}` - AI complexity score (0.0-10.0)
  - `{:error, reason}` - Calculation failed

  ## Examples

      iex> CodeAnalyzer.calculate_ai_complexity_score("def hello, do: :world", "elixir")
      {:ok, 1.2}

      iex> CodeAnalyzer.calculate_ai_complexity_score(complex_rust_code, "rust")
      {:ok, 7.8}
  """
  def calculate_ai_complexity_score(code, language)
      when is_binary(code) and is_binary(language) do
    Native.calculate_ai_complexity_score(code, language)
  end

  @doc """
  Extract comprehensive complexity features from code.

  ## Parameters
  - `code` - Source code string
  - `language` - Language identifier

  ## Returns
  - `{:ok, features}` - Complexity features map
  - `{:error, reason}` - Extraction failed

  ## Examples

      iex> CodeAnalyzer.extract_complexity_features(code, "elixir")
      {:ok, %{
        "total_lines" => 50,
        "function_count" => 8,
        "cyclomatic_complexity" => 3.2,
        "comment_ratio" => 0.15
      }}
  """
  def extract_complexity_features(code, language) when is_binary(code) and is_binary(language) do
    Native.extract_complexity_features(code, language)
  end

  @doc """
  Calculate code evolution trends for AI learning.

  ## Parameters
  - `before_metrics` - Previous code metrics
  - `after_metrics` - Current code metrics

  ## Returns
  - `{:ok, trends}` - Evolution trend analysis
  - `{:error, reason}` - Calculation failed

  ## Examples

      iex> CodeAnalyzer.calculate_evolution_trends(before_metrics, after_metrics)
      {:ok, %{
        "complexity_trend" => "Improving",
        "maintainability_trend" => "Stable",
        "quality_trend" => "Improving"
      }}
  """
  def calculate_evolution_trends(before_metrics, after_metrics)
      when is_map(before_metrics) and is_map(after_metrics) do
    Native.calculate_evolution_trends(before_metrics, after_metrics)
  end

  @doc """
  Predict AI-generated code quality.

  ## Parameters
  - `code_features` - Code features map
  - `language` - Language identifier
  - `model_name` - AI model name

  ## Returns
  - `{:ok, prediction}` - Quality prediction with confidence and risk factors
  - `{:error, reason}` - Prediction failed

  ## Examples

      iex> CodeAnalyzer.predict_ai_code_quality(features, "elixir", "claude-3.5-sonnet")
      {:ok, %{
        "predicted_quality" => 0.85,
        "confidence" => 0.92,
        "risk_factors" => [%{"factor_type" => "HighComplexity", "severity" => "Medium"}]
      }}
  """
  def predict_ai_code_quality(code_features, language, model_name)
      when is_map(code_features) and is_binary(language) and is_binary(model_name) do
    Native.predict_ai_code_quality(code_features, language, model_name)
  end

  @doc """
  Calculate pattern effectiveness for AI learning.

  ## Parameters
  - `pattern` - Code pattern string
  - `metrics` - Complexity metrics

  ## Returns
  - `{:ok, effectiveness}` - Pattern effectiveness score (0.0-1.0)
  - `{:error, reason}` - Calculation failed

  ## Examples

      iex> CodeAnalyzer.calculate_pattern_effectiveness("defmodule", metrics)
      {:ok, 0.75}
  """
  def calculate_pattern_effectiveness(pattern, metrics)
      when is_binary(pattern) and is_map(metrics) do
    Native.calculate_pattern_effectiveness(pattern, metrics)
  end

  @doc """
  Calculate supervision complexity for BEAM languages.

  ## Parameters
  - `modules` - List of module names

  ## Returns
  - `{:ok, complexity}` - Supervision complexity score
  - `{:error, reason}` - Calculation failed

  ## Examples

      iex> CodeAnalyzer.calculate_supervision_complexity(["MyApp.Supervisor", "MyApp.Worker"])
      {:ok, 2.1}
  """
  def calculate_supervision_complexity(modules) when is_list(modules) do
    Native.calculate_supervision_complexity(modules)
  end

  @doc """
  Calculate actor complexity for BEAM languages.

  ## Parameters
  - `functions` - List of function names

  ## Returns
  - `{:ok, complexity}` - Actor complexity score
  - `{:error, reason}` - Calculation failed

  ## Examples

      iex> CodeAnalyzer.calculate_actor_complexity(["spawn", "send", "receive"])
      {:ok, 1.5}
  """
  def calculate_actor_complexity(functions) when is_list(functions) do
    Native.calculate_actor_complexity(functions)
  end

  # Helper: Put value in map only if not nil
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
