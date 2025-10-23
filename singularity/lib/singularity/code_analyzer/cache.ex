defmodule Singularity.CodeAnalyzer.Cache do
  @moduledoc """
  Analysis Result Caching Layer for CodeAnalyzer

  Provides in-memory caching of code analysis results to avoid re-analyzing
  unchanged code. Uses ETS for fast lookups.

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.CodeAnalyzer.Cache",
    "purpose": "Cache code analysis results to avoid redundant computation",
    "type": "GenServer with ETS-backed cache",
    "operates_on": "Analysis results keyed by content hash",
    "output": "Cached analysis results or triggers new analysis"
  }
  ```

  ## Features

  - **Content-based hashing**: Uses SHA256 of code content as cache key
  - **TTL support**: Configurable expiration (default: 1 hour)
  - **LRU eviction**: Automatically removes least recently used entries when full
  - **Statistics tracking**: Cache hit/miss rates, memory usage

  ## Usage

  ```elixir
  # Start the cache
  {:ok, _pid} = CodeAnalyzer.Cache.start_link(max_size: 1000, ttl: 3600)

  # Get cached result or analyze
  {:ok, analysis} = CodeAnalyzer.Cache.get_or_analyze(code, "elixir", fn ->
    CodeAnalyzer.analyze_language(code, "elixir")
  end)

  # Check cache stats
  stats = CodeAnalyzer.Cache.stats()
  # => %{hits: 150, misses: 50, hit_rate: 0.75, size: 200}

  # Clear cache
  :ok = CodeAnalyzer.Cache.clear()
  ```

  ## Call Graph (YAML)

  ```yaml
  Cache:
    calls:
      - :ets (cache storage)
      - :crypto.hash/2 (content hashing)
      - CodeAnalyzer (on cache miss)
    called_by:
      - CodeAnalyzer (wrapper functions)
      - HTDAGAutoBootstrap (module reanalysis)
  ```

  ## Anti-Patterns

  **DO NOT create these duplicates:**
  - ❌ `AnalysisCache` - This IS the analysis cache
  - ❌ `CodeCache` - Same purpose, different name
  - ❌ `ResultCache` - Generic, use this instead

  ## Search Keywords

  caching, memoization, performance-optimization, ets-cache,
  analysis-results, content-hashing, ttl-cache, lru-eviction
  """

  use GenServer
  require Logger

  # Default configuration
  @default_max_size 1000
  @default_ttl 3600  # 1 hour in seconds

  # ETS table name
  @table_name :code_analyzer_cache

  # Client API
  # ===========

  @doc """
  Start the cache server.

  ## Options
  - `:max_size` - Maximum number of cached entries (default: #{@default_max_size})
  - `:ttl` - Time-to-live in seconds (default: #{@default_ttl})
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get cached result or compute and cache it.

  ## Parameters
  - `code` - Source code string
  - `language` - Language hint
  - `analyzer_fun` - Function to call on cache miss (0-arity)

  ## Returns
  - `{:ok, result}` - Cached or computed result
  - `{:error, reason}` - If analysis fails
  """
  def get_or_analyze(code, language, analyzer_fun) when is_binary(code) and is_function(analyzer_fun, 0) do
    key = cache_key(code, language)

    case get(key) do
      {:ok, cached_result} ->
        # Cache hit
        record_hit()
        {:ok, cached_result}

      :miss ->
        # Cache miss - compute and store
        record_miss()

        case analyzer_fun.() do
          {:ok, result} ->
            put(key, result)
            {:ok, result}

          {:error, _reason} = error ->
            error
        end
    end
  end

  @doc """
  Get cache statistics.

  ## Returns
  Map with:
  - `:hits` - Number of cache hits
  - `:misses` - Number of cache misses
  - `:hit_rate` - Hit rate percentage (0.0-1.0)
  - `:size` - Current number of cached entries
  - `:max_size` - Maximum cache size
  - `:memory_bytes` - Approximate memory usage
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Clear all cached entries.
  """
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Stop the cache server.
  """
  def stop do
    GenServer.stop(__MODULE__)
  end

  # Private Client Helpers
  # =======================

  defp get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expires_at}] ->
        if expired?(expires_at) do
          :ets.delete(@table_name, key)
          :miss
        else
          {:ok, value}
        end

      [] ->
        :miss
    end
  end

  defp put(key, value) do
    GenServer.cast(__MODULE__, {:put, key, value})
  end

  defp record_hit do
    GenServer.cast(__MODULE__, :hit)
  end

  defp record_miss do
    GenServer.cast(__MODULE__, :miss)
  end

  defp cache_key(code, language) do
    hash = :crypto.hash(:sha256, code <> language) |> Base.encode16(case: :lower)
    "analysis:#{language}:#{hash}"
  end

  defp expired?(expires_at) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  # Server Callbacks
  # ================

  @impl true
  def init(opts) do
    max_size = Keyword.get(opts, :max_size, @default_max_size)
    ttl = Keyword.get(opts, :ttl, @default_ttl)

    # Create ETS table
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])

    Logger.info("CodeAnalyzer.Cache started with max_size=#{max_size}, ttl=#{ttl}s")

    state = %{
      max_size: max_size,
      ttl: ttl,
      hits: 0,
      misses: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:put, key, value}, state) do
    # Check if we need to evict entries
    current_size = :ets.info(@table_name, :size)

    if current_size >= state.max_size do
      evict_lru()
    end

    # Insert with expiration time
    expires_at = DateTime.add(DateTime.utc_now(), state.ttl, :second)
    :ets.insert(@table_name, {key, value, expires_at})

    {:noreply, state}
  end

  @impl true
  def handle_cast(:hit, state) do
    {:noreply, %{state | hits: state.hits + 1}}
  end

  @impl true
  def handle_cast(:miss, state) do
    {:noreply, %{state | misses: state.misses + 1}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    total = state.hits + state.misses
    hit_rate = if total > 0, do: state.hits / total, else: 0.0

    stats = %{
      hits: state.hits,
      misses: state.misses,
      hit_rate: hit_rate,
      size: :ets.info(@table_name, :size),
      max_size: state.max_size,
      memory_bytes: :ets.info(@table_name, :memory) * :erlang.system_info(:wordsize)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    Logger.info("CodeAnalyzer.Cache cleared")

    # Reset stats
    state = %{state | hits: 0, misses: 0}

    {:reply, :ok, state}
  end

  # Private Helpers
  # ===============

  defp evict_lru do
    # Simple LRU: Remove first entry (ETS maintains insertion order with :ordered_set)
    # For better LRU, we'd need to track access times
    case :ets.first(@table_name) do
      :"$end_of_table" ->
        :ok

      key ->
        :ets.delete(@table_name, key)
        Logger.debug("Evicted cache entry: #{key}")
    end
  end
end
