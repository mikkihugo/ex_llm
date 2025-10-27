defmodule Singularity.Repo.Migrations.CreateKnowledgeArtifacts do
  use Ecto.Migration

  def up do
    # Enable pgvector if not already enabled
    execute("CREATE EXTENSION IF NOT EXISTS vector")

    create_if_not_exists table(:knowledge_artifacts, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Identity
      add :artifact_type, :text, null: false
      add :artifact_id, :text, null: false
      add :version, :text, null: false, default: "1.0.0"

      # Dual storage: Raw JSON + Parsed JSONB
      add :content_raw, :text, null: false
      add :content, :jsonb, null: false

      # Semantic search (1536 dims for text-embedding-004 / Jina v2)
      add :embedding, :vector, size: 1536

      # Generated columns (auto-extracted from JSONB for fast filtering)
      # Note: Ecto doesn't support GENERATED ALWAYS in schema, so we use execute
      # These will be added separately below

      timestamps(type: :utc_datetime)
    end

    # Add generated columns (Ecto doesn't support in table definition)
    execute("""
    ALTER TABLE knowledge_artifacts
    ADD COLUMN language TEXT GENERATED ALWAYS AS (content->>'language') STORED
    """)

    # Create function to extract tags from JSONB
    execute("""
    CREATE OR REPLACE FUNCTION extract_tags_from_jsonb(content JSONB)
    RETURNS TEXT[] AS $$
    BEGIN
      IF jsonb_typeof(content->'tags') = 'array' THEN
        RETURN ARRAY(SELECT jsonb_array_elements_text(content->'tags'));
      ELSE
        RETURN ARRAY[]::TEXT[];
      END IF;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE
    """)

    execute("""
    ALTER TABLE knowledge_artifacts
    ADD COLUMN tags TEXT[] GENERATED ALWAYS AS (extract_tags_from_jsonb(content)) STORED
    """)

    # Consistency check: ensure raw and parsed match
    execute("""
    ALTER TABLE knowledge_artifacts
    ADD CONSTRAINT content_consistency_check
    CHECK (content = content_raw::jsonb)
    """)

    # Unique constraint
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS knowledge_artifacts_artifact_type_artifact_id_version_key
      ON knowledge_artifacts (artifact_type, artifact_id, version)
    """, "")

    # Indexes for fast queries
    execute("""
      CREATE INDEX IF NOT EXISTS knowledge_artifacts_artifact_type_language_index
      ON knowledge_artifacts (artifact_type, language)
    """, "")

    # GIN index for JSONB queries (fast WHERE content @> ...)
    execute("CREATE INDEX knowledge_artifacts_content_gin_idx ON knowledge_artifacts USING gin(content)")

    # GIN index for tags array
    execute("CREATE INDEX knowledge_artifacts_tags_gin_idx ON knowledge_artifacts USING gin(tags)")

    # Full-text search on raw JSON (for debugging/audit)
    execute("""
    CREATE INDEX knowledge_artifacts_content_raw_fts_idx
    ON knowledge_artifacts
    USING gin(to_tsvector('english', content_raw))
    """)

    # pgvector index for semantic search (ivfflat with cosine distance)
    # Note: We'll create this after data is loaded (needs tuning based on row count)
    # For now, just add a comment
    execute("""
    COMMENT ON COLUMN knowledge_artifacts.embedding IS
    'Vector embedding for semantic search. Create ivfflat index after loading data: CREATE INDEX CONCURRENTLY ON knowledge_artifacts USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);'
    """)

    # Trigger to auto-update updated_at
    execute("""
    CREATE OR REPLACE FUNCTION update_knowledge_artifacts_updated_at()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER knowledge_artifacts_updated_at_trigger
    BEFORE UPDATE ON knowledge_artifacts
    FOR EACH ROW
    EXECUTE FUNCTION update_knowledge_artifacts_updated_at()
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS knowledge_artifacts_updated_at_trigger ON knowledge_artifacts")
    execute("DROP FUNCTION IF EXISTS update_knowledge_artifacts_updated_at()")
    execute("DROP FUNCTION IF EXISTS extract_tags_from_jsonb(JSONB)")
    drop table(:knowledge_artifacts)
  end
end
