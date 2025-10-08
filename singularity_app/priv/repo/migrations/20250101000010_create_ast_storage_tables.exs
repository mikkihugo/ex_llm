defmodule Singularity.Repo.Migrations.CreateAstStorageTables do
  use Ecto.Migration

  def change do
    # Code Files with AST storage
    create table(:code_files, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codebase_id, :string, null: false
      add :file_path, :string, null: false
      add :language, :string
      add :content, :text
      add :file_size, :integer
      add :line_count, :integer
      add :hash, :string
      
      # AST Storage
      add :ast_json, :jsonb
      add :functions, :jsonb, default: fragment("'[]'::jsonb")
      add :classes, :jsonb, default: fragment("'[]'::jsonb")
      add :imports, :jsonb, default: fragment("'[]'::jsonb")
      add :exports, :jsonb, default: fragment("'[]'::jsonb")
      add :symbols, :jsonb, default: fragment("'[]'::jsonb")

      # Metadata
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")
      add :parsed_at, :utc_datetime
      timestamps()
    end

    create unique_index(:code_files, [:codebase_id, :file_path])
    create index(:code_files, [:language])
    create index(:code_files, [:hash])
    create index(:code_files, [:codebase_id])
    
    # GIN indexes for JSONB fields for fast queries
    create index(:code_files, [:ast_json], using: :gin)
    create index(:code_files, [:functions], using: :gin)
    create index(:code_files, [:classes], using: :gin)
    create index(:code_files, [:imports], using: :gin)
    create index(:code_files, [:exports], using: :gin)
    create index(:code_files, [:symbols], using: :gin)
    create index(:code_files, [:metadata], using: :gin)

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