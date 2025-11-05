# SingularityLLM Caching Architecture

## Overview

SingularityLLM implements a sophisticated dual-cache architecture designed to optimize both production performance and development/testing workflows. The system uses a strategy pattern to cleanly separate these concerns while maintaining a unified interface.

## Architecture Components

### 1. Production Cache (ETS-based)

The production cache is designed for runtime performance optimization:

- **Storage**: In-memory ETS tables for sub-millisecond access
- **Scope**: Runtime LLM response caching
- **TTL**: Configurable time-to-live (default: 15 minutes)
- **Purpose**: Reduce API costs and latency in production
- **Level**: Operates at the pipeline level
- **Key Generation**: Based on provider, messages, and request parameters

**Configuration:**
```elixir
config :singularity_llm, :cache,
  enabled: true,
  storage: {SingularityLLM.Infrastructure.Cache.Storage.ETS, []},
  default_ttl: :timer.minutes(15),
  cleanup_interval: :timer.minutes(5)
```

### 2. Test Cache (File-based)

The test cache is designed for integration test optimization:

- **Storage**: JSON files on disk with timestamp-based naming
- **Scope**: Integration test response caching
- **TTL**: Context-aware (infinity for :live_api tests)
- **Purpose**: Enable 25x faster test runs
- **Level**: Operates at the HTTP client level
- **Key Generation**: Based on test context, provider, and request signature

**Configuration:**
```elixir
# Enable test caching
export EX_LLM_TEST_CACHE_ENABLED=true

# In config/test.exs
config :singularity_llm,
  cache_strategy: SingularityLLM.Cache.Strategies.Test
```

## Cache Strategy Pattern

The dual-cache architecture is implemented using a strategy pattern that eliminates architectural layering violations:

```
┌─────────────────────────────────────────┐
│         SingularityLLM.Infrastructure.Cache      │
│         (Production Code Layer)         │
└────────────────────┬───────────────────┘
                     │ uses
                     ▼
┌─────────────────────────────────────────┐
│       SingularityLLM.Cache.Strategy (behavior)   │
└────────────────────┬───────────────────┘
                     │ implements
        ┌────────────┴────────────┐
        ▼                         ▼
┌──────────────────┐    ┌──────────────────┐
│ Production       │    │ Test             │
│ Strategy         │    │ Strategy         │
└──────────────────┘    └──────────────────┘
```

### Strategy Implementations

1. **SingularityLLM.Cache.Strategies.Production**
   - Default strategy for all environments
   - Uses ETS-based caching via Infrastructure.Cache
   - Respects cache options (TTL, enabled flags)

2. **SingularityLLM.Cache.Strategies.Test**
   - Activated in test environment
   - Checks if test caching should be active
   - Defers to HTTP-level caching for :live_api tests
   - Falls back to production strategy for unit tests

## When Each Cache is Used

### Production Cache Active

- Normal application runtime
- Unit tests without :live_api tag
- When `cache: true` option is provided
- Streaming requests are never cached

### Test Cache Active

- Integration tests with `:live_api` tag
- When `EX_LLM_TEST_CACHE_ENABLED=true`
- During test development to capture responses
- For cross-test response sharing

## Cache Flow Diagram

```
User Request
     │
     ▼
SingularityLLM.chat/stream
     │
     ▼
Pipeline Processing
     │
     ▼
Cache Plug ──────► Cache Strategy Decision
                          │
                          ├─► Production Strategy?
                          │   └─► Check ETS Cache
                          │
                          └─► Test Strategy?
                              ├─► Test cache active?
                              │   └─► Pass through to HTTP
                              │
                              └─► Use Production Strategy
```

## Telemetry Events

Both cache systems emit telemetry events for monitoring:

### Production Cache Events
- `[:singularity_llm, :cache, :hit]` - Cache hit with key
- `[:singularity_llm, :cache, :miss]` - Cache miss with key
- `[:singularity_llm, :cache, :put]` - Item stored with size
- `[:singularity_llm, :cache, :evict]` - Item evicted

### Test Cache Events
- `[:singularity_llm, :test_cache, :hit]` - Test cache hit
- `[:singularity_llm, :test_cache, :miss]` - Test cache miss
- `[:singularity_llm, :test_cache, :save]` - Response saved
- `[:singularity_llm, :test_cache, :error]` - Cache error

## Metadata Preservation

Both cache systems preserve metadata through the response chain:

1. **Production Cache**: Stores complete LLMResponse structs
2. **Test Cache**: Adds `:from_cache` metadata to responses

## Configuration Examples

### Development Setup
```elixir
# config/dev.exs
config :singularity_llm,
  cache_enabled: true,
  cache_ttl: :timer.hours(1)
```

### Test Setup
```elixir
# config/test.exs
config :singularity_llm,
  cache_strategy: SingularityLLM.Cache.Strategies.Test

# For specific test runs
export EX_LLM_TEST_CACHE_ENABLED=true
mix test --only live_api
```

### Production Setup
```elixir
# config/prod.exs
config :singularity_llm,
  cache_enabled: true,
  cache_ttl: :timer.minutes(30),
  cache_cleanup_interval: :timer.minutes(10)
```

## Best Practices

1. **Don't mix cache systems**: Let the strategy pattern handle separation
2. **Use appropriate TTLs**: Shorter for dynamic content, longer for stable
3. **Monitor cache metrics**: Use telemetry to track hit rates
4. **Clean test caches**: Use `mix singularity_llm.cache clean` periodically
5. **Version cache keys**: Include version in keys when formats change

## Troubleshooting

### Cache Not Working

1. Check strategy configuration:
   ```elixir
   Application.get_env(:singularity_llm, :cache_strategy)
   ```

2. Verify cache is enabled:
   ```elixir
   Application.get_env(:singularity_llm, :cache_enabled)
   ```

3. Check test cache environment:
   ```bash
   echo $EX_LLM_TEST_CACHE_ENABLED
   ```

### Clearing Caches

```bash
# Clear test cache
mix singularity_llm.cache clear

# Clear production cache (in IEx)
SingularityLLM.Infrastructure.Cache.clear()
```

## Future Enhancements

- Distributed caching support (Redis/Memcached)
- Cache warming strategies
- Advanced eviction policies
- Cross-environment cache sharing
- GraphQL response caching