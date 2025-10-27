defmodule Singularity.Repo.Migrations.CreateCodeAnalysisTables do
  use Ecto.Migration

  def change do
    # Code Files
    create_if_not_exists table(:code_files, primary_key: false) do
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

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS code_files_project_name_file_path_key
      ON code_files (project_name, file_path)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_files_language_index
      ON code_files (language)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_files_hash_index
      ON code_files (hash)
    """, "")

    # Code Embeddings
    create_if_not_exists table(:code_embeddings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code_file_id, references(:code_files, type: :binary_id, on_delete: :delete_all)
      add :chunk_index, :integer, null: false
      add :chunk_text, :text, null: false
      add :embedding, :vector, size: 2560, null: true
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS code_embeddings_code_file_id_index
      ON code_embeddings (code_file_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_embeddings_chunk_index_index
      ON code_embeddings (chunk_index)
    """, "")

    # Code Fingerprints
    create_if_not_exists table(:code_fingerprints, primary_key: false) do
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

    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS code_fingerprints_file_path_key
      ON code_fingerprints (file_path)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_fingerprints_content_hash_index
      ON code_fingerprints (content_hash)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_fingerprints_structural_hash_index
      ON code_fingerprints (structural_hash)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_fingerprints_language_index
      ON code_fingerprints (language)
    """, "")

    # Code Location Index
    create_if_not_exists table(:code_locations, primary_key: false) do
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
      add :embedding, :vector, size: 2560, null: true
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS code_locations_project_file_path_index
      ON code_locations (project, file_path)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_locations_symbol_type_symbol_name_index
      ON code_locations (symbol_type, symbol_name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS code_locations_parent_symbol_index
      ON code_locations (parent_symbol)
    """, "")

    # Detection Events (formerly codebase_snapshots)
    create_if_not_exists table(:detection_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :detector, :string, null: false
      add :confidence, :float, null: false
      add :data, :map, null: false
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS detection_events_event_type_index
      ON detection_events (event_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS detection_events_detector_index
      ON detection_events (detector)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS detection_events_inserted_at_index
      ON detection_events (inserted_at)
    """, "")
  end
end