defmodule Centralcloud.Scheduler do
  @moduledoc """
  Quantum Scheduler Configuration for Centralcloud

  Manages cron-like scheduled tasks for global intelligence aggregation:
  - Aggregate patterns from all Singularity instances
  - Sync external package registries (npm, cargo, hex, pypi)
  - Generate global statistics
  - Cleanup old aggregated data
  - Refresh knowledge caches

  Configuration is in config/config.exs under `Centralcloud.Scheduler` key.

  This makes Centralcloud a true global intelligence backend that runs
  automatically without intervention.

  ## Jobs

  - **Pattern Aggregation** (every 1 hour) - Combine patterns from all instances
  - **Package Sync** (every 1 day) - Update external package metadata
  - **Statistics Generation** (every 1 hour) - Generate global insights
  - **Data Cleanup** (every 1 week) - Remove old aggregated data
  - **Cache Prewarm** (every 6 hours) - Load hot knowledge into cache
  """

  use Quantum.Scheduler, otp_app: :centralcloud
end
