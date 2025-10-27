defmodule Genesis.Repo.Migrations.EnablePgCron do
  use Ecto.Migration

  @moduledoc """
  Enable pg_cron extension for autonomous task scheduling in Genesis database.

  pg_cron is PostgreSQL's native task scheduler, allowing autonomous operations
  to run independently of the application layer at database-native speeds.

  ## Scheduled Tasks

  Genesis uses pg_cron for:
  - Experiment cleanup: Remove old/stale experiments every 1 hour
  - Metrics aggregation: Summarize experiment metrics every 30 minutes
  - Sandbox reset: Clear test data every 6 hours

  ## Extension Details

  pg_cron runs jobs in the background using PostgreSQL's own scheduler.
  Jobs are tracked in the `cron.job` table and execute PL/pgSQL procedures
  or SQL commands independently of Elixir.

  This is essential for Genesis to maintain autonomy and not depend on Elixir
  availability for critical maintenance tasks.
  """

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_cron"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS pg_cron CASCADE"
  end
end
