defmodule Singularity.Repo.Migrations.CreateAstStorageTables do
  use Ecto.Migration

  def change do
    # Note: code_files table is created by migration 20240101000004
    # This migration only creates the additional tables (codebase_chunks, embeddings)

    # Code Chunks for embeddings
    create table(:codebase_chunks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code_file_id, references(:code_files, type: :binary_id, on_delete: :delete_all)
      add :chunk_index, :integer, null: false
      add :chunk_text, :text, null: false
      add :chunk_type, :string # function, class, comment, etc.
      add :start_line, :integer
      add :end_line, :integer
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")
      timestamps()
    end

    create index(:codebase_chunks, [:code_file_id])
    create index(:codebase_chunks, [:chunk_type])
    create index(:codebase_chunks, [:chunk_index])

    # Code Chunk Embeddings
    create table(:codebase_chunk_embeddings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :chunk_id, references(:codebase_chunks, type: :binary_id, on_delete: :delete_all)
      add :embedding, :vector, size: 768
      add :model_name, :string
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")
      timestamps()
    end

    create index(:codebase_chunk_embeddings, [:chunk_id])
    create index(:codebase_chunk_embeddings, [:model_name])
    
    # Vector similarity search index
    execute "CREATE INDEX ON codebase_chunk_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
  end
end