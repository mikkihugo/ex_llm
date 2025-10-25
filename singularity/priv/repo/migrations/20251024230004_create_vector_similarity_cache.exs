defmodule Singularity.Repo.Migrations.CreateVectorSimilarityCache do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:vector_similarity_cache, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codebase_id, :string, null: false
      add :query_vector_hash, :string, null: false
      add :target_file_path, :string, null: false
      add :similarity_score, :float, null: false

      timestamps()
    end

    # Indexes for performance
    execute("""
      CREATE INDEX IF NOT EXISTS vector_similarity_cache_codebase_id_index
      ON vector_similarity_cache (codebase_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS vector_similarity_cache_codebase_id_query_vector_hash_index
      ON vector_similarity_cache (codebase_id, query_vector_hash)
    """, "")
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS vector_similarity_cache_codebase_id_query_vector_hash_target_file_path_key
      ON vector_similarity_cache (codebase_id, query_vector_hash, target_file_path)
    """, "")

    # Index on inserted_at for TTL cleanup (if you want to expire cache entries)
    # Note: Only create if inserted_at column exists
    execute("""
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'vector_similarity_cache' AND column_name = 'inserted_at'
        ) THEN
          CREATE INDEX IF NOT EXISTS vector_similarity_cache_inserted_at_index
          ON vector_similarity_cache (inserted_at);
        END IF;
      END$$;
    """, "")
  end
end
