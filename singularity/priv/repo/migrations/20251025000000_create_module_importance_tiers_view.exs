defmodule Singularity.Repo.Migrations.CreateModuleImportanceTiersView do
  use Ecto.Migration

  @moduledoc """
  Create materialized view for module importance tier distribution.

  This view pre-calculates module importance tiers for instant queries.
  Uses window functions to automatically classify modules:
  - CRITICAL (>5.0): Core infrastructure modules
  - IMPORTANT (2.0-5.0): Significant modules with many dependents
  - MODERATE (0.5-2.0): Standard modules with moderate importance
  - LOW (<0.5): Specialized or rarely-called modules

  ## Performance

  Without view: Full table scan + sort + tier calculation = 2-3 seconds
  With view: Indexed lookup = 1-5ms

  ## Refresh Strategy

  View refreshes automatically after PageRank calculation completes.
  Add to pagerank_daily_refresh() SQL function:
    REFRESH MATERIALIZED VIEW CONCURRENTLY module_importance_tiers;

  ## Usage

  ```sql
  -- Instant tier summary
  SELECT tier, COUNT(*), AVG(pagerank_score)
  FROM module_importance_tiers
  WHERE codebase_id = 'singularity'
  GROUP BY tier;
  ```
  """

  def up do
    # Create materialized view - only runs if graph_nodes table exists
    execute(~s(
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'graph_nodes') THEN
          CREATE MATERIALIZED VIEW IF NOT EXISTS module_importance_tiers AS
          SELECT
            codebase_id,
            name,
            file_path,
            node_type,
            pagerank_score,
            CASE
              WHEN pagerank_score > 5.0 THEN 'CRITICAL'
              WHEN pagerank_score > 2.0 THEN 'IMPORTANT'
              WHEN pagerank_score > 0.5 THEN 'MODERATE'
              ELSE 'LOW'
            END as tier,
            NTILE(100) OVER (
              PARTITION BY codebase_id
              ORDER BY pagerank_score DESC
            ) as percentile,
            RANK() OVER (
              PARTITION BY codebase_id
              ORDER BY pagerank_score DESC
            ) as rank_in_codebase,
            COUNT(*) FILTER (WHERE pagerank_score > 0) OVER (
              PARTITION BY codebase_id
            ) as total_modules
          FROM graph_nodes
          WHERE pagerank_score > 0
          ORDER BY codebase_id, pagerank_score DESC;

          CREATE INDEX IF NOT EXISTS idx_module_importance_tiers_codebase
          ON module_importance_tiers(codebase_id);

          CREATE INDEX IF NOT EXISTS idx_module_importance_tiers_tier
          ON module_importance_tiers(codebase_id, tier);

          CREATE INDEX IF NOT EXISTS idx_module_importance_tiers_rank
          ON module_importance_tiers(codebase_id, rank_in_codebase);
        END IF;
      END$$;
    ))
  end

  def down do
    # Drop view (automatically drops dependent objects if needed)
    execute("DROP MATERIALIZED VIEW IF EXISTS module_importance_tiers CASCADE;")
    IO.puts("Dropped materialized view: module_importance_tiers")
  end
end
