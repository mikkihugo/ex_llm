defmodule Singularity.FrameworkPatternStore do
  @moduledoc """
  Self-learning framework pattern storage in PostgreSQL

  Learns and adapts framework detection patterns over time:
  - Stores detection patterns from successful detections
  - Updates confidence scores based on accuracy
  - Discovers new frameworks automatically
  - Provides semantic pattern search

  ## Self-Learning Flow

  1. Rust detector finds framework
  2. Store detection pattern in PG
  3. Track success/failure
  4. Update confidence weights
  5. Discover new patterns from repos
  """

  require Logger
  alias Singularity.Repo

  @doc """
  Get framework pattern by name
  """
  def get_pattern(framework_name) do
    query = """
    SELECT
      framework_name, framework_type, version_pattern,
      file_patterns, directory_patterns, config_files,
      build_command, dev_command, install_command, test_command,
      output_directory, confidence_weight,
      detection_count, success_rate
    FROM framework_patterns
    WHERE framework_name = $1
    ORDER BY success_rate DESC, detection_count DESC
    LIMIT 1
    """

    case Repo.query(query, [framework_name]) do
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
  """
  def learn_pattern(detection_result) do
    query = """
    INSERT INTO framework_patterns (
      framework_name, framework_type,
      file_patterns, directory_patterns, config_files,
      build_command, dev_command, install_command,
      output_directory, confidence_weight,
      detection_count, last_detected_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 1, NOW())
    ON CONFLICT (framework_name, framework_type) DO UPDATE SET
      file_patterns = COALESCE(
        framework_patterns.file_patterns,
        EXCLUDED.file_patterns
      ),
      directory_patterns = COALESCE(
        framework_patterns.directory_patterns,
        EXCLUDED.directory_patterns
      ),
      config_files = framework_patterns.config_files || EXCLUDED.config_files,
      detection_count = framework_patterns.detection_count + 1,
      last_detected_at = NOW(),
      updated_at = NOW()
    RETURNING id
    """

    params = [
      detection_result.framework_name,
      detection_result.framework_type,
      Jason.encode!(detection_result.file_patterns || []),
      Jason.encode!(detection_result.directory_patterns || []),
      Jason.encode!(detection_result.config_files || []),
      detection_result.build_command,
      detection_result.dev_command,
      detection_result.install_command,
      detection_result.output_directory,
      detection_result.confidence || 1.0
    ]

    case Repo.query(query, params) do
      {:ok, %{rows: [[id]]}} ->
        Logger.info("Learned pattern for #{detection_result.framework_name} (id: #{id})")
        {:ok, id}

      {:error, reason} ->
        Logger.error("Failed to learn pattern: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Update pattern confidence based on detection success
  """
  def update_confidence(framework_name, success?) do
    # Exponential moving average of success rate
    query = """
    UPDATE framework_patterns
    SET
      success_rate = success_rate * 0.9 + $2 * 0.1,
      updated_at = NOW()
    WHERE framework_name = $1
    RETURNING success_rate
    """

    success_value = if success?, do: 1.0, else: 0.0

    case Repo.query(query, [framework_name, success_value]) do
      {:ok, %{rows: [[new_rate]]}} ->
        Logger.debug("Updated #{framework_name} success_rate: #{Float.round(new_rate, 3)}")
        {:ok, new_rate}

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
      framework_name, framework_type,
      file_patterns, directory_patterns, config_files,
      build_command, dev_command,
      1 - (pattern_embedding <=> $1::vector) AS similarity
    FROM framework_patterns
    WHERE pattern_embedding IS NOT NULL
    ORDER BY pattern_embedding <=> $1::vector
    LIMIT $2
    """

    case Repo.query(sql, [embedding, top_k]) do
      {:ok, %{rows: rows}} ->
        patterns = Enum.map(rows, fn row ->
          [name, type, files, dirs, configs, build, dev, sim] = row
          %{
            framework_name: name,
            framework_type: type,
            file_patterns: files,
            directory_patterns: dirs,
            config_files: configs,
            build_command: build,
            dev_command: dev,
            similarity: sim
          }
        end)

        {:ok, patterns}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get all patterns for a framework type
  """
  def get_patterns_by_type(framework_type) do
    query = """
    SELECT
      framework_name, file_patterns, directory_patterns, config_files,
      build_command, dev_command, confidence_weight, success_rate
    FROM framework_patterns
    WHERE framework_type = $1
    ORDER BY success_rate DESC, detection_count DESC
    """

    case Repo.query(query, [framework_type]) do
      {:ok, %{rows: rows}} ->
        patterns = Enum.map(rows, &build_pattern_struct/1)
        {:ok, patterns}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Discover new patterns from detected files

  Analyzes repos to find new framework patterns not in DB
  """
  def discover_new_patterns(repo_path) do
    # Find unique file extensions
    query = """
    SELECT DISTINCT
      SUBSTRING(file_path FROM '\\.([^.]+)$') AS extension,
      COUNT(*) AS count
    FROM code_files
    WHERE repo_name = $1
    GROUP BY extension
    HAVING COUNT(*) > 5
    ORDER BY count DESC
    LIMIT 20
    """

    case Repo.query(query, [repo_path]) do
      {:ok, %{rows: rows}} ->
        # Analyze patterns
        patterns = Enum.map(rows, fn [ext, count] ->
          %{extension: ext, file_count: count}
        end)

        # Check if we have known patterns for these extensions
        unknown = Enum.reject(patterns, fn p ->
          known_extension?(p.extension)
        end)

        if unknown != [] do
          Logger.info("Discovered #{length(unknown)} potential new framework patterns")
          {:ok, unknown}
        else
          {:ok, []}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Export patterns to JSON for Rust detector
  """
  def export_to_json(output_path) do
    query = """
    SELECT
      framework_name, framework_type,
      file_patterns, directory_patterns, config_files,
      build_command, dev_command, install_command, test_command,
      output_directory, confidence_weight
    FROM framework_patterns
    ORDER BY framework_type, framework_name
    """

    case Repo.query(query, []) do
      {:ok, %{rows: rows}} ->
        patterns = Enum.map(rows, fn row ->
          [name, type, files, dirs, configs, build, dev, install, test, output, conf] = row

          %{
            framework_name: name,
            framework_type: type,
            file_patterns: files,
            directory_patterns: dirs,
            config_files: configs,
            build_command: build,
            dev_command: dev,
            install_command: install,
            test_command: test,
            output_directory: output,
            confidence_weight: conf
          }
        end)

        json = Jason.encode!(patterns, pretty: true)
        File.write!(output_path, json)

        Logger.info("Exported #{length(patterns)} patterns to #{output_path}")
        {:ok, length(patterns)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Private Functions

  defp build_pattern_struct(row) do
    [name, type, version, files, dirs, configs, build, dev, install, test, output, conf, count, success] = row

    %{
      framework_name: name,
      framework_type: type,
      version_pattern: version,
      file_patterns: files,
      directory_patterns: dirs,
      config_files: configs,
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

  defp known_extension?(ext) do
    query = """
    SELECT 1 FROM framework_patterns
    WHERE file_patterns @> $1::jsonb
    LIMIT 1
    """

    case Repo.query(query, [Jason.encode!(["*.#{ext}"])]) do
      {:ok, %{rows: []}} -> false
      {:ok, %{rows: _}} -> true
      _ -> false
    end
  end
end
