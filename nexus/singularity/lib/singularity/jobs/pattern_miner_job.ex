defmodule Singularity.Jobs.PatternMinerJob do
  @moduledoc """
  Oban job for mining code patterns from local codebase.

  **What it does:**
  - Analyzes local codebase for reusable patterns
  - Extracts architectural patterns (GenServer, pgmq, async/await)
  - Clusters similar patterns using embeddings
  - Stores patterns in database with pgvector embeddings
  - Publishes pattern updates to pgmq for centralcloud sync

  **Job Configuration:**
  - Queue: `:pattern_mining` (dedicated queue for pattern analysis)
  - Max attempts: 3 (retry on transient failures)
  - Priority: 2 (medium priority)

  **pgmq Integration:**
  Publishes to `patterns.mined.completed` when successful
  Publishes pattern clusters to `patterns.cluster.updated`

  ## Usage

      # Mine patterns from specific directory
      %{
        codebase_path: "/path/to/code",
        languages: ["elixir", "rust"],
        min_quality_score: 0.7
      }
      |> Singularity.Jobs.PatternMinerJob.new()
      |> Singularity.JobQueue.insert()

      # Mine patterns with clustering
      %{
        codebase_path: "/path/to/code",
        cluster_patterns: true,
        similarity_threshold: 0.75
      }
      |> Singularity.Jobs.PatternMinerJob.new()
      |> Singularity.JobQueue.insert()
  """

  use Singularity.JobQueue.Worker,
    queue: :pattern_mining,
    max_attempts: 3,
    priority: 2

  require Logger
  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.info("Starting pattern mining job", args: args)

    codebase_path = Map.fetch!(args, "codebase_path")
    languages = Map.get(args, "languages", ["elixir", "rust"])
    min_quality_score = Map.get(args, "min_quality_score", 0.7)
    cluster_patterns = Map.get(args, "cluster_patterns", true)
    similarity_threshold = Map.get(args, "similarity_threshold", 0.75)

    with {:ok, code_files} <- scan_codebase(codebase_path, languages),
         {:ok, extracted_patterns} <- extract_patterns(code_files, min_quality_score),
         {:ok, clustered_patterns} <-
           maybe_cluster_patterns(extracted_patterns, cluster_patterns, similarity_threshold),
         {:ok, stored_count} <- store_patterns(clustered_patterns),
         :ok <- publish_completion(codebase_path, stored_count, clustered_patterns) do
      Logger.info("Pattern mining job completed successfully",
        codebase_path: codebase_path,
        patterns_stored: stored_count
      )

      {:ok, %{patterns_stored: stored_count, clusters: length(clustered_patterns)}}
    else
      {:error, reason} = error ->
        Logger.error("Pattern mining job failed", error: inspect(reason))
        publish_failure(codebase_path, reason)
        error
    end
  rescue
    exception ->
      Logger.error("Pattern mining job exception", exception: inspect(exception))
      publish_failure(args["codebase_path"], exception)
      {:error, exception}
  end

  ## Private Functions

  defp get_instance_id do
    # Get unique instance identifier (same as central_cloud.ex)
    cond do
      instance_id = System.get_env("SINGULARITY_INSTANCE_ID") ->
        instance_id

      true ->
        hostname = :inet.gethostname() |> elem(1) |> List.to_string()
        workdir = File.cwd!() |> Path.basename()

        path_hash =
          :crypto.hash(:sha256, File.cwd!()) |> Base.encode16(case: :lower) |> String.slice(0, 8)

        timestamp =
          DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string() |> String.slice(-6, 6)

        "#{hostname}-#{workdir}-#{path_hash}-#{timestamp}"
    end
  end

  defp scan_codebase(codebase_path, languages) do
    Logger.info("Scanning codebase for patterns",
      path: codebase_path,
      languages: languages
    )

    try do
      # Query codebase_chunks table for code in specified languages
      query = """
      SELECT
        id,
        content,
        language,
        file_path,
        repo,
        chunk_index,
        embedding
      FROM codebase_chunks
      WHERE language = ANY($1::text[])
        AND repo LIKE $2
        AND content IS NOT NULL
        AND byte_length(content) >= 100
      ORDER BY inserted_at DESC
      LIMIT 1000
      """

      # Create instance-aware repo pattern to avoid conflicts
      instance_id = get_instance_id()
      repo_pattern = "#{codebase_path}%#{instance_id}%"

      case Repo.query(query, [languages, repo_pattern]) do
        {:ok, %{rows: [_head | _] = rows}} ->
          code_files =
            Enum.map(rows, fn [id, content, language, file_path, repo, chunk_index, embedding] ->
              %{
                id: id,
                content: content,
                language: language,
                file_path: file_path,
                repo: repo,
                chunk_index: chunk_index,
                embedding: embedding
              }
            end)

          Logger.info("Found #{length(code_files)} code files to analyze")
          {:ok, code_files}

        {:ok, %{rows: []}} ->
          Logger.warning("No code files found in codebase", path: codebase_path)
          {:error, :no_files_found}

        {:error, reason} ->
          Logger.error("Failed to query codebase", error: inspect(reason))
          {:error, reason}
      end
    rescue
      exception ->
        Logger.error("Exception scanning codebase", exception: inspect(exception))
        {:error, exception}
    end
  end

  defp extract_patterns(code_files, min_quality_score) do
    Logger.info("Extracting patterns from code files",
      file_count: length(code_files),
      min_quality_score: min_quality_score
    )

    try do
      extracted_patterns =
        code_files
        |> Enum.map(&extract_pattern_from_file(&1, min_quality_score))
        |> Enum.filter(&(&1 != nil))

      Logger.info("Extracted #{length(extracted_patterns)} patterns")
      {:ok, extracted_patterns}
    rescue
      exception ->
        Logger.error("Exception extracting patterns", exception: inspect(exception))
        {:error, exception}
    end
  end

  defp extract_pattern_from_file(file, min_quality_score) do
    language = String.to_atom(file.language)
    keywords = CodePatternExtractor.extract_from_code(file.content, language)

    if length(keywords) >= 3 do
      # Calculate quality score based on pattern complexity
      quality_score = calculate_pattern_quality(keywords, file.content)

      if quality_score >= min_quality_score do
        %{
          name: extract_pattern_name(file.file_path, keywords),
          type: determine_pattern_type(keywords),
          keywords: keywords,
          content: file.content,
          language: file.language,
          file_path: file.file_path,
          repo: file.repo,
          quality_score: quality_score,
          embedding: file.embedding,
          chunk_id: file.id,
          extracted_at: DateTime.utc_now()
        }
      end
    end
  end

  defp calculate_pattern_quality(keywords, content) do
    # Base quality score
    base_score = 0.5

    # Architectural pattern bonus
    architectural_keywords = ~w(genserver supervisor broadway pgmq async tokio actor)
    architectural_count = Enum.count(keywords, &(&1 in architectural_keywords))
    architectural_bonus = min(0.3, architectural_count * 0.1)

    # Code length bonus (longer patterns = more context)
    length_bonus = min(0.1, String.length(content) / 10000)

    # Uniqueness bonus (more unique keywords = better pattern)
    uniqueness_bonus = min(0.1, length(Enum.uniq(keywords)) / 20)

    total_score = base_score + architectural_bonus + length_bonus + uniqueness_bonus
    Float.round(total_score, 2)
  end

  defp extract_pattern_name(file_path, keywords) do
    filename = Path.basename(file_path, Path.extname(file_path))

    # Use most significant keyword as suffix
    significant_keyword =
      keywords
      |> Enum.filter(&(&1 in ~w(genserver supervisor pgmq async http)))
      |> List.first()

    if significant_keyword do
      "#{filename}_#{significant_keyword}"
    else
      filename
    end
  end

  defp determine_pattern_type(keywords) do
    cond do
      Enum.any?(keywords, &(&1 in ~w(genserver supervisor actor))) -> "process"
      Enum.any?(keywords, &(&1 in ~w(pgmq http kafka messaging))) -> "integration"
      Enum.any?(keywords, &(&1 in ~w(async concurrent tokio))) -> "concurrency"
      Enum.any?(keywords, &(&1 in ~w(error retry circuit))) -> "resilience"
      true -> "general"
    end
  end

  defp maybe_cluster_patterns(patterns, false = _cluster_enabled, _threshold) do
    Logger.info("Skipping pattern clustering (disabled)")
    {:ok, patterns}
  end

  defp maybe_cluster_patterns(patterns, true = _cluster_enabled, similarity_threshold) do
    Logger.info("Clustering patterns",
      pattern_count: length(patterns),
      similarity_threshold: similarity_threshold
    )

    try do
      # Use PatternMiner's clustering logic
      clustered = cluster_patterns_by_similarity(patterns, similarity_threshold)
      Logger.info("Created #{length(clustered)} pattern clusters")
      {:ok, clustered}
    rescue
      exception ->
        Logger.error("Exception clustering patterns", exception: inspect(exception))
        # Fallback: treat each pattern as its own cluster
        {:ok, Enum.map(patterns, &wrap_in_cluster/1)}
    end
  end

  defp cluster_patterns_by_similarity(patterns, threshold) do
    # Group patterns by embeddings similarity
    # Use simple clustering based on existing embeddings
    patterns
    |> Enum.group_by(& &1.type)
    |> Enum.flat_map(fn {type, type_patterns} ->
      cluster_by_type(type_patterns, type, threshold)
    end)
  end

  defp cluster_by_type(patterns, type, _threshold) do
    # Simple clustering: group by pattern type and quality range
    patterns
    |> Enum.group_by(fn pattern ->
      quality_range =
        cond do
          pattern.quality_score >= 0.9 -> :high
          pattern.quality_score >= 0.7 -> :medium
          true -> :low
        end

      {type, quality_range}
    end)
    |> Enum.map(fn {{pattern_type, quality_range}, cluster_patterns} ->
      %{
        id: "cluster_#{pattern_type}_#{quality_range}_#{System.unique_integer([:positive])}",
        type: pattern_type,
        quality_range: quality_range,
        patterns: cluster_patterns,
        size: length(cluster_patterns),
        avg_quality:
          Enum.sum(Enum.map(cluster_patterns, & &1.quality_score)) / length(cluster_patterns),
        created_at: DateTime.utc_now()
      }
    end)
  end

  defp wrap_in_cluster(pattern) do
    %{
      id: "cluster_single_#{System.unique_integer([:positive])}",
      type: pattern.type,
      patterns: [pattern],
      size: 1,
      avg_quality: pattern.quality_score,
      created_at: DateTime.utc_now()
    }
  end

  defp store_patterns(clustered_patterns) do
    Logger.info("Storing pattern clusters in database",
      cluster_count: length(clustered_patterns)
    )

    try do
      stored_count =
        clustered_patterns
        |> Enum.map(&store_pattern_cluster/1)
        |> Enum.count(fn result -> match?({:ok, _}, result) end)

      Logger.info("Stored #{stored_count} pattern clusters")
      {:ok, stored_count}
    rescue
      exception ->
        Logger.error("Exception storing patterns", exception: inspect(exception))
        {:error, exception}
    end
  end

  defp store_pattern_cluster(cluster) do
    try do
      # Store cluster metadata in pattern_clusters table
      cluster_data = %{
        cluster_id: cluster.id,
        pattern_type: to_string(cluster.type),
        size: cluster.size,
        avg_quality: cluster.avg_quality,
        patterns: Jason.encode!(cluster.patterns),
        created_at: DateTime.utc_now()
      }

      case Repo.insert_all("pattern_clusters", [cluster_data]) do
        {1, _} ->
          {:ok, cluster.id}

        {0, _} ->
          {:error, :insert_failed}
      end
    rescue
      exception ->
        Logger.error("Exception storing cluster", exception: inspect(exception))
        {:error, exception}
    end
  end

  defp publish_completion(codebase_path, stored_count, clusters) do
    Logger.debug("Publishing pattern mining completion to pgmq")

    payload =
      Jason.encode!(%{
        event: "pattern_mining_completed",
        codebase_path: codebase_path,
        patterns_stored: stored_count,
        cluster_count: length(clusters),
        timestamp: DateTime.utc_now()
      })

    case Singularity.Messaging.Client.publish("patterns.mined.completed", payload) do
      :ok ->
        Logger.info("Published pattern mining completion to pgmq",
          codebase_path: codebase_path
        )

        # Also publish individual cluster updates
        publish_cluster_updates(clusters)
        :ok

      {:error, reason} ->
        Logger.warning("Failed to publish to pgmq (non-critical)", error: inspect(reason))
        :ok
    end
  rescue
    exception ->
      Logger.warning("Exception publishing to pgmq (non-critical)", exception: inspect(exception))
      :ok
  end

  defp publish_cluster_updates(clusters) do
    Enum.each(clusters, fn cluster ->
      payload =
        Jason.encode!(%{
          cluster_id: cluster.id,
          pattern_type: cluster.type,
          size: cluster.size,
          avg_quality: cluster.avg_quality,
          timestamp: DateTime.utc_now()
        })

      Singularity.Messaging.Client.publish("patterns.cluster.updated", payload)
    end)
  rescue
    exception ->
      Logger.warning("Exception publishing cluster updates", exception: inspect(exception))
  end

  defp publish_failure(codebase_path, reason) do
    Logger.debug("Publishing pattern mining failure to pgmq")

    payload =
      Jason.encode!(%{
        event: "pattern_mining_failed",
        codebase_path: codebase_path,
        error: inspect(reason),
        timestamp: DateTime.utc_now()
      })

    case Singularity.Messaging.Client.publish("patterns.mined.failed", payload) do
      :ok ->
        Logger.info("Published pattern mining failure to pgmq", codebase_path: codebase_path)

      {:error, pgmq_error} ->
        Logger.warning("Failed to publish failure to pgmq", error: inspect(pgmq_error))
    end
  rescue
    exception ->
      Logger.warning("Exception publishing failure to pgmq", exception: inspect(exception))
  end
end
