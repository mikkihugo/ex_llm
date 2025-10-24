defmodule Singularity.Repo.Migrations.CreateCodeEmbeddingCache do
  use Ecto.Migration

  def change do
    create table(:code_embedding_cache, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code_hash, :string, null: false
      add :language, :string, null: false
      # Use halfvec (half-precision) to support up to 4000 dimensions
      add :embedding, :halfvec, size: 2560, null: false
      add :metadata, :map, default: %{}
      add :expires_at, :utc_datetime_usec, null: false
      add :hit_count, :integer, default: 0

      timestamps()
    end

    # Index for semantic search (pgvector similarity) with half-precision
    # Half-precision mode supports up to 4000 dimensions (vs 2000 in float32)
    # This allows us to index the full 2560-dim concatenated vectors (Qodo 1536 + Jina 1024)
    execute("CREATE INDEX code_embedding_cache_embedding_hnsw ON code_embedding_cache USING hnsw (embedding halfvec_cosine_ops)")

    # Index for fast TTL-based cleanup queries
    create index(:code_embedding_cache, [:expires_at])

    # Index for cache lookups
    create index(:code_embedding_cache, [:language])

    # Unique constraint: each code_hash+language combination is unique
    create unique_index(:code_embedding_cache, [:code_hash, :language])
  end
end
