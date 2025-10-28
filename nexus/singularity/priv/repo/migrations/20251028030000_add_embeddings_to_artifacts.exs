defmodule Singularity.Repo.Migrations.AddEmbeddingsToArtifacts do
  use Ecto.Migration

  def change do
    # Add embedding vector column (1024-dim: Jina v3 only)
    # Jina v3 provides balanced quality for code patterns + general text
    # 1024-dim < 2000-dim pgvector limit, enabling ivfflat index support
    alter table(:curated_knowledge_artifacts) do
      add :embedding, :vector, size: 1024, null: true, comment: "Jina v3 embeddings (1024-dim, general + code-optimized)"
      add :embedding_model, :string, null: true, comment: "Model used for embedding: jina_v3"
      add :embedding_generated_at, :utc_datetime, null: true
    end

    # Create ivfflat index for fast vector similarity search
    # ivfflat is now possible with 1024-dim (< 2000-dim limit)
    # lists=100 is appropriate for 123 artifacts
    execute("""
    CREATE INDEX IF NOT EXISTS curated_knowledge_artifacts_embedding_ivfflat
    ON curated_knowledge_artifacts USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);
    """)

    # Also keep timestamp index for sorting by recency
    execute("""
    CREATE INDEX IF NOT EXISTS curated_knowledge_artifacts_embedding_generated_idx
    ON curated_knowledge_artifacts (embedding_generated_at DESC)
    WHERE embedding IS NOT NULL;
    """)

    # Full-text search on content_raw (already exists, just documenting)
    # execute("""
    # CREATE INDEX IF NOT EXISTS artifacts_content_fts
    # ON curated_knowledge_artifacts USING GIN(to_tsvector('english', content_raw));
    # """)
  end
end
