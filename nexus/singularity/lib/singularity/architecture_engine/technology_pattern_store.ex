defmodule Singularity.ArchitectureEngine.TechnologyPatternStore do
  @moduledoc """
  Self-learning technology pattern storage in PostgreSQL - Production Quality

  ```json
  {
    "module": "Singularity.ArchitectureEngine.TechnologyPatternStore",
    "layer": "infrastructure",
    "persistence": "PostgreSQL technology_patterns table",
    "purpose": "Store and query technology detection patterns with self-learning",
    "database_schema": "technology_patterns (17 columns with GIN indexes)",
    "detection_types": ["language", "database", "tool", "library", "package_manager"],
    "pattern_signals": ["file_extensions", "import_patterns", "config_files", "package_managers"],
    "self_learning": "Exponential moving average on success_rate (α=0.1)",
    "related_modules": {
      "queries_db": "Singularity.Repo",
      "rust_nif": "architecture_engine NIF (detect_technologies)",
      "embeddings": "Singularity.EmbeddingGenerator"
    },
    "pgmq_subjects": [],
    "technology_stack": ["Elixir", "PostgreSQL", "pgvector", "Ecto.SQL"]
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TB
      A[Rust NIF<br/>detect_technologies] -->|detection result| B[TechnologyPatternStore]
      B -->|INSERT/UPDATE| C[(PostgreSQL<br/>technology_patterns)]
      B -->|query patterns| C
      C -->|patterns| D[Rust NIF<br/>pattern matching]

      E[CodeSearch] -->|discover patterns| B
      F[EmbeddingGenerator] -->|embed query| G[semantic_search_similar]
      G -->|pgvector search| C

      H[Export/Backup] -->|export_to_json| B

      style B fill:#90EE90
      style C fill:#ADD8E6
      style D fill:#FFB6C1
  ```

  ## Call Graph (YAML - Machine Readable)

  ```yaml
  TechnologyPatternStore:
    calls:
      - Singularity.Repo.query/2: "All DB queries"
      - Singularity.EmbeddingGenerator.embed/1: "For semantic search"
      - Logger.info/debug/error: "Logging"
    called_by:
      - Singularity.ArchitectureEngine.detect_technologies/2: "Fetch patterns from DB"
      - Singularity.CodeSearch: "Discover new patterns from codebase"
      - Mix.Tasks.Architecture.Export: "Backup patterns"
    database:
      table: "technology_patterns"
      indexes:
        - "technology_name"
        - "technology_type"
        - "unique: [technology_name, technology_type]"
        - "GIN: file_extensions, import_patterns, package_managers"
        - "pgvector: pattern_embedding"
    pgmq: null
  ```

  ## Anti-Patterns (DO NOT DO THIS!)

  - ❌ **DO NOT pull external dependency source code into local DB** - Use central package intelligence
  - ❌ **DO NOT create duplicate pattern storage** - This is THE ONLY technology pattern store
  - ❌ **DO NOT bypass Rust NIF for detection** - All detection goes through architecture_engine NIF
  - ❌ **DO NOT confuse with FrameworkPatternStore** - Separate tables, separate concerns
  - ❌ **DO NOT modify success_rate directly** - Always use `update_confidence/2` for EMA

  ## Search Keywords (for AI/vector search)

  technology detection, pattern storage, self-learning, PostgreSQL patterns, framework detection,
  language detection, database detection, tool detection, file extension matching, import pattern matching,
  confidence scoring, success rate tracking, exponential moving average, pattern discovery,
  semantic pattern search, pgvector similarity, technology_patterns table, Rust NIF integration,
  codebase analysis, technology identification

  ## Technology vs Framework

  **Technologies** = Languages, databases, tools, libraries (Elixir, Rust, PostgreSQL, npm)
  **Frameworks** = Architectural patterns (Phoenix, React, Rails)

  This module handles technology detection patterns.

  ## Self-Learning Flow

  1. Rust detector finds technology
  2. Store detection pattern in PG
  3. Track success/failure
  4. Update confidence weights (EMA: new_rate = old_rate * 0.9 + result * 0.1)
  5. Discover new patterns from repos

  ## Example

      # Learn from successful detection
      result = %{
        technology_name: "elixir",
        technology_type: "language",
        file_extensions: [".ex", ".exs"],
        import_patterns: ["defmodule ", "use "],
        confidence: 0.95
      }
      TechnologyPatternStore.learn_pattern(result)

      # Update success rate
      TechnologyPatternStore.update_confidence("elixir", true)

      # Get pattern for detection
      {:ok, pattern} = TechnologyPatternStore.get_pattern("elixir")
  """

  require Logger
  alias Singularity.Repo

  @doc """
  Get technology pattern by name
  """
  def get_pattern(technology_name) do
    query = """
    SELECT
      technology_name, technology_type, version_pattern,
      file_extensions, import_patterns, config_files, package_managers,
      file_patterns, directory_patterns,
      build_command, dev_command, install_command, test_command,
      output_directory, confidence_weight,
      detection_count, success_rate
    FROM technology_patterns
    WHERE technology_name = $1
    ORDER BY success_rate DESC, detection_count DESC
    LIMIT 1
    """

    case Repo.query(query, [technology_name]) do
      {:ok, %{rows: [row | _]}} ->
        {:ok, build_pattern_struct(row)}

      {:ok, %{rows: []}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Learn new pattern from detection result

  ## Examples

      result = %{
        name: "elixir",
        confidence: 0.95,
        evidence: ["file extension: .ex", "import pattern: defmodule "]
      }
      TechnologyPatternStore.learn_pattern(result)
  """
  def learn_pattern(detection_result) do
    # Extract patterns from evidence
    {file_exts, import_pats, config_files, pkg_mgrs} =
      extract_patterns_from_evidence(
        detection_result[:evidence] || detection_result.evidence || []
      )

    query = """
    INSERT INTO technology_patterns (
      technology_name, technology_type, version_pattern,
      file_extensions, import_patterns, config_files, package_managers,
      confidence_weight,
      detection_count, last_detected_at,
      created_at, updated_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 1, NOW(), NOW(), NOW())
    ON CONFLICT (technology_name, technology_type) DO UPDATE SET
      file_extensions = technology_patterns.file_extensions || EXCLUDED.file_extensions,
      import_patterns = technology_patterns.import_patterns || EXCLUDED.import_patterns,
      config_files = technology_patterns.config_files || EXCLUDED.config_files,
      package_managers = technology_patterns.package_managers || EXCLUDED.package_managers,
      detection_count = technology_patterns.detection_count + 1,
      last_detected_at = NOW(),
      updated_at = NOW()
    RETURNING id
    """

    # Get technology type from result or default to "unknown"
    tech_type =
      detection_result[:technology_type] || detection_result[:type] ||
        infer_technology_type(detection_result)

    version = detection_result[:version] || "unknown"
    confidence = detection_result[:confidence] || 0.8

    params = [
      detection_result[:name] || detection_result.name,
      tech_type,
      version,
      file_exts,
      import_pats,
      config_files,
      pkg_mgrs,
      confidence
    ]

    case Repo.query(query, params) do
      {:ok, %{rows: [[id]]}} ->
        Logger.info(
          "Learned technology pattern for #{detection_result[:name] || detection_result.name} (id: #{id})"
        )

        {:ok, id}

      {:error, reason} ->
        Logger.error("Failed to learn technology pattern: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Update pattern confidence based on detection success
  """
  def update_confidence(technology_name, success?) do
    # Exponential moving average of success rate
    query = """
    UPDATE technology_patterns
    SET
      success_rate = success_rate * 0.9 + $2 * 0.1,
      updated_at = NOW()
    WHERE technology_name = $1
    RETURNING success_rate
    """

    success_value = if success?, do: 1.0, else: 0.0

    case Repo.query(query, [technology_name, success_value]) do
      {:ok, %{rows: [[new_rate]]}} ->
        Logger.debug("Updated #{technology_name} success_rate: #{Float.round(new_rate, 3)}")
        {:ok, new_rate}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get all patterns for a technology type

  ## Examples

      {:ok, languages} = TechnologyPatternStore.get_patterns_by_type("language")
      # => [%{technology_name: "elixir", ...}, %{technology_name: "rust", ...}]

      {:ok, databases} = TechnologyPatternStore.get_patterns_by_type("database")
      # => [%{technology_name: "postgresql", ...}]
  """
  def get_patterns_by_type(technology_type) do
    query = """
    SELECT
      technology_name, technology_type, version_pattern,
      file_extensions, import_patterns, config_files, package_managers,
      confidence_weight, success_rate, detection_count
    FROM technology_patterns
    WHERE technology_type = $1
    ORDER BY success_rate DESC, detection_count DESC
    """

    case Repo.query(query, [technology_type]) do
      {:ok, %{rows: rows}} ->
        patterns = Enum.map(rows, &build_simple_pattern_struct/1)
        {:ok, patterns}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Search patterns by semantic similarity
  """
  def search_similar_patterns(query_text, top_k \\ 5) do
    # Embed query
    {:ok, embedding} = Singularity.EmbeddingGenerator.embed(query_text)

    sql = """
    SELECT
      technology_name, technology_type,
      file_extensions, import_patterns, config_files,
      1 - (pattern_embedding <=> $1::vector) AS similarity
    FROM technology_patterns
    WHERE pattern_embedding IS NOT NULL
    ORDER BY pattern_embedding <=> $1::vector
    LIMIT $2
    """

    case Repo.query(sql, [embedding, top_k]) do
      {:ok, %{rows: rows}} ->
        patterns =
          Enum.map(rows, fn row ->
            [name, type, exts, imports, configs, sim] = row

            %{
              technology_name: name,
              technology_type: type,
              file_extensions: exts,
              import_patterns: imports,
              config_files: configs,
              similarity: sim
            }
          end)

        {:ok, patterns}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Discover new technologies from detected files

  Analyzes repos to find new technology patterns not in DB
  """
  def discover_new_patterns(repo_path) do
    # Find unique file extensions
    query = """
    SELECT DISTINCT
      SUBSTRING(file_path FROM '\\.([^.]+)$') AS extension,
      COUNT(*) AS count
    FROM codebase_chunks
    WHERE repo_name = $1
    GROUP BY extension
    HAVING COUNT(*) > 5
    ORDER BY count DESC
    LIMIT 20
    """

    case Repo.query(query, [repo_path]) do
      {:ok, %{rows: rows}} ->
        # Analyze patterns
        patterns =
          Enum.map(rows, fn [ext, count] ->
            %{extension: ext, file_count: count}
          end)

        # Check if we have known patterns for these extensions
        unknown =
          Enum.reject(patterns, fn p ->
            known_extension?(p.extension)
          end)

        if unknown != [] do
          Logger.info("Discovered #{length(unknown)} potential new technology patterns")
          {:ok, unknown}
        else
          {:ok, []}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Export patterns to JSON

  Useful for backing up patterns or sharing between environments
  """
  def export_to_json(output_path) do
    query = """
    SELECT
      technology_name, technology_type, version_pattern,
      file_extensions, import_patterns, config_files, package_managers,
      confidence_weight, success_rate, detection_count
    FROM technology_patterns
    ORDER BY technology_type, technology_name
    """

    case Repo.query(query, []) do
      {:ok, %{rows: rows}} ->
        patterns =
          Enum.map(rows, fn row ->
            [name, type, version, exts, imports, configs, pkg_mgrs, conf, success, count] = row

            %{
              technology_name: name,
              technology_type: type,
              version_pattern: version,
              file_extensions: exts,
              import_patterns: imports,
              config_files: configs,
              package_managers: pkg_mgrs,
              confidence_weight: conf,
              success_rate: success,
              detection_count: count
            }
          end)

        json = Jason.encode!(patterns, pretty: true)
        File.write!(output_path, json)

        Logger.info("Exported #{length(patterns)} technology patterns to #{output_path}")
        {:ok, length(patterns)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get statistics for all technologies
  """
  def get_stats do
    query = """
    SELECT
      technology_type,
      COUNT(*) as pattern_count,
      AVG(success_rate) as avg_success_rate,
      SUM(detection_count) as total_detections
    FROM technology_patterns
    GROUP BY technology_type
    ORDER BY total_detections DESC
    """

    case Repo.query(query, []) do
      {:ok, %{rows: rows}} ->
        stats =
          Enum.map(rows, fn [type, count, avg_success, total_detections] ->
            %{
              technology_type: type,
              pattern_count: count,
              avg_success_rate: Float.round(avg_success, 3),
              total_detections: total_detections
            }
          end)

        {:ok, stats}

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Private Functions

  defp build_pattern_struct(row) do
    [
      name,
      type,
      version,
      exts,
      imports,
      configs,
      pkg_mgrs,
      files,
      dirs,
      build,
      dev,
      install,
      test,
      output,
      conf,
      count,
      success
    ] = row

    %{
      technology_name: name,
      technology_type: type,
      version_pattern: version,
      file_extensions: exts || [],
      import_patterns: imports || [],
      config_files: configs || [],
      package_managers: pkg_mgrs || [],
      file_patterns: files || [],
      directory_patterns: dirs || [],
      build_command: build,
      dev_command: dev,
      install_command: install,
      test_command: test,
      output_directory: output,
      confidence_weight: conf,
      detection_count: count,
      success_rate: success
    }
  end

  defp build_simple_pattern_struct(row) do
    [name, type, version, exts, imports, configs, pkg_mgrs, conf, success, count] = row

    %{
      technology_name: name,
      technology_type: type,
      version_pattern: version,
      file_extensions: exts || [],
      import_patterns: imports || [],
      config_files: configs || [],
      package_managers: pkg_mgrs || [],
      confidence_weight: conf,
      success_rate: success,
      detection_count: count
    }
  end

  # Extract patterns from evidence array
  # Evidence format: ["file extension: .ex", "import pattern: defmodule ", ...]
  defp extract_patterns_from_evidence(evidence) when is_list(evidence) do
    file_exts =
      evidence
      |> Enum.filter(&String.contains?(&1, "file extension:"))
      |> Enum.map(&String.replace(&1, "file extension:", ""))
      |> Enum.map(&String.trim/1)

    import_pats =
      evidence
      |> Enum.filter(&String.contains?(&1, "import pattern:"))
      |> Enum.map(&String.replace(&1, "import pattern:", ""))
      |> Enum.map(&String.trim/1)

    config_files =
      evidence
      |> Enum.filter(&String.contains?(&1, "config file:"))
      |> Enum.map(&String.replace(&1, "config file:", ""))
      |> Enum.map(&String.trim/1)

    pkg_mgrs =
      evidence
      |> Enum.filter(&String.contains?(&1, "package manager:"))
      |> Enum.map(&String.replace(&1, "package manager:", ""))
      |> Enum.map(&String.trim/1)

    {file_exts, import_pats, config_files, pkg_mgrs}
  end

  defp extract_patterns_from_evidence(_), do: {[], [], [], []}

  # Infer technology type from detection result
  defp infer_technology_type(result) do
    name = (result[:name] || result.name || "") |> String.downcase()

    cond do
      name in [
        "elixir",
        "rust",
        "python",
        "javascript",
        "typescript",
        "go",
        "java",
        "ruby",
        "c",
        "cpp"
      ] ->
        "language"

      name in ["postgresql", "mysql", "redis", "mongodb", "elasticsearch"] ->
        "database"

      name in ["docker", "kubernetes", "terraform", "ansible"] ->
        "tool"

      name in ["npm", "yarn", "cargo", "pip", "mix"] ->
        "package_manager"

      true ->
        "unknown"
    end
  end

  defp known_extension?(ext) do
    query = """
    SELECT 1 FROM technology_patterns
    WHERE $1 = ANY(file_extensions)
    LIMIT 1
    """

    case Repo.query(query, [".#{ext}"]) do
      {:ok, %{rows: []}} -> false
      {:ok, %{rows: _}} -> true
      _ -> false
    end
  end
end
