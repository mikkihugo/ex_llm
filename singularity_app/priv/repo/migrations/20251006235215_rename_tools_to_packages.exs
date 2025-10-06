defmodule Singularity.Repo.Migrations.RenameToolsToPackages do
  use Ecto.Migration

  def change do
    # Rename main table
    rename table(:tools), to: table(:packages)
    
    # Rename related tables for clarity
    rename table(:tool_examples), to: table(:package_examples)
    rename table(:tool_patterns), to: table(:package_patterns)  
    rename table(:tool_dependencies), to: table(:package_dependencies)
    
    # Update foreign key column names
    rename table(:package_examples), :tool_id, to: :package_id
    rename table(:package_patterns), :tool_id, to: :package_id
    rename table(:package_dependencies), :tool_id, to: :package_id
    
    # Rename indexes to match
    execute """
    ALTER INDEX tools_unique_identifier RENAME TO packages_unique_identifier;
    ALTER INDEX tools_semantic_embedding_idx RENAME TO packages_semantic_embedding_idx;
    """, """
    ALTER INDEX packages_unique_identifier RENAME TO tools_unique_identifier;
    ALTER INDEX packages_semantic_embedding_idx RENAME TO tools_semantic_embedding_idx;
    """
  end
end
