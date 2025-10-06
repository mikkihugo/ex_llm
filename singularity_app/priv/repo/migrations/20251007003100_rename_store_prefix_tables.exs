defmodule Singularity.Repo.Migrations.RenameStorePrefixTables do
  use Ecto.Migration

  @moduledoc """
  Phase 2: Remove confusing "store_" prefix from tables

  BEFORE: store_code_artifacts - "Store" is vague (everything is stored!)
  AFTER: code_artifacts - Clear and direct

  Pattern: Drop "store_" prefix or replace with more descriptive suffix
  """

  def up do
    # store_code_artifacts → code_artifacts (just drop "store_")
    execute "ALTER TABLE store_code_artifacts RENAME TO code_artifacts"

    # store_codebase_services → codebase_service_registry
    execute "ALTER TABLE store_codebase_services RENAME TO codebase_service_registry"

    # store_git_state → git_state_snapshots (more descriptive)
    execute "ALTER TABLE store_git_state RENAME TO git_state_snapshots"

    # NOTE: store_knowledge_artifacts, store_packages, store_templates
    # are likely DUPLICATES - will merge in Phase 3
  end

  def down do
    execute "ALTER TABLE git_state_snapshots RENAME TO store_git_state"
    execute "ALTER TABLE codebase_service_registry RENAME TO store_codebase_services"
    execute "ALTER TABLE code_artifacts RENAME TO store_code_artifacts"
  end
end
