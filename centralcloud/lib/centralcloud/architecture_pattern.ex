defmodule CentralCloud.ArchitecturePattern do
  @moduledoc """
  Schema for architecture pattern definitions.

  Stores pattern metadata imported from templates_data/architecture_patterns/
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "architecture_patterns" do
    field :pattern_id, :string
    field :name, :string
    field :category, :string
    field :version, :string

    field :description, :string
    field :metadata, :map
    field :indicators, {:array, :map}
    field :benefits, {:array, :string}
    field :concerns, {:array, :string}

    field :detection_template, :string
    field :embedding, Pgvector.Ecto.Vector

    timestamps()
  end

  @doc false
  def changeset(pattern, attrs) do
    pattern
    |> cast(attrs, [
      :id,
      :pattern_id,
      :name,
      :category,
      :version,
      :description,
      :metadata,
      :indicators,
      :benefits,
      :concerns,
      :detection_template,
      :embedding
    ])
    |> validate_required([:pattern_id, :name, :category, :version])
    |> unique_constraint([:pattern_id, :version])
  end
end
