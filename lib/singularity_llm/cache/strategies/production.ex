defmodule SingularityLLM.Cache.Strategies.Production do
  @moduledoc """
  Production caching strategy using ETS-based storage.

  This is the default caching strategy for SingularityLLM, providing high-performance
  in-memory caching suitable for production environments. It delegates to the
  `SingularityLLM.Infrastructure.Cache` GenServer for actual storage operations.

  ## When This Strategy is Used

  - **Production environments** (default)
  - **Development environments** for runtime performance
  - **Unit tests** that don't require API response caching
  - Any environment where `cache_strategy` is not explicitly configured

  ## Features

  - Sub-millisecond cache lookups via ETS
  - Configurable TTL with automatic expiration
  - Thread-safe concurrent access
  - Memory-efficient storage
  - Telemetry integration for monitoring

  ## Configuration

  This strategy is the default, but you can explicitly configure it:

      # config/prod.exs
      config :singularity_llm,
        cache_strategy: SingularityLLM.Cache.Strategies.Production

      # Cache-specific settings
      config :singularity_llm, :cache,
        enabled: true,
        default_ttl: :timer.minutes(15),
        cleanup_interval: :timer.minutes(5)

  ## How It Works

  1. Checks if caching should be used based on request options
  2. On cache hit: Returns the cached response immediately
  3. On cache miss: Executes the function and stores the result
  4. Respects TTL and automatic expiration policies

  ## Example Flow

      # User makes a request
      SingularityLLM.chat(:openai, messages, cache: true)
      
      # Strategy receives the cache request
      Production.with_cache(cache_key, [cache: true], fn ->
        # This function only executes on cache miss
        make_api_request()
      end)

  ## Telemetry

  Emits standard cache telemetry events:
  - `[:singularity_llm, :cache, :hit]`
  - `[:singularity_llm, :cache, :miss]`
  - `[:singularity_llm, :cache, :put]`

  ## See Also

  - `SingularityLLM.Infrastructure.Cache` - The underlying cache implementation
  - `SingularityLLM.Cache.Strategy` - The behavior this module implements
  - [Caching Architecture Guide](docs/caching_architecture.md)
  """

  @behaviour SingularityLLM.Cache.Strategy

  alias SingularityLLM.Infrastructure.Cache

  @impl SingularityLLM.Cache.Strategy
  def with_cache(cache_key, opts, fun) do
    if Cache.should_cache?(opts) do
      handle_cache_lookup(cache_key, fun, opts)
    else
      fun.()
    end
  end

  defp handle_cache_lookup(cache_key, fun, opts) do
    case Cache.get(cache_key) do
      {:ok, cached_response} ->
        # Return cached response wrapped in ok tuple
        {:ok, cached_response}

      :miss ->
        # Execute function and cache result
        case fun.() do
          {:ok, response} = result ->
            Cache.put(cache_key, response, opts)
            result

          error ->
            error
        end
    end
  end
end
