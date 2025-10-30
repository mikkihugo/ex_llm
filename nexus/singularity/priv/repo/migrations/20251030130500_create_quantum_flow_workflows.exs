defmodule Singularity.Repo.Migrations.CreateQuantumFlowWorkflows do
  use Ecto.Migration

  def change do
    create table(:quantum_flow_workflows, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :workflow_id, :string, null: false
      add :type, :string, null: false
      add :payload, :map, null: false
      add :status, :string, null: false, default: "pending"
      add :expires_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:quantum_flow_workflows, [:workflow_id])
    create index(:quantum_flow_workflows, [:status])
    create index(:quantum_flow_workflows, [:expires_at])
  end
end
