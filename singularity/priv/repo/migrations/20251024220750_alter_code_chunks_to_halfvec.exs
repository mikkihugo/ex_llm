defmodule Singularity.Repo.Migrations.AlterCodeChunksToHalfvec do
  use Ecto.Migration

  def change do
    # Drop the old index before altering the column
    execute("DROP INDEX IF EXISTS code_chunks_embedding_hnsw")

    # Alter the embedding column from vector(1536) to halfvec(2560)
    execute("ALTER TABLE code_chunks ALTER COLUMN embedding TYPE halfvec(2560)")

    # Recreate the index with the correct operator class
    execute("CREATE INDEX code_chunks_embedding_hnsw ON code_chunks USING hnsw (embedding halfvec_cosine_ops)")
  end
end
