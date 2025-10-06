defmodule Singularity.Repo.Migrations.RenameToolTablesToPackageTables do
  use Ecto.Migration

  @moduledoc """
  Phase 1: Rename tool_* tables to package_* tables for clarity

  BEFORE: "tools" - What tools? Internal? External? Vague!
  AFTER: "external_package_*" - Clear: npm/cargo/hex/pypi packages

  This follows the naming convention: <What><How>
  - external_package_registry = External packages, Registry
  - package_usage_patterns = Package usage, Patterns
  - package_code_examples = Package examples, Code
  """

  def up do
    # Main package table: tools → external_package_registry
    execute "ALTER TABLE tools RENAME TO external_package_registry"

    # Rename indexes
    execute "ALTER INDEX tools_pkey RENAME TO external_package_registry_pkey"
    execute """
    ALTER INDEX IF EXISTS dependency_catalog_unique_identifier
    RENAME TO external_package_registry_unique_identifier
    """

    # Related tables: tool_* → package_*
    execute "ALTER TABLE tool_patterns RENAME TO package_usage_patterns"
    execute "ALTER TABLE tool_examples RENAME TO package_code_examples"
    execute "ALTER TABLE tool_dependencies RENAME TO package_dependency_graph"

    # Update foreign key constraints
    # tool_patterns -> package_usage_patterns
    execute """
    ALTER TABLE package_usage_patterns
    DROP CONSTRAINT IF EXISTS tool_patterns_tool_id_fkey
    """
    execute """
    ALTER TABLE package_usage_patterns
    ADD CONSTRAINT package_usage_patterns_package_id_fkey
    FOREIGN KEY (tool_id)
    REFERENCES external_package_registry(id)
    ON DELETE CASCADE
    """

    # tool_examples -> package_code_examples
    execute """
    ALTER TABLE package_code_examples
    DROP CONSTRAINT IF EXISTS tool_examples_tool_id_fkey
    """
    execute """
    ALTER TABLE package_code_examples
    ADD CONSTRAINT package_code_examples_package_id_fkey
    FOREIGN KEY (tool_id)
    REFERENCES external_package_registry(id)
    ON DELETE CASCADE
    """

    # tool_dependencies -> package_dependency_graph
    execute """
    ALTER TABLE package_dependency_graph
    DROP CONSTRAINT IF EXISTS tool_dependencies_tool_id_fkey
    """
    execute """
    ALTER TABLE package_dependency_graph
    ADD CONSTRAINT package_dependency_graph_package_id_fkey
    FOREIGN KEY (tool_id)
    REFERENCES external_package_registry(id)
    ON DELETE CASCADE
    """

    # Note: Column names (tool_id) stay the same for now
    # Can rename in separate migration if needed
  end

  def down do
    # Reverse foreign key constraints
    execute """
    ALTER TABLE package_dependency_graph
    DROP CONSTRAINT IF EXISTS package_dependency_graph_package_id_fkey
    """
    execute """
    ALTER TABLE package_dependency_graph
    ADD CONSTRAINT tool_dependencies_tool_id_fkey
    FOREIGN KEY (tool_id)
    REFERENCES tools(id)
    ON DELETE CASCADE
    """

    execute """
    ALTER TABLE package_code_examples
    DROP CONSTRAINT IF EXISTS package_code_examples_package_id_fkey
    """
    execute """
    ALTER TABLE package_code_examples
    ADD CONSTRAINT tool_examples_tool_id_fkey
    FOREIGN KEY (tool_id)
    REFERENCES tools(id)
    ON DELETE CASCADE
    """

    execute """
    ALTER TABLE package_usage_patterns
    DROP CONSTRAINT IF EXISTS package_usage_patterns_package_id_fkey
    """
    execute """
    ALTER TABLE package_usage_patterns
    ADD CONSTRAINT tool_patterns_tool_id_fkey
    FOREIGN KEY (tool_id)
    REFERENCES tools(id)
    ON DELETE CASCADE
    """

    # Reverse table renames
    execute "ALTER TABLE package_dependency_graph RENAME TO tool_dependencies"
    execute "ALTER TABLE package_code_examples RENAME TO tool_examples"
    execute "ALTER TABLE package_usage_patterns RENAME TO tool_patterns"

    execute """
    ALTER INDEX IF EXISTS external_package_registry_unique_identifier
    RENAME TO dependency_catalog_unique_identifier
    """
    execute "ALTER INDEX external_package_registry_pkey RENAME TO tools_pkey"
    execute "ALTER TABLE external_package_registry RENAME TO tools"
  end
end
