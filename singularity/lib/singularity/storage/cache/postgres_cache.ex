defmodule Singularity.Storage.Cache.PostgresCache do
  @moduledoc """
  PostgreSQL-based caching using UNLOGGED tables.

  A Redis-alternative cache that lives in PostgreSQL for:
  - Package metadata caching
  - Query result caching
  - Session data
  - Any volatile data that benefits from SQL queryability

  ## Features
  - ⚡ Fast UNLOGGED table (no WAL overhead)
  - 🔄 Automatic expiration
  - 📊 Hit count tracking
  - 🔍 Full SQL query support on cached data
  - 🎯 JSONB for complex data structures

  ## Usage

      # Store in cache
      PostgresCache.put("npm:react:18.0.0", package_data, ttl: 3600)

      # Retrieve from cache
      {:ok, data} = PostgresCache.get("npm:react:18.0.0")

      # Get or compute
      data = PostgresCache.fetch("npm:react:18.0.0", fn ->
        expensive_operation()
      end, ttl: 3600)

      # Statistics
      stats = PostgresCache.stats()
  """

  import Ecto.Query
  alias Singularity.Repo

  # 1 hour in seconds
  @default_ttl 3600

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Get a value from cache.

  Returns `{:ok, value}` if found and not expired, `{:error, :not_found}` otherwise.
  Increments hit counter on successful retrieval.
  """
  def get(cache_key) do
    query = """
    UPDATE package_cache
    SET hit_count = hit_count + 1
    WHERE cache_key = $1 AND expires_at > NOW()
    RETURNING package_data
    """

    case Repo.query(query, [cache_key]) do
      {:ok, %{rows: [[data]]}} -> {:ok, data}
      {:ok, %{rows: []}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Store a value in cache with optional TTL.

  Options:
  - `:ttl` - Time to live in seconds (default: 3600)
  """
  def put(cache_key, value, _opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)

    query = """
    INSERT INTO package_cache (cache_key, package_data, expires_at)
    VALUES ($1, $2, NOW() + INTERVAL '1 second' * $3)
    ON CONFLICT (cache_key) DO UPDATE
      SET package_data = EXCLUDED.package_data,
          expires_at = EXCLUDED.expires_at,
          created_at = NOW(),
          hit_count = 0
    """

    case Repo.query(query, [cache_key, value, ttl]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetch from cache or compute if missing.

  If the key exists and is not expired, returns the cached value.
  Otherwise, calls the provided function, stores the result, and returns it.

  Options:
  - `:ttl` - Time to live in seconds (default: 3600)
  """
  def fetch(cache_key, compute_fn, _opts \\ []) do
    case get(cache_key) do
      {:ok, value} ->
        value

      {:error, :not_found} ->
        value = compute_fn.()
        put(cache_key, value, _opts)
        value
    end
  end

  @doc """
  Delete a specific cache entry.
  """
  def delete(cache_key) do
    query = "DELETE FROM package_cache WHERE cache_key = $1"

    case Repo.query(query, [cache_key]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete all cache entries matching a pattern.

  Example: delete_pattern("npm:%") deletes all npm package caches.
  """
  def delete_pattern(pattern) do
    query = "DELETE FROM package_cache WHERE cache_key LIKE $1"

    case Repo.query(query, [pattern]) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Clean up all expired cache entries.

  Returns the number of deleted entries.
  """
  def cleanup_expired do
    case Repo.query("SELECT cleanup_expired_cache()", []) do
      {:ok, %{rows: [[count]]}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get cache statistics.

  Returns a map with:
  - `:total_entries` - Total cache entries
  - `:expired_entries` - Expired but not yet cleaned
  - `:valid_entries` - Currently valid entries
  - `:total_size_mb` - Total size in MB
  - `:avg_hit_count` - Average hit count
  """
  def stats do
    case Repo.query("SELECT * FROM cache_stats()", []) do
      {:ok, %{rows: [[total, expired, valid, size, avg_hits]]}} ->
        %{
          total_entries: total,
          expired_entries: expired,
          valid_entries: valid,
          total_size_mb: Decimal.to_float(size),
          avg_hit_count: Decimal.to_float(avg_hits)
        }

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get the most frequently accessed cache entries.
  """
  def top_hits(limit \\ 10) do
    query = """
    SELECT cache_key, hit_count, created_at, expires_at
    FROM package_cache
    WHERE expires_at > NOW()
    ORDER BY hit_count DESC
    LIMIT $1
    """

    case Repo.query(query, [limit]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [key, hits, created, expires] ->
          %{
            cache_key: key,
            hit_count: hits,
            created_at: created,
            expires_at: expires
          }
        end)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Clear all cache entries (careful!).
  """
  def clear_all do
    case Repo.query("TRUNCATE package_cache", []) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Prewarm cache with hot packages from materialized view.
  """
  def prewarm_hot_packages do
    query = """
    INSERT INTO package_cache (cache_key, package_data, expires_at)
    SELECT
      ecosystem || ':' || package_name || ':' || version as cache_key,
      to_jsonb(hot_packages.*) as package_data,
      NOW() + INTERVAL '24 hours' as expires_at
    FROM hot_packages
    ON CONFLICT (cache_key) DO NOTHING
    """

    case Repo.query(query, []) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Refresh the hot packages materialized view.
  """
  def refresh_hot_packages do
    case Repo.query("REFRESH MATERIALIZED VIEW CONCURRENTLY hot_packages", []) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Prewarm the entire cache by refreshing hot packages view and loading into cache.

  Called by CachePrewarmWorker every 6 hours.
  Combines refresh_hot_packages and prewarm_hot_packages operations.

  Returns `{:ok, count}` with number of cache entries prewarmed.
  """
  def prewarm_cache do
    with :ok <- refresh_hot_packages(),
         {:ok, count} <- prewarm_hot_packages() do
      {:ok, count}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
