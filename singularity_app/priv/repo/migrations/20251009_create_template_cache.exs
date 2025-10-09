defmodule Singularity.Repo.Migrations.CreateTemplateCache do
  use Ecto.Migration

  def change do
    create table(:template_cache, primary_key: false) do
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

    create unique_index(:template_cache, [:artifact_id, :version])
    create index(:template_cache, [:downloaded_at])
    create index(:template_cache, [:last_used_at])
    create index(:template_cache, [:content], using: :gin)

    create table(:local_learning, primary_key: false) do
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

    create index(:local_learning, [:artifact_id])
    create index(:local_learning, [:synced_to_central])
    create index(:local_learning, [:synced_at])
  end
end
