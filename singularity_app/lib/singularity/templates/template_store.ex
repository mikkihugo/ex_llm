defmodule Singularity.TemplateStore do
  @moduledoc """
  Centralized template management with Qodo-Embed-1 semantic search.

  All templates stored in `/templates_data` (git-versioned source of truth)
  are synced to PostgreSQL with embeddings for fast runtime access.

  ## Architecture

  ```
  templates_data/*.json (source)
      ↓
  TemplateStore.sync() reads all JSON
      ↓
  EmbeddingEngine.embed_batch() with Qodo-Embed-1
      ↓
  PostgreSQL templates table + pgvector index
      ↓
  Fast semantic search at runtime!
  ```

  ## Usage

      # Sync templates from disk to database
      TemplateStore.sync()

      # Get template by ID
      {:ok, template} = TemplateStore.get("elixir-nats-consumer")

      # Semantic search (uses Qodo-Embed-1)
      {:ok, templates} = TemplateStore.search("async worker pattern",
        language: "elixir",
        top_k: 5
      )

      # Get best templates for a task
      {:ok, best} = TemplateStore.get_best_for_task(
        "NATS consumer with error handling",
        "elixir",
        top_k: 3
      )

      # Track usage (for learning which templates work)
      TemplateStore.record_usage("elixir-nats-consumer", success: true)
  """

  use GenServer
  require Logger

  alias Singularity.{Repo, EmbeddingEngine}
  alias Singularity.Schemas.Template

  @templates_dir Path.join([File.cwd!(), "..", "templates_data"])

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sync all templates from disk to database.

  Reads all JSON files from templates_data/, validates schema,
  generates embeddings with Qodo-Embed-1, and stores in PostgreSQL.
  """
  def sync(opts \\ []) do
    GenServer.call(__MODULE__, {:sync, opts}, :infinity)
  end

  @doc """
  Get template by ID.
  """
  @spec get(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get(template_id) do
    case Repo.get_by(Template, id: template_id) do
      nil -> {:error, :not_found}
      template -> {:ok, template_to_map(template)}
    end
  end

  @doc """
  Search templates semantically using Qodo-Embed-1.

  ## Options

  - `:language` - Filter by language (e.g., "elixir", "rust")
  - `:type` - Filter by type ("code_pattern", "quality_rule", etc.)
  - `:tags` - Filter by tags (list of strings)
  - `:top_k` - Number of results (default: 10)
  - `:min_score` - Minimum similarity score (default: 0.7)
  """
  @spec search(String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def search(query, opts \\ []) do
    language = Keyword.get(opts, :language)
    type = Keyword.get(opts, :type)
    tags = Keyword.get(opts, :tags)
    top_k = Keyword.get(opts, :top_k, 10)
    min_score = Keyword.get(opts, :min_score, 0.7)

    with {:ok, embedding} <- EmbeddingEngine.embed(query, model: :qodo_embed) do
      # Build query with filters
      sql = """
      SELECT
        id,
        version,
        type,
        metadata,
        content,
        quality,
        usage,
        1 - (embedding <=> $1::vector) AS similarity
      FROM templates
      WHERE 1=1
        #{if language, do: "AND metadata->>'language' = $2", else: ""}
        #{if type, do: "AND type = $3", else: ""}
        #{if tags, do: "AND metadata->'tags' ?| $4::text[]", else: ""}
        AND 1 - (embedding <=> $1::vector) >= $5
      ORDER BY similarity DESC
      LIMIT $6
      """

      params =
        [embedding, language, type, tags, min_score, top_k]
        |> Enum.reject(&is_nil/1)

      case Repo.query(sql, params) do
        {:ok, %{rows: rows, columns: columns}} ->
          templates =
            rows
            |> Enum.map(fn row ->
              columns
              |> Enum.zip(row)
              |> Map.new()
              |> parse_template_row()
            end)

          {:ok, templates}

        {:error, reason} ->
          Logger.error("Template search failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc """
  Get best templates for a specific task.

  Combines semantic search with usage statistics to find
  templates that are both relevant AND proven to work.
  """
  @spec get_best_for_task(String.t(), String.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def get_best_for_task(task, language, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 5)

    # Get 3x candidates via semantic search
    with {:ok, candidates} <-
           search(task, language: language, top_k: top_k * 3) do
      # Rank by combined score: similarity * success_rate * quality
      ranked =
        candidates
        |> Enum.map(fn template ->
          combined_score = calculate_combined_score(template)
          Map.put(template, :combined_score, combined_score)
        end)
        |> Enum.sort_by(& &1.combined_score, :desc)
        |> Enum.take(top_k)

      {:ok, ranked}
    end
  end

  @doc """
  Record template usage for learning.

  Tracks which templates are used and whether they led to
  successful code generation (user accepted the code).
  """
  @spec record_usage(String.t(), keyword()) :: :ok | {:error, term()}
  def record_usage(template_id, opts) do
    success = Keyword.get(opts, :success, true)

    sql = """
    UPDATE templates
    SET
      usage = jsonb_set(
        jsonb_set(
          jsonb_set(
            usage,
            '{count}',
            ((usage->>'count')::int + 1)::text::jsonb
          ),
          '{last_used}',
          to_jsonb(NOW()::text)
        ),
        '{success_rate}',
        CASE
          WHEN (usage->>'count')::int = 0 THEN
            #{if success, do: "1.0", else: "0.0"}::text::jsonb
          ELSE
            (
              (
                (usage->>'success_rate')::float * (usage->>'count')::int
                + #{if success, do: "1.0", else: "0.0"}
              ) / ((usage->>'count')::int + 1)
            )::text::jsonb
        END
      ),
      updated_at = NOW()
    WHERE id = $1
    """

    case Repo.query(sql, [template_id]) do
      {:ok, _} ->
        Logger.debug("Recorded usage for template: #{template_id}, success: #{success}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to record usage: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  List all templates with optional filters.
  """
  def list(opts \\ []) do
    language = Keyword.get(opts, :language)
    type = Keyword.get(opts, :type)

    query = Template
    query = if language, do: Template.by_language(query, language), else: query
    query = if type, do: Template.by_type(query, type), else: query

    templates = Repo.all(query)
    {:ok, Enum.map(templates, &template_to_map/1)}
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    # Auto-sync on startup if configured
    if Application.get_env(:singularity, :templates)[:sync_on_startup] do
      Task.start(fn -> sync() end)
    end

    {:ok, %{}}
  end

  @impl true
  def handle_call({:sync, opts}, _from, state) do
    result = do_sync(opts)
    {:reply, result, state}
  end

  ## Private Functions

  defp do_sync(opts) do
    force = Keyword.get(opts, :force, false)

    Logger.info("Syncing templates from #{@templates_dir}")

    with {:ok, files} <- find_all_template_files(),
         {:ok, templates} <- load_and_validate_templates(files),
         {:ok, count} <- upsert_templates(templates, force) do
      Logger.info("✅ Synced #{count} templates to database")
      {:ok, count}
    else
      {:error, reason} ->
        Logger.error("Template sync failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp find_all_template_files do
    files =
      @templates_dir
      |> Path.join("**/*.json")
      |> Path.wildcard()
      |> Enum.reject(&String.ends_with?(&1, "schema.json"))

    {:ok, files}
  rescue
    e -> {:error, e}
  end

  defp load_and_validate_templates(files) do
    templates =
      files
      |> Enum.map(&load_and_validate_template/1)
      |> Enum.filter(fn
        {:ok, _} -> true
        {:error, reason} ->
          Logger.warninging("Skipping invalid template: #{inspect(reason)}")
          false
      end)
      |> Enum.map(fn {:ok, template} -> template end)

    {:ok, templates}
  end

  defp load_and_validate_template(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, data} <- Jason.decode(content),
         :ok <- validate_schema(data) do
      {:ok, data}
    end
  end

  defp validate_schema(data) do
    # TODO: Implement JSON schema validation
    # For now, just check required fields
    required = ["version", "type", "metadata", "content"]

    if Enum.all?(required, &Map.has_key?(data, &1)) do
      :ok
    else
      {:error, :invalid_schema}
    end
  end

  defp upsert_templates(templates, force) do
    count =
      templates
      |> Enum.map(&upsert_template(&1, force))
      |> Enum.count(fn
        {:ok, _} -> true
        _ -> false
      end)

    {:ok, count}
  end

  defp upsert_template(data, force) do
    template_id = get_in(data, ["metadata", "id"])

    # Check if exists
    existing = Repo.get_by(Template, id: template_id)

    if existing && !force do
      # Skip if not forcing update
      {:ok, :skipped}
    else
      # Generate embedding
      search_text = build_search_text(data)

      with {:ok, embedding} <- EmbeddingEngine.embed(search_text, model: :qodo_embed) do
        # Upsert template
        attrs = %{
          id: template_id,
          version: data["version"],
          type: data["type"],
          metadata: Map.put(data["metadata"], "embedding", embedding),
          content: data["content"],
          quality: data["quality"] || %{},
          usage: data["usage"] || %{count: 0, success_rate: 0.0, last_used: nil},
          embedding: embedding
        }

        if existing do
          Template.changeset(existing, attrs)
          |> Repo.update()
        else
          %Template{}
          |> Template.changeset(attrs)
          |> Repo.insert()
        end
      end
    end
  end

  defp build_search_text(data) do
    [
      get_in(data, ["metadata", "name"]),
      get_in(data, ["metadata", "description"]),
      get_in(data, ["metadata", "language"]),
      Enum.join(get_in(data, ["metadata", "tags"]) || [], " "),
      String.slice(get_in(data, ["content", "code"]) || "", 0..500)
    ]
    |> Enum.join(" ")
  end

  defp calculate_combined_score(template) do
    similarity = template[:similarity] || 0.8
    success_rate = get_in(template, [:usage, :success_rate]) || 0.5
    quality_score = get_in(template, [:quality, :score]) || 0.8
    usage_count = get_in(template, [:usage, :count]) || 0

    # Weight: similarity (50%) + success_rate (30%) + quality (20%)
    # Boost templates that have been used successfully
    usage_boost = :math.log(usage_count + 1) / 10

    (similarity * 0.5 + success_rate * 0.3 + quality_score * 0.2 + usage_boost)
    |> min(1.0)
  end

  defp template_to_map(template) do
    %{
      id: template.id,
      version: template.version,
      type: template.type,
      metadata: template.metadata,
      content: template.content,
      quality: template.quality,
      usage: template.usage
    }
  end

  defp parse_template_row(row) do
    %{
      id: row["id"],
      version: row["version"],
      type: row["type"],
      metadata: row["metadata"],
      content: row["content"],
      quality: row["quality"],
      usage: row["usage"],
      similarity: row["similarity"]
    }
  end
end
