# Internal Modules Guide

This document lists all internal modules in SingularityLLM that should NOT be used directly. These are implementation details subject to change without notice.

## ⚠️ WARNING

All modules listed here are internal to SingularityLLM. Always use the public API through the main `SingularityLLM` module instead.

## Core Internal Modules

### Infrastructure Layer
- `SingularityLLM.Infrastructure.Cache.*` - Internal caching implementation
- `SingularityLLM.Infrastructure.CircuitBreaker.*` - Fault tolerance internals
- `SingularityLLM.Infrastructure.Config.*` - Configuration management
- `SingularityLLM.Infrastructure.Logger` - Internal logging
- `SingularityLLM.Infrastructure.Retry` - Retry logic implementation
- `SingularityLLM.Infrastructure.Streaming.*` - Streaming implementation details
- `SingularityLLM.Infrastructure.Error` - Error structure definitions

### Provider Shared Utilities
- `SingularityLLM.Providers.Shared.ConfigHelper` - Provider config utilities
- `SingularityLLM.Providers.Shared.ErrorHandler` - Error handling
- `SingularityLLM.Providers.Shared.HTTPClient` - HTTP implementation
- `SingularityLLM.Providers.Shared.MessageFormatter` - Message formatting
- `SingularityLLM.Providers.Shared.ModelFetcher` - Model fetching logic
- `SingularityLLM.Providers.Shared.ModelUtils` - Model utilities
- `SingularityLLM.Providers.Shared.ResponseBuilder` - Response construction
- `SingularityLLM.Providers.Shared.StreamingBehavior` - Streaming behavior
- `SingularityLLM.Providers.Shared.StreamingCoordinator` - Stream coordination
- `SingularityLLM.Providers.Shared.Validation` - Input validation
- `SingularityLLM.Providers.Shared.VisionFormatter` - Vision formatting

### Provider Internals
- `SingularityLLM.Providers.Gemini.*` - Gemini-specific internals
- `SingularityLLM.Providers.Bumblebee.*` - Bumblebee internals
- `SingularityLLM.Providers.OpenAICompatible` - Base module for providers

### Testing Infrastructure
- `SingularityLLM.Testing.Cache.*` - Test caching system
- `SingularityLLM.Testing.ResponseCache` - Response caching for tests
- All modules in `test/support/*` - Test helpers

## Why These Are Internal

1. **Implementation Details**: These modules contain implementation-specific logic that may change between versions
2. **No Stability Guarantees**: Internal APIs can change without deprecation notices
3. **Complex Dependencies**: Many internal modules have complex interdependencies
4. **Provider-Specific**: Provider internals are tailored to specific API requirements

## Migration Guide

If you're currently using any internal modules, here's how to migrate:

### Cache Access
```elixir
# ❌ Don't use internal cache modules
SingularityLLM.Infrastructure.Cache.get(key)

# ✅ Use the public API
# Caching is handled automatically by SingularityLLM
{:ok, response} = SingularityLLM.chat(:openai, "Hello")
```

### Error Handling
```elixir
# ❌ Don't create internal error types
SingularityLLM.Infrastructure.Error.api_error(500, "Error")

# ✅ Use pattern matching on public API returns
case SingularityLLM.chat(:openai, "Hello") do
  {:error, {:api_error, status, message}} -> 
    # Handle error
end
```

### Configuration
```elixir
# ❌ Don't access internal config modules
SingularityLLM.Infrastructure.Config.ModelConfig.get_model(:openai, "gpt-4")

# ✅ Use public configuration API
{:ok, info} = SingularityLLM.get_model_info(:openai, "gpt-4")
```

### HTTP Requests
```elixir
# ❌ Don't use internal HTTP client
SingularityLLM.Providers.Shared.HTTPClient.post_json(url, body, headers)

# ✅ Use the public API which handles HTTP internally
{:ok, response} = SingularityLLM.chat(:openai, "Hello")
```

### Provider Implementation
```elixir
# ❌ Don't use provider internals directly
SingularityLLM.Providers.Anthropic.chat(messages, options)

# ✅ Use the unified public API
{:ok, response} = SingularityLLM.chat(:anthropic, messages, options)
```

## For Library Contributors

If you're contributing to SingularityLLM:

1. Keep internal modules marked with `@moduledoc false`
2. Don't expose internal functions in the public API
3. Add new public functionality to the main `SingularityLLM` module
4. Document any new internal modules in this guide
5. Ensure internal modules are properly namespaced

## Questions?

If you need functionality that's only available in internal modules, please:
1. Check if the public API already provides it
2. Open an issue requesting the feature
3. Consider contributing a PR that exposes it properly through the public API