defmodule Centralcloud.Schemas.PackageExample do
  @moduledoc """
  Package example schema for storing usage examples.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "package_examples" do
    belongs_to :package, Centralcloud.Schemas.Package

    field :title, :string
    field :description, :string
    field :code, :string
    field :language, :string
    field :source, :string

    field :created_at, :utc_datetime
  end

  def changeset(example, attrs) do
    example
    |> cast(attrs, [:package_id, :title, :description, :code, :language, :source, :created_at])
    |> validate_required([:title, :code, :language])
    |> foreign_key_constraint(:package_id)
  end
end
