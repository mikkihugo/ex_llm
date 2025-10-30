defmodule CentralCloud.Evolution.Patterns.Schemas.PatternUsage do
  @moduledoc """
  Schema for tracking pattern usage per instance.

  Records when patterns are used, their success rates, and usage frequency
  to identify high-value patterns for promotion to Genesis.

  ## Table Structure

  - Primary Key: `id` (UUID, autogenerate)
  - Foreign Keys: `pattern_id` → patterns
  - Indexes: pattern_id, instance_id, last_used_at
  - Composite Unique: (pattern_id, instance_id)

  ## Module Identity (JSON)
  ```json
  {
    "module": "CentralCloud.Evolution.Patterns.Schemas.PatternUsage",
    "purpose": "Track pattern usage frequency and success per instance",
    "role": "schema",
    "layer": "centralcloud",
    "table": "pattern_usage",
    "relationships": {
      "belongs_to": "Pattern - the pattern being tracked"
    }
  }
  ```

  ## Anti-Patterns

  - ❌ DO NOT delete usage records - historical data for learning
  - ❌ DO NOT allow duplicate (pattern_id, instance_id) - use upsert
  - ✅ DO increment usage_count on repeated use - aggregate metric
  - ✅ DO update last_used_at - time-series tracking
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pattern_usage" do
    belongs_to :pattern, CentralCloud.Evolution.Patterns.Schemas.Pattern

    field :instance_id, :string
    field :success_rate, :float
    field :usage_count, :integer
    field :last_used_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for recording pattern usage.

  ## Required Fields
  - pattern_id
  - instance_id
  - success_rate
  - usage_count
  - last_used_at
  """
  def changeset(usage, attrs) do
    usage
    |> cast(attrs, [
      :pattern_id,
      :instance_id,
      :success_rate,
      :usage_count,
      :last_used_at
    ])
    |> validate_required([
      :pattern_id,
      :instance_id,
      :success_rate,
      :usage_count,
      :last_used_at
    ])
    |> validate_number(:success_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:usage_count, greater_than_or_equal_to: 1)
    |> unique_constraint([:pattern_id, :instance_id])
    |> foreign_key_constraint(:pattern_id)
  end
end
