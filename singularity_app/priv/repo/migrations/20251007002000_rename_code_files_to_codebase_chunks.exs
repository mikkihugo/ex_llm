defmodule Singularity.Repo.Migrations.RenameCodeFilesToCodebaseChunks do
  use Ecto.Migration

  def up do
    # Rename table: code_files → codebase_chunks
    # This better reflects that we store YOUR codebase (NOT external packages)
    # and that files are chunked for semantic search
    execute "ALTER TABLE code_files RENAME TO codebase_chunks"

    # Rename foreign key constraint in code_embeddings table
    execute """
    ALTER TABLE code_embeddings
    DROP CONSTRAINT code_embeddings_code_file_id_fkey
    """

    execute """
    ALTER TABLE code_embeddings
    ADD CONSTRAINT code_embeddings_code_file_id_fkey
    FOREIGN KEY (code_file_id)
    REFERENCES codebase_chunks(id)
    ON DELETE CASCADE
    """

    # Note: code_file_id column name stays the same for now
    # (renaming FK columns is more invasive, can do separately if needed)
  end

  def down do
    # Reverse the changes
    execute """
    ALTER TABLE code_embeddings
    DROP CONSTRAINT code_embeddings_code_file_id_fkey
    """

    execute """
    ALTER TABLE code_embeddings
    ADD CONSTRAINT code_embeddings_code_file_id_fkey
    FOREIGN KEY (code_file_id)
    REFERENCES code_files(id)
    ON DELETE CASCADE
    """

    execute "ALTER TABLE codebase_chunks RENAME TO code_files"
  end
end
