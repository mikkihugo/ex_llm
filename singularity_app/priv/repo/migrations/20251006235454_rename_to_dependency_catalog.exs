defmodule Singularity.Repo.Migrations.RenameToDependencyCatalog do
  use Ecto.Migration

  def change do
    # Rename main table directly from tools to dependency_catalog
    rename table(:tools), to: table(:dependency_catalog)

    # Rename related tables
    rename table(:tool_examples), to: table(:dependency_catalog_examples)
    rename table(:tool_patterns), to: table(:dependency_catalog_patterns)
    rename table(:tool_dependencies), to: table(:dependency_catalog_deps)

    # Update foreign key column names
    rename table(:dependency_catalog_examples), :tool_id, to: :dependency_id
    rename table(:dependency_catalog_patterns), :tool_id, to: :dependency_id
    rename table(:dependency_catalog_deps), :tool_id, to: :dependency_id

    # Rename indexes
    execute """
    ALTER INDEX IF EXISTS tools_unique_identifier RENAME TO dependency_catalog_unique_identifier;
    ALTER INDEX IF EXISTS tools_semantic_embedding_idx RENAME TO dependency_catalog_embedding_idx;
    """, """
    ALTER INDEX IF EXISTS dependency_catalog_unique_identifier RENAME TO tools_unique_identifier;
    ALTER INDEX IF EXISTS dependency_catalog_embedding_idx RENAME TO tools_semantic_embedding_idx;
    """
  end
end
