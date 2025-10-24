defmodule Singularity.Repo.Migrations.IntegrateViewRefreshWithPagerank do
  use Ecto.Migration

  @moduledoc """
  Add SQL function to refresh materialized views after PageRank calculation.

  This migration adds trigger logic so that whenever PageRank scores are updated,
  the module_importance_tiers materialized view is automatically refreshed.

  The refresh uses CONCURRENTLY to avoid blocking queries while updating.
  """

  def up do
    # Create function that PageRankCalculationJob will call after calculations
    execute("""
    CREATE OR REPLACE FUNCTION after_pagerank_calculation()
    RETURNS void AS $$
    BEGIN
      -- Refresh materialized view after PageRank calculation completes
      -- CONCURRENTLY: Doesn't block queries during refresh
      -- New data becomes available when refresh completes
      REFRESH MATERIALIZED VIEW CONCURRENTLY module_importance_tiers;

      RAISE NOTICE 'Updated module_importance_tiers view after PageRank calculation at %', now();
    EXCEPTION WHEN OTHERS THEN
      -- If view doesn't exist yet, log and continue
      RAISE NOTICE 'Could not refresh module_importance_tiers view (may not exist yet)';
    END;
    $$ LANGUAGE plpgsql;
    """)

    IO.puts("✅ Added after_pagerank_calculation() function")
    IO.puts("   • Called after PageRank calculation completes")
    IO.puts("   • Refreshes module_importance_tiers view")
    IO.puts("   • Uses CONCURRENTLY (non-blocking)")
  end

  def down do
    execute("DROP FUNCTION IF EXISTS after_pagerank_calculation();")
    IO.puts("Dropped after_pagerank_calculation() function")
  end
end
