defmodule Singularity.Schemas.Template do
  @moduledoc """
  Template schema for centralized template management.

  Templates are loaded from /templates_data (JSON files) and
  stored in PostgreSQL with Qodo-Embed-1 embeddings for fast
  semantic search.
  """

  use Ecto.Schema
  import Ecto.{Changeset, Query}

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  schema "templates" do
    field :version, :string
    field :type, :string

    # JSONB fields
    field :metadata, :map
    field :content, :map
    field :quality, :map
    field :usage, :map, default: %{count: 0, success_rate: 0.0, last_used: nil}

    # Qodo-Embed-1 vector (1536 dimensions)
    field :embedding, Pgvector.Ecto.Vector

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          version: String.t(),
          type: String.t(),
          metadata: map(),
          content: map(),
          quality: map(),
          usage: map(),
          embedding: Pgvector.Ecto.Vector.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Changeset for creating/updating templates.
  """
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:id, :version, :type, :metadata, :content, :quality, :usage, :embedding])
    |> validate_required([:id, :version, :type, :metadata, :content])
    |> validate_inclusion(:type, ["code_pattern", "quality_rule", "workflow", "snippet"])
    |> validate_metadata()
    |> validate_content()
    |> validate_quality()
    |> validate_embedding()
    |> unique_constraint(:id)
  end

  ## Query Helpers

  def by_language(query, language) do
    from t in query,
      where: fragment("?->>'language' = ?", t.metadata, ^language)
  end

  def by_type(query, type) do
    from t in query,
      where: t.type == ^type
  end

  def by_tags(query, tags) when is_list(tags) do
    from t in query,
      where: fragment("? \\?| ?::text[]", t.metadata, ^tags)
  end

  def with_min_quality(query, min_score) do
    from t in query,
      where: fragment("(?->>'score')::float >= ?", t.quality, ^min_score)
  end

  def recently_used(query, limit \\ 10) do
    from t in query,
      where: not is_nil(fragment("?->>'last_used'", t.usage)),
      order_by: [desc: fragment("?->>'last_used'", t.usage)],
      limit: ^limit
  end

  def most_successful(query, limit \\ 10) do
    from t in query,
      where: fragment("(?->>'count')::int > 0", t.usage),
      order_by: [desc: fragment("(?->>'success_rate')::float", t.usage)],
      limit: ^limit
  end

  ## Private Validation Helpers

  defp validate_metadata(changeset) do
    metadata = get_field(changeset, :metadata)

    if metadata do
      required_keys = ["id", "name", "description", "language"]

      missing =
        Enum.filter(required_keys, fn key ->
          !Map.has_key?(metadata, key) || metadata[key] == nil
        end)

      if Enum.empty?(missing) do
        changeset
      else
        add_error(changeset, :metadata, "missing required keys: #{Enum.join(missing, ", ")}")
      end
    else
      changeset
    end
  end

  defp validate_content(changeset) do
    content = get_field(changeset, :content)

    if content do
      if Map.has_key?(content, "code") && content["code"] != nil do
        changeset
      else
        add_error(changeset, :content, "must contain 'code' field")
      end
    else
      changeset
    end
  end

  defp validate_quality(changeset) do
    type = get_field(changeset, :type)
    quality = get_field(changeset, :quality)

    # code_pattern type must have quality score >= 0.80
    if type == "code_pattern" && quality do
      score = quality["score"]

      if score && score >= 0.80 do
        changeset
      else
        add_error(changeset, :quality, "code_pattern must have quality score >= 0.80")
      end
    else
      changeset
    end
  end

  defp validate_embedding(changeset) do
    embedding = get_field(changeset, :embedding)

    if embedding do
      # Qodo-Embed-1 produces 1536-dimensional vectors
      case Pgvector.Ecto.Vector.to_list(embedding) do
        {:ok, list} when length(list) == 1536 ->
          changeset

        {:ok, list} ->
          add_error(
            changeset,
            :embedding,
            "must be 1536 dimensions (Qodo-Embed-1), got #{length(list)}"
          )

        {:error, _} ->
          add_error(changeset, :embedding, "invalid vector format")
      end
    else
      changeset
    end
  end
end
