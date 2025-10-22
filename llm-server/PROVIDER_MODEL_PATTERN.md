# Provider Model Listing Pattern

## Overview

Two strategies for model listing:

1. **Provider has auto-listing** → Use provider's API to list models
2. **Provider doesn't have auto-listing** → Maintain static model list in provider file

AI SDK providers (ProviderV2) **do NOT** support auto-listing. So we use strategy #2.

## Current Implementation: Manual Model Lists

Since AI SDK providers don't auto-list models, each provider wrapper maintains a static model list.

### Implementation

```typescript
// 1. Define model metadata (owned by provider)
export const PROVIDER_MODELS = [
  {
    id: 'model-name',
    displayName: 'Human-readable name',
    description: 'Model description',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: false, tools: true },
    cost: 'free' | 'subscription',
    subscription: 'Subscription Name', // if cost is 'subscription'
  },
] as const;

// 2. Extend provider with listModels()
export interface ExtendedProvider extends BaseProvider {
  listModels(): typeof PROVIDER_MODELS;
}

// 3. Create extended provider instance
export function createProvider(options?: Options): ExtendedProvider {
  const baseProvider = baseCreateProvider(options);

  return Object.assign(baseProvider, {
    listModels: () => PROVIDER_MODELS,
  }) as ExtendedProvider;
}
```

### Central Registry

```typescript
import { buildModelCatalog, type ProviderWithModels } from './model-registry';

// Create provider instances
const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });
const claudeCode = claudeCode;  // Already extended
const codex = codex;            // Already extended

// Build catalog from providers
const MODELS = buildModelCatalog({
  'gemini-code': geminiCode as unknown as ProviderWithModels,
  'claude-code': claudeCode as unknown as ProviderWithModels,
  'openai-codex': codex as unknown as ProviderWithModels,
});
```

## Provider Responsibilities

Each provider file is responsible for:

1. ✅ Maintaining accurate model metadata
2. ✅ Exposing `listModels()` method
3. ✅ Keeping metadata up-to-date with upstream changes
4. ✅ Documenting cost model (free vs subscription)

## Central Registry Responsibilities

The central registry (`model-registry.ts`) is responsible for:

1. ✅ Aggregating models from all providers
2. ✅ Adding `provider:` prefix to model IDs
3. ✅ Providing query utilities (getModelInfo, getProviderModels, etc.)
4. ✅ Converting to OpenAI /v1/models format

## Benefits

- **Decentralized**: Each provider owns its model list
- **Type-safe**: `as const` ensures compile-time checking
- **Discoverable**: `listModels()` makes models queryable
- **Maintainable**: Update one file to add/remove models
- **Extensible**: Easy to add new providers

## Example: Adding a New Provider

```typescript
// 1. Create provider wrapper (llm-server/src/providers/new-provider.ts)
import { createNewProvider as baseCreateNewProvider } from 'ai-sdk-provider-new';

export const NEW_PROVIDER_MODELS = [
  {
    id: 'model-1',
    displayName: 'Model 1',
    description: 'First model',
    contextWindow: 100000,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: false, tools: true },
    cost: 'free' as const,
  },
] as const;

export interface NewProvider extends BaseNewProvider {
  listModels(): typeof NEW_PROVIDER_MODELS;
}

export function createNewProvider(options?: Options): NewProvider {
  const baseProvider = baseCreateNewProvider(options);
  return Object.assign(baseProvider, {
    listModels: () => NEW_PROVIDER_MODELS,
  }) as NewProvider;
}

// 2. Register in server.ts
const newProvider = createNewProvider();
const registry = createProviderRegistry({
  'gemini-code': geminiCode,
  'claude-code': claudeCode,
  'openai-codex': codex,
  'new-provider': newProvider,  // Add here
});

const MODELS = buildModelCatalog({
  'gemini-code': geminiCode as unknown as ProviderWithModels,
  'claude-code': claudeCode as unknown as ProviderWithModels,
  'openai-codex': codex as unknown as ProviderWithModels,
  'new-provider': newProvider as unknown as ProviderWithModels,  // Add here
});
```

## Alternative: If Provider Has Auto-Listing

If you add a provider that **does** support auto-listing:

```typescript
// Example: Hypothetical provider with /v1/models endpoint
export interface AutoListingProvider extends BaseProvider {
  listModels(): Promise<ModelInfo[]>;  // Async!
}

export function createAutoListingProvider(options?: Options): AutoListingProvider {
  const baseProvider = baseCreateProvider(options);

  return Object.assign(baseProvider, {
    async listModels() {
      // Provider has API to list models
      const response = await fetch('https://api.provider.com/v1/models');
      const data = await response.json();
      return data.models.map(transformToModelInfo);
    },
  }) as AutoListingProvider;
}
```

**Key difference**: `listModels()` would be `async` and fetch from provider's API.

Then update `buildModelCatalog()` to support async providers.

## Summary

**Two strategies:**

1. **Provider auto-lists** → Use provider's API (async)
2. **Provider doesn't auto-list** → Static model list in provider file (sync)

**Current reality**: AI SDK providers don't auto-list, so we use static lists (strategy #2).
