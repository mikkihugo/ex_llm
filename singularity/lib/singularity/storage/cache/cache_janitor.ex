defmodule Singularity.Storage.Cache.CacheJanitor do
  @moduledoc """
  Background worker for automatic cache maintenance.

  Responsibilities:
  - Clean up expired cache entries
  - Refresh materialized views
  - Prewarm cache with hot data
  - Report cache statistics

  Runs periodically to keep the cache healthy.
  """

  use GenServer
  require Logger
  alias Singularity.Storage.Cache.PostgresCache

  # Every 15 minutes
  @cleanup_interval :timer.minutes(15)
  # Every hour
  @refresh_interval :timer.hours(1)
  # Every 6 hours
  @prewarm_interval :timer.hours(6)

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Trigger immediate cleanup.
  """
  def cleanup_now do
    GenServer.cast(__MODULE__, :cleanup)
  end

  @doc """
  Trigger immediate refresh of hot packages.
  """
  def refresh_now do
    GenServer.cast(__MODULE__, :refresh)
  end

  @doc """
  Get current cache statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    Logger.info("🧹 Starting CacheJanitor for PostgreSQL cache maintenance")

    # Schedule periodic tasks
    schedule_cleanup()
    schedule_refresh()
    schedule_prewarm()

    # Initial prewarm on startup
    send(self(), :prewarm)

    {:ok, %{stats: %{}, last_cleanup: nil, last_refresh: nil}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    Logger.debug("🧹 Running cache cleanup...")

    case PostgresCache.cleanup_expired() do
      {:ok, count} ->
        if count > 0 do
          Logger.info("🧹 Cleaned up #{count} expired cache entries")
        end

        schedule_cleanup()
        {:noreply, %{state | last_cleanup: DateTime.utc_now()}}

      {:error, reason} ->
        Logger.error("❌ Cache cleanup failed: #{inspect(reason)}")
        schedule_cleanup()
        {:noreply, state}
    end
  end

  def handle_info(:refresh, state) do
    Logger.debug("🔄 Refreshing hot packages materialized view...")

    case PostgresCache.refresh_hot_packages() do
      :ok ->
        Logger.info("✅ Hot packages materialized view refreshed")
        schedule_refresh()
        {:noreply, %{state | last_refresh: DateTime.utc_now()}}

      {:error, reason} ->
        Logger.error("❌ Materialized view refresh failed: #{inspect(reason)}")
        schedule_refresh()
        {:noreply, state}
    end
  end

  def handle_info(:prewarm, state) do
    Logger.debug("🔥 Prewarming cache with hot packages...")

    case PostgresCache.prewarm_hot_packages() do
      {:ok, count} ->
        Logger.info("🔥 Prewarmed cache with #{count} hot packages")
        schedule_prewarm()
        {:noreply, state}

      {:error, reason} ->
        Logger.error("❌ Cache prewarm failed: #{inspect(reason)}")
        schedule_prewarm()
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:cleanup, state) do
    send(self(), :cleanup)
    {:noreply, state}
  end

  def handle_cast(:refresh, state) do
    send(self(), :refresh)
    {:noreply, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      case PostgresCache.stats() do
        {:error, _} -> %{}
        stats -> stats
      end

    top_hits = PostgresCache.top_hits(5)

    response = %{
      cache_stats: stats,
      top_hits: top_hits,
      last_cleanup: state.last_cleanup,
      last_refresh: state.last_refresh
    }

    {:reply, response, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp schedule_prewarm do
    Process.send_after(self(), :prewarm, @prewarm_interval)
  end
end
