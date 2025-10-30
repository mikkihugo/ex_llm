defmodule Singularity.Repo.Migrations.CreateWorkflowApprovalTokens do
  use Ecto.Migration

  def change do
    create table(:workflow_approval_tokens, primary_key: false) do
      add :token, :string, primary_key: true
      add :workflow_slug, :string
      add :payload, :map, null: false
      add :status, :string, null: false, default: "pending"
      add :expires_at, :utc_datetime_usec, null: false
      add :consumed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:workflow_approval_tokens, [:workflow_slug])
    create index(:workflow_approval_tokens, [:expires_at])
    create index(:workflow_approval_tokens, [:status])
  end
end
