defmodule CentralCloud.Repo.Migrations.AddLogicalReplicationForTemplates do
  use Ecto.Migration

  def up do
    # Add templates to logical replication publication
    # This allows Singularity instances to subscribe and receive read-only copies
    
    execute """
    -- Add templates to existing publication (or create if needed)
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'centralcloud_templates') THEN
        CREATE PUBLICATION centralcloud_templates FOR TABLE templates;
      ELSE
        ALTER PUBLICATION centralcloud_templates ADD TABLE templates;
      END IF;
    END $$;
    """
    
    # Grant SELECT to replication user (if exists)
    execute """
    -- Grant SELECT to replication user for logical replication
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'replication_user') THEN
        GRANT SELECT ON templates TO replication_user;
      END IF;
    END $$;
    """
  end

  def down do
    execute """
    ALTER PUBLICATION centralcloud_templates DROP TABLE templates;
    """
  end
end
