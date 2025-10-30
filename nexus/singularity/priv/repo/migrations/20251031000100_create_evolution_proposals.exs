defmodule Singularity.Repo.Migrations.CreateEvolutionProposals do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:evolution_proposals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_type, :string, null: false
      add :agent_id, :string
      add :code_change, :jsonb, null: false
      add :metadata, :jsonb, default: "{}"
      add :safety_profile, :jsonb, default: "{}"
      add :impact_score, :float, default: 5.0
      add :risk_score, :float, default: 5.0
      add :priority_score, :float, default: 0.0

      add :status, :string, default: "pending", null: false
      add :consensus_votes, :jsonb, default: "{}"
      add :consensus_sent_at, :utc_datetime_usec
      add :consensus_result, :string
      add :consensus_required, :boolean, default: true

      add :execution_started_at, :utc_datetime_usec
      add :execution_completed_at, :utc_datetime_usec
      add :execution_error, :text

      add :metrics_before, :jsonb
      add :metrics_after, :jsonb

      add :rollback_triggered_at, :utc_datetime_usec
      add :rollback_reason, :text

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for query performance
    create_if_not_exists index(:evolution_proposals, [:status])
    create_if_not_exists index(:evolution_proposals, [:agent_type])
    create_if_not_exists index(:evolution_proposals, [:agent_id])
    create_if_not_exists index(:evolution_proposals, [:priority_score])
    create_if_not_exists index(:evolution_proposals, [:inserted_at])
    create_if_not_exists index(:evolution_proposals, [:consensus_required])

    # Composite indexes for common queries
    create_if_not_exists index(:evolution_proposals, [:status, :priority_score, :inserted_at])
    create_if_not_exists index(:evolution_proposals, [:agent_type, :status])
  end
end
