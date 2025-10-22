defmodule Singularity.Repo.Migrations.CreateCodeAnalysisTables do
  use Ecto.Migration

  def change do
    # Code Files
    create table(:code_files, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :file_path, :string, null: false
      add :project_name, :string, null: false
      add :content, :text
      add :language, :string
      add :size_bytes, :integer
      add :line_count, :integer
      add :hash, :string
      add :metadata, :map, default: %{}
      timestamps()
    end

    create unique_index(:code_files, [:project_name, :file_path])
    create index(:code_files, [:language])
    create index(:code_files, [:hash])

    # Code Embeddings
    create table(:code_embeddings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code_file_id, references(:code_files, type: :binary_id, on_delete: :delete_all)
      add :chunk_index, :integer, null: false
      add :chunk_text, :text, null: false
      add :embedding, :vector, size: 768
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:code_embeddings, [:code_file_id])
    create index(:code_embeddings, [:chunk_index])

    # Code Fingerprints
    create table(:code_fingerprints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :file_path, :string, null: false
      add :content_hash, :string, null: false
      add :structural_hash, :string, null: false
      add :semantic_hash, :string
      add :language, :string
      add :tokens, {:array, :string}, default: []
      add :ast_signature, :text
      add :complexity_score, :integer
      add :metadata, :map, default: %{}
      timestamps()
    end

    create unique_index(:code_fingerprints, [:file_path])
    create index(:code_fingerprints, [:content_hash])
    create index(:code_fingerprints, [:structural_hash])
    create index(:code_fingerprints, [:language])

    # Code Location Index
    create table(:code_locations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project, :string, null: false
      add :file_path, :string, null: false
      add :line_start, :integer, null: false
      add :line_end, :integer, null: false
      add :column_start, :integer
      add :column_end, :integer
      add :symbol_type, :string, null: false
      add :symbol_name, :string, null: false
      add :parent_symbol, :string
      add :signature, :text
      add :documentation, :text
      add :metadata, :map, default: %{}
      add :embedding, :vector, size: 768
      timestamps()
    end

    create index(:code_locations, [:project, :file_path])
    create index(:code_locations, [:symbol_type, :symbol_name])
    create index(:code_locations, [:parent_symbol])

    # Detection Events (formerly codebase_snapshots)
    create table(:detection_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :detector, :string, null: false
      add :confidence, :float, null: false
      add :data, :map, null: false
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:detection_events, [:event_type])
    create index(:detection_events, [:detector])
    create index(:detection_events, [:inserted_at])
  end
end