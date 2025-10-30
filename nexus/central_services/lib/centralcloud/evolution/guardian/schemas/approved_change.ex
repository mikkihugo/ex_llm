defmodule CentralCloud.Evolution.Guardian.Schemas.ApprovedChange do
  @moduledoc """
  Schema for tracking approved changes across all instances.

  Stores all registered changes with their safety profiles, code changesets,
  and rollback history for learning optimal rollback strategies.

  ## Table Structure

  - Primary Key: `id` (UUID, provided by caller)
  - Foreign Keys: None (cross-instance tracking)
  - Indexes: instance_id, change_type, status, registered_at

  ## Module Identity (JSON)
  ```json
  {
    "module": "CentralCloud.Evolution.Guardian.Schemas.ApprovedChange",
    "purpose": "Track approved code changes for rollback coordination",
    "role": "schema",
    "layer": "centralcloud",
    "table": "approved_changes",
    "relationships": {
      "has_many": "ChangeMetrics - real-time metrics for this change"
    }
  }
  ```

  ## Anti-Patterns

  - ❌ DO NOT insert without instance_id - required for cross-instance tracking
  - ❌ DO NOT modify status without updating updated_at timestamp
  - ✅ DO include full code_changeset for rollback capability
  - ✅ DO track rollback_strategy for learning
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "approved_changes" do
    field :instance_id, :string
    field :change_type, :string
    field :code_changeset, :map
    field :safety_profile, :map
    field :status, :string
    field :rollback_strategy, :map
    field :rollback_history, {:array, :map}

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating/updating approved changes.

  ## Required Fields
  - instance_id
  - change_type
  - code_changeset
  - safety_profile
  - status

  ## Validations
  - status must be one of: active, rolled_back, superseded, expired
  - change_type must be one of: pattern_enhancement, model_optimization, cache_improvement, code_refactoring
  """
  def changeset(change, attrs) do
    change
    |> cast(attrs, [
      :id,
      :instance_id,
      :change_type,
      :code_changeset,
      :safety_profile,
      :status,
      :rollback_strategy,
      :rollback_history
    ])
    |> validate_required([
      :instance_id,
      :change_type,
      :code_changeset,
      :safety_profile,
      :status
    ])
    |> validate_inclusion(:status, ["active", "rolled_back", "superseded", "expired"])
    |> validate_inclusion(:change_type, [
      "pattern_enhancement",
      "model_optimization",
      "cache_improvement",
      "code_refactoring"
    ])
  end
end
