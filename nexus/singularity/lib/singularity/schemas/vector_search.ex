defmodule Singularity.Schemas.VectorSearch do
  @moduledoc """
  VectorSearch schema - Semantic search vectors for code content.

  Stores vector embeddings for different types of content (functions, classes, files)
  to enable semantic similarity search. Used for finding conceptually similar code.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "vector_search" do
    field :codebase_id, :string
    field :file_path, :string
    field :content_type, :string
    field :content, :string
    field :vector_embedding, Pgvector.Ecto.Vector
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(vector_search, attrs) do
    vector_search
    |> cast(attrs, [
      :codebase_id,
      :file_path,
      :content_type,
      :content,
      :vector_embedding,
      :metadata
    ])
    |> validate_required([:codebase_id, :file_path, :content_type, :content, :vector_embedding])
    |> unique_constraint([:codebase_id, :file_path, :content_type])
  end
end
