defmodule Singularity.Repo.Migrations.CreateFixApplications do
  use Ecto.Migration

  def change do
    create table(:fix_applications, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Linking failure to fix
      add :failure_pattern_id, :uuid  # Which failure this fixed (from failure_patterns table)
      add :generation_session_id, :uuid, null: false  # The session that generated the fix

      # Who applied the fix
      add :fixer_type, :string, null: false, default: "agent"  # "human" or "agent"
      add :applied_by_agent_id, :string  # Which agent applied the fix
      add :applied_by_human, :string  # If human-applied, who

      # What was fixed
      add :fix_diff_text, :text, null: false  # The actual code diff/patch
      add :fix_commit_hash, :string  # Git commit hash if committed

      # Result of applying the fix
      add :fix_applied_successfully, :boolean, default: true
      add :subsequent_test_results, :map  # Test results after applying the fix
      add :fix_validation_status, :string, default: "pending"  # pending, validated, failed

      # Cost tracking
      add :fix_generation_cost_tokens, :integer, default: 0

      # Audit trail
      add :fix_reason, :text  # Why this fix was needed
      add :fix_notes, :text  # Additional notes

      # Timestamps
      add :applied_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :validated_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    # Indexes
    create index(:fix_applications, [:failure_pattern_id])
    create index(:fix_applications, [:generation_session_id])
    create index(:fix_applications, [:applied_by_agent_id])
    create index(:fix_applications, [:fixer_type])
    create index(:fix_applications, [:fix_validation_status])
    create index(:fix_applications, [:applied_at])

    # Foreign key for generation_session
    alter table(:fix_applications) do
      modify :generation_session_id, references(:code_generation_sessions, type: :uuid, on_delete: :cascade)
    end
  end
end
