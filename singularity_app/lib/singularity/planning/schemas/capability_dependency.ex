defmodule Singularity.Planning.Schemas.CapabilityDependency do
  @moduledoc """
  Capability Dependency - Tracks dependencies between capabilities

  Used to ensure proper ordering of work based on dependencies.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Singularity.Planning.Schemas.Capability

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "capability_dependencies" do
    belongs_to :capability, Capability
    belongs_to :depends_on_capability, Capability

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a capability dependency.
  """
  def changeset(dependency, attrs) do
    dependency
    |> cast(attrs, [:capability_id, :depends_on_capability_id])
    |> validate_required([:capability_id, :depends_on_capability_id])
    |> validate_not_self_referencing()
    |> foreign_key_constraint(:capability_id)
    |> foreign_key_constraint(:depends_on_capability_id)
    |> unique_constraint([:capability_id, :depends_on_capability_id],
      name: :capability_dependencies_unique
    )
  end

  defp validate_not_self_referencing(changeset) do
    capability_id = get_field(changeset, :capability_id)
    depends_on_id = get_field(changeset, :depends_on_capability_id)

    if capability_id && depends_on_id && capability_id == depends_on_id do
      add_error(changeset, :depends_on_capability_id, "cannot depend on itself")
    else
      changeset
    end
  end
end
