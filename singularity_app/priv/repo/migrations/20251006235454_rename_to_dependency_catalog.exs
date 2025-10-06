defmodule Singularity.Repo.Migrations.RenameToDependencyCatalog do
  use Ecto.Migration

  def change do
    # Rename main table to dependency_catalog
    rename table(:packages), to: table(:dependency_catalog)
    
    # Rename related tables
    rename table(:package_examples), to: table(:dependency_catalog_examples)
    rename table(:package_patterns), to: table(:dependency_catalog_patterns)  
    rename table(:package_dependencies), to: table(:dependency_catalog_deps)
    
    # Update foreign key column names
    rename table(:dependency_catalog_examples), :package_id, to: :dependency_id
    rename table(:dependency_catalog_patterns), :package_id, to: :dependency_id
    rename table(:dependency_catalog_deps), :package_id, to: :dependency_id
    
    # Rename indexes
    execute """
    ALTER INDEX IF EXISTS packages_unique_identifier RENAME TO dependency_catalog_unique_identifier;
    ALTER INDEX IF EXISTS packages_semantic_embedding_idx RENAME TO dependency_catalog_embedding_idx;
    """, """
    ALTER INDEX IF EXISTS dependency_catalog_unique_identifier RENAME TO packages_unique_identifier;
    ALTER INDEX IF EXISTS dependency_catalog_embedding_idx RENAME TO packages_semantic_embedding_idx;
    """
  end
end
