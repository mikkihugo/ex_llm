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

  schema "curated_knowledge_artifacts" do
    # Template identification
    field :artifact_type, :string
    field :artifact_id, :string
    field :version, :string, default: "1.0.0"

    # Dual storage (dual storage pattern: raw JSON + parsed JSONB)
    field :content_raw, :string
    field :content, :map

    # Generated columns (read-only) - extracted from JSONB content
    field :language, :string
    field :tags, {:array, :string}

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
      :content
    ])
    |> validate_required([:artifact_type, :artifact_id, :version, :content_raw, :content])
    |> validate_content_consistency()
    |> unique_constraint([:artifact_type, :artifact_id, :version])
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
      where:
        fragment(
          "to_tsvector('english', content_raw) @@ plainto_tsquery('english', ?)",
          ^search_term
        )
  end

end
