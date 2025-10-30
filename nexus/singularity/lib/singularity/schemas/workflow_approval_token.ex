defmodule Singularity.Schemas.WorkflowApprovalToken do
  @moduledoc """
  Persistent approval tokens for QuantumFlow workflows.

  Tokens are stored in PostgreSQL for durability and auditable workflows.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:token, :string, []}

  schema "workflow_approval_tokens" do
    field :workflow_slug, :string
    field :payload, :map
    field :status, :string, default: "pending"
    field :expires_at, :utc_datetime_usec
    field :consumed_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Create changeset for issuing a new approval token.
  """
  def creation_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:token, :workflow_slug, :payload, :status, :expires_at])
    |> validate_required([:token, :payload, :expires_at])
    |> validate_inclusion(:status, ["pending", "consumed", "expired"])
  end

  @doc """
  Mark a token as consumed.
  """
  def consume_changeset(%__MODULE__{} = token, consumed_at \\ DateTime.utc_now()) do
    token
    |> change(%{status: "consumed", consumed_at: consumed_at})
  end

  @doc """
  Mark a token as expired.
  """
  def expire_changeset(%__MODULE__{} = token, expired_at \\ DateTime.utc_now()) do
    token
    |> change(%{status: "expired", consumed_at: expired_at})
  end
end
