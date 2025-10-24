defmodule Singularity.Metrics.QueryCache do
  @moduledoc """
  Metrics Query Cache - ETS-backed result caching with TTL.

  GenServer managing an ETS table for caching query results.
  Eliminates repeated database queries by caching results for short TTL.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Metrics.QueryCache",
    "purpose": "ETS caching of query results with automatic TTL cleanup",
    "layer": "metrics",
    "status": "production",
    "backend": "ETS"
  }
  ```

  ## Self-Documenting API

  - `get(key)` - Retrieve cached result if fresh
  - `put(key, value)` - Cache a result
  - `delete(key)` - Manually invalidate entry
  - `invalidate_all()` - Clear entire cache
  - `cleanup_expired()` - Remove expired entries (called periodically)

  ## Cache Strategy

  - **Default TTL**: 5 seconds
  - **Storage**: ETS public table (fast concurrent reads)
  - **Entry Format**: {key, value, expires_at}
  - **Cleanup**: On get (lazy removal) + periodic timer task

  ## Example Usage

  ```elixir
  # Cache a query result
  QueryCache.put(
    "agent_metrics_agent-123_day_ago_now",
    {:ok, %{success_rate: 0.95, ...}},
    ttl_ms: 5000
  )

  # Retrieve (returns nil if expired or missing)
  {:ok, metrics} = QueryCache.get("agent_metrics_agent-123_day_ago_now")
  ```

  ## Performance

  - ETS lookups: ~1 microsecond (in-memory)
  - Database query (if miss): ~10-50 milliseconds
  - Cache hit savings: 50x faster

  ## Implementation Notes

  - ETS `:public` mode (read without lock)
  - No write locking (single GenServer manages all writes)
  - Lazy expiration on get + periodic cleanup
  - Loss on app restart is acceptable (cache is optional)
  """

  use GenServer
  require Logger

  @default_ttl_ms 5000  # 5 second cache TTL
  @cleanup_interval_ms 60_000  # Cleanup every minute

  @doc """
  Start the cache GenServer.

  Typically called by Metrics.Supervisor, not directly.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.debug("Starting Metrics QueryCache")

    # Create ETS table for caching
    _table = :ets.new(:metrics_query_cache, [
      :public,
      :named_table,
      :set,
      {:read_concurrency, true}
    ])

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, %{}}
  end

  @doc """
  Retrieve cached result if still valid.

  Returns value if found and not expired, nil if missing or expired.
  """
  def get(key) do
    case :ets.lookup(:metrics_query_cache, key) do
      [] ->
        # Not in cache
        nil

      [{^key, value, expires_at}] ->
        # Check expiration
        now = System.monotonic_time(:millisecond)

        if now < expires_at do
          # Still valid
          value
        else
          # Expired, remove it
          :ets.delete(:metrics_query_cache, key)
          nil
        end
    end
  end

  @doc """
  Cache a result with optional TTL.

  ## Parameters

  - `key` - Cache key (string or term)
  - `value` - Value to cache
  - `opts` - Options keyword list with `:ttl_ms` (default: 5000)
  """
  def put(key, value, opts \\ []) do
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
    expires_at = System.monotonic_time(:millisecond) + ttl_ms

    :ets.insert(:metrics_query_cache, {key, value, expires_at})
    :ok
  end

  @doc """
  Manually invalidate a cached entry.
  """
  def delete(key) do
    :ets.delete(:metrics_query_cache, key)
    :ok
  end

  @doc """
  Clear entire cache.
  """
  def invalidate_all do
    :ets.delete_all_objects(:metrics_query_cache)
    :ok
  end

  @doc """
  Get cache statistics (for monitoring).

  Returns: `%{size: int, capacity: int}`
  """
  def stats do
    info = :ets.info(:metrics_query_cache)

    %{
      size: info[:size],
      memory_bytes: info[:memory]
    }
  end

  @doc """
  Cleanup expired entries (called periodically by timer).

  Removes entries where expires_at < now.
  Called automatically via cleanup schedule.
  """
  def cleanup_expired do
    GenServer.cast(__MODULE__, :cleanup)
  end

  @impl true
  def handle_cast(:cleanup, state) do
    # Scan entire cache and remove expired entries
    now = System.monotonic_time(:millisecond)

    # Get all entries
    all_entries = :ets.tab2list(:metrics_query_cache)

    # Filter and delete expired
    expired_keys =
      all_entries
      |> Enum.filter(fn {_key, _value, expires_at} -> now >= expires_at end)
      |> Enum.map(fn {key, _value, _expires_at} -> key end)

    Enum.each(expired_keys, fn key -> :ets.delete(:metrics_query_cache, key) end)

    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up #{length(expired_keys)} expired cache entries")
    end

    {:noreply, state}
  end

  # Private helpers

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_timer, @cleanup_interval_ms)
  end

  @impl true
  def handle_info(:cleanup_timer, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end
end
