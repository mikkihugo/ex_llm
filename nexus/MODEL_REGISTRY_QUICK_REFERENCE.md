# ExLLM Model Registry - Quick Reference

## Key Modules

### Model Discovery & Querying
- **ExLLM.Core.Models** - High-level query API (list all, find by capability, compare, etc.)
- **ExLLM.Infrastructure.Config.ModelConfig** - Low-level config access (pricing, context window, etc.)
- **ExLLM.Infrastructure.Config.ModelLoader** - Dynamic API-based discovery with caching
- **ExLLM.Infrastructure.OllamaModelRegistry** - Ollama-specific GenServer with fallback chain

### Provider Information
- **ExLLM.Infrastructure.Config.ProviderCapabilities** - Provider-level features/limitations
- **ExLLM.Types** - Shared type definitions (Model struct, etc.)

### Storage
- **config/models/*.yml** - 59 YAML files with model definitions
- **:model_config_cache** - ETS cache table (compile-time)
- **:ex_llm_model_cache** - ETS cache table (1-hour TTL)

## Common Operations

### Find Models by Capability
```elixir
{:ok, models} = ExLLM.Core.Models.find_by_capabilities([:vision, :streaming])
```

### Find Models by Context Window
```elixir
{:ok, models} = ExLLM.Core.Models.find_by_min_context(100_000)
```

### Get Model Pricing
```elixir
pricing = ExLLM.Infrastructure.Config.ModelConfig.get_pricing(:openai, "gpt-4o")
# => %{input: 2.50, output: 10.00}
```

### Get Default Model for Provider
```elixir
{:ok, model} = ExLLM.Core.Models.get_default(:anthropic)
# => "claude-3-5-sonnet-20241022"
```

### Check Provider Features
```elixir
true = ExLLM.Infrastructure.Config.ProviderCapabilities.supports?(:openai, :embeddings)
```

### Compare Models
```elixir
{:ok, comparison} = ExLLM.Core.Models.compare(["claude-3-5-sonnet-20241022", "gpt-4o"])
# => %{models: [...], capabilities: %{...}, pricing: %{...}}
```

### Get Ollama Model Details
```elixir
{:ok, details} = ExLLM.Infrastructure.OllamaModelRegistry.get_model_details("llama2")
# => %{context_window: 4096, capabilities: ["streaming"]}
```

## YAML Configuration Format

### Minimal Example
```yaml
provider: custom_provider
models:
  my-model:
    context_window: 4096
```

### Complete Example
```yaml
provider: anthropic
default_model: claude-3-5-sonnet-20241022

models:
  claude-3-5-sonnet-20241022:
    name: "Claude 3.5 Sonnet"
    description: "Latest Claude model"
    context_window: 200000
    max_output_tokens: 8192
    pricing:
      input: 3.0      # Per 1M tokens
      output: 15.0
    capabilities:
      - streaming
      - function_calling
      - vision
      - prompt_caching
    deprecation_date: "2025-10-01"
    metadata:
      custom_field: value
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      ExLLM.Core.Models                          │
│  (High-level API: list_all, find_by_capability, compare, etc)   │
└─────────────────┬───────────────────────────────────────────────┘
                  │
    ┌─────────────┼──────────────────────┐
    │             │                      │
    ▼             ▼                      ▼
┌──────────┐  ┌──────────────┐    ┌────────────────┐
│ModelConfig   ModelLoader      │OllamaModelReg  
│(Static YAML) (API Discovery) │(Stateful GenServer)
│ETS Cache     ETS Cache        │In-process Cache
└──────────┘  └──────────────┘    └────────────────┘
    │             │                      │
    │             └──────────┬───────────┘
    │                        │
    └────────────────┬───────┘
                     │
    ┌────────────────▼────────────────┐
    │  config/models/*.yml (YAML)     │
    │  + Provider APIs (optional)     │
    └─────────────────────────────────┘
```

## Caching Strategy

| Layer | Source | Cache | TTL | Access |
|-------|--------|-------|-----|--------|
| 1 | YAML files | `:model_config_cache` ETS | Forever | ModelConfig |
| 2 | Provider APIs | `:ex_llm_model_cache` ETS | 1 hour | ModelLoader |
| 3 | Ollama API | GenServer state | 1 hour | OllamaModelRegistry |

## Known Limitations

1. **Manual Updates**: New models require YAML edits
2. **No Versioning**: Model changes aren't tracked historically
3. **Unstructured Capabilities**: Simple list, no metadata per capability
4. **Pricing Lag**: Updates are manual, no automatic sync
5. **Hardcoded Defaults**: Local providers use hardcoded 4096 context window
6. **No Multi-Instance Sync**: Each instance loads independently

## Future Improvements

### Short-term
- [ ] Add `updated_at` timestamp to all YAML files
- [ ] YAML schema validation
- [ ] Auto-update CLI for fetching from provider APIs
- [ ] Capability documentation in code

### Medium-term
- [ ] PostgreSQL model store for multi-instance deployments
- [ ] Automatic pricing sync from provider APIs
- [ ] Capability change tracking
- [ ] NATS-based registry synchronization

### Long-term
- [ ] Model discovery marketplace
- [ ] User-contributed custom models
- [ ] Usage analytics
- [ ] Automatic model selection

## Files to Check

- **Model definitions**: `/packages/ex_llm/config/models/*.yml`
- **Core logic**: `/packages/ex_llm/lib/ex_llm/infrastructure/config/`
- **High-level API**: `/packages/ex_llm/lib/ex_llm/core/models.ex`
- **Types**: `/packages/ex_llm/lib/types.ex`

## Troubleshooting

**Q: Model not found in config**
A: Check if YAML file exists and model_id matches exactly (case-sensitive)

**Q: Getting hardcoded defaults for Ollama**
A: Check if model exists in ollama.yml, otherwise defaults are used

**Q: Pricing looks wrong**
A: Pricing is per 1M tokens, check provider's official docs

**Q: Cache not updating**
A: Use `ModelConfig.reload_config()` (YAML only) or clear cache in GenServer

**Q: Multi-instance out of sync**
A: This is expected - each instance loads independently. Use database for shared registry.
