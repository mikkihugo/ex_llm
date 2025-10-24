defmodule Singularity.Repo.Migrations.CreateVectorSimilarityCache do
  use Ecto.Migration

  def change do
    create table(:vector_similarity_cache, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codebase_id, :string, null: false
      add :query_vector_hash, :string, null: false
      add :target_file_path, :string, null: false
      add :similarity_score, :float, null: false

      timestamps()
    end

    # Indexes for performance
    create index(:vector_similarity_cache, [:codebase_id])
    create index(:vector_similarity_cache, [:codebase_id, :query_vector_hash])
    create unique_index(:vector_similarity_cache, [:codebase_id, :query_vector_hash, :target_file_path])

    # Index on inserted_at for TTL cleanup (if you want to expire cache entries)
    create index(:vector_similarity_cache, [:inserted_at])
  end
end
