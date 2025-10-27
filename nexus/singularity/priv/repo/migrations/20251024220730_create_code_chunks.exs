defmodule Singularity.Repo.Migrations.CreateCodeChunks do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:code_chunks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codebase_id, :string, null: false
      add :file_path, :string, null: false
      add :language, :string, null: false
      add :content, :text, null: false
      # Use halfvec (half-precision) to support up to 4000 dimensions
      add :embedding, :halfvec, size: 2560, null: false
      add :metadata, :map, default: %{}
      add :content_hash, :string, null: false

      timestamps()
    end

    # Index for semantic search (pgvector similarity) with half-precision
    # Half-precision mode supports up to 4000 dimensions (vs 2000 in float32)
    # This allows us to index the full 2560-dim concatenated vectors (Qodo 1536 + Jina 1024)
    execute("CREATE INDEX code_chunks_embedding_hnsw ON code_chunks USING hnsw (embedding halfvec_cosine_ops)")

    # Index for fast lookups by codebase and file
    execute("""
      CREATE INDEX IF NOT EXISTS code_chunks_codebase_id_file_path_index
      ON code_chunks (codebase_id, file_path)
    """, "")

    # Index for language-specific queries
    execute("""
      CREATE INDEX IF NOT EXISTS code_chunks_language_index
      ON code_chunks (language)
    """, "")

    # Unique constraint: each codebase+content_hash combination is unique
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS code_chunks_codebase_id_content_hash_key
      ON code_chunks (codebase_id, content_hash)
    """, "")
  end
end
