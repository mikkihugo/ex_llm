defmodule Singularity.Repo.Migrations.CreateBootstrapStages do
  use Ecto.Migration

  def change do
    create table(:bootstrap_stages, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :current_stage, :integer, null: false
      add :stage_started_at, :utc_datetime, null: false
      add :metrics, :jsonb, default: "{}"
      add :stage_history, :jsonb, default: "[]"  # Track all stage changes

      timestamps(type: :utc_datetime)
    end

    # Only one row should exist (singleton pattern)
    create unique_index(:bootstrap_stages, [:id], where: "id IS NOT NULL")

    # Initialize with Stage 1
    execute """
    INSERT INTO bootstrap_stages (id, current_stage, stage_started_at, metrics, stage_history, inserted_at, updated_at)
    VALUES (
      gen_random_uuid(),
      1,
      NOW(),
      '{}',
      '[{"stage": 1, "started_at": "' || NOW()::text || '", "reason": "initial"}]',
      NOW(),
      NOW()
    )
    """, """
    DELETE FROM bootstrap_stages
    """

    # Add codebase_type to codebases table (if it exists)
    # This distinguishes meta_system (Singularity itself) from user_project
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'codebases') THEN
        ALTER TABLE codebases ADD COLUMN IF NOT EXISTS codebase_type TEXT DEFAULT 'user_project';
        ALTER TABLE codebases ADD CONSTRAINT valid_codebase_type
          CHECK (codebase_type IN ('meta_system', 'user_project'));
      END IF;
    END $$;
    """, "-- No rollback for conditional alter"
  end
end
