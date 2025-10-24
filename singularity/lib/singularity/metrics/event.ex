defmodule Singularity.Metrics.Event do
  @moduledoc """
  Metrics Event Schema - Raw measurement events from all sources.

  Stores individual metric measurements (latency, cost, success rate, etc.)
  from Telemetry, RateLimiter, ErrorRateTracker, and other sources.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Metrics.Event",
    "purpose": "Raw metrics event storage in unified system",
    "layer": "metrics",
    "status": "production",
    "table": "metrics_events"
  }
  ```

  ## Fields

  - `event_name` - Event identifier: "agent.success", "llm.cost", "search.latency", etc.
  - `measurement` - The numeric value (latency_ms, cost_usd, count, etc.)
  - `unit` - Unit of measurement: "ms", "usd", "count", "%", etc.
  - `tags` - JSONB map of contextual data: {agent_id, model, operation, environment, ...}
  - `recorded_at` - When the event occurred

  ## Example Events

  ```
  {event_name: "agent.success", measurement: 1, unit: "count", tags: {agent_id: "123"}}
  {event_name: "llm.cost", measurement: 0.025, unit: "usd", tags: {model: "claude-opus"}}
  {event_name: "search.latency", measurement: 245, unit: "ms", tags: {query: "async"}}
  {event_name: "error.rate", measurement: 1, unit: "count", tags: {operation: "inference"}}
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "metrics_events" do
    field :event_name, :string
    field :measurement, :float
    field :unit, :string
    field :tags, :map, default: %{}
    field :recorded_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_name, :measurement, :unit, :tags, :recorded_at])
    |> validate_required([:event_name, :measurement, :unit, :recorded_at])
    |> validate_measurement_valid(:measurement)
  end

  @doc """
  Validate that measurement is a valid number (not NaN or Infinity).
  """
  defp validate_measurement_valid(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      cond do
        not is_number(value) -> [{field, "must be a number"}]
        :math.is_nan(value) -> [{field, "cannot be NaN"}]
        :math.is_inf(value) != 0 -> [{field, "cannot be infinity"}]
        true -> []
      end
    end)
  end
end
