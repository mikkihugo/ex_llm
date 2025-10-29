defmodule Singularity.Metrics.Event do
  @moduledoc """
  Metrics Event Schema - Raw measurement events from all sources.

  Stores individual metric measurements (latency, cost, success rate, etc.)
  from Telemetry, RateLimiter, ErrorRateTracker, and other sources.

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Metrics.Event",
    "purpose": "Raw metrics event storage in unified system",
    "role": "schema",
    "layer": "monitoring",
    "table": "metrics_events",
    "features": ["telemetry", "measurement_validation", "tagged_events"]
  }
  ```

  ### Anti-Patterns
  - ❌ DO NOT use Metrics.AggregatedData for raw events - use this schema
  - ❌ DO NOT allow NaN or Infinity measurements - validation prevents this
  - ✅ DO use this for all raw metric measurements (latency, cost, success rate)
  - ✅ DO tag events with contextual data for aggregation

  ### Search Keywords
  metrics event, telemetry, raw measurement, monitoring, observability,
  event tracking, performance tracking, cost tracking, latency, tags

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

  defp validate_measurement_valid(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      cond do
        not is_number(value) -> [{field, "must be a number"}]
        is_nan(value) -> [{field, "cannot be NaN"}]
        is_infinity(value) -> [{field, "cannot be infinity"}]
        true -> []
      end
    end)
  end

  # Helper functions for NaN and Infinity checking
  defp is_nan(value) when is_float(value), do: value != value
  defp is_nan(_), do: false

  defp is_infinity(value) when is_float(value) do
    value == :infinity or value == :neg_infinity
  end

  defp is_infinity(_), do: false
end
