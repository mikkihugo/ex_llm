defmodule Singularity.Repo.Migrations.CreateKnowledgeArtifacts do
  use Ecto.Migration

  def up do
    # Enable required extensions
    execute "CREATE EXTENSION IF NOT EXISTS vector"
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    create table(:knowledge_artifacts, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Template identification
      add :artifact_type, :text, null: false
      add :artifact_id, :text, null: false
      add :version, :text, null: false, default: "1.0.0"

      # Dual storage (raw + parsed)
      add :content_raw, :text, null: false
      add :content, :jsonb, null: false

      # Semantic search
      add :embedding, :vector, size: 1536

      # Learning metadata
      add :source, :text, null: false, default: "git" # 'git' or 'learned'
      add :learned_from, :jsonb

      # Usage tracking
      add :usage_count, :integer, default: 0
      add :success_count, :integer, default: 0
      add :failure_count, :integer, default: 0
      add :avg_performance_ms, :float
      add :user_ratings, {:array, :float}, default: []

      # Change tracking
      add :created_by, :text
      add :change_reason, :text

      # Versioning
      add :previous_version_id, references(:knowledge_artifacts, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create unique_index(:knowledge_artifacts, [:artifact_type, :artifact_id, :version])
    create index(:knowledge_artifacts, [:artifact_type])
    create index(:knowledge_artifacts, [:artifact_id])
    create index(:knowledge_artifacts, [:source])
    create index(:knowledge_artifacts, [:updated_at])

    # GIN index for JSONB queries
    create index(:knowledge_artifacts, [:content], using: :gin)

    # Vector index for semantic search (IVFFlat)
    execute """
    CREATE INDEX knowledge_artifacts_embedding_idx
    ON knowledge_artifacts
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100)
    """

    # Generated columns for fast queries
    execute """
    ALTER TABLE knowledge_artifacts
    ADD COLUMN language TEXT
    GENERATED ALWAYS AS (content->>'language') STORED
    """

    execute """
    ALTER TABLE knowledge_artifacts
    ADD COLUMN category TEXT
    GENERATED ALWAYS AS (content->>'category') STORED
    """

    execute """
    ALTER TABLE knowledge_artifacts
    ADD COLUMN tags TEXT[]
    GENERATED ALWAYS AS (
      CASE
        WHEN jsonb_typeof(content->'tags') = 'array'
        THEN ARRAY(SELECT jsonb_array_elements_text(content->'tags'))
        ELSE ARRAY[]::TEXT[]
      END
    ) STORED
    """

    # Indexes on generated columns
    create index(:knowledge_artifacts, [:language])
    create index(:knowledge_artifacts, [:category])
    create index(:knowledge_artifacts, [:tags], using: :gin)

    # Check constraint: ensure content matches content_raw
    execute """
    ALTER TABLE knowledge_artifacts
    ADD CONSTRAINT content_matches_raw
    CHECK (content = content_raw::jsonb)
    """

    # Trigger for LISTEN/NOTIFY on changes
    execute """
    CREATE OR REPLACE FUNCTION notify_template_change()
    RETURNS trigger AS $$
    DECLARE
      notification JSON;
    BEGIN
      notification = json_build_object(
        'id', NEW.artifact_id,
        'type', NEW.artifact_type,
        'version', NEW.version,
        'source', NEW.source,
        'category', NEW.category
      );

      PERFORM pg_notify('template_updated', notification::text);
      PERFORM pg_notify('template_updated_' || NEW.artifact_id, notification::text);

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER template_change_trigger
    AFTER INSERT OR UPDATE ON knowledge_artifacts
    FOR EACH ROW EXECUTE FUNCTION notify_template_change()
    """

    # Trigger to update timestamps
    execute """
    CREATE OR REPLACE FUNCTION update_updated_at()
    RETURNS trigger AS $$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER update_knowledge_artifacts_updated_at
    BEFORE UPDATE ON knowledge_artifacts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at()
    """
  end

  def down do
    drop table(:knowledge_artifacts)
    execute "DROP FUNCTION IF EXISTS notify_template_change() CASCADE"
    execute "DROP FUNCTION IF EXISTS update_updated_at() CASCADE"
  end
end
