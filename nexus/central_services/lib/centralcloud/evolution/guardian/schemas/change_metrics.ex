defmodule CentralCloud.Evolution.Guardian.Schemas.ChangeMetrics do
  @moduledoc """
  Schema for tracking real-time metrics for approved changes.

  Stores time-series metrics reported by instances to detect threshold breaches
  and trigger auto-rollback when changes degrade performance.

  ## Table Structure

  - Primary Key: `id` (UUID, autogenerate)
  - Foreign Keys: `change_id` → approved_changes
  - Indexes: change_id, reported_at (for time-series queries)

  ## Module Identity (JSON)
  ```json
  {
    "module": "CentralCloud.Evolution.Guardian.Schemas.ChangeMetrics",
    "purpose": "Track real-time metrics for threshold-based rollback",
    "role": "schema",
    "layer": "centralcloud",
    "table": "change_metrics",
    "relationships": {
      "belongs_to": "ApprovedChange - the change being monitored"
    }
  }
  ```

  ## Anti-Patterns

  - ❌ DO NOT delete old metrics - use for trend analysis
  - ❌ DO NOT skip reported_at timestamp - required for time-series
  - ✅ DO partition by reported_at for performance (future optimization)
  - ✅ DO aggregate metrics for long-term storage
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "change_metrics" do
    belongs_to :change, CentralCloud.Evolution.Guardian.Schemas.ApprovedChange,
      foreign_key: :change_id,
      references: :id

    field :instance_id, :string
    field :success_rate, :float
    field :error_rate, :float
    field :latency_p95_ms, :integer
    field :cost_cents, :float
    field :throughput_per_min, :integer
    field :reported_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for recording change metrics.

  ## Required Fields
  - change_id
  - instance_id
  - reported_at
  - At least one metric field (success_rate, error_rate, latency_p95_ms, cost_cents, throughput_per_min)
  """
  def changeset(metrics, attrs) do
    metrics
    |> cast(attrs, [
      :change_id,
      :instance_id,
      :success_rate,
      :error_rate,
      :latency_p95_ms,
      :cost_cents,
      :throughput_per_min,
      :reported_at
    ])
    |> validate_required([:change_id, :instance_id, :reported_at])
    |> validate_number(:success_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:error_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:latency_p95_ms, greater_than_or_equal_to: 0)
    |> validate_number(:cost_cents, greater_than_or_equal_to: 0.0)
    |> validate_number(:throughput_per_min, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:change_id)
  end
end
