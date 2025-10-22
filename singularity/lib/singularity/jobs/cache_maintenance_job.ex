defmodule Singularity.Jobs.CacheMaintenanceJob do
  @moduledoc """
  Background job for PostgreSQL cache maintenance.

  Responsibilities:
  - Clean up expired cache entries (every 15 minutes)
  - Refresh materialized views (every 1 hour)
  - Prewarm cache with hot data (every 6 hours)
  - Report cache statistics

  This module provides static functions that are scheduled via Quantum.
  Previously implemented as a GenServer with timers in CacheJanitor.
  """

  require Logger
  alias Singularity.Storage.Cache.PostgresCache

  @doc """
  Clean up expired cache entries.

  Called every 15 minutes via Quantum scheduler.
  """
  def cleanup do
    Logger.debug("🧹 Running cache cleanup...")

    case PostgresCache.cleanup_expired() do
      {:ok, count} ->
        if count > 0 do
          Logger.info("🧹 Cleaned up #{count} expired cache entries")
        end

        {:ok, count}

      {:error, reason} ->
        Logger.error("❌ Cache cleanup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Refresh hot packages materialized view.

  Called every 1 hour via Quantum scheduler.
  """
  def refresh do
    Logger.debug("🔄 Refreshing hot packages materialized view...")

    case PostgresCache.refresh_hot_packages() do
      :ok ->
        Logger.info("✅ Hot packages materialized view refreshed")
        :ok

      {:error, reason} ->
        Logger.error("❌ Materialized view refresh failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Prewarm cache with hot data.

  Called every 6 hours via Quantum scheduler.
  """
  def prewarm do
    Logger.debug("🔥 Prewarming cache with hot data...")

    case PostgresCache.prewarm_cache() do
      {:ok, count} ->
        Logger.info("🔥 Prewarmed #{count} cache entries")
        {:ok, count}

      {:error, reason} ->
        Logger.error("❌ Cache prewarm failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get current cache statistics.

  Can be called on-demand at any time.
  """
  def get_stats do
    case PostgresCache.stats() do
      {:ok, stats} ->
        Logger.info("📊 Cache stats", stats: stats)
        {:ok, stats}

      {:error, reason} ->
        Logger.error("❌ Failed to get cache stats: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
