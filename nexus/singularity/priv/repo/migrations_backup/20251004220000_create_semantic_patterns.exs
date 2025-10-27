defmodule Singularity.Repo.Migrations.CreateSemanticPatterns do
  use Ecto.Migration

  def up do
    execute """
    CREATE TABLE IF NOT EXISTS semantic_patterns (
      id TEXT PRIMARY KEY,
      language TEXT NOT NULL,
      pattern_name TEXT NOT NULL,
      pseudocode TEXT NOT NULL,
      relationships TEXT[] DEFAULT '{}',
      keywords TEXT[] DEFAULT '{}',
      pattern_type TEXT NOT NULL,
      searchable_text TEXT NOT NULL,
      embedding vector(768) NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    )
    """

    execute """
    CREATE INDEX IF NOT EXISTS semantic_patterns_embedding_idx
      ON semantic_patterns USING hnsw (embedding vector_cosine_ops)
      WITH (m = 16, ef_construction = 64)
    """

    execute """
    CREATE INDEX IF NOT EXISTS semantic_patterns_language_idx
      ON semantic_patterns (language)
    """

    execute """
    CREATE INDEX IF NOT EXISTS semantic_patterns_keywords_idx
      ON semantic_patterns USING gin (keywords)
    """
  end

  def down do
    execute "DROP TABLE IF EXISTS semantic_patterns"
  end
end
