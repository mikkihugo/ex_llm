defmodule Singularity.Infrastructure.QuantumFlow.Workflow do
  @moduledoc """
  Persistent record for QuantumFlow workflow requests tracked inside Singularity.

  Each entry mirrors the request payload sent to the shared QuantumFlow instance so
  operators can introspect pending workflows directly from the database.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "quantum_flow_workflows" do
    field :workflow_id, :string
    field :type, :string
    field :payload, :map
    field :status, :string, default: "pending"
    field :expires_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset helper for creating or updating workflow records.
  """
  def changeset(workflow, attrs) do
    workflow
    |> cast(attrs, [:workflow_id, :type, :payload, :status, :expires_at])
    |> validate_required([:workflow_id, :type, :payload])
  end
end
