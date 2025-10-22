defmodule Singularity.Repo.Migrations.RenameGraphAndGenericTables do
  use Ecto.Migration

  @moduledoc """
  Phase 5: Add context to generic table names

  BEFORE: "rules", "capabilities", "graph_nodes" - What? Where? Why?
  AFTER: Full context in the name
  """

  def up do
    # Graph tables (HTDAG task decomposition)
    execute "ALTER TABLE graph_nodes RENAME TO task_decomposition_graph_nodes"
    execute "ALTER TABLE graph_edges RENAME TO task_decomposition_graph_edges"
    execute "ALTER TABLE graph_types RENAME TO task_decomposition_graph_types"

    # Agent/Rule engine tables
    execute "ALTER TABLE rules RENAME TO agent_behavior_confidence_rules"
    execute "ALTER TABLE capabilities RENAME TO agent_capability_registry"

    # SAFe methodology tables (already good, but add prefix for consistency)
    execute "ALTER TABLE features RENAME TO safe_methodology_features"
    execute "ALTER TABLE epics RENAME TO safe_methodology_epics"
    # strategic_themes already has good context

    # Update indexes
    execute """
    ALTER INDEX IF EXISTS graph_nodes_pkey
    RENAME TO task_decomposition_graph_nodes_pkey
    """
    execute """
    ALTER INDEX IF EXISTS graph_edges_pkey
    RENAME TO task_decomposition_graph_edges_pkey
    """
    execute """
    ALTER INDEX IF EXISTS graph_types_pkey
    RENAME TO task_decomposition_graph_types_pkey
    """
    execute """
    ALTER INDEX IF EXISTS rules_pkey
    RENAME TO agent_behavior_confidence_rules_pkey
    """
    execute """
    ALTER INDEX IF EXISTS capabilities_pkey
    RENAME TO agent_capability_registry_pkey
    """
    execute """
    ALTER INDEX IF EXISTS features_pkey
    RENAME TO safe_methodology_features_pkey
    """
    execute """
    ALTER INDEX IF EXISTS epics_pkey
    RENAME TO safe_methodology_epics_pkey
    """
  end

  def down do
    # Reverse index renames
    execute """
    ALTER INDEX IF EXISTS safe_methodology_epics_pkey
    RENAME TO epics_pkey
    """
    execute """
    ALTER INDEX IF EXISTS safe_methodology_features_pkey
    RENAME TO features_pkey
    """
    execute """
    ALTER INDEX IF EXISTS agent_capability_registry_pkey
    RENAME TO capabilities_pkey
    """
    execute """
    ALTER INDEX IF EXISTS agent_behavior_confidence_rules_pkey
    RENAME TO rules_pkey
    """
    execute """
    ALTER INDEX IF EXISTS task_decomposition_graph_types_pkey
    RENAME TO graph_types_pkey
    """
    execute """
    ALTER INDEX IF EXISTS task_decomposition_graph_edges_pkey
    RENAME TO graph_edges_pkey
    """
    execute """
    ALTER INDEX IF EXISTS task_decomposition_graph_nodes_pkey
    RENAME TO graph_nodes_pkey
    """

    # Reverse table renames
    execute "ALTER TABLE safe_methodology_epics RENAME TO epics"
    execute "ALTER TABLE safe_methodology_features RENAME TO features"
    execute "ALTER TABLE agent_capability_registry RENAME TO capabilities"
    execute "ALTER TABLE agent_behavior_confidence_rules RENAME TO rules"
    execute "ALTER TABLE task_decomposition_graph_types RENAME TO graph_types"
    execute "ALTER TABLE task_decomposition_graph_edges RENAME TO graph_edges"
    execute "ALTER TABLE task_decomposition_graph_nodes RENAME TO graph_nodes"
  end
end
