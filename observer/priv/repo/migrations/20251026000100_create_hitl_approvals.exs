defmodule Observer.Repo.Migrations.CreateHitlApprovals do
  use Ecto.Migration

  def change do
    create table(:hitl_approvals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :request_id, :string, null: false
      add :agent_id, :string
      add :task_type, :string
      add :status, :string, null: false, default: "pending"
      add :decision_reason, :text
      add :decided_by, :string
      add :decided_at, :utc_datetime_usec
      add :payload, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}
      add :expires_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:hitl_approvals, [:request_id])
    create index(:hitl_approvals, [:status])
    create index(:hitl_approvals, [:task_type])
    create index(:hitl_approvals, [:inserted_at])
  end
end
