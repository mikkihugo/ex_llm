defmodule Singularity.Schemas.KnowledgeArtifact do
  @moduledoc """
  Knowledge Artifact schema - Bidirectional template storage (Git ↔ PostgreSQL)

  Supports:
  - Dual storage: content_raw (TEXT) + content (JSONB)
  - Semantic search: embedding (vector)
  - Learning: usage tracking, AI improvements
  - Versioning: full history
  - Hot reload: LISTEN/NOTIFY triggers
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "knowledge_artifacts" do
    # Template identification
    field :artifact_type, :string
    field :artifact_id, :string
    field :version, :string, default: "1.0.0"

    # Dual storage
    field :content_raw, :string
    field :content, :map

    # Semantic search
    field :embedding, Pgvector.Ecto.Vector

    # Learning metadata
    field :source, :string, default: "git" # 'git' or 'learned'
    field :learned_from, :map

    # Usage tracking
    field :usage_count, :integer, default: 0
    field :success_count, :integer, default: 0
    field :failure_count, :integer, default: 0
    field :avg_performance_ms, :float
    field :user_ratings, {:array, :float}, default: []

    # Change tracking
    field :created_by, :string
    field :change_reason, :string

    # Versioning
    belongs_to :previous_version, __MODULE__, type: :binary_id

    # Generated columns (read-only)
    field :language, :string, virtual: true
    field :category, :string, virtual: true
    field :tags, {:array, :string}, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating knowledge artifacts
  """
  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [
      :artifact_type,
      :artifact_id,
      :version,
      :content_raw,
      :content,
      :embedding,
      :source,
      :learned_from,
      :usage_count,
      :success_count,
      :failure_count,
      :avg_performance_ms,
      :user_ratings,
      :created_by,
      :change_reason,
      :previous_version_id
    ])
    |> validate_required([:artifact_type, :artifact_id, :version, :content_raw, :content])
    |> validate_inclusion(:source, ["git", "learned"])
    |> validate_content_consistency()
    |> unique_constraint([:artifact_type, :artifact_id, :version])
  end

  @doc """
  Changeset for tracking usage
  """
  def usage_changeset(artifact, result) do
    artifact
    |> change(%{
      usage_count: artifact.usage_count + 1,
      success_count: artifact.success_count + if(result.success?, do: 1, else: 0),
      failure_count: artifact.failure_count + if(result.success?, do: 0, else: 1),
      avg_performance_ms: calculate_avg_performance(artifact, result.duration_ms)
    })
  end

  defp calculate_avg_performance(artifact, new_duration) do
    if artifact.avg_performance_ms do
      (artifact.avg_performance_ms * artifact.usage_count + new_duration) / (artifact.usage_count + 1)
    else
      new_duration
    end
  end

  @doc """
  Validate that content matches content_raw
  """
  defp validate_content_consistency(changeset) do
    content_raw = get_field(changeset, :content_raw)
    content = get_field(changeset, :content)

    if content_raw && content do
      case Jason.decode(content_raw) do
        {:ok, parsed} when parsed == content ->
          changeset

        {:ok, _parsed} ->
          add_error(changeset, :content, "content must match content_raw when parsed as JSON")

        {:error, _} ->
          add_error(changeset, :content_raw, "must be valid JSON")
      end
    else
      changeset
    end
  end

  ## Queries

  @doc """
  Get latest version of an artifact
  """
  def latest_version(query \\ __MODULE__, artifact_id) do
    from a in query,
      where: a.artifact_id == ^artifact_id,
      order_by: [desc: a.inserted_at],
      limit: 1
  end

  @doc """
  Get artifacts by type
  """
  def by_type(query \\ __MODULE__, type) do
    from a in query, where: a.artifact_type == ^type
  end

  @doc """
  Get artifacts by category (uses generated column)
  """
  def by_category(query \\ __MODULE__, category) do
    from a in query, where: fragment("category = ?", ^category)
  end

  @doc """
  Get learned templates (high usage + success)
  """
  def learning_candidates(query \\ __MODULE__, min_usage \\ 1000, min_success_rate \\ 0.95) do
    from a in query,
      where: a.usage_count >= ^min_usage,
      where: fragment("?::float / NULLIF(?, 0) >= ?", a.success_count, a.usage_count, ^min_success_rate),
      where: a.source == "git",
      order_by: [desc: a.usage_count]
  end

  @doc """
  Semantic search by embedding
  """
  def semantic_search(query \\ __MODULE__, embedding, limit \\ 10) do
    from a in query,
      order_by: fragment("embedding <-> ?", ^embedding),
      limit: ^limit
  end

  @doc """
  JSONB queries - find by content
  """
  def with_content(query \\ __MODULE__, content_filter) do
    from a in query,
      where: fragment("content @> ?::jsonb", ^Jason.encode!(content_filter))
  end

  @doc """
  Full-text search in content_raw
  """
  def full_text_search(query \\ __MODULE__, search_term) do
    from a in query,
      where: fragment(
        "to_tsvector('english', content_raw) @@ plainto_tsquery('english', ?)",
        ^search_term
      )
  end

  @doc """
  Get version history for an artifact
  """
  def version_history(artifact_id) do
    from a in __MODULE__,
      where: a.artifact_id == ^artifact_id,
      order_by: [desc: a.inserted_at],
      preload: [:previous_version]
  end
end
