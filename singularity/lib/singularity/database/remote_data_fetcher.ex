defmodule Singularity.Database.RemoteDataFetcher do
  @moduledoc """
  Remote data fetching via PostgreSQL pg_net extension.

  Fetches package registry data (npm, cargo, hex, pypi) directly from PostgreSQL
  using HTTP requests embedded in SQL. Results are stored in database for caching.

  ## Why pg_net?

  - No external HTTP libraries needed (PostgreSQL handles it)
  - Asynchronous (non-blocking) HTTP from SQL
  - Automatic request/response handling
  - Built-in timeout and retry logic
  - Results integrate seamlessly with SQL queries

  ## Architecture

  ```
  Elixir: PackageRegistry.fetch("tokio")
      ↓
  PostgreSQL pg_net.http_get()
      ↓
  External Registry API (npm.js.org, crates.io, etc)
      ↓
  PostgreSQL stores in package_registry table
      ↓
  Elixir app has full package metadata
  ```

  ## Supported Registries

  - npm: registry.npmjs.org/package
  - cargo: crates.io/api/v1/crates/package
  - hex: hex.pm/api/packages/package
  - pypi: pypi.org/pypi/package/json

  ## Usage

  ```elixir
  # Fetch and cache package metadata
  {:ok, pkg} = RemoteDataFetcher.fetch_npm("react")
  {:ok, pkg} = RemoteDataFetcher.fetch_cargo("tokio")
  {:ok, pkg} = RemoteDataFetcher.fetch_hex("phoenix")
  {:ok, pkg} = RemoteDataFetcher.fetch_pypi("django")

  # Get cached metadata (no network call)
  {:ok, pkg} = RemoteDataFetcher.get_cached("npm", "react")

  # Check if cached data is fresh (< 24h)
  true = RemoteDataFetcher.is_fresh?("cargo", "tokio")
  ```
  """

  require Logger
  alias CentralCloud.Repo

  @http_timeout 5000  # 5 seconds for external API calls
  @cache_ttl 86400    # 24 hours cache TTL

  # ============================================================================
  # npm Registry
  # ============================================================================

  @doc """
  Fetch package metadata from npm registry via pg_net.

  Caches result in package_registry table.
  """
  def fetch_npm(package_name) when is_binary(package_name) do
    url = "https://registry.npmjs.org/#{encode_url(package_name)}"

    case fetch_and_cache("npm", package_name, url) do
      {:ok, data} ->
        parse_npm_response(package_name, data)

      error ->
        error
    end
  end

  # ============================================================================
  # Cargo Registry
  # ============================================================================

  @doc """
  Fetch package metadata from Cargo registry via pg_net.

  Caches result in package_registry table.
  """
  def fetch_cargo(package_name) when is_binary(package_name) do
    url = "https://crates.io/api/v1/crates/#{encode_url(package_name)}"

    case fetch_and_cache("cargo", package_name, url) do
      {:ok, data} ->
        parse_cargo_response(package_name, data)

      error ->
        error
    end
  end

  # ============================================================================
  # Hex Registry
  # ============================================================================

  @doc """
  Fetch package metadata from Hex registry via pg_net.

  Caches result in package_registry table.
  """
  def fetch_hex(package_name) when is_binary(package_name) do
    url = "https://hex.pm/api/packages/#{encode_url(package_name)}"

    case fetch_and_cache("hex", package_name, url) do
      {:ok, data} ->
        parse_hex_response(package_name, data)

      error ->
        error
    end
  end

  # ============================================================================
  # PyPI Registry
  # ============================================================================

  @doc """
  Fetch package metadata from PyPI registry via pg_net.

  Caches result in package_registry table.
  """
  def fetch_pypi(package_name) when is_binary(package_name) do
    url = "https://pypi.org/pypi/#{encode_url(package_name)}/json"

    case fetch_and_cache("pypi", package_name, url) do
      {:ok, data} ->
        parse_pypi_response(package_name, data)

      error ->
        error
    end
  end

  # ============================================================================
  # Cache Management
  # ============================================================================

  @doc """
  Get cached package metadata (no network call).

  Returns {:ok, data} if cached, {:error, :not_found} if not cached or expired.
  """
  def get_cached(ecosystem, package_name) when is_binary(ecosystem) and is_binary(package_name) do
    case Repo.query("""
      SELECT metadata FROM package_registry
      WHERE ecosystem = $1 AND package_name = $2
        AND cached_at > NOW() - INTERVAL '1 day'
      LIMIT 1
    """, [ecosystem, package_name]) do
      {:ok, %{rows: [[metadata_json]]}} ->
        {:ok, Jason.decode!(metadata_json)}

      {:ok, %{rows: []}} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  @doc """
  Check if cached data is fresh (< 24 hours old).
  """
  def is_fresh?(ecosystem, package_name) when is_binary(ecosystem) and is_binary(package_name) do
    case Repo.query("""
      SELECT 1 FROM package_registry
      WHERE ecosystem = $1 AND package_name = $2
        AND cached_at > NOW() - INTERVAL '1 day'
      LIMIT 1
    """, [ecosystem, package_name]) do
      {:ok, %{rows: [[_]]}} -> true
      {:ok, %{rows: []}} -> false
      _ -> false
    end
  end

  @doc """
  Refresh expired cache entries (older than 24h).

  Returns count of refreshed packages.
  """
  def refresh_expired_cache(limit \\ 100) do
    case Repo.query("""
      UPDATE package_registry
      SET refresh_needed = true
      WHERE cached_at < NOW() - INTERVAL '1 day'
      LIMIT $1
      RETURNING package_name
    """, [limit]) do
      {:ok, %{num_rows: count}} ->
        Logger.info("Marked #{count} packages for cache refresh")
        {:ok, count}

      error ->
        error
    end
  end

  @doc """
  Get cache statistics.
  """
  def cache_stats do
    case Repo.query("""
      SELECT
        ecosystem,
        COUNT(*) as total_cached,
        SUM(CASE WHEN cached_at > NOW() - INTERVAL '1 day' THEN 1 ELSE 0 END) as fresh_count,
        SUM(CASE WHEN refresh_needed THEN 1 ELSE 0 END) as refresh_needed_count
      FROM package_registry
      GROUP BY ecosystem
    """) do
      {:ok, %{rows: rows}} ->
        stats =
          Enum.map(rows, fn [eco, total, fresh, refresh_needed] ->
            %{
              ecosystem: eco,
              total_cached: total,
              fresh_count: fresh,
              refresh_needed_count: refresh_needed
            }
          end)

        {:ok, stats}

      error ->
        error
    end
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  defp fetch_and_cache(ecosystem, package_name, url) do
    Logger.debug("Fetching #{ecosystem} package: #{package_name} from #{url}")

    case Repo.query("""
      SELECT net.http_get(
        url := $1,
        timeout_milliseconds := $2
      ) as response
    """, [url, @http_timeout]) do
      {:ok, %{rows: [[response_json]]}} ->
        case Jason.decode(response_json) do
          {:ok, response} ->
            case response["status_code"] do
              200 ->
                # Cache the raw response
                cache_response(ecosystem, package_name, response)

              404 ->
                {:error, :package_not_found}

              status ->
                Logger.warn("HTTP #{status} from #{ecosystem} for #{package_name}")
                {:error, {:http_error, status}}
            end

          {:error, reason} ->
            Logger.error("JSON decode error: #{inspect(reason)}")
            {:error, {:decode_error, reason}}
        end

      error ->
        Logger.error("pg_net HTTP error: #{inspect(error)}")
        error
    end
  end

  defp cache_response(ecosystem, package_name, response) do
    metadata = response["body"]

    case Repo.query("""
      INSERT INTO package_registry
        (ecosystem, package_name, metadata, cached_at, refresh_needed)
      VALUES ($1, $2, $3, NOW(), false)
      ON CONFLICT (ecosystem, package_name)
      DO UPDATE SET
        metadata = EXCLUDED.metadata,
        cached_at = NOW(),
        refresh_needed = false
      RETURNING metadata
    """, [ecosystem, package_name, metadata]) do
      {:ok, %{rows: [[cached_json]]}} ->
        {:ok, Jason.decode!(cached_json)}

      error ->
        error
    end
  end

  defp parse_npm_response(name, data) do
    {:ok, %{
      name: name,
      ecosystem: "npm",
      version: data["dist-tags"]["latest"],
      description: data["description"],
      homepage: data["homepage"],
      repository: get_in(data, ["repository", "url"]),
      downloads: data["downloads_per_month"],
      updated_at: data["time"]["modified"]
    }}
  end

  defp parse_cargo_response(name, data) do
    {:ok, %{
      name: name,
      ecosystem: "cargo",
      version: get_in(data, ["crate", "max_version"]),
      description: get_in(data, ["crate", "description"]),
      repository: get_in(data, ["crate", "repository"]),
      downloads: get_in(data, ["crate", "downloads"]),
      updated_at: get_in(data, ["crate", "updated_at"])
    }}
  end

  defp parse_hex_response(name, data) do
    {:ok, %{
      name: name,
      ecosystem: "hex",
      version: data["latest_version"],
      description: data["meta"]["description"],
      repository: data["meta"]["links"]["Repository"],
      downloads: data["downloads"]["all"],
      updated_at: data["updated_at"]
    }}
  end

  defp parse_pypi_response(name, data) do
    {:ok, %{
      name: name,
      ecosystem: "pypi",
      version: get_in(data, ["info", "version"]),
      description: get_in(data, ["info", "summary"]),
      repository: get_in(data, ["info", "home_page"]),
      downloads: get_in(data, ["info", "downloads"]),
      updated_at: get_in(data, ["info", "last_updated"])
    }}
  end

  defp encode_url(name) do
    URI.encode(name, &URI.char_unreserved?/1)
  end
end
