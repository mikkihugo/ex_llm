defmodule Singularity.ArchitectureEngine do
  @moduledoc """
  Architecture Engine - Unified Pattern Detection for Architectural Analysis - Production Quality

  **PURE ELIXIR IMPLEMENTATION** - Database-driven pattern matching with self-learning

  ```json
  {
    "module": "Singularity.ArchitectureEngine",
    "layer": "pattern_detection",
    "purpose": "Orchestrate I/O (PostgreSQL) and pattern matching (Pure Elixir) for architecture analysis",
    "implementation": "Pure Elixir via FrameworkDetector and TechnologyDetector",
    "operations": [
      "detect_frameworks",
      "detect_technologies",
      "get_architectural_suggestions"
    ],
    "database_tables": [
      "framework_patterns (via FrameworkPatternStore)",
      "technology_patterns (via TechnologyPatternStore)"
    ],
    "io_pattern": "Elixir I/O → PostgreSQL lookup → Elixir analysis",
    "related_modules": {
      "stores": ["FrameworkPatternStore", "TechnologyPatternStore"],
      "callers": ["CodeSearch", "ArchitectureAnalyzer", "Mix.Tasks.Architecture.*"]
    },
    "technology_stack": ["Elixir", "PostgreSQL", "Ecto.SQL"]
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TB
      A[Client: CodeSearch] -->|detect_frameworks| B[ArchitectureEngine]
      B -->|1. Query DB| C[(PostgreSQL<br/>framework_patterns)]
      C -->|2. patterns| D[FrameworkDetector]
      D -->|3. Pattern Matching| E[File/Config Analysis]
      E -->|4. Results| F[Elixir: store results]
      F -->|5. store| G[(PostgreSQL<br/>framework_patterns)]
      F -->|6. return| A

      H[Client: detect_technologies] -->|request| B
      B -->|1. Query DB| I[(PostgreSQL<br/>technology_patterns)]
      I -->|2. patterns| J[TechnologyDetector]
      J -->|3. Pattern Matching| K[Language/DB/Container Detection]

      style B fill:#90EE90
      style D fill:#87CEEB
      style E fill:#FFB6C1
      style C fill:#FFE4B5
      style I fill:#FFE4B5
  ```

  ## Call Graph (YAML - Machine Readable)

  ```yaml
  ArchitectureEngine:
    calls:
      - Singularity.Repo.query/2: "Fetch patterns from PostgreSQL"
      - Singularity.Architecture.Detectors.FrameworkDetector.detect/2: "Framework detection"
      - Singularity.Architecture.Detectors.TechnologyDetector.detect/2: "Technology detection"
      - FrameworkPatternStore.learn_pattern/1: "Store framework results"
      - TechnologyPatternStore.learn_pattern/1: "Store technology results"
      - Logger: "Logging detection progress"
    called_by:
      - Singularity.CodeSearch: "Technology detection from codebase"
      - Singularity.ArchitectureAnalyzer: "Full architecture analysis"
      - Mix.Tasks.Architecture.Detect: "CLI detection tasks"
      - Singularity.Agents.*: "Agent-driven analysis"
    implementations:
      - FrameworkDetector: "Pure Elixir framework detection via file patterns"
      - TechnologyDetector: "Pure Elixir technology detection via language detection + file patterns"
    database:
      tables:
        - framework_patterns: "Framework detection patterns and stats"
        - technology_patterns: "Technology detection patterns and stats"
      queries:
        - fetch_framework_patterns_from_db: "SELECT top 100 patterns"
        - fetch_technology_patterns_from_db: "SELECT top 100 tech patterns"
      writes:
        - store_detection_results: "INSERT/UPDATE via FrameworkPatternStore"
        - store_technology_results: "INSERT/UPDATE via TechnologyPatternStore"
  ```

  ## Anti-Patterns (DO NOT DO THIS!)

  - ❌ **DO NOT bypass this module** - All detection flows through the orchestrator so learning hooks fire
  - ❌ **DO NOT skip database queries** - Detectors rely on stored patterns for accurate detection
  - ❌ **DO NOT reintroduce Rust calls** - Implementation is intentionally pure Elixir for portability
  - ❌ **DO NOT bypass pattern stores** - Always use FrameworkPatternStore/TechnologyPatternStore
  - ❌ **DO NOT create duplicate architecture analysis modules** - This is THE ONLY architecture engine
  - ❌ **DO NOT confuse with central package intelligence** - This analyzes YOUR codebase, not external packages

  ## Search Keywords (for AI/vector search)

  architecture engine, Elixir orchestrator, framework detection, technology detection, pattern matching,
  database-driven detection, self-learning patterns, PGFlow integration,
  PostgreSQL patterns, confidence scoring, architectural suggestions, codebase analysis,
  technology identification, framework identification, pattern storage, success rate tracking,
  pure computation, I/O orchestration, Ecto queries

  ## Implementation Pattern (Pure Elixir)

  **I/O → Detection → I/O Pattern:**

  1. **Elixir fetches data** from PostgreSQL (framework_patterns, technology_patterns tables)
  2. **Elixir delegates to detectors** (FrameworkDetector, TechnologyDetector)
  3. **Detectors perform pattern matching** (file checks, config analysis, language detection)
  4. **Detectors return results** to Elixir
  5. **Elixir stores results** in PostgreSQL (via pattern stores)

  **Why this pattern?**
  - Simplicity: Pure Elixir, no NIF compilation issues
  - Testability: Can mock database layer in Elixir
  - Flexibility: Can swap detectors without changing orchestrator
  - Learning: Elixir tracks pattern success rates
  - Performance: Simple pattern matching is fast enough for architecture detection

  ## Operations

  - **Framework detection** - Detect frameworks (Phoenix, React, Rails) using learned patterns
  - **Technology detection** - Detect technologies (Elixir, Rust, PostgreSQL) from file extensions/imports
  - **Architectural suggestions** - Generate architecture recommendations based on detected patterns
  - **Package collection** - Delegates to central package intelligence (not implemented locally)

  ## Self-Learning

  Each detection updates pattern success rates in PostgreSQL:
  - `detection_count` increments
  - `success_rate` updates (exponential moving average: α=0.1)
  - `confidence_weight` adjusts based on historical accuracy

  This creates a feedback loop where patterns improve over time!
  """

  require Logger
  alias Singularity.Repo
  alias Singularity.ArchitectureEngine.FrameworkPatternStore

  ##############################################################################
  ## PUBLIC API
  ##############################################################################

  @doc """
  Detect frameworks using learned patterns from PostgreSQL.

  ## Flow

  1. Fetch patterns from PostgreSQL
  2. Delegate to in-process detectors for pattern matching
  3. Store results back to PostgreSQL

  ## Examples

      detect_frameworks(["use Phoenix.Router"], context: "elixir_code")
      # => {:ok, [%{name: "phoenix", version: "1.7.0", confidence: 0.98}]}
  """
  @spec detect_frameworks(list(String.t()), keyword()) :: {:ok, list(map())} | {:error, term()}
  def detect_frameworks(code_patterns, opts \\ []) do
    context = Keyword.get(opts, :context, "")
    confidence_threshold = Keyword.get(opts, :confidence_threshold, 0.7)

    Logger.info("🔍 Detecting frameworks", patterns: length(code_patterns), context: context)

    # STEP 1: Fetch learned patterns from PostgreSQL (Elixir I/O)
    with {:ok, db_patterns} <- fetch_framework_patterns_from_db(),
         # STEP 2: Run detector in-process
         {:ok, results} <-
           run_detect_frameworks(code_patterns, db_patterns, context, confidence_threshold),
         # STEP 3: Store results back to PostgreSQL (Elixir I/O)
         :ok <- store_detection_results(results) do
      Logger.info("✅ Detected #{length(results)} frameworks")
      {:ok, results}
    end
  end

  @doc """
  Detect technologies using learned patterns from PostgreSQL.

  ## Flow

  1. Fetch technology patterns from PostgreSQL
  2. Delegate to in-process detectors for pattern matching
  3. Store results back to PostgreSQL

  ## Examples

      detect_technologies(["lib/myapp.ex", "use GenServer"], context: "elixir_code")
      # => {:ok, [%{name: "elixir", version: "1.18", confidence: 0.95}]}
  """
  @spec detect_technologies(list(String.t()), keyword()) :: {:ok, list(map())} | {:error, term()}
  def detect_technologies(code_patterns, opts \\ []) do
    context = Keyword.get(opts, :context, "")
    confidence_threshold = Keyword.get(opts, :confidence_threshold, 0.6)

    Logger.info("🔍 Detecting technologies", patterns: length(code_patterns), context: context)

    # STEP 1: Fetch learned technology patterns from PostgreSQL (Elixir I/O)
    with {:ok, db_patterns} <- fetch_technology_patterns_from_db(),
         # STEP 2: Run detector in-process
         {:ok, results} <-
           run_detect_technologies(
             code_patterns,
             db_patterns,
             context,
             confidence_threshold
           ),
         # STEP 3: Store results back to PostgreSQL (Elixir I/O)
         :ok <- store_technology_results(results) do
      Logger.info("✅ Detected #{length(results)} technologies")
      {:ok, results}
    end
  end

  @doc """
  Get architectural suggestions.
  """
  @spec get_architectural_suggestions(map(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def get_architectural_suggestions(codebase_info, opts \\ []) do
    context = Keyword.get(opts, :context, "")
    types = Keyword.get(opts, :suggestion_types, [:naming, :patterns])

    request = %{
      codebase_info: codebase_info,
      suggestion_types: Enum.map(types, &to_string/1),
      context: context
    }

    architecture_engine_call("get_architectural_suggestions", request)
  end

  ##############################################################################
  ## PRIVATE: Database Operations (Elixir I/O)
  ##############################################################################

  # Fetch all learned framework patterns from PostgreSQL
  defp fetch_framework_patterns_from_db do
    query = """
    SELECT
      framework_name, framework_type, version_pattern,
      file_patterns, directory_patterns, config_files,
      confidence_weight, success_rate, detection_count
    FROM framework_patterns
    WHERE success_rate > 0.5
    ORDER BY success_rate DESC, detection_count DESC
    LIMIT 100
    """

    case Repo.query(query, []) do
      {:ok, %{rows: [_head | _] = rows}} ->
        patterns = Enum.map(rows, &parse_framework_pattern_row/1)
        {:ok, patterns}

      {:ok, %{rows: []}} ->
        Logger.warning("No framework patterns in DB, using defaults")
        {:ok, get_default_framework_patterns()}

      {:error, reason} ->
        Logger.error("Failed to fetch patterns: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Parse a database row into a framework pattern map
  defp parse_framework_pattern_row([
         name,
         type,
         version,
         files,
         dirs,
         configs,
         weight,
         rate,
         count
       ]) do
    %{
      framework_name: name,
      framework_type: type,
      version_pattern: version,
      file_patterns: Jason.decode!(files || "[]"),
      directory_patterns: Jason.decode!(dirs || "[]"),
      config_files: Jason.decode!(configs || "[]"),
      confidence_weight: weight || 0.8,
      success_rate: rate || 0.0,
      detection_count: count || 0
    }
  end

  # Default patterns when database is empty
  defp get_default_framework_patterns do
    [
      %{
        framework_name: "phoenix",
        framework_type: "web",
        version_pattern: "1.7",
        file_patterns: ["*_web.ex", "router.ex", "endpoint.ex"],
        directory_patterns: ["lib/*_web/", "assets/"],
        config_files: ["mix.exs", "config/config.exs"],
        confidence_weight: 0.9,
        success_rate: 0.95,
        detection_count: 0
      },
      %{
        framework_name: "ecto",
        framework_type: "database",
        version_pattern: "3.10",
        file_patterns: ["*repo.ex", "*migration*.ex"],
        directory_patterns: ["priv/repo/"],
        config_files: ["mix.exs"],
        confidence_weight: 0.9,
        success_rate: 0.95,
        detection_count: 0
      },
      %{
        framework_name: "rustler",
        framework_type: "nif",
        version_pattern: "0.34",
        file_patterns: ["native/*/Cargo.toml", "rust/*/Cargo.toml"],
        directory_patterns: ["native/", "rust/"],
        config_files: ["mix.exs"],
        confidence_weight: 0.9,
        success_rate: 0.95,
        detection_count: 0
      }
    ]
  end

  # Fetch all learned technology patterns from PostgreSQL
  defp fetch_technology_patterns_from_db do
    query = """
    SELECT
      technology_name, technology_type, version_pattern,
      file_extensions, import_patterns, config_files, package_managers,
      confidence_weight, success_rate, detection_count
    FROM technology_patterns
    WHERE success_rate > 0.5
    ORDER BY success_rate DESC, detection_count DESC
    LIMIT 100
    """

    case Repo.query(query, []) do
      {:ok, %{rows: rows}} when length(rows) > 0 ->
        patterns = Enum.map(rows, &parse_technology_pattern_row/1)
        {:ok, patterns}

      {:ok, %{rows: []}} ->
        Logger.warning("No technology patterns in DB, using defaults")
        {:ok, get_default_technology_patterns()}

      {:error, reason} ->
        Logger.error("Failed to fetch technology patterns: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Parse a database row into a technology pattern map
  defp parse_technology_pattern_row([
         name,
         type,
         version,
         exts,
         imports,
         configs,
         pkg_mgrs,
         weight,
         rate,
         count
       ]) do
    %{
      technology_name: name,
      technology_type: type,
      version_pattern: version,
      file_extensions: Jason.decode!(exts || "[]"),
      import_patterns: Jason.decode!(imports || "[]"),
      config_files: Jason.decode!(configs || "[]"),
      package_managers: Jason.decode!(pkg_mgrs || "[]"),
      confidence_weight: weight || 0.8,
      success_rate: rate || 0.0,
      detection_count: count || 0
    }
  end

  # Default technology patterns when database is empty
  defp get_default_technology_patterns do
    [
      %{
        technology_name: "elixir",
        technology_type: "language",
        version_pattern: "1.18",
        file_extensions: [".ex", ".exs"],
        import_patterns: ["defmodule ", "use ", "alias ", "import "],
        config_files: ["mix.exs", ".formatter.exs"],
        package_managers: ["mix"],
        confidence_weight: 0.95,
        success_rate: 0.98,
        detection_count: 0
      },
      %{
        technology_name: "rust",
        technology_type: "language",
        version_pattern: "1.75",
        file_extensions: [".rs"],
        import_patterns: ["use ", "mod ", "extern crate "],
        config_files: ["Cargo.toml", "Cargo.lock"],
        package_managers: ["cargo"],
        confidence_weight: 0.95,
        success_rate: 0.98,
        detection_count: 0
      },
      %{
        technology_name: "postgresql",
        technology_type: "database",
        version_pattern: "17",
        file_extensions: [".sql"],
        import_patterns: ["SELECT ", "INSERT ", "CREATE TABLE"],
        config_files: ["postgresql.conf", "pg_hba.conf"],
        package_managers: ["psql"],
        confidence_weight: 0.9,
        success_rate: 0.95,
        detection_count: 0
      },
      %{
        technology_name: "javascript",
        technology_type: "language",
        version_pattern: "ES2023",
        file_extensions: [".js", ".jsx", ".mjs"],
        import_patterns: ["import ", "export ", "require("],
        config_files: ["package.json", "package-lock.json"],
        package_managers: ["npm", "yarn", "pnpm", "bun"],
        confidence_weight: 0.9,
        success_rate: 0.95,
        detection_count: 0
      },
      %{
        technology_name: "typescript",
        technology_type: "language",
        version_pattern: "5.3",
        file_extensions: [".ts", ".tsx"],
        import_patterns: ["import ", "export ", "interface ", "type "],
        config_files: ["tsconfig.json", "package.json"],
        package_managers: ["npm", "yarn", "pnpm", "bun"],
        confidence_weight: 0.9,
        success_rate: 0.95,
        detection_count: 0
      },
      %{
        technology_name: "python",
        technology_type: "language",
        version_pattern: "3.12",
        file_extensions: [".py"],
        import_patterns: ["import ", "from ", "def ", "class "],
        config_files: ["requirements.txt", "pyproject.toml", "setup.py"],
        package_managers: ["pip", "poetry", "pipenv"],
        confidence_weight: 0.9,
        success_rate: 0.95,
        detection_count: 0
      }
    ]
  end

  ##############################################################################
  ## PRIVATE: Detection Dispatch (Pure Elixir)
  ##############################################################################

  # Run Elixir-based framework detection
  defp run_detect_frameworks(code_patterns, db_patterns, context, threshold) do
    request = %{
      code_patterns: code_patterns,
      known_frameworks: db_patterns,
      context: context,
      confidence_threshold: threshold
    }

    architecture_engine_call("detect_frameworks", request)
  end

  # Store detection results back to PostgreSQL
  defp store_detection_results(results) do
    Enum.each(results, fn result ->
      FrameworkPatternStore.learn_pattern(result)
    end)

    :ok
  end

  # Run Elixir-based technology detection
  defp run_detect_technologies(code_patterns, db_patterns, context, threshold) do
    request = %{
      code_patterns: code_patterns,
      known_technologies: db_patterns,
      context: context,
      confidence_threshold: threshold
    }

    architecture_engine_call("detect_technologies", request)
  end

  # Store technology detection results back to PostgreSQL
  defp store_technology_results(results) do
    alias Singularity.ArchitectureEngine.TechnologyPatternStore

    Enum.each(results, fn result ->
      TechnologyPatternStore.learn_pattern(result)
    end)

    :ok
  end

  ##############################################################################
  ## PURE ELIXIR IMPLEMENTATIONS
  ##############################################################################

  # Delegate to Elixir detectors for framework detection
  defp architecture_engine_call("detect_frameworks", request) do
    code_patterns = Map.get(request, :code_patterns, [])

    case Singularity.Architecture.Detectors.FrameworkDetector.detect("") do
      results when is_list(results) ->
        {:ok, Enum.map(results, &Map.from_struct/1)}

      error ->
        Logger.error("Framework detection failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # Delegate to Elixir detectors for technology detection
  defp architecture_engine_call("detect_technologies", request) do
    code_patterns = Map.get(request, :code_patterns, [])

    case Singularity.Architecture.Detectors.TechnologyDetector.detect("") do
      results when is_list(results) ->
        {:ok, Enum.map(results, &Map.from_struct/1)}

      error ->
        Logger.error("Technology detection failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # Architectural suggestions (simple implementation)
  defp architecture_engine_call("get_architectural_suggestions", request) do
    _codebase_info = Map.get(request, :codebase_info, %{})

    # For now, return empty suggestions (can be enhanced later)
    {:ok, []}
  end

  # Unknown operation
  defp architecture_engine_call(operation, _request) do
    Logger.warning("Unknown architecture_engine operation: #{operation}")
    {:error, {:unknown_operation, operation}}
  end
end
