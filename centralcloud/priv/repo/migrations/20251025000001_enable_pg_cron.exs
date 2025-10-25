defmodule CentralCloud.Repo.Migrations.EnablePgCron do
  use Ecto.Migration

  @moduledoc """
  Enable pg_cron extension for autonomous task scheduling in CentralCloud.

  pg_cron enables CentralCloud to run autonomous aggregation and learning tasks
  independently of the application layer, providing fault-tolerant distributed
  learning across multiple Singularity instances.

  ## Scheduled Tasks

  CentralCloud uses pg_cron for:
  - Knowledge aggregation: Combine learnings from all instances every 10 minutes
  - Pattern consolidation: Identify common patterns across instances every 1 hour
  - Package stats update: Update package intelligence every 6 hours
  - Metrics cleanup: Archive old metrics every 24 hours

  ## Autonomous Learning Loop

  1. Singularity instances stream learned patterns via CDC (wal2json)
  2. pg_cron aggregates patterns into global knowledge base
  3. CentralCloud exports consolidated knowledge back to instances
  4. Continuous improvement without Elixir dependency

  This is critical for the multi-instance self-improving system to work autonomously.
  """

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_cron"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS pg_cron CASCADE"
  end
end
