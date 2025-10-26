# ExLLM Model Registry Analysis

## Executive Summary

ExLLM has a **static YAML-based model registry** with ETS caching layers for Ollama-specific models. The system uses a three-tier configuration approach:
1. **Static YAML Files** (config/models/*.yml) - 12,355 lines across 59 files covering 40+ providers
2. **ETS Cache Layer** - In-memory caching with TTL for dynamic lookups
3. **API Fallback** - Optional provider-specific API integration for real-time discovery

The current approach prioritizes **simplicity and offline-first functionality** over dynamic model discovery, but has several pain points around maintainability and versioning.

---

## 1. Does ex_llm have a models registry?

### Yes, but it's primarily YAML-based and static

**Model Registry Composition:**
```
config/models/
├── anthropic.yml         (80+ models)
├── openai.yml            (100+ models)
├── gemini.yml            (30+ models)
├── gemini_capabilities.yml  (discovered/generated)
├── openai_capabilities.yml  (discovered/generated)
├── ollama.yml            (5+ models)
├── bedrock.yml           (150+ models)
└── ... (53 more provider files)
```

**Total Coverage:**
- 59 YAML files
- 12,355 lines of configuration
- 40+ LLM providers
- Hundreds of models

### Registry Architecture

**Three-Tier Model Discovery:**

```elixir
# Tier 1: Static YAML Configuration (Primary)
ExLLM.Infrastructure.Config.ModelConfig
  └─ Reads: config/models/{provider}.yml
  └─ Caches: :ets.new(:model_config_cache, [:set, :public, :named_table])
  └─ TTL: None (compile-time cache)

# Tier 2: Ollama-Specific Dynamic Registry (GenServer)
ExLLM.Infrastructure.OllamaModelRegistry
  └─ Type: GenServer (stateful)
  └─ Cache TTL: 1 hour
  └─ Fallback chain:
     1. In-memory cache
     2. Static YAML (ModelConfig)
     3. Ollama /api/show endpoint

# Tier 3: Provider-Specific API Discovery (Optional)
ExLLM.Infrastructure.Config.ModelLoader
  └─ Type: ETS-based cache with TTL
  └─ Cache TTL: 1 hour (configurable)
  └─ Supports custom API fetchers and transformers
  └─ Used by: Bumblebee, Gemini (optional)
```

### Model Metadata Structure

**Static YAML Format** (config/models/anthropic.yml):
```yaml
provider: anthropic
models:
  claude-3-5-sonnet-20241022:
    context_window: 200000
    max_output_tokens: 8192
    pricing:
      input: 3.0
      output: 15.0
    capabilities:
      - streaming
      - function_calling
      - vision
      - prompt_caching
      - structured_output
    deprecation_date: '2025-10-01'  # Optional
```

**Programmatic Model Struct** (ExLLM.Types.Model):
```elixir
defstruct [
  :id,                    # "claude-3-5-sonnet-20241022"
  :name,                  # "Claude 3.5 Sonnet"
  :description,           # Optional
  :context_window,        # 200000 tokens
  :pricing,               # %{input: 3.0, output: 15.0}
  :capabilities,          # [:streaming, :function_calling, ...]
  :max_output_tokens      # 8192
]
```

**Extended Capabilities Format** (gemini_capabilities.yml):
```yaml
provider: gemini
discovered_at: '2025-06-06T14:31:23.159170'
endpoints:
  - chat
  - embeddings
  - count_tokens
features:
  - tool_use
  - structured_outputs
  - system_messages
  - dynamic_model_listing
  # ... 20+ features
model_capabilities:
  gemini-1.5-pro:
    context_window: 2000000
    max_output_tokens: 8192
    capabilities:
      - long_context
      - system_messages
      - document_understanding
      - vision
```

### Model Registry APIs

**High-Level Query API** (ExLLM.Core.Models):
```elixir
# List all models across all providers
ExLLM.Core.Models.list_all()
  => {:ok, [%{provider: :anthropic, id: "claude-3-5-sonnet-20241022", ...}, ...]}

# List models for specific provider
ExLLM.Core.Models.list_for_provider(:anthropic)
  => {:ok, [%{id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", ...}, ...]}

# Get detailed model information
ExLLM.Core.Models.get_info(:anthropic, "claude-3-5-sonnet-20241022")
  => {:ok, %{id: "...", context_window: 200000, pricing: %{input: 3.0, ...}, ...}}

# Find models by capability
ExLLM.Core.Models.find_by_capabilities([:vision, :streaming])
  => {:ok, [%{provider: :anthropic, id: "...", ...}, %{provider: :openai, ...}, ...]}

# Find models by context window
ExLLM.Core.Models.find_by_min_context(100_000)
  => {:ok, [%{provider: :anthropic, id: "...", context_window: 200000}, ...]}

# Find models by cost
ExLLM.Core.Models.find_by_cost_range(input: {0, 5.0}, output: {0, 20.0})
  => {:ok, [...]}

# Compare models
ExLLM.Core.Models.compare(["claude-3-5-sonnet-20241022", "gpt-4o"])
  => {:ok, %{models: [...], capabilities: %{...}, pricing: %{...}, context_windows: %{...}}}
```

**Low-Level Config API** (ExLLM.Infrastructure.Config.ModelConfig):
```elixir
# Get pricing for a model
ModelConfig.get_pricing(:openai, "gpt-4o")
  => %{input: 2.50, output: 10.00}

# Get context window
ModelConfig.get_context_window(:anthropic, "claude-3-5-sonnet-20241022")
  => 200000

# Get capabilities
ModelConfig.get_capabilities(:openai, "gpt-4o")
  => [:text, :vision, :function_calling, :streaming]

# Get max output tokens
ModelConfig.get_max_output_tokens(:openai, "gpt-4o")
  => 16384

# Get all models for provider
ModelConfig.get_all_models(:anthropic)
  => %{"claude-3-5-sonnet-20241022" => %{context_window: 200000, ...}, ...}

# Get default model
ModelConfig.get_default_model(:openai)
  => {:ok, "gpt-4o-mini"}

# For local providers with sane defaults
ModelConfig.get_model_config_with_defaults(:ollama, "unknown-model")
  => %{context_window: 4096, max_output_tokens: 4096, capabilities: [:chat, :streaming], ...}
```

**Ollama-Specific Registry** (ExLLM.Infrastructure.OllamaModelRegistry):
```elixir
# Get Ollama model details (with 1-hour cache + fallback)
OllamaModelRegistry.get_model_details("llama2")
  => {:ok, %{context_window: 4096, capabilities: ["streaming", "function_calling"]}}

# Clear cache
OllamaModelRegistry.clear_cache()
```

---

## 2. How is provider configuration currently handled?

### Two Configuration Modes

**Mode 1: Compile-Time Static Configuration**
- Models defined in YAML files at development time
- Loaded into ETS cache when application starts
- No API calls during initialization
- Safe for offline use

**Mode 2: Runtime Dynamic Discovery** (Optional)
- Providers (Gemini, Groq, OpenRouter) can fetch models from their APIs
- Falls back to YAML config if API fails
- Caches results in ETS with 1-hour TTL

### Configuration Loading Pipeline

```
Application Startup
  ↓
ModelConfig.ensure_cache_table()  # Create :model_config_cache ETS table
  ↓
For each provider (anthropic, openai, gemini, ollama, ...):
  ├─ Load {provider}.yml from config/models/
  ├─ Parse YAML with YamlElixir
  ├─ Normalize string keys to atoms (safe atomization)
  └─ Cache in ETS with compile-time persistence
```

### Key Configuration Files

**Provider Configuration Structure:**
```yaml
provider: anthropic              # Required
default_model: claude-3-5-sonnet-20241022  # Optional (used by ExLLM.Core.Models.get_default/1)
models:                          # Required
  model-id:
    name: "Display Name"         # Optional
    description: "..."           # Optional
    context_window: 200000       # Tokens
    max_output_tokens: 8192      # Tokens
    pricing:                      # Optional
      input: 3.0                 # Per 1M tokens
      output: 15.0               # Per 1M tokens
    capabilities:                # Optional list of atoms
      - streaming
      - function_calling
      - vision
      - tool_choice
    deprecation_date: "2025-10-01"  # Optional
    metadata:                    # Optional custom metadata
      custom_field: value
```

### Safe Atomization Strategy

**Problem:** YAML keys are strings, Elixir prefers atoms, but arbitrary string→atom conversion is unsafe in production.

**Solution:** Whitelist-based safe atomization:

```elixir
@config_key_mappings %{
  # Top-level
  "provider" => :provider,
  "default_model" => :default_model,
  "models" => :models,
  "metadata" => :metadata,
  
  # Model fields
  "name" => :name,
  "context_window" => :context_window,
  "max_output_tokens" => :max_output_tokens,
  "capabilities" => :capabilities,
  "pricing" => :pricing,
  
  # Pricing fields
  "input" => :input,
  "output" => :output,
  
  # Capability fields
  "vision" => :vision,
  "function_calling" => :function_calling,
  "streaming" => :streaming,
  # ... 20+ more
}

def safe_atomize_key(key) when is_binary(key) do
  Map.get(@config_key_mappings, key, key)  # Returns key as-is if unknown
end
```

### Provider-Level Capabilities

A separate system (ExLLM.Infrastructure.Config.ProviderCapabilities) tracks provider-level features:

```elixir
# Not individual model capabilities, but provider-wide features
%ProviderInfo{
  id: :openai,
  name: "OpenAI",
  endpoints: [:chat, :embeddings, :images, :files, :fine_tuning, ...],
  authentication: [:api_key, :bearer_token],
  features: [
    :streaming,
    :function_calling,
    :cost_tracking,
    :batch_operations,
    :fine_tuning_api,
    :vision,
    # ... 25+ more
  ],
  limitations: %{
    max_file_size: 512 * 1024 * 1024,
    max_context_tokens: 128_000,
    max_output_tokens: 16_384,
    # ...
  }
}
```

### Runtime Model Discovery (Optional)

**For providers supporting API-based model listing:**

```elixir
# ExLLM.Core.Models.list_for_provider/1 tries this flow:
1. Get provider's pipeline implementation
2. Create request with operation: :list_models
3. Run pipeline (may call provider API)
4. If successful: Return API models
5. If failed/unsupported: Fallback to YAML config

# With custom options:
ExLLM.Infrastructure.Config.ModelLoader.load_models(:gemini, [
  force_refresh: true,
  api_fetcher: fn options -> {:ok, models_from_api} end,
  config_transformer: fn model_id, config -> %Types.Model{...} end
])
```

---

## 3. What are the pain points of the current approach?

### Pain Point 1: Manual Model Updates

**Problem:**
- New models released by providers (weekly/monthly) require manual YAML edits
- No automation for discovering new models
- Risk of stale/deprecated models remaining in config

**Examples:**
- Claude models released in Oct 2024: Must manually add to anthropic.yml
- GPT-4.1 released in Apr 2025: Must manually add to openai.yml
- Ollama model discovery: Can happen at runtime but YAML is static

**Impact:**
- Time-intensive maintenance
- Easy to miss model deprecations
- Config drift between what users have available vs. what's in YAML

### Pain Point 2: No Versioning of Model Definitions

**Problem:**
- Model metadata changes (pricing, context windows) aren't tracked over time
- Capability lists can't be rolled back if incorrect
- No audit trail of when configs were last updated

**Current state:**
```yaml
claude-3-5-sonnet-20241022:
  context_window: 200000      # What if this was 192000 before?
  pricing:
    input: 3.0                 # What if this was 2.5 last month?
```

**What's missing:**
- `updated_at` timestamp
- Previous version history
- Changelog/migration notes

### Pain Point 3: Capability Lists Are Unstructured

**Problem:**
- Capabilities stored as simple atom lists: `[:streaming, :function_calling, :vision]`
- No structured metadata about what each capability means
- Different providers use different naming conventions

**Current state:**
```yaml
# Anthropic uses these
capabilities:
  - streaming
  - function_calling
  - vision
  - prompt_caching
  - structured_output
  - web_search
  - pdf_input
  - tool_choice

# While other providers might use
capabilities:
  - chat
  - embeddings
  - image_generation
  - code_execution
```

**Missing structure:**
```elixir
# Would be better:
capabilities: %{
  "streaming" => %{
    supported: true,
    version: "1.0",
    documentation: "https://...",
    breaking_changes: []
  },
  "function_calling" => %{
    supported: true,
    version: "2.0",
    documentation: "https://...",
    breaking_changes: ["parallel_calling" => "v2.0+"]
  }
}
```

### Pain Point 4: Pricing Updates Lag Behind Actual Prices

**Problem:**
- Pricing changes multiple times per year
- Manual updates required for each provider
- No way to sync with actual provider pricing APIs (most providers have pricing APIs)
- No historical pricing tracking

**Current state:**
```yaml
claude-3-5-sonnet-20241022:
  pricing:
    input: 3.0      # Per 1M tokens
    output: 15.0
```

**What's missing:**
- Last updated timestamp
- Effective date
- Currency information
- Special pricing tiers (volume discounts, batch pricing)
- A way to sync with provider APIs

### Pain Point 5: No Runtime Configuration Reloading

**Problem:**
- Model configs must be in YAML at startup
- Can't update models at runtime without restarting
- Multi-instance deployments can't share model registry

**Current state:**
```elixir
# ModelConfig.reload_config/0 exists but:
# 1. Still only loads from YAML files
# 2. Doesn't persist changes
# 3. Requires manual invocation
# 4. Not distributed across multiple instances
```

### Pain Point 6: Local Providers Have Hardcoded Defaults

**Problem:**
- Ollama, LMStudio, Bumblebee use hardcoded fallback values:
  ```elixir
  context_window: 4096              # Always
  max_output_tokens: 4096           # Always
  capabilities: [:chat, :streaming] # Always
  ```
- Doesn't reflect actual model capabilities
- No way for users to register custom models with custom capabilities

**Why it matters:**
- User installs Ollama with Mistral 7B (4K context)
- User needs 32K context → But config says 4K
- User installs local Llama-2 (4K) and Llama-3 (8K) → Both reported as 4K

### Pain Point 7: No Centralized Model Metadata

**Problem:**
- Model metadata scattered across:
  - Static YAML files
  - Provider-level capabilities file
  - Hardcoded in provider adapters
  - API responses (for providers with discovery)
  
**Example:** Getting complete info about Claude 3.5 Sonnet requires checking:
1. `config/models/anthropic.yml` → Basic metadata
2. `ExLLM.Infrastructure.Config.ProviderCapabilities` → Provider features
3. `Anthropic.parse_response/1` → Response format specifics
4. Provider docs → Token counting details

### Pain Point 8: Model Discovery Not Query-Friendly

**Problem:**
- Can't easily query: "Which models support vision AND streaming AND cost < $5/1M?"
- Finding models by capability requires loading all models and filtering in Elixir
- No database indexes (everything is ETS)

**Current workaround:**
```elixir
{:ok, models} = ExLLM.Core.Models.list_all()
filtered = Enum.filter(models, fn model ->
  model.context_window >= 100_000 and
  :vision in model.capabilities and
  model.pricing.input < 5.0
end)
```

**The pain:** This loads all ~500+ models into memory just to filter ~5-10.

### Pain Point 9: No Multi-Instance Model Registry

**Problem:**
- Each instance loads YAML independently
- If using CentralCloud (Singularity multi-instance), models aren't shared
- No way to centralize model definitions across 10 instances

**Current architecture:**
```
Instance 1: ModelConfig (ETS)
Instance 2: ModelConfig (ETS)    ← Duplicated, out of sync
Instance 3: ModelConfig (ETS)

No shared registry or sync mechanism
```

### Pain Point 10: Capability Evolution Not Tracked

**Problem:**
- Can't see which models gained/lost capabilities in which update
- Deprecation dates exist but deprecated models aren't automatically hidden
- Breaking changes in capabilities aren't documented

**Example - Missing:**
```yaml
claude-3-5-sonnet-20241022:
  capabilities:
    - streaming:
        added_in: "2024-10-22"
        stable_since: "2024-10-22"
    - function_calling:
        added_in: "2024-10-22"
        breaking_changes: []
    - web_search:
        added_in: "2025-01-15"
        status: "beta"
        breaking_changes:
          - "Requires API version >= 2025-01-15"
```

---

## 4. Database Considerations

### Current State: ETS + Compile-Time Cache

**What exists:**
1. `:model_config_cache` ETS table
   - Type: `:set` (unique keys)
   - Scope: Public
   - Persistence: None (lost on restart)
   - TTL: Forever (no expiration)
   - Updated: At application startup

2. `:ex_llm_model_cache` ETS table (ModelLoader)
   - Type: `:set`
   - Scope: Public
   - TTL: 1 hour (configurable)
   - Updated: On demand (lazy loading)

3. OllamaModelRegistry GenServer
   - Type: Stateful process
   - In-process state: `map(model_name => {timestamp, details})`
   - TTL: 1 hour
   - Purpose: Ollama-specific dynamic discovery

### Why Database Might Help

**Current limitations of ETS:**

1. **No Persistence**
   ```elixir
   # If app crashes, all cached data is lost
   # Must reload from YAML on restart
   ```

2. **No Querying**
   ```elixir
   # Can't do: "Find models where context_window > 100000"
   # Must load all models and filter in code
   ```

3. **No Multi-Instance Sharing**
   ```elixir
   # In Singularity (multi-instance):
   # - Instance A: Load models from YAML
   # - Instance B: Load models from YAML (duplicated)
   # - No coordination or syncing
   ```

4. **No Versioning/History**
   ```elixir
   # Can't track: "When did Claude's pricing change?"
   # Can't see: "What was the context window before?"
   ```

5. **No Audit Trail**
   ```elixir
   # No record of who/when/why model configs changed
   # No way to validate data consistency
   ```

### Recommended Database Schema (PostgreSQL)

If database integration were added:

```sql
-- Models table
CREATE TABLE llm_models (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider VARCHAR(50) NOT NULL,
  model_id VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  description TEXT,
  
  context_window INTEGER,
  max_output_tokens INTEGER,
  
  -- Structured metadata
  metadata JSONB DEFAULT '{}',
  
  -- Capabilities as JSONB for efficient querying
  capabilities JSONB DEFAULT '{}',
  
  -- Pricing
  pricing_input DECIMAL(10, 6),    -- Per 1M tokens
  pricing_output DECIMAL(10, 6),
  
  -- Lifecycle
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deprecated_at TIMESTAMP,
  
  -- Data source tracking
  source VARCHAR(50),  -- 'yaml', 'api', 'manual'
  source_metadata JSONB DEFAULT '{}',
  
  UNIQUE(provider, model_id)
);

-- Model capability history
CREATE TABLE llm_model_capabilities_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id UUID NOT NULL REFERENCES llm_models(id),
  capabilities JSONB,
  changed_at TIMESTAMP DEFAULT NOW(),
  changed_by VARCHAR(100),  -- User or 'system'
  reason TEXT
);

-- Pricing history
CREATE TABLE llm_pricing_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id UUID NOT NULL REFERENCES llm_models(id),
  pricing_input DECIMAL(10, 6),
  pricing_output DECIMAL(10, 6),
  effective_date DATE,
  source VARCHAR(50),  -- 'provider_api', 'manual', 'billing_api'
  changed_at TIMESTAMP DEFAULT NOW()
);

-- Provider-level capabilities
CREATE TABLE llm_provider_capabilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider VARCHAR(50) UNIQUE NOT NULL,
  endpoints TEXT[] DEFAULT '{}',
  features TEXT[] DEFAULT '{}',
  authentication TEXT[] DEFAULT '{}',
  limitations JSONB DEFAULT '{}',
  updated_at TIMESTAMP DEFAULT NOW(),
  source VARCHAR(50)  -- 'yaml', 'api', 'manual'
);

-- Efficient querying
CREATE INDEX idx_models_provider_id ON llm_models(provider, model_id);
CREATE INDEX idx_models_context_window ON llm_models(context_window);
CREATE INDEX idx_models_capabilities ON llm_models USING gin(capabilities);
CREATE INDEX idx_pricing_effective_date ON llm_pricing_history(effective_date);
```

### Benefits of Database Integration

**1. Multi-Instance Consistency**
```elixir
# All instances query from single source
Instance 1 --\
              PostgreSQL (single source of truth)
Instance 2 --/
Instance 3 --\
```

**2. Efficient Querying**
```sql
-- Find models supporting vision with context > 100K
SELECT * FROM llm_models
WHERE capabilities @> '["vision"]'::jsonb
  AND context_window > 100000
  AND deprecated_at IS NULL;
```

**3. Versioning & Audit Trail**
```sql
-- See how Claude's pricing changed
SELECT * FROM llm_pricing_history
WHERE model_id = (SELECT id FROM llm_models WHERE model_id = 'claude-3-5-sonnet-20241022')
ORDER BY changed_at DESC;
```

**4. Capability Evolution Tracking**
```sql
-- See when vision support was added
SELECT changed_at, capabilities
FROM llm_model_capabilities_history
WHERE model_id = (SELECT id FROM llm_models WHERE model_id = 'gpt-4o')
AND capabilities @> '["vision"]'::jsonb;
```

**5. Automatic Pricing Sync**
```elixir
# Could add background job to fetch latest pricing from provider APIs
# and update database with effective dates and history
```

**6. Smart Caching**
```elixir
# Cache invalidation becomes event-driven:
# - Load from cache when possible
# - Invalidate only when database changes
# - Broadcast changes to all instances via NATS
```

### Current Status: Not Required

**Why the system doesn't need a database currently:**
- Models are relatively static (change weekly, not hourly)
- ETS cache is sufficient for single/few-instance deployments
- YAML files provide version control and audit trail (via git)
- System is designed for internal tooling (Singularity), not a multi-tenant service

**When database would become necessary:**
- Multi-instance Singularity deployments with 10+ instances
- Need for automatic model discovery and pricing sync
- API-first model registry (serving external clients)
- Real-time capability tracking across organization

---

## Summary Table: Current Model Registry Features

| Feature | Current | Status | Pain Level |
|---------|---------|--------|-----------|
| Static model definitions | YAML files | ✅ Working | Low |
| Model discovery | ETS cache + YAML | ✅ Working | Medium (manual) |
| Pricing queries | ModelConfig.get_pricing | ✅ Working | Medium (stale) |
| Capability queries | List/filter in code | ✅ Working | Medium (inefficient) |
| Provider-level info | ProviderCapabilities | ✅ Working | Low |
| Multi-instance sync | None | ❌ Missing | High (if needed) |
| Model versioning | None | ❌ Missing | Medium |
| Pricing history | None | ❌ Missing | Medium |
| Capability tracking | None | ❌ Missing | Medium |
| Auto-sync from APIs | Gemini/OpenRouter | Partial | Medium |
| Local model registry | Ollama GenServer | ✅ Working | Low |
| Safe config loading | Whitelist atoms | ✅ Working | Low |

---

## Recommendations

### Short-term (No Database Needed)
1. Add `discovered_at`, `updated_at` timestamps to YAML
2. Create YAML schema validation (JSON Schema)
3. Build CLI tool to auto-update models from provider APIs
4. Document capability matrix more clearly
5. Add deprecation warnings for old models

### Medium-term (With Lightweight Database)
1. Add PostgreSQL model store for Singularity multi-instance deployments
2. Implement automatic pricing sync from provider APIs
3. Track model capability changes over time
4. Add web UI for model registry management
5. Enable NATS-based registry synchronization

### Long-term (If Needed)
1. Build model discovery marketplace
2. Support user-contributed custom models
3. Analytics on which models are used most
4. Automatic model selection based on use case
