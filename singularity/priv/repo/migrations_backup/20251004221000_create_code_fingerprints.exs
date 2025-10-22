defmodule Singularity.Repo.Migrations.CreateCodeFingerprints do
  use Ecto.Migration

  def up do
    execute """
    CREATE TABLE IF NOT EXISTS code_fingerprints (
      id TEXT PRIMARY KEY,
      file_path TEXT NOT NULL,
      language TEXT NOT NULL,
      content TEXT NOT NULL,
      exact_hash TEXT NOT NULL,
      normalized_hash TEXT NOT NULL,
      ast_hash TEXT,
      pattern_signature TEXT NOT NULL,
      embedding vector(768) NOT NULL,
      keywords TEXT[] DEFAULT '{}',
      length INTEGER NOT NULL,
      lines INTEGER NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    )
    """

    # Fast exact duplicate detection
    execute """
    CREATE INDEX IF NOT EXISTS code_fingerprints_exact_hash_idx
      ON code_fingerprints (exact_hash)
    """

    # Near-duplicate detection (normalized code)
    execute """
    CREATE INDEX IF NOT EXISTS code_fingerprints_normalized_hash_idx
      ON code_fingerprints (normalized_hash)
    """

    # Pattern-based search
    execute """
    CREATE INDEX IF NOT EXISTS code_fingerprints_pattern_idx
      ON code_fingerprints (pattern_signature, language)
    """

    # Semantic similarity search
    execute """
    CREATE INDEX IF NOT EXISTS code_fingerprints_embedding_idx
      ON code_fingerprints USING hnsw (embedding vector_cosine_ops)
      WITH (m = 16, ef_construction = 64)
    """

    # Keyword search
    execute """
    CREATE INDEX IF NOT EXISTS code_fingerprints_keywords_idx
      ON code_fingerprints USING gin (keywords)
    """

    # Language filter
    execute """
    CREATE INDEX IF NOT EXISTS code_fingerprints_language_idx
      ON code_fingerprints (language)
    """
  end

  def down do
    execute "DROP TABLE IF EXISTS code_fingerprints"
  end
end
