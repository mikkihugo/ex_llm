defmodule CentralCloud.Repo.Migrations.CreateSyncLogTable do
  use Ecto.Migration

  def change do
    create table(:sync_log, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v7()")
      add :sync_type, :string, null: false  # pattern_sync, template_sync, metrics_sync
      add :pattern_id, :uuid  # If syncing a specific pattern
      add :instance_id, :string  # Which instance(s) received the sync
      add :items_synced, :integer, null: false, default: 0
      add :status, :string, null: false, default: "pending"  # pending, synced, failed
      add :error_message, :text
      add :sync_triggered_by, :string  # confidence_threshold, manual, scheduled
      add :synced_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:sync_log, [:sync_type])
    create index(:sync_log, [:status])
    create index(:sync_log, [:sync_triggered_by])
    create index(:sync_log, [:synced_at])
  end
end
