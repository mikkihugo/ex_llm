defmodule Singularity.Schemas.PackageCodeExample do
  @moduledoc """
  Schema for package_code_examples table - code examples extracted from package documentation

  Stores real code examples from package sources (examples/ directories, official docs, tests)
  with embeddings for semantic search. These are curated examples, not user code.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "tool_examples" do
    field :title, :string
    field :code, :string
    field :language, :string
    field :explanation, :string
    field :tags, {:array, :string}
    field :code_embedding, Pgvector.Ecto.Vector
    field :example_order, :integer

    belongs_to :package, Singularity.Schemas.PackageRegistryKnowledge, foreign_key: :tool_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(example, attrs) do
    example
    |> cast(attrs, [:tool_id, :title, :code, :language, :explanation, :tags, :code_embedding, :example_order])
    |> validate_required([:tool_id, :title, :code])
    |> foreign_key_constraint(:tool_id)
  end
end
