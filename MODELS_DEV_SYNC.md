# Models.dev Integration Guide

## What is Models.dev?

[models.dev](https://models.dev) is an **open-source, community-maintained database** of 300+ LLM models across 40+ providers.

- **MIT Licensed**: Free to use and integrate
- **Real-time Updates**: Community keeps pricing and capabilities current
- **Comprehensive**: Covers major providers, open-source models, and regional variants
- **Public API**: https://models.dev/api.json (no auth required)

## ExLLM Integration

ExLLM includes direct integration with models.dev to keep your model catalogs synchronized with the authoritative source.

### Data Flow

```
models.dev/api.json
    ↓ (fetch)
ModelsDevSyncer
    ├─ Parse models
    ├─ Group by provider
    └─ Merge with existing configs
    ↓
Preserve your custom data:
    ├─ task_complexity_score (learned scores from CentralCloud)
    ├─ notes (manual annotations)
    └─ default_model (if set)
    ↓
Update YAML configs with:
    ├─ pricing (current)
    ├─ capabilities (accurate)
    ├─ context_window (real)
    └─ availability status
    ↓
config/models/*.yml (updated)
```

## Usage

### Sync All Models

```bash
cd packages/ex_llm
mix ex_llm.models_dev.sync
```

This:
1. Fetches latest models from models.dev API
2. Merges with existing YAML configs
3. Preserves your complexity scores and notes
4. Updates pricing and capabilities
5. Writes updated configs

### In Elixir Code

```elixir
alias ExLLM.ModelDiscovery.ModelsDevSyncer

# Fetch all models
{:ok, models} = ModelsDevSyncer.fetch_all()
# => %{
#   "anthropic" => [model_map, ...],
#   "openai" => [model_map, ...],
#   ...
# }

# Sync to YAML configs
:ok = ModelsDevSyncer.sync_to_configs()

# Get specific model
{:ok, model} = ModelsDevSyncer.get_model("anthropic", "claude-3-5-sonnet-20241022")
```

## What Gets Updated

### Before Sync
```yaml
provider: anthropic
models:
  claude-3-5-sonnet-20241022:
    name: Claude 3.5 Sonnet
    context_window: 200000
    task_complexity_score:
      simple: 1.5
      medium: 3.0
      complex: 4.2
```

### After Sync
```yaml
provider: anthropic
models:
  claude-3-5-sonnet-20241022:
    name: Claude 3.5 Sonnet
    description: From models.dev
    context_window: 200000
    max_output_tokens: 4096
    pricing:
      input: 3.0
      output: 15.0
    capabilities:
      - streaming
      - function_calling
      - vision
      - json_mode
      - system_messages
    available: true
    deprecated: false
    source: models.dev
    task_complexity_score:  # YOUR CUSTOM SCORE PRESERVED!
      simple: 1.5
      medium: 3.0
      complex: 4.2
```

## Caching

Models.dev data is cached locally for **60 minutes** to:
- Reduce API calls
- Improve performance
- Avoid rate limiting

**Cache location**: `~/.cache/models_dev.json`

Cache is automatically refreshed when older than 60 minutes, or manually:

```bash
# Clear cache and force fresh fetch
rm ~/.cache/models_dev.json
mix ex_llm.models_dev.sync
```

## Provider Coverage

Models.dev includes models from:

### Major Cloud Providers
- **Anthropic**: Claude 2, 3, 3.5 (Haiku, Sonnet, Opus)
- **OpenAI**: GPT-4o, GPT-4 Turbo, GPT-3.5, o1
- **Google**: Gemini 1.5, 2.0, 2.5 (Pro, Flash)
- **Meta**: Llama 2, 3, 3.1 (8B, 70B, 405B)
- **Mistral**: Large, Medium, Small, Nemo
- **xAI**: Grok, Grok-2

### Open-Source
- **Llama**: All versions via Hugging Face
- **Qwen**: By Alibaba
- **DeepSeek**: DeepSeek-V3, Coder
- **Phi**: By Microsoft
- **Mixtral**: By Mistral

### Specialized
- **Codex**: via OpenAI Codex CLI
- **Groq**: Ultra-fast inference
- **Fireworks**: Serverless inference
- **Together AI**: Fine-tuning platform

### Regional
- **Alibaba**: Qwen models
- **Baidu**: Ernie models
- **Moonshot**: by Kimi
- **Zhipu**: ChatGLM

## Integration with CentralCloud Learning

Your learned complexity scores are **preserved** during sync:

```
CentralCloud learns optimal scores from real usage
    ↓
Scores stored in task_complexity_score
    ↓
Mix task syncs models.dev data
    ↓
Preserves task_complexity_score (not overwritten)
    ↓
Result: Fresh model data + your learned scores
```

## Sync Workflow

### Option 1: Manual Sync (Development)

```bash
# When you want to update models
mix ex_llm.models_dev.sync
git add config/models/*.yml
git commit -m "chore: sync models from models.dev"
```

### Option 2: Scheduled Sync (Production)

Add to CentralCloud GenServer:

```elixir
def handle_info(:daily_sync, state) do
  # Update models daily from models.dev
  ModelsDevSyncer.sync_to_configs()

  # Schedule next day
  schedule_next_sync()

  {:noreply, state}
end
```

### Option 3: On-Demand via API

```elixir
# In Singularity/CentralCloud API handler
{:ok, models} = ModelsDevSyncer.fetch_all()
# Show user latest available models
```

## Error Handling

The syncer is resilient:

```elixir
# If API unreachable, uses cached data if available
{:ok, models} = ModelsDevSyncer.fetch_all()
# Returns cached data (up to 60 min old) if API down

# If specific provider sync fails, continues with others
:ok = ModelsDevSyncer.sync_to_configs()
# Syncs successful providers, logs errors for failed ones

# If cache is stale and API unreachable
{:error, :fetch_failed, reason} = ModelsDevSyncer.fetch_all()
# Falls back gracefully, existing configs remain valid
```

## Performance Notes

- **First sync**: 1-2 seconds (API call)
- **Cached syncs**: <100ms (local file read)
- **Network**: Uses 10-50KB bandwidth
- **Frequency**: Safe to run hourly or daily
- **Storage**: Cache is ~500KB, YAML configs ~5-10MB total

## Comparison: Models.dev vs ProviderFetcher

| Feature | models.dev | ProviderFetcher |
|---------|-----------|-----------------|
| **Coverage** | 300+ models, 40+ providers | Only providers with API keys configured |
| **Requires Auth** | No (public API) | Yes (provider-specific keys) |
| **Real-time** | Community-maintained | Provider's current state |
| **Use Case** | Discover all available models | Fetch from configured providers |
| **Caching** | 60 minutes | Per-provider |

### Use Both!

1. **models.dev** - Discover and add new models to configs
2. **ProviderFetcher** - Validate your configured providers are working
3. **CentralCloud Learning** - Optimize scores from real usage

## Troubleshooting

### "Failed to fetch from models.dev"

**Cause**: Network unreachable or API down

**Solution**:
```bash
# Check if models.dev is accessible
curl https://models.dev/api.json | head -c 100

# If timeout, wait or use cached data
# Cache is ~60 minutes old
```

### "Not all providers updated"

**Cause**: Some providers in API, some not in your config

**Solution**: This is fine! Sync updates whatever providers exist in models.dev. You can manually add new providers.

### "My complexity scores disappeared"

**Cause**: You used old version of sync

**Solution**: Update to latest version - current version always preserves `task_complexity_score`

```bash
git pull origin main
mix ex_llm.models_dev.sync
```

## See Also

- **ModelRouter**: Auto-select models by complexity
- **ProviderFetcher**: Discover from configured provider APIs
- **CentralCloud Learning**: Learn optimal scores from usage
- **models.dev**: https://models.dev
