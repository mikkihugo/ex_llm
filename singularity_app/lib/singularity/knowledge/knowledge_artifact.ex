defmodule Singularity.Knowledge.KnowledgeArtifact do
  @moduledoc """
  Ecto schema for knowledge artifacts (internal tooling).

  Optimized for:
  - Fast iteration (no production constraints)
  - Rich debugging (store everything)
  - Learning loops (usage tracking)
  - Experimentation (flexible JSONB schema)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "curated_knowledge_artifacts" do
    field :artifact_type, :string
    field :artifact_id, :string
    field :version, :string, default: "1.0.0"

    # Dual storage
    field :content_raw, :string
    field :content, :map

    # Semantic search
    field :embedding, Pgvector.Ecto.Vector

    # Generated columns (read-only, set by PostgreSQL)
    field :language, :string, virtual: true, source: :language
    field :tags, {:array, :string}, virtual: true, source: :tags

    # Virtual field for similarity score (populated by queries)
    field :similarity, :float, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [:artifact_type, :artifact_id, :version, :content_raw, :content, :embedding])
    |> validate_required([:artifact_type, :artifact_id, :content_raw, :content])
    |> validate_json_consistency()
    |> unique_constraint([:artifact_type, :artifact_id, :version],
      name: :knowledge_artifacts_unique_idx
    )
  end

  # Ensure content_raw and content are consistent
  defp validate_json_consistency(changeset) do
    content_raw = get_field(changeset, :content_raw)
    content = get_field(changeset, :content)

    if content_raw && content do
      case Jason.decode(content_raw) do
        {:ok, parsed} ->
          if parsed == content do
            changeset
          else
            add_error(changeset, :content_raw, "does not match parsed content")
          end

        {:error, _} ->
          add_error(changeset, :content_raw, "is not valid JSON")
      end
    else
      changeset
    end
  end
end
