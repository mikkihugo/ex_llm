defmodule Singularity.Schemas.PackageDependency do
  @moduledoc """
  Schema for package_dependencies table - dependencies of packages from registries

  Tracks what other packages a package depends on, with version constraints and dependency types
  (runtime, dev, peer, optional).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "tool_dependencies" do
    field :dependency_name, :string
    field :dependency_version, :string
    field :dependency_type, :string
    field :is_optional, :boolean

    belongs_to :package, Singularity.Schemas.PackageRegistryKnowledge,
      foreign_key: :tool_id,
      type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(dependency, attrs) do
    dependency
    |> cast(attrs, [
      :tool_id,
      :dependency_name,
      :dependency_version,
      :dependency_type,
      :is_optional
    ])
    |> validate_required([:tool_id, :dependency_name])
    |> validate_inclusion(:dependency_type, ["runtime", "dev", "peer", "optional"])
    |> foreign_key_constraint(:tool_id)
  end
end
