# ExLLM Model Registry Exploration Summary

## Overview

This exploration analyzed the model registry system in the ExLLM package to understand how models are discovered, configured, and managed across 40+ LLM providers.

## Findings

### 1. Model Registry Architecture

ExLLM uses a **three-tier model discovery system**:

**Tier 1: Static YAML Configuration** (Primary)
- 59 YAML files in `config/models/` directory
- 12,355 lines of configuration
- Covers 40+ providers (Anthropic, OpenAI, Gemini, Ollama, Bedrock, etc.)
- Cached in `:model_config_cache` ETS table at startup
- Provides: pricing, context windows, capabilities, metadata

**Tier 2: Ollama-Specific Dynamic Registry** (GenServer)
- Stateful GenServer for Ollama model discovery
- Fallback chain: In-memory cache → YAML → Ollama API
- 1-hour TTL for cached data
- Location: `ExLLM.Infrastructure.OllamaModelRegistry`

**Tier 3: Provider API Discovery** (Optional)
- Optional integration with provider APIs (Gemini, Groq, OpenRouter)
- ETS cache with 1-hour TTL
- Fallback to YAML if API fails
- Location: `ExLLM.Infrastructure.Config.ModelLoader`

### 2. Key Components

**Core Query API** (`ExLLM.Core.Models`)
- `list_all/0` - List all models across all providers
- `list_for_provider/1` - List models for specific provider
- `get_info/2` - Get detailed model information
- `find_by_capabilities/1` - Find models with specific capabilities
- `find_by_min_context/1` - Find models with minimum context window
- `find_by_cost_range/1` - Find models within cost range
- `compare/1` - Compare multiple models

**Low-Level Config API** (`ExLLM.Infrastructure.Config.ModelConfig`)
- `get_pricing/2` - Get model pricing
- `get_context_window/2` - Get context window size
- `get_capabilities/2` - Get model capabilities
- `get_max_output_tokens/2` - Get max output tokens
- `get_default_model/1` - Get provider's default model
- `get_all_models/1` - Get all models for provider
- `reload_config/0` - Reload configuration from YAML

**Provider Info API** (`ExLLM.Infrastructure.Config.ProviderCapabilities`)
- Provider-level capabilities (endpoints, features, limitations)
- 10 providers with detailed feature matrices
- Helper functions for feature detection and recommendations

### 3. Configuration Format

Models are defined in YAML with the following structure:

```yaml
provider: anthropic
default_model: claude-3-5-sonnet-20241022

models:
  model-id:
    name: "Display Name"
    description: "Optional description"
    context_window: 200000
    max_output_tokens: 8192
    pricing:
      input: 3.0    # Per 1M tokens
      output: 15.0
    capabilities:
      - streaming
      - function_calling
      - vision
    deprecation_date: "2025-10-01"  # Optional
    metadata: {}    # Optional custom metadata
```

**Safe Atomization**: YAML keys are converted to atoms using a whitelist mapping (48 known keys) to prevent arbitrary string→atom conversion vulnerabilities.

### 4. Pain Points

#### High Impact
1. **Manual Model Updates** - New models require manual YAML edits; no automation
2. **No Multi-Instance Sync** - Each Singularity instance loads independently; no sharing
3. **Pricing Updates Lag** - Pricing changes are manual; no sync with provider APIs

#### Medium Impact
4. **No Versioning** - Model changes not tracked; can't rollback or audit
5. **Pricing History Missing** - Can't see how pricing changed over time
6. **Capability Evolution Not Tracked** - Can't see when capabilities added/removed
7. **Hardcoded Local Defaults** - Ollama uses hardcoded 4K context window for all models
8. **Unstructured Capabilities** - Simple list with no metadata about each capability

#### Lower Impact
9. **No Runtime Reloading** - Can't update models at runtime without restart
10. **Query Performance** - Must load all models to filter; no database indexes

### 5. Database Considerations

**Current State**
- Uses ETS tables for caching (no persistence)
- No query support beyond simple key-value lookups
- No multi-instance sharing mechanism

**Why Database Would Help**
- Multi-instance deployments (Singularity) could share a single source of truth
- Efficient querying: "Find models with vision, context > 100K, price < $5"
- Versioning and audit trails for model changes
- Automatic pricing sync from provider APIs
- Persistent storage and recovery after crashes

**Recommended Approach** (PostgreSQL)
- Table for models with JSONB capabilities and metadata
- History tables for pricing and capability changes
- Indexes on frequently queried fields
- NATS-based event broadcasting for cache invalidation
- Not required for single-instance deployments

**Current Status**: Not needed for Singularity's current use case (internal tooling, single/few instances, weekly model changes). Would become necessary for: multi-instance federated deployments, API-first model registry, or real-time capability tracking.

### 6. Files Generated

Two comprehensive documents were created:

1. **MODEL_REGISTRY_ANALYSIS.md** (Detailed)
   - Complete architecture breakdown
   - All 10 pain points with examples
   - Database schema recommendations
   - Implementation timeline and recommendations

2. **MODEL_REGISTRY_QUICK_REFERENCE.md** (Quick)
   - Key modules and functions
   - Common code examples
   - Configuration format reference
   - Troubleshooting guide

## Key Insights

### Strengths
- Clean, simple YAML-based approach
- Comprehensive coverage of 40+ providers
- Safe configuration loading (whitelist atomization)
- Good fallback mechanisms (API → YAML)
- Ollama dynamic discovery works well
- Provider-level capabilities well documented

### Weaknesses
- No automatic model discovery (requires manual updates)
- No historical tracking (pricing, capabilities)
- No multi-instance coordination
- Hardcoded defaults for local providers
- Pricing updates are manual and lag behind reality

### Design Philosophy
The system prioritizes **simplicity and offline-first functionality** over dynamic discovery. This is appropriate for internal tooling (Singularity) but would need enhancement for:
- External API (serving model registry to other systems)
- Multi-instance coordinated deployments
- Real-time pricing and capability tracking

## Recommendations

### Immediate (No Code Changes)
1. Document the three-tier discovery system more clearly
2. Add `updated_at` timestamps to YAML files
3. Create YAML schema validator

### Short-term (1-2 weeks)
1. Add CLI tool to auto-sync models from provider APIs
2. Add capability metadata documentation
3. Improve Ollama model registration UI

### Medium-term (1-2 months)
1. PostgreSQL model store for multi-instance deployments
2. Automatic pricing sync background job
3. Capability change history tracking
4. NATS-based registry synchronization

### Long-term (If Needed)
1. Model discovery marketplace
2. User-contributed custom models
3. Usage analytics dashboard
4. Automatic model selection AI

## Related Modules

- `/lib/ex_llm/core/models.ex` - High-level queries
- `/lib/ex_llm/infrastructure/config/` - Configuration loading
- `/lib/ex_llm/infrastructure/ollama_model_registry.ex` - Ollama GenServer
- `/config/models/*.yml` - Model definitions
- `/lib/types.ex` - Types and structs

## Conclusion

ExLLM has a well-designed but manual model registry system that works well for internal use. The three-tier approach provides good flexibility and resilience. The main pain point is manual maintenance of model definitions, which could be addressed with automation and a database layer for multi-instance deployments.

The system prioritizes simplicity and offline functionality over dynamic discovery, which is appropriate for its current context (internal tooling). As Singularity grows and moves toward multi-instance deployments, database integration would become valuable.
