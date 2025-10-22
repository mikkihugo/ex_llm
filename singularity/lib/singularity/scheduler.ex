defmodule Singularity.Scheduler do
  @moduledoc """
  Quantum Scheduler Configuration

  Manages cron-like scheduled tasks for periodic background work:
  - Cache cleanup and maintenance
  - Pattern synchronization
  - Other periodic jobs

  Configuration is in config/config.exs under `Singularity.Scheduler` key.

  Jobs are executed in the main BEAM process pool, separate from Oban's
  background job queue. Use Quantum for periodic maintenance tasks that
  don't need job persistence or complex retry logic.

  ## Jobs

  - **Cache Cleanup** (every 15 min) - Remove expired cache entries
  - **Cache Refresh** (every 1 hour) - Refresh materialized views
  - **Cache Prewarm** (every 6 hours) - Preload hot data into cache
  - **Pattern Sync** (every 5 min) - Sync framework patterns to ETS/NATS/JSON
  """

  use Quantum.Scheduler, otp_app: :singularity
end
