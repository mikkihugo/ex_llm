defmodule Singularity.Schemas.TechnologyTemplate do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "technology_templates" do
    field :identifier, :string
    field :category, :string
    field :version, :string
    field :source, :string
    field :template, :map
    field :metadata, :map, default: %{}
    field :checksum, :string

    timestamps(type: :utc_datetime_usec)
  end

  @required ~w(identifier category template)a

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:identifier, :category, :version, :source, :template, :metadata, :checksum])
    |> validate_required(@required)
    |> unique_constraint(:identifier)
    |> validate_template_is_object()
  end

  defp validate_template_is_object(changeset) do
    case get_field(changeset, :template) do
      %{} -> changeset
      _ -> add_error(changeset, :template, "must be a JSON object")
    end
  end
end
