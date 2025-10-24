defmodule Singularity.Repo.Migrations.CreateVectorSearch do
  use Ecto.Migration

  def change do
    create table(:vector_search, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codebase_id, :string, null: false
      add :file_path, :string, null: false
      add :content_type, :string, null: false
      add :content, :text, null: false
      add :vector_embedding, :vector, size: 1536, null: false
      add :metadata, :jsonb, default: "{}"

      timestamps()
    end

    # Indexes for performance
    create index(:vector_search, [:codebase_id])
    create index(:vector_search, [:codebase_id, :file_path])
    create index(:vector_search, [:codebase_id, :content_type])
    create unique_index(:vector_search, [:codebase_id, :file_path, :content_type])

    # Vector index for similarity search
    execute("""
    CREATE INDEX idx_vector_search_vector
    ON vector_search USING ivfflat (vector_embedding vector_cosine_ops)
    """)
  end
end
