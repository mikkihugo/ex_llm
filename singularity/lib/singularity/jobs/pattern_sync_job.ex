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

  Syncs patterns from PostgreSQL → ETS → NATS → JSON file.
  """
  def sync do
    Logger.debug("🔄 Syncing framework patterns...")

    try do
      case Singularity.ArchitectureEngine.FrameworkPatternSync.refresh_cache() do
        :ok ->
          Logger.info("✅ Framework patterns synced to ETS/NATS/JSON")
          :ok

        {:error, reason} ->
          Logger.error("❌ Pattern sync failed", reason: inspect(reason))
          :ok  # Don't fail - patterns will sync on next cycle
      end
    rescue
      e in Exception ->
        Logger.error("❌ Pattern sync exception", error: inspect(e))
        :ok  # Log but don't crash the scheduler
    end
  end
end
