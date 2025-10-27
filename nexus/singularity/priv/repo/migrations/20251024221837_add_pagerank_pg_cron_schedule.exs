defmodule Singularity.Repo.Migrations.AddPageRankPgCronSchedule do
  use Ecto.Migration

  @moduledoc """
  Setup pg_cron scheduled task for automatic daily PageRank recalculation.

  ## TEMPORARILY DISABLED FOR DEVELOPMENT
  This migration is disabled because pg_cron is not enabled in development.
  Re-enable once pg_cron is properly configured.
  """

  def up do
    # Schedule daily PageRank recalculation at 3 AM UTC
    # This ensures that the dependency graph's PageRank scores are updated daily
    # to reflect the latest code patterns and architecture insights
    execute("""
      SELECT cron.schedule(
        'daily-pagerank-recalc',
        '0 3 * * *',
        'SELECT Singularity.ArchitectureEngine.PageRankCalculator.recalculate_all_pagerank()'
      );
    """)
  end

  def down do
    # Unschedule PageRank recalculation
    execute("SELECT cron.unschedule('daily-pagerank-recalc')")
  rescue
    _ -> :ok
  end
end
