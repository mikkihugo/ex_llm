defmodule Singularity.Schemas.PackageCodeExample do
  @moduledoc """
  Schema for package_code_examples table - code examples extracted from package documentation

  Stores real code examples from package sources (examples/ directories, official docs, tests)
  with embeddings for semantic search. These are curated examples, not user code.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "dependency_catalog_examples" do
    field :title, :string
    field :code, :string
    field :language, :string
    field :explanation, :string
    field :tags, {:array, :string}
    field :code_embedding, Pgvector.Ecto.Vector
    field :example_order, :integer

    belongs_to :package, Singularity.Schemas.DependencyCatalog,
      foreign_key: :dependency_id,
      type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(example, attrs) do
    example
    |> cast(attrs, [
      :dependency_id,
      :title,
      :code,
      :language,
      :explanation,
      :tags,
      :code_embedding,
      :example_order
    ])
    |> validate_required([:dependency_id, :title, :code])
    |> foreign_key_constraint(:dependency_id)
  end
end
