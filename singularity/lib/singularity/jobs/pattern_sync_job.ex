defmodule Singularity.Jobs.PatternSyncJob do
  @moduledoc """
  Background job for syncing framework patterns across the system.

  Syncs framework patterns through:
  - PostgreSQL (source of truth, self-learning)
  - ETS Cache (hot patterns, <5ms reads)
  - NATS (distribute to SPARC fact system)
  - JSON Export (for Rust detector to read)

  This module provides static functions that are scheduled via Quantum.
  Previously implemented as timer logic within FrameworkPatternSync GenServer.
  """

  require Logger

  @doc """
  Refresh pattern cache and sync to NATS/JSON.

  Called every 5 minutes via Quantum scheduler.
  """
  def sync do
    Logger.debug("🔄 Syncing framework patterns...")

    case Singularity.ArchitectureEngine.FrameworkPatternSync.refresh_cache() do
      :ok ->
        Logger.info("✅ Framework patterns synced")
        :ok

      {:error, reason} ->
        Logger.error("❌ Pattern sync failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
