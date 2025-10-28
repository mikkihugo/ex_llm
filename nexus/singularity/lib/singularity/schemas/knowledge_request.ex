defmodule Singularity.Schemas.KnowledgeRequest do
  @moduledoc """
  Generic knowledge request ticket used to coordinate between Singularity
  and CentralCloud/PGFlow workflows.

  Supports multiple request types (patterns, signatures, datasets, models, workflows)
  and tracks lifecycle state so downstream systems can react via NOTIFY.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type status :: :pending | :in_progress | :resolved | :failed
  @type request_type :: :pattern | :signature | :dataset | :model | :workflow | :anti_pattern

  @statuses [:pending, :in_progress, :resolved, :failed]
  @request_types [:pattern, :signature, :dataset, :model, :workflow, :anti_pattern]

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "knowledge_requests" do
    field :request_type, Ecto.Enum, values: @request_types
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :external_key, :string
    field :payload, :map
    field :source, :string
    field :source_reference, :string
    field :retry_at, :utc_datetime_usec
    field :last_error, :string
    field :resolution_payload, :map
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def create_changeset(request, attrs) do
    request
    |> cast(attrs, [
      :request_type,
      :status,
      :external_key,
      :payload,
      :source,
      :source_reference,
      :retry_at,
      :last_error,
      :resolution_payload,
      :metadata
    ])
    |> validate_required([:request_type, :external_key, :payload, :source])
    |> validate_length(:external_key, max: 255)
    |> unique_constraint(:external_key, name: "knowledge_requests_external_key_index")
  end

  @doc false
  def status_changeset(request, attrs) do
    request
    |> cast(attrs, [:status, :retry_at, :last_error, :resolution_payload, :metadata])
    |> validate_required([:status])
  end
end
