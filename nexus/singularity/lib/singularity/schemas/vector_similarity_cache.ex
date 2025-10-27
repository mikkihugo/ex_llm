defmodule Singularity.Schemas.VectorSimilarityCache do
  @moduledoc """
  VectorSimilarityCache schema - Cache for vector similarity search results.

  Caches computed similarity scores between query vectors and target files
  to avoid recomputing expensive similarity calculations.

  Used for performance optimization of semantic search operations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "vector_similarity_cache" do
    field :codebase_id, :string
    field :query_vector_hash, :string
    field :target_file_path, :string
    field :similarity_score, :float

    timestamps()
  end

  @doc false
  def changeset(cache, attrs) do
    cache
    |> cast(attrs, [
      :codebase_id,
      :query_vector_hash,
      :target_file_path,
      :similarity_score
    ])
    |> validate_required([:codebase_id, :query_vector_hash, :target_file_path, :similarity_score])
    |> validate_number(:similarity_score,
      greater_than_or_equal_to: -1.0,
      less_than_or_equal_to: 1.0
    )
    |> unique_constraint([:codebase_id, :query_vector_hash, :target_file_path])
  end
end
