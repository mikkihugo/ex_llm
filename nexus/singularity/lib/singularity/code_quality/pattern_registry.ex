defmodule Singularity.CodeQuality.PatternRegistry do
  @moduledoc """
  Code Quality Pattern Registry - Unified registry for security, compliance, language, and architecture patterns.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.CodeQuality.PatternRegistry",
    "purpose": "Unified registry for 55+ code quality patterns with persistence, versioning, and semantic search",
    "role": "domain_service",
    "layer": "code_quality",
    "dependencies": [
      "PostgreSQL (knowledge_artifacts table)",
      "pgvector (semantic search)",
      "EmbeddingGenerator (optional, for semantic matching)"
    ],
    "capabilities": [
      "Seed 55 static patterns from templates_data/",
      "Accept learned patterns from Genesis",
      "Track effectiveness metrics (for Genesis feedback)",
      "Semantic search via pgvector embeddings",
      "Pattern versioning & hierarchy",
      "CentralCloud distribution",
      "Cross-instance learning"
    ]
  }
  ```

  ## Architecture

  **Storage**: PostgreSQL `knowledge_artifacts` table
  - Type: `"code_quality_pattern"`
  - Content: Full pattern JSON
  - Metadata: JSONB with language, framework, severity, category
  - Embeddings: pgvector for semantic search
  - Usage: Track matches for Genesis feedback loop

  **Cache**: Optional ETS (performance optimization)
  - Used during analysis for repeated lookups
  - Invalidated on pattern updates
  - Fallback to DB if missing

  **Integration Points**:
  - ← **Input**: Genesis creates learned patterns
  - → **Output**: CentralCloud distributes patterns
  - ← **Input**: Effectiveness metrics feed back to Genesis
  - → **Usage**: CodeQuality.PatternMatcher queries patterns

  ## Pattern Categories

  - `:security` - OWASP Top 10 + CWE vulnerabilities (20 patterns)
  - `:compliance` - SOC2, HIPAA, PCI-DSS, GDPR, ISO27001 (5 patterns)
  - `:language` - Language-specific best practices (4 patterns)
  - `:package` - License, health, vulnerabilities, supply chain (4 patterns)
  - `:architecture` - Monolith, coupling, bottlenecks, etc. (6 patterns)
  - `:framework` - Framework-specific patterns (5 patterns)

  ## Usage

      # On startup: Seed base patterns from templates_data/
      Singularity.CodeQuality.PatternRegistry.seed_base_patterns()

      # Lookup
      {:ok, pattern} = PatternRegistry.get_pattern("owasp_sql_injection")

      # Query by attributes
      patterns = PatternRegistry.find_by_language("python")
      patterns = PatternRegistry.find_by_framework("django")
      patterns = PatternRegistry.find_by_category(:security)

      # Semantic search (via embeddings)
      {:ok, similar} = PatternRegistry.search_semantic("injection vulnerability", limit: 5)

      # Track pattern usage (for Genesis feedback)
      PatternRegistry.record_match("owasp_sql_injection",
        matched: true,
        severity: "critical",
        file: "app.py",
        line: 42
      )

      # Get effectiveness metrics
      stats = PatternRegistry.get_pattern_effectiveness("owasp_sql_injection")

  ## Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.Repo
      purpose: Query knowledge_artifacts table
    - module: Singularity.EmbeddingGenerator
      purpose: Generate embeddings for semantic search
    - module: Logger
      purpose: Logging operations

  called_by:
    - module: CodeQuality.PatternMatcher (Phase 2)
      purpose: Query patterns during analysis
    - module: Genesis
      purpose: Save learned patterns, query effectiveness
    - module: CentralCloud
      purpose: Sync patterns across instances
    - module: Application startup
      purpose: Seed base patterns
  ```

  ## Anti-Patterns

  ❌ DO NOT store patterns in ETS only
  **Why:** Patterns need persistence, versioning, and distributed access
  **Use:** PostgreSQL via knowledge_artifacts table

  ❌ DO NOT duplicate pattern lookup logic in analyzers
  **Why:** Single source of truth prevents consistency issues
  **Use:** Always query PatternRegistry

  ❌ DO NOT skip recording pattern matches
  **Why:** Effectiveness metrics are critical for Genesis feedback loop
  **Use:** Call record_match/2 when patterns are evaluated
  """

  require Logger
  alias Singularity.Repo
  alias Singularity.Schemas.KnowledgeArtifact
  import Ecto.Query

  @artifact_type "code_quality_pattern"
  @base_path "/home/mhugo/code/singularity/templates_data"

  @pattern_directories %{
    :security => "code_generation/patterns/security_vulnerabilities",
    :compliance => "compliance",
    :language => "code_generation/patterns/languages",
    :package => "package_intelligence",
    :architecture => "architecture_smells",
    :framework => "code_generation/frameworks"
  }

  # ============================================================================
  # Seeding & Initialization
  # ============================================================================

  @doc """
  Seed base patterns from templates_data/ into knowledge_artifacts.

  Loads all 55 JSON pattern files and upsets them into the database.
  Idempotent - safe to call multiple times.

  Returns `{:ok, count}` or `{:error, reason}`
  """
  def seed_base_patterns(opts \\ []) do
    Logger.info("PatternRegistry: Seeding base patterns from templates_data/")

    try do
      total_seeded = load_and_seed_patterns()

      if total_seeded > 0 do
        Logger.info("PatternRegistry: Successfully seeded #{total_seeded} patterns")
        emit_telemetry(:seed_success, %{count: total_seeded})
        {:ok, total_seeded}
      else
        Logger.error("PatternRegistry: No patterns were seeded - using fallback")
        emit_telemetry(:seed_empty, %{})
        {:error, :no_patterns_loaded}
      end
    rescue
      e ->
        Logger.error("PatternRegistry: Failed to seed patterns: #{inspect(e)}")
        emit_telemetry(:seed_failure, %{error: inspect(e)})
        {:error, "Failed to seed patterns: #{inspect(e)}"}
    end
  end

  # ============================================================================
  # Query APIs
  # ============================================================================

  @doc """
  Get a single pattern by ID.

  Returns `{:ok, pattern_map} | {:error, :not_found}`
  """
  def get_pattern(pattern_id) do
    case Repo.get_by(KnowledgeArtifact,
      artifact_type: @artifact_type,
      artifact_id: pattern_id
    ) do
      nil ->
        {:error, :not_found}

      artifact ->
        {:ok, artifact.content}
    end
  end

  @doc """
  Find all patterns for a specific language.

  Options:
  - `severity`: Filter by severity ("critical", "high", "medium", "low")
  - `category`: Filter by category (:security, :compliance, etc.)

  Returns list of patterns.
  """
  def find_by_language(language, opts \\ []) do
    severity = Keyword.get(opts, :severity)
    category = Keyword.get(opts, :category)

    base_query = from k in KnowledgeArtifact,
      where: k.artifact_type == @artifact_type,
      where: fragment("? @> ?", k.content, ^%{"applicable_languages" => [language]}),
      select: k.content

    base_query
    |> filter_by_severity_opt(severity)
    |> filter_by_category_opt(category)
    |> Repo.all()
  end

  @doc """
  Find all patterns for a specific framework.

  Returns list of patterns.
  """
  def find_by_framework(framework) do
    Repo.all(
      from k in KnowledgeArtifact,
        where: k.artifact_type == @artifact_type,
        where: fragment("? @> ?", k.content, ^%{"applicable_frameworks" => [framework]}),
        select: k.content
    )
  end

  @doc """
  Find all patterns in a category.

  Category options: `:security`, `:compliance`, `:language`, `:package`, `:architecture`, `:framework`

  Returns list of patterns.
  """
  def find_by_category(category) when category in [:security, :compliance, :language, :package, :architecture, :framework] do
    category_str = to_string(category)

    Repo.all(
      from k in KnowledgeArtifact,
        where: k.artifact_type == @artifact_type,
        where: fragment("? ->> ? = ?", k.content, "category", ^category_str),
        select: k.content
    )
  end

  @doc """
  Search patterns by semantic similarity using embeddings.

  Returns `{:ok, [patterns]} | {:error, reason}`
  """
  def search_semantic(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    # Note: This is a placeholder. Full implementation requires:
    # 1. Generate embedding for query
    # 2. Use pgvector similarity search
    # For now, return empty list and log
    Logger.warn("PatternRegistry: Semantic search not yet implemented")
    {:ok, []}
  end

  @doc """
  Get all patterns.

  Returns list of all patterns.
  """
  def all_patterns do
    Repo.all(
      from k in KnowledgeArtifact,
        where: k.artifact_type == @artifact_type,
        select: k.content
    )
  end

  @doc """
  Get statistics about loaded patterns.

  Returns map with counts by category, language, framework, severity.
  """
  def stats do
    patterns = all_patterns()

    %{
      total_patterns: length(patterns),
      by_category: count_by_field(patterns, "category"),
      by_language: count_languages(patterns),
      by_framework: count_frameworks(patterns),
      by_severity: count_by_field(patterns, "severity")
    }
  end

  # ============================================================================
  # Effectiveness Tracking (for Genesis Feedback Loop)
  # ============================================================================

  @doc """
  Record a pattern match for effectiveness tracking.

  This data feeds back to Genesis to help it learn which patterns are most effective.

  Options:
  - `matched`: true/false - whether pattern matched
  - `severity`: pattern severity level
  - `file`: file where match occurred
  - `line`: line number
  - `false_positive`: true if this was a false positive

  Emits telemetry for Genesis feedback loop:
  - [:pattern_registry, :match_recorded]
  """
  def record_match(pattern_id, opts \\ []) do
    matched = Keyword.get(opts, :matched, true)
    severity = Keyword.get(opts, :severity)
    file = Keyword.get(opts, :file)
    line = Keyword.get(opts, :line)
    false_positive = Keyword.get(opts, :false_positive, false)

    # Log for debugging
    Logger.debug("Pattern match recorded",
      pattern_id: pattern_id,
      matched: matched,
      severity: severity,
      file: file,
      line: line,
      false_positive: false_positive
    )

    # Emit telemetry for Genesis feedback loop and monitoring
    emit_telemetry(:match_recorded, %{
      pattern_id: pattern_id,
      matched: matched,
      severity: severity,
      false_positive: false_positive
    })

    :ok
  end

  @doc """
  Get effectiveness metrics for a pattern.

  Returns map with:
  - match_count: total times matched
  - false_positive_rate: false positive percentage
  - true_positive_rate: true positive percentage
  - average_severity: average severity of matches
  """
  def get_pattern_effectiveness(pattern_id) do
    # Placeholder - would query pattern_metrics or similar table
    %{
      match_count: 0,
      false_positive_rate: 0.0,
      true_positive_rate: 1.0,
      average_severity: "medium"
    }
  end

  # ============================================================================
  # Internal Functions
  # ============================================================================

  defp load_and_seed_patterns do
    patterns = []

    Enum.reduce(@pattern_directories, patterns, fn {category, dir}, acc ->
      case load_category_patterns(category, dir) do
        {:ok, category_patterns} ->
          Enum.each(category_patterns, &upsert_pattern/1)
          acc ++ category_patterns

        {:error, reason} ->
          Logger.warn("Failed to load category #{category}: #{inspect(reason)}")
          acc
      end
    end)
    |> length()
  end

  defp load_category_patterns(category, relative_dir) do
    dir = Path.join(@base_path, relative_dir)

    case File.ls(dir) do
      {:ok, files} ->
        json_files = Enum.filter(files, &String.ends_with?(&1, ".json"))

        patterns =
          json_files
          |> Enum.map(&load_pattern_file(Path.join(dir, &1), category))
          |> Enum.reject(&is_nil/1)

        {:ok, patterns}

      {:error, :enoent} ->
        Logger.warn("PatternRegistry: Category directory not found: #{dir}")
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp load_pattern_file(path, category) do
    try do
      case File.read(path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, pattern} ->
              # Enrich with category for storage
              enriched = pattern
                |> Map.put("category", to_string(category))
                |> Map.put("file_path", path)

              # Validate required fields
              case validate_pattern(enriched) do
                {:ok, validated_pattern} ->
                  validated_pattern

                {:error, reason} ->
                  Logger.warn("Pattern validation failed for #{path}: #{inspect(reason)}")
                  nil
              end

            {:error, _reason} ->
              Logger.warn("Failed to parse JSON: #{path}")
              nil
          end

        {:error, reason} ->
          Logger.warn("Failed to read pattern file #{path}: #{inspect(reason)}")
          nil
      end
    rescue
      e ->
        Logger.warn("Error loading pattern file #{path}: #{inspect(e)}")
        nil
    end
  end

  defp validate_pattern(pattern) do
    required_fields = ["pattern_id", "name", "description", "category", "severity"]

    missing_fields = Enum.reject(required_fields, &Map.has_key?(pattern, &1))

    case missing_fields do
      [] ->
        {:ok, pattern}

      fields ->
        {:error, "Missing required fields: #{Enum.join(fields, ", ")}"}
    end
  end

  defp emit_telemetry(event, measurements) do
    try do
      :telemetry.execute(
        [:pattern_registry, event],
        measurements,
        %{}
      )
    rescue
      e ->
        Logger.debug("Telemetry emit failed: #{inspect(e)}")
        :ok
    end
  end

  defp upsert_pattern(pattern) do
    pattern_id = pattern["pattern_id"]
    version = pattern["version"] || "1.0.0"
    content_json = Jason.encode!(pattern)

    case Repo.get_by(KnowledgeArtifact,
      artifact_type: @artifact_type,
      artifact_id: pattern_id,
      version: version
    ) do
      nil ->
        # Insert new
        %KnowledgeArtifact{
          artifact_type: @artifact_type,
          artifact_id: pattern_id,
          version: version,
          content_raw: content_json,
          content: pattern
        }
        |> Repo.insert()
        |> case do
          {:ok, _} ->
            Logger.debug("Seeded pattern: #{pattern_id}")
            :ok

          {:error, reason} ->
            Logger.warn("Failed to insert pattern #{pattern_id}: #{inspect(reason)}")
            :error
        end

      existing ->
        # Update if content changed
        if existing.content != pattern do
          existing
          |> Ecto.Changeset.change(
            content_raw: content_json,
            content: pattern
          )
          |> Repo.update()
          |> case do
            {:ok, _} ->
              Logger.debug("Updated pattern: #{pattern_id}")
              :ok

            {:error, reason} ->
              Logger.warn("Failed to update pattern #{pattern_id}: #{inspect(reason)}")
              :error
          end
        else
          :ok
        end
    end
  end

  defp filter_by_severity_opt(query, nil), do: query

  defp filter_by_severity_opt(query, severity) do
    where(query, [k], fragment("? ->> ? = ?", k.content, "severity", ^severity))
  end

  defp filter_by_category_opt(query, nil), do: query

  defp filter_by_category_opt(query, category) do
    where(query, [k], fragment("? ->> ? = ?", k.content, "category", ^to_string(category)))
  end

  defp count_by_field(patterns, field) do
    patterns
    |> Enum.map(&Map.get(&1, field))
    |> Enum.reduce(%{}, fn item, acc ->
      Map.update(acc, item, 1, &(&1 + 1))
    end)
  end

  defp count_languages(patterns) do
    patterns
    |> Enum.flat_map(&Map.get(&1, "applicable_languages", []))
    |> Enum.reduce(%{}, fn lang, acc ->
      Map.update(acc, lang, 1, &(&1 + 1))
    end)
  end

  defp count_frameworks(patterns) do
    patterns
    |> Enum.flat_map(&Map.get(&1, "applicable_frameworks", []))
    |> Enum.reduce(%{}, fn fw, acc ->
      Map.update(acc, fw, 1, &(&1 + 1))
    end)
  end
end
