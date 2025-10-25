defmodule Singularity.Repo.Migrations.CreateAutonomousStoredProcedures do
  use Ecto.Migration

  # NOTE: This migration creates the learning_sync_log table
  # Complex autonomous procedures (pattern learning, session persistence, etc.)
  # are deferred until their dependent tables are created.

  def up do
    # Log table for tracking syncs
    create_if_not_exists table(:learning_sync_log, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :batch_id, :string
      add :pattern_count, :integer
      add :synced_at, :utc_datetime
      add :status, :string, default: "queued"
      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS learning_sync_log_batch_id_index
      ON learning_sync_log (batch_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS learning_sync_log_status_index
      ON learning_sync_log (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS learning_sync_log_synced_at_index
      ON learning_sync_log (synced_at)
    """, "")
  end

  def down do
    drop_if_exists table(:learning_sync_log)
  end
end
