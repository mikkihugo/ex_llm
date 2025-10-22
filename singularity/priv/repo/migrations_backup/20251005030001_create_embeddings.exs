defmodule Singularity.Repo.Migrations.CreateEmbeddings do
  use Ecto.Migration

  def up do
    # Enable pgvector extension (idempotent - already enabled in flake.nix but safe to repeat)
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    create table(:embeddings) do
      add :path, :text, null: false
      add :embedding, :vector, size: 768  # Google text-embedding-004 dimension
      add :model, :text, default: "text-embedding-004"
      add :repo_name, :text, null: false

      timestamps(type: :utc_datetime)
    end

    # Regular indexes for filtering
    create index(:embeddings, [:repo_name])
    create index(:embeddings, [:path])
    create index(:embeddings, [:model])

    # HNSW index for fast approximate nearest neighbor search
    # m=16 (max connections per layer), ef_construction=64 (search quality during build)
    execute """
    CREATE INDEX embeddings_embedding_hnsw ON embeddings
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    """

    # Unique constraint: one embedding per path+repo combination
    create unique_index(:embeddings, [:path, :repo_name])
  end

  def down do
    drop table(:embeddings)
  end
end
