defmodule Singularity.Infrastructure.PgFlow.Workflow do
  @moduledoc """
  Ecto schema for a PgFlow workflow.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "pgflow_workflows" do
    field :workflow_id, :string
    field :type, :string
    field :payload, :map
    field :status, :string, default: "pending"

    timestamps()
  end

  @doc false
  def changeset(workflow, attrs) do
    workflow
    |> cast(attrs, [:workflow_id, :type, :payload, :status])
    |> validate_required([:workflow_id, :type])
    |> unique_constraint(:workflow_id)
  end
end
