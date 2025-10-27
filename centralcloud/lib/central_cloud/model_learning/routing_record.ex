defmodule CentralCloud.ModelLearning.RoutingRecord do
  @moduledoc """
  Audit log of all routing decisions from Singularity instances.

  Tracks every model selection decision for learning and debugging.

  ## Attributes

  - `timestamp` - When routing decision was made
  - `instance_id` - Which Singularity instance made decision
  - `complexity` - Task complexity: "simple", "medium", "complex"
  - `model` - Model name selected
  - `provider` - Provider name
  - `score` - Complexity score used (0.0-5.0)
  - `outcome` - Status: "routed", "success", "failure"
  - `response_time_ms` - Response time in milliseconds
  - `capabilities_required` - Required capabilities used for filtering
  - `preference` - Selection preference: "speed" or "cost"
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :bigserial, autogenerate: true}
  schema "routing_records" do
    field :timestamp, :utc_datetime
    field :instance_id, :string
    field :complexity, :string
    field :model, :string
    field :provider, :string
    field :score, :float
    field :outcome, :string
    field :response_time_ms, :integer
    field :capabilities_required, {:array, :string}, default: []
    field :preference, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :timestamp,
      :instance_id,
      :complexity,
      :model,
      :provider,
      :score,
      :outcome,
      :response_time_ms,
      :capabilities_required,
      :preference
    ])
    |> validate_required([
      :timestamp,
      :instance_id,
      :complexity,
      :model,
      :provider,
      :score
    ])
    |> validate_inclusion(:complexity, ["simple", "medium", "complex"])
    |> validate_inclusion(:outcome, ["routed", "success", "failure"])
  end
end
