defmodule Singularity.Repo.Migrations.CreateCodeEmbeddingCache do
  use Ecto.Migration

  def change do
    # Create table if not exists
    # Note: Table likely already exists from earlier migrations
    # Using vector type with HNSW index for semantic search
    create_if_not_exists table(:code_embedding_cache, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content_hash, :string, null: false
      add :content, :text, null: false
      add :embedding, :vector
      add :model_type, :string, default: "candle-transformer"
      add :language, :string
      add :file_path, :string
      add :created_at, :timestamp, default: fragment("now()")
    end

    # Index for semantic search using HNSW (supports high-dimensional vectors)
    execute("""
      CREATE INDEX IF NOT EXISTS code_embedding_cache_embedding_hnsw
      ON code_embedding_cache USING hnsw (embedding vector_cosine_ops)
    """, "")

    # Index for content hash lookups
    execute("""
      CREATE INDEX IF NOT EXISTS code_embedding_cache_content_hash_index
      ON code_embedding_cache (content_hash)
    """, "")

    # Index for language-based queries
    execute("""
      CREATE INDEX IF NOT EXISTS code_embedding_cache_language_index
      ON code_embedding_cache (language)
    """, "")

    # Index for file_path queries
    execute("""
      CREATE INDEX IF NOT EXISTS code_embedding_cache_file_path_index
      ON code_embedding_cache (file_path)
    """, "")
  end
end
