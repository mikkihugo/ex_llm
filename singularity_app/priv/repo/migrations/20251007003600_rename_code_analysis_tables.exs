defmodule Singularity.Repo.Migrations.RenameCodeAnalysisTables do
  use Ecto.Migration

  @moduledoc """
  Phase 7: Make code analysis table names more specific

  BEFORE: code_embeddings - Embeddings of what code?
  AFTER: codebase_chunk_embeddings - Embeddings of YOUR codebase chunks

  This distinguishes YOUR code from external packages.
  """

  def up do
    # code_embeddings → codebase_chunk_embeddings
    # (Embeddings OF your codebase chunks)
    execute "ALTER TABLE code_embeddings RENAME TO codebase_chunk_embeddings"

    # code_fingerprints → codebase_file_fingerprints
    # (Fingerprints OF your files - hashes, AST signatures)
    execute "ALTER TABLE code_fingerprints RENAME TO codebase_file_fingerprints"

    # code_locations → codebase_symbol_locations
    # (WHERE symbols are defined in YOUR codebase)
    execute "ALTER TABLE code_locations RENAME TO codebase_symbol_locations"

    # Update foreign keys
    execute """
    ALTER TABLE codebase_chunk_embeddings
    DROP CONSTRAINT IF EXISTS code_embeddings_code_file_id_fkey
    """
    execute """
    ALTER TABLE codebase_chunk_embeddings
    ADD CONSTRAINT codebase_chunk_embeddings_codebase_chunk_id_fkey
    FOREIGN KEY (code_file_id)
    REFERENCES codebase_chunks(id)
    ON DELETE CASCADE
    """

    # Update indexes
    execute """
    ALTER INDEX IF EXISTS code_embeddings_pkey
    RENAME TO codebase_chunk_embeddings_pkey
    """
    execute """
    ALTER INDEX IF EXISTS code_embeddings_code_file_id_index
    RENAME TO codebase_chunk_embeddings_codebase_chunk_id_index
    """
    execute """
    ALTER INDEX IF EXISTS code_fingerprints_pkey
    RENAME TO codebase_file_fingerprints_pkey
    """
    execute """
    ALTER INDEX IF EXISTS code_locations_pkey
    RENAME TO codebase_symbol_locations_pkey
    """
  end

  def down do
    # Reverse indexes
    execute """
    ALTER INDEX IF EXISTS codebase_symbol_locations_pkey
    RENAME TO code_locations_pkey
    """
    execute """
    ALTER INDEX IF EXISTS codebase_file_fingerprints_pkey
    RENAME TO code_fingerprints_pkey
    """
    execute """
    ALTER INDEX IF EXISTS codebase_chunk_embeddings_codebase_chunk_id_index
    RENAME TO code_embeddings_code_file_id_index
    """
    execute """
    ALTER INDEX IF EXISTS codebase_chunk_embeddings_pkey
    RENAME TO code_embeddings_pkey
    """

    # Reverse foreign keys
    execute """
    ALTER TABLE codebase_chunk_embeddings
    DROP CONSTRAINT IF EXISTS codebase_chunk_embeddings_codebase_chunk_id_fkey
    """
    execute """
    ALTER TABLE codebase_chunk_embeddings
    ADD CONSTRAINT code_embeddings_code_file_id_fkey
    FOREIGN KEY (code_file_id)
    REFERENCES codebase_chunks(id)
    ON DELETE CASCADE
    """

    # Reverse table renames
    execute "ALTER TABLE codebase_symbol_locations RENAME TO code_locations"
    execute "ALTER TABLE codebase_file_fingerprints RENAME TO code_fingerprints"
    execute "ALTER TABLE codebase_chunk_embeddings RENAME TO code_embeddings"
  end
end
