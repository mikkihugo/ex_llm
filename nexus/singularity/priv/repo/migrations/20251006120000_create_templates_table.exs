defmodule Singularity.Repo.Migrations.CreateTemplatesTable do
  use Ecto.Migration

  def up do
    # Create templates table
    create_if_not_exists table(:templates, primary_key: false) do
      add :id, :text, primary_key: true
      add :version, :text, null: false
      add :type, :text, null: false

      # JSONB columns for flexible schema
      add :metadata, :jsonb, null: false
      add :content, :jsonb, null: false
      add :quality, :jsonb, default: "{}"
      add :usage, :jsonb,
        default: ~s({"count": 0, "success_rate": 0.0, "last_used": null})

      # Qodo-Embed-1 vector (1536 dimensions)
      # add :embedding, :vector, size: 1536  # pgvector - install via separate migration

      timestamps(type: :timestamptz)
    end

    # Indexes for fast queries

    # Vector similarity search (IVFFlat for pgvector) - disabled, vector column commented out
    # execute """
    # CREATE INDEX templates_embedding_idx
    #   ON templates
    #   USING ivfflat (embedding vector_cosine_ops)
    #   WITH (lists = 100);
    # """

    # Type filter
    execute("""
      CREATE INDEX IF NOT EXISTS templates_type_index
      ON templates (type)
    """, "")

    # Language filter (JSONB)
    execute("""
      CREATE INDEX IF NOT EXISTS templates_metadata_language_index
      ON templates ((metadata->>'language'))
    """, "")

    # Tags search (JSONB array contains)
    execute "CREATE INDEX templates_tags_idx ON templates USING gin((metadata->'tags'));"

    # Quality score filter
    execute "CREATE INDEX templates_quality_score_idx ON templates ((quality->>'score'));"

    # Usage tracking
    execute "CREATE INDEX templates_usage_count_idx ON templates ((usage->>'count'));"
    execute "CREATE INDEX templates_usage_success_idx ON templates ((usage->>'success_rate'));"
    execute "CREATE INDEX templates_last_used_idx ON templates ((usage->>'last_used'));"

    # Full-text search on content
    execute """
    CREATE INDEX templates_content_fts_idx
      ON templates
      USING gin(to_tsvector('english', content->>'code'));
    """

    # Composite index for common queries
    execute("""
      CREATE INDEX IF NOT EXISTS templates_type_language_index
      ON templates (type, (metadata->>'language'))
    """, "")
  end

  def down do
    drop table(:templates)
  end
end
