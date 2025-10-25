defmodule Singularity.Repo.Migrations.CreateTemplateCache do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:template_cache, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :artifact_id, :text, null: false
      add :version, :text, null: false
      add :content, :jsonb, null: false

      # Cache metadata
      add :downloaded_at, :utc_datetime, null: false, default: fragment("NOW()")
      add :last_used_at, :utc_datetime
      add :source, :text, null: false, default: "central"

      # Local usage tracking
      add :local_usage_count, :integer, default: 0
      add :local_success_count, :integer, default: 0
      add :local_failure_count, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS template_cache_artifact_id_version_key
      ON template_cache (artifact_id, version)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS template_cache_downloaded_at_index
      ON template_cache (downloaded_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS template_cache_last_used_at_index
      ON template_cache (last_used_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS template_cache_content_index
      ON template_cache (content)
    """, "")

    create_if_not_exists table(:local_learning, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :artifact_id, :text, null: false
      add :version, :text, null: false

      # Learning data
      add :usage_data, :jsonb, null: false
      add :learned_improvements, :jsonb

      # Sync status
      add :synced_to_central, :boolean, default: false
      add :synced_at, :utc_datetime

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    execute("""
      CREATE INDEX IF NOT EXISTS local_learning_artifact_id_index
      ON local_learning (artifact_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS local_learning_synced_to_central_index
      ON local_learning (synced_to_central)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS local_learning_synced_at_index
      ON local_learning (synced_at)
    """, "")
  end
end
