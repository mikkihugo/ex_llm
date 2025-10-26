defmodule Observer.HITL.Approval do
  @moduledoc """
  HITL Approval schema representing a human decision required for an AI task.

  Records inbound approval requests, their payload, and the eventual decision
  made by a human operator.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_keys_type :binary_id

  @statuses [:pending, :approved, :rejected, :cancelled]

  schema "hitl_approvals" do
    field :request_id, :string
    field :agent_id, :string
    field :task_type, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :decision_reason, :string
    field :decided_by, :string
    field :decided_at, :utc_datetime_usec

    field :payload, :map, default: %{}
    field :metadata, :map, default: %{}
    field :expires_at, :utc_datetime_usec
    field :response_queue, :string

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Base changeset used for inserting or updating general fields.
  """
  def changeset(approval, attrs) do
    approval
    |> cast(attrs, [
      :request_id,
      :agent_id,
      :task_type,
      :status,
      :decision_reason,
      :decided_by,
      :decided_at,
      :payload,
      :metadata,
      :expires_at,
      :response_queue
    ])
    |> validate_required([:request_id, :payload])
    |> validate_length(:request_id, max: 255)
    |> validate_length(:agent_id, max: 255)
    |> validate_length(:task_type, max: 255)
    |> validate_length(:response_queue, max: 255)
    |> put_default(:payload, %{})
    |> put_default(:metadata, %{})
    |> unique_constraint(:request_id)
  end

  @doc """
  Changeset for recording a human decision (approve/reject/cancel).
  """
  def decision_changeset(approval, attrs) do
    approval
    |> cast(attrs, [:status, :decision_reason, :decided_by, :decided_at])
    |> validate_required([:status, :decided_by])
    |> validate_inclusion(:status, [:approved, :rejected, :cancelled])
    |> ensure_decided_at()
  end

  def pending?(%__MODULE__{status: :pending}), do: true
  def pending?(_), do: false

  def statuses, do: @statuses

  defp put_default(changeset, field, default) do
    case fetch_field(changeset, field) do
      {:changes, _} -> changeset
      {:data, value} when value not in [nil, %{}] -> changeset
      _ -> put_change(changeset, field, default)
    end
  end

  defp ensure_decided_at(changeset) do
    case get_field(changeset, :decided_at) do
      nil -> put_change(changeset, :decided_at, DateTime.utc_now())
      _ -> changeset
    end
  end
end
