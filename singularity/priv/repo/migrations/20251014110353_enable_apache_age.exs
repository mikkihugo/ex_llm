defmodule Singularity.Repo.Migrations.EnableApacheAge do
  use Ecto.Migration

  @moduledoc """
  Enable Apache AGE extension for graph database with Cypher queries.

  Apache AGE adds native graph capabilities to PostgreSQL:
  - Cypher query language (like Neo4j)
  - Graph algorithms (shortest path, PageRank, etc.)
  - Better performance for 3+ hop queries

  Note: Requires AGE extension to be installed (included in flake.nix)
  """

  def up do
    # Check if AGE extension is available (skip if not)
    case repo().query("SELECT 1 FROM pg_available_extensions WHERE name = 'age'") do
      {:ok, %{num_rows: 0}} ->
        IO.puts("⚠️  Apache AGE extension not available - skipping graph database setup")
        IO.puts("   This is OK - graph features are optional")
        :ok

      {:ok, _} ->
        # Enable AGE extension
        execute "CREATE EXTENSION IF NOT EXISTS age CASCADE"

        # Load AGE into search path
        execute "LOAD 'age'"

        # Set search path to include ag_catalog
        execute "SET search_path = ag_catalog, \"$user\", public"

        # Create graph for codebase (only if doesn't exist)
        execute """
        DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM ag_catalog.ag_graph WHERE name = 'singularity_code'
          ) THEN
            PERFORM ag_catalog.create_graph('singularity_code');
          END IF;
        END $$;
        """

        # Note: Apache AGE doesn't support "IF NOT EXISTS" for VLABEL/ELABEL
        # Vertex/edge labels are created automatically when first used in Cypher queries
        # So we'll skip explicit creation and let them be created on-demand

        IO.puts("✅ Apache AGE graph database enabled: singularity_code")

      {:error, _} ->
        IO.puts("⚠️  Could not check AGE extension - skipping")
        :ok
    end
  end

  def down do
    # Drop graph (cascades to all vertices/edges)
    execute "SELECT ag_catalog.drop_graph('singularity_code', true)"

    # Drop extension
    execute "DROP EXTENSION IF EXISTS age CASCADE"
  end
end
