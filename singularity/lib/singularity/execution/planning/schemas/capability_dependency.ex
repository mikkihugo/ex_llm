defmodule Singularity.Execution.Planning.Schemas.CapabilityDependency do
  @moduledoc """
  Capability Dependency schema for tracking dependencies between capabilities with validation.

  Manages dependency relationships between capabilities to ensure proper
  work ordering and prevent circular dependencies with self-reference validation
  and unique constraint enforcement.

  ## Integration Points

  This module integrates with:
  - `Singularity.Execution.Planning.Schemas.Capability` - Capability relationships (belongs_to associations)
  - PostgreSQL table: `capability_dependencies` (stores dependency relationships)

  ## Usage

      # Create dependency changeset
      changeset = CapabilityDependency.changeset(%CapabilityDependency{}, %{
        capability_id: "cap-123",
        depends_on_capability_id: "cap-456"
      })
      # => #Ecto.Changeset<...>

      # Validate self-reference prevention
      invalid_changeset = CapabilityDependency.changeset(%CapabilityDependency{}, %{
        capability_id: "cap-123",
        depends_on_capability_id: "cap-123"  # Self-reference - will be invalid
      })
      # => #Ecto.Changeset<...> with error: "cannot depend on itself"
  """

  use Ecto.Schema
  import Ecto.Changeset

  # INTEGRATION: Capability relationships (belongs_to associations)
  alias Singularity.Execution.Planning.Schemas.Capability

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
