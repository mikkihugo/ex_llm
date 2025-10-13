defmodule Singularity.Repo.Migrations.RenameToDependencyCatalog do
  use Ecto.Migration

  def change do
    # Rename main table from store_packages to dependency_catalog
    # Note: tools table was never populated, store_packages is the actual table
    rename table(:store_packages), to: table(:dependency_catalog)

    # Rename related tables (if they exist)
    # These may not exist yet, so we use IF EXISTS
    execute "ALTER TABLE IF EXISTS tool_examples RENAME TO dependency_catalog_examples", ""
    execute "ALTER TABLE IF EXISTS tool_patterns RENAME TO dependency_catalog_patterns", ""
    execute "ALTER TABLE IF EXISTS tool_dependencies RENAME TO dependency_catalog_deps", ""

    # Rename indexes (one at a time to avoid prepared statement issue)
    execute "ALTER INDEX IF EXISTS store_packages_pkey RENAME TO dependency_catalog_pkey", "ALTER INDEX IF EXISTS dependency_catalog_pkey RENAME TO store_packages_pkey"
    execute "ALTER INDEX IF EXISTS store_packages_package_name_version_ecosystem_index RENAME TO dependency_catalog_unique_identifier", "ALTER INDEX IF EXISTS dependency_catalog_unique_identifier RENAME TO store_packages_package_name_version_ecosystem_index"
    execute "ALTER INDEX IF EXISTS store_packages_ecosystem_index RENAME TO dependency_catalog_ecosystem_index", "ALTER INDEX IF EXISTS dependency_catalog_ecosystem_index RENAME TO store_packages_ecosystem_index"
    execute "ALTER INDEX IF EXISTS store_packages_github_stars_index RENAME TO dependency_catalog_github_stars_index", "ALTER INDEX IF EXISTS dependency_catalog_github_stars_index RENAME TO store_packages_github_stars_index"
    execute "ALTER INDEX IF EXISTS idx_store_packages_embedding RENAME TO dependency_catalog_embedding_idx", "ALTER INDEX IF EXISTS dependency_catalog_embedding_idx RENAME TO idx_store_packages_embedding"
  end
end
