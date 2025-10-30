defmodule Singularity.Knowledge.ArtifactStore do
  @moduledoc """
  Unified knowledge artifact storage with dual-layer persistence.

  ## Architecture (HashiCorp-Inspired)

  **Git (Source of Truth)** ←→ **PostgreSQL (Runtime + Learning)**

  ### Git Layer (`templates_data/`)
  - Human-editable JSON files
  - Version control, PRs, reviews
  - Schema validation (Moon tasks)
  - Curated, production-ready artifacts

  ### PostgreSQL Layer (`knowledge_artifacts` table)
  - Runtime queries (JSONB fast queries)
  - Semantic search (pgvector embeddings)
  - Usage tracking (success_rate, usage_count)
  - **Learning storage** (improved versions, user feedback)

  ## Bidirectional Sync

  ### Git → PostgreSQL (Import)
  ```elixir
  # Sync from Git to DB
  ArtifactStore.sync_from_git("templates_data/quality/elixir-production.json")
  ```

  ### PostgreSQL → Git (Export Learnings)
  ```elixir
  # Export improved artifacts back to Git
  ArtifactStore.export_learned_to_git(
    artifact_type: "quality_template",
    min_usage_count: 10,
    min_success_rate: 0.90
  )
  ```

  ## Dual Storage

  - `content_raw` (TEXT) - Exact JSON string (audit trail)
  - `content` (JSONB) - Parsed for queries (fast)
  - `embedding` (vector) - Semantic search

  ## Usage

  ### Store
  ```elixir
  ArtifactStore.store(
    "quality_template",
    "elixir-production",
    %{
      "language" => "elixir",
      "quality_level" => "production",
      "requirements" => %{...}
    },
    tags: ["elixir", "production"]
  )
  ```

  ### Search (Semantic)
  ```elixir
  {:ok, results} = ArtifactStore.search(
    "async worker pattern",
    artifact_types: ["framework_pattern", "code_template"],
    language: "elixir",
    top_k: 5
  )
  ```

  ### Query (JSONB)
  ```elixir
  {:ok, templates} = ArtifactStore.query_jsonb(
    artifact_type: "quality_template",
    filter: %{"language" => "elixir", "quality_level" => "production"}
  )
  ```

  ### Track Usage (Learning Loop)
  ```elixir
  # Record usage
  ArtifactStore.record_usage(artifact_id, success: true)

  # After 100 uses with 95% success rate, export to Git
  ArtifactStore.export_learned_to_git(min_usage_count: 100, min_success_rate: 0.95)
  ```
  """

  require Logger

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Schemas.KnowledgeArtifact
  # Single embedding source with auto-fallback
  alias Singularity.CodeGeneration.Implementations.EmbeddingGenerator

  require Logger

  @templates_data_dir "templates_data"

  # ===========================
  # Storage Operations
  # ===========================

  @doc """
  Store a knowledge artifact with dual storage (raw JSON + JSONB).

  ## Options
  - `:version` - Version string (default: "1.0.0")
  - `:tags` - List of tags
  - `:skip_embedding` - Skip embedding generation (default: false)
  """
  def store(artifact_type, artifact_id, content_map, opts \\ []) do
    # Encode to pretty JSON (for Git/human readability)
    content_raw = Jason.encode!(content_map, pretty: true)

    attrs = %{
      artifact_type: artifact_type,
      artifact_id: artifact_id,
      version: opts[:version] || "1.0.0",
      content_raw: content_raw,
      content: content_map
    }

    %KnowledgeArtifact{}
    |> KnowledgeArtifact.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:artifact_type, :artifact_id, :version]
    )
    |> case do
      {:ok, artifact} ->
        # Generate embedding async (unless skipped)
        if !opts[:skip_embedding] do
          Task.start(fn -> generate_embedding_async(artifact) end)
        end

        {:ok, artifact}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Get a specific artifact by type, ID, and version.

  ## Examples

      iex> ArtifactStore.get("quality_template", "elixir-production")
      {:ok, %KnowledgeArtifact{}}

      iex> ArtifactStore.get("quality_template", "elixir-production", "2.0.0")
      {:ok, %KnowledgeArtifact{}}
  """
  def get(artifact_type, artifact_id, version \\ "latest") do
    query =
      if version == "latest" do
        from(a in KnowledgeArtifact,
          where: a.artifact_type == ^artifact_type and a.artifact_id == ^artifact_id,
          order_by: [desc: a.version],
          limit: 1
        )
      else
        from(a in KnowledgeArtifact,
          where:
            a.artifact_type == ^artifact_type and a.artifact_id == ^artifact_id and
              a.version == ^version
        )
      end

    case Repo.one(query) do
      nil -> {:error, :not_found}
      artifact -> {:ok, artifact}
    end
  end

  # ===========================
  # Search Operations
  # ===========================

  @doc """
  Semantic search across artifacts using vector embeddings.

  ## Options
  - `:artifact_types` - List of artifact types to search (default: all)
  - `:language` - Filter by language
  - `:tags` - Filter by tags (array contains)
  - `:top_k` - Number of results (default: 10)
  - `:min_similarity` - Minimum cosine similarity (default: 0.7)

  ## Examples

      iex> ArtifactStore.search("async worker pattern", language: "elixir", top_k: 5)
      {:ok, [%KnowledgeArtifact{}, ...]}
  """
  def search(query_text, opts \\ []) do
    # Generate embedding for query
    case EmbeddingGenerator.embed(query_text, provider: :auto) do
      {:ok, embedding} ->
        results = search_by_embedding(embedding, opts)
        {:ok, results}

      {:error, reason} ->
        Logger.error("Failed to generate embedding for search: #{inspect(reason)}")
        {:error, :embedding_failed}
    end
  end

  defp search_by_embedding(embedding, opts) do
    artifact_types = opts[:artifact_types]
    language = opts[:language]
    tags = opts[:tags]
    top_k = opts[:top_k] || 10
    min_similarity = opts[:min_similarity] || 0.7

    query =
      from(a in KnowledgeArtifact,
        where: not is_nil(a.embedding),
        select: %{
          artifact: a,
          similarity: fragment("1 - (embedding <=> ?)", ^embedding)
        },
        order_by: fragment("embedding <=> ?", ^embedding),
        limit: ^top_k
      )

    query =
      if artifact_types do
        from([a] in query, where: a.artifact_type in ^artifact_types)
      else
        query
      end

    query =
      if language do
        from([a] in query, where: a.language == ^language)
      else
        query
      end

    query =
      if tags do
        from([a] in query, where: fragment("tags && ?", ^tags))
      else
        query
      end

    query
    |> Repo.all()
    |> Enum.filter(fn %{similarity: sim} -> sim >= min_similarity end)
    |> Enum.map(fn %{artifact: artifact, similarity: sim} ->
      Map.put(artifact, :similarity, sim)
    end)
  end

  @doc """
  Query artifacts using JSONB containment/operators.

  ## Options
  - `:artifact_type` - Filter by artifact type
  - `:filter` - JSONB filter (uses @> containment operator)
  - `:language` - Filter by language (uses generated column)

  ## Examples

      iex> ArtifactStore.query_jsonb(
      ...>   artifact_type: "quality_template",
      ...>   filter: %{"language" => "elixir", "quality_level" => "production"}
      ...> )
      {:ok, [%KnowledgeArtifact{}, ...]}
  """
  def query_jsonb(opts \\ []) do
    artifact_type = opts[:artifact_type]
    filter = opts[:filter]
    language = opts[:language]

    query = from(a in KnowledgeArtifact)

    query =
      if artifact_type do
        from(a in query, where: a.artifact_type == ^artifact_type)
      else
        query
      end

    query =
      if filter do
        from(a in query, where: fragment("content @> ?", ^filter))
      else
        query
      end

    query =
      if language do
        from(a in query, where: a.language == ^language)
      else
        query
      end

    {:ok, Repo.all(query)}
  end

  # ===========================
  # Git Sync Operations
  # ===========================

  @doc """
  Sync artifacts from Git (templates_data/) to PostgreSQL.

  Reads JSON files, validates, and upserts into database with embeddings.

  ## Options
  - `:path` - Specific file or directory to sync (default: all of templates_data/)
  - `:skip_embedding` - Skip embedding generation (faster for bulk imports)

  ## Examples

      # Sync all
      ArtifactStore.sync_from_git()

      # Sync specific file
      ArtifactStore.sync_from_git(path: "templates_data/quality/elixir-production.json")

      # Sync directory
      ArtifactStore.sync_from_git(path: "templates_data/quality/")
  """
  def sync_from_git(opts \\ []) do
    path = opts[:path] || @templates_data_dir
    full_path = Path.expand(path)

    files =
      if File.dir?(full_path) do
        Path.wildcard("#{full_path}/**/*.json")
      else
        [full_path]
      end

    results =
      Enum.map(files, fn file_path ->
        sync_file_from_git(file_path, opts)
      end)

    success_count = Enum.count(results, &match?({:ok, _}, &1))
    error_count = Enum.count(results, &match?({:error, _}, &1))

    Logger.info("Git sync complete: #{success_count} success, #{error_count} errors")

    {:ok, %{success: success_count, errors: error_count, results: results}}
  end

  defp sync_file_from_git(file_path, opts) do
    with {:ok, json_string} <- File.read(file_path),
         {:ok, content_map} <- Jason.decode(json_string),
         {:ok, metadata} <- extract_metadata_from_path(file_path) do
      artifact_type = metadata.artifact_type
      artifact_id = metadata.artifact_id

      store(artifact_type, artifact_id, content_map, opts)
    else
      {:error, reason} ->
        Logger.error("Failed to sync #{file_path}: #{inspect(reason)}")
        {:error, {file_path, reason}}
    end
  end

  defp extract_metadata_from_path(file_path) do
    # Extract artifact type and ID from path
    # Example: templates_data/quality/elixir-production.json
    #   → artifact_type: "quality_template"
    #   → artifact_id: "elixir-production"

    relative_path = Path.relative_to(file_path, @templates_data_dir)
    parts = Path.split(relative_path)

    case parts do
      ["quality", filename] ->
        {:ok, %{artifact_type: "quality_template", artifact_id: Path.rootname(filename)}}

      ["frameworks", filename] ->
        {:ok, %{artifact_type: "framework_pattern", artifact_id: Path.rootname(filename)}}

      ["prompts", filename] ->
        {:ok, %{artifact_type: "system_prompt", artifact_id: Path.rootname(filename)}}

      ["code_generation", "patterns", category, filename] ->
        {:ok, %{artifact_type: "code_template_#{category}", artifact_id: Path.rootname(filename)}}

      _ ->
        # Fallback: use directory name as type
        [type_dir | _] = parts
        filename = List.last(parts)
        {:ok, %{artifact_type: type_dir, artifact_id: Path.rootname(filename)}}
    end
  end

  @doc """
  Count total artifacts in the knowledge store.

  ## Options
  - `:artifact_type` - Filter by artifact type
  - `:language` - Filter by language

  ## Examples

      iex> ArtifactStore.count_artifacts()
      {:ok, 152}

      iex> ArtifactStore.count_artifacts(artifact_type: "quality_template")
      {:ok, 23}
  """
  def count_artifacts(opts \\ []) do
    artifact_type = opts[:artifact_type]
    language = opts[:language]

    query = from(a in KnowledgeArtifact, select: count(a.id))

    query =
      if artifact_type do
        from(a in query, where: a.artifact_type == ^artifact_type)
      else
        query
      end

    query =
      if language do
        from(a in query, where: a.language == ^language)
      else
        query
      end

    count = Repo.one(query)
    {:ok, count || 0}
  rescue
    error ->
      Logger.error("Failed to count artifacts", error: inspect(error))
      {:error, :query_failed}
  end

  @doc """
  Count artifacts ready for promotion (high usage count and success rate).

  ## Options
  - `:artifact_type` - Filter by artifact type
  - `:min_usage_count` - Minimum usage count (default: 10)
  - `:min_success_rate` - Minimum success rate (default: 0.90)

  ## Examples

      iex> ArtifactStore.count_ready_to_promote()
      {:ok, 5}

      iex> ArtifactStore.count_ready_to_promote(min_usage_count: 100, min_success_rate: 0.95)
      {:ok, 2}
  """
  def count_ready_to_promote(opts \\ []) do
    artifact_type = opts[:artifact_type]
    min_usage_count = opts[:min_usage_count] || 10
    min_success_rate = opts[:min_success_rate] || 0.90

    try do
      query =
        from(a in KnowledgeArtifact,
          # Safe JSONB extraction with fallback for missing fields
          where:
            fragment(
              "COALESCE((content->>'usage_count')::int, 0) >= ?",
              ^min_usage_count
            ),
          where:
            fragment(
              "COALESCE((content->>'success_rate')::float, 0.0) >= ?",
              ^min_success_rate
            ),
          select: count(a.id)
        )

      query =
        if artifact_type do
          from(a in query, where: a.artifact_type == ^artifact_type)
        else
          query
        end

      count = Repo.one(query)
      {:ok, count || 0}
    rescue
      error ->
        SASL.database_failure(
          :promotion_count_query_failed,
          "Failed to count ready-to-promote artifacts",
          error: inspect(error),
          artifact_type: artifact_type,
          min_usage_count: min_usage_count,
          min_success_rate: min_success_rate
        )

        {:error, :query_failed}
    end
  end

  @doc """
  Export learned artifacts back to Git.

  Exports artifacts that have been validated through usage (high success rate, sufficient usage).
  This creates a feedback loop: DB learning → Git curation.

  ## Options
  - `:artifact_type` - Filter by artifact type
  - `:min_usage_count` - Minimum usage count (default: 10)
  - `:min_success_rate` - Minimum success rate (default: 0.90)
  - `:output_dir` - Output directory (default: templates_data/learned/)

  ## Examples

      # Export high-quality learned templates
      ArtifactStore.export_learned_to_git(
        artifact_type: "quality_template",
        min_usage_count: 100,
        min_success_rate: 0.95
      )
  """
  def export_learned_to_git(opts \\ []) do
    artifact_type = opts[:artifact_type]
    min_usage_count = opts[:min_usage_count] || 10
    min_success_rate = opts[:min_success_rate] || 0.90
    output_dir = opts[:output_dir] || Path.join(@templates_data_dir, "learned")

    # Query high-quality artifacts
    query =
      from(a in KnowledgeArtifact,
        where: fragment("(content->>'usage_count')::int >= ?", ^min_usage_count),
        where: fragment("(content->>'success_rate')::float >= ?", ^min_success_rate)
      )

    query =
      if artifact_type do
        from(a in query, where: a.artifact_type == ^artifact_type)
      else
        query
      end

    artifacts = Repo.all(query)

    # Ensure output directory exists
    File.mkdir_p!(output_dir)

    results =
      Enum.map(artifacts, fn artifact ->
        export_artifact_to_file(artifact, output_dir)
      end)

    success_count = Enum.count(results, &match?({:ok, _}, &1))
    Logger.info("Exported #{success_count} learned artifacts to #{output_dir}")

    {:ok, %{exported: success_count, output_dir: output_dir}}
  end

  defp export_artifact_to_file(artifact, output_dir) do
    filename = "#{artifact.artifact_id}.json"
    file_path = Path.join([output_dir, artifact.artifact_type, filename])

    # Ensure subdirectory exists
    File.mkdir_p!(Path.dirname(file_path))

    # Use content_raw (exact original formatting)
    File.write(file_path, artifact.content_raw)
  end

  # ===========================
  # Usage Tracking (Learning Loop)
  # ===========================

  @doc """
  Record usage of an artifact (learning loop).

  Updates usage_count and success_rate in JSONB content.

  ## Examples

      ArtifactStore.record_usage("elixir-production", success: true)
      ArtifactStore.record_usage("rust-api-endpoint", success: false)
  """
  def record_usage(artifact_id, opts \\ []) do
    success = Keyword.get(opts, :success, true)

    # Increment usage_count and update success_rate
    Repo.transaction(fn ->
      case get_by_artifact_id(artifact_id) do
        {:ok, artifact} ->
          current_usage = get_in(artifact.content, ["usage_count"]) || 0
          current_success_count = get_in(artifact.content, ["success_count"]) || 0

          new_usage = current_usage + 1

          new_success_count =
            if success, do: current_success_count + 1, else: current_success_count

          new_success_rate = new_success_count / new_usage

          updated_content =
            artifact.content
            |> Map.put("usage_count", new_usage)
            |> Map.put("success_count", new_success_count)
            |> Map.put("success_rate", new_success_rate)
            |> Map.put("last_used_at", DateTime.utc_now() |> DateTime.to_iso8601())

          updated_content_raw = Jason.encode!(updated_content, pretty: true)

          artifact
          |> KnowledgeArtifact.changeset(%{
            content: updated_content,
            content_raw: updated_content_raw
          })
          |> Repo.update()

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  defp get_by_artifact_id(artifact_id) do
    case Repo.one(from(a in KnowledgeArtifact, where: a.artifact_id == ^artifact_id)) do
      nil -> {:error, :not_found}
      artifact -> {:ok, artifact}
    end
  end

  # ===========================
  # Embedding Generation
  # ===========================

  defp generate_embedding_async(artifact) do
    # Generate text for embedding (combines key fields)
    text = generate_embedding_text(artifact)

    case Singularity.FastEmbeddingService.embed(text) do
      {:ok, embedding} ->
        artifact
        |> KnowledgeArtifact.changeset(%{embedding: embedding})
        |> Repo.update()

        Logger.debug("Generated embedding for #{artifact.artifact_type}/#{artifact.artifact_id}")

      {:error, reason} ->
        Logger.error(
          "Failed to generate embedding for #{artifact.artifact_id}: #{inspect(reason)}"
        )
    end
  end

  defp generate_embedding_text(artifact) do
    # Combine relevant fields for embedding
    name = get_in(artifact.content, ["name"]) || artifact.artifact_id
    description = get_in(artifact.content, ["description"]) || ""
    tags = get_in(artifact.content, ["tags"]) || []

    "#{name}\n#{description}\n#{Enum.join(tags, " ")}"
  end

  @doc """
  Create vector index after bulk data load.

  This should be run ONCE after initial data migration, or after bulk imports.
  """
  def create_vector_index do
    Repo.query("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS knowledge_artifacts_embedding_idx
    ON knowledge_artifacts
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100)
    """)
  end
end
