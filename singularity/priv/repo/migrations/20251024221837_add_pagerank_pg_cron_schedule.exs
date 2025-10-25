defmodule Singularity.Repo.Migrations.AddPageRankPgCronSchedule do
  use Ecto.Migration

  @moduledoc """
  Setup pg_cron scheduled task for automatic daily PageRank recalculation.

  ## TEMPORARILY DISABLED FOR DEVELOPMENT
  This migration is disabled because pg_cron is not enabled in development.
  Re-enable once pg_cron is properly configured.
  """

  def up do
    # No-op: pg_cron not available in development
  end

  def down do
    # No-op: pg_cron not available in development
  end
end
