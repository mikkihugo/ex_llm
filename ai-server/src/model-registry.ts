/**
 * AI SDK Provider Registry Configuration
 *
 * Each provider exports a listModels() method that returns its available models.
 * This file provides utilities to aggregate models from all providers.
 */

export interface ModelInfo {
  id: string;              // Full ID: "provider:model"
  provider: string;        // Provider name
  model: string;           // Model name (without provider prefix)
  displayName: string;
  description: string;
  contextWindow: number;
  capabilities: {
    completion: boolean;
    streaming: boolean;
    reasoning: boolean;
    vision: boolean;
    tools: boolean;
  };
  cost: 'free' | 'limited' | 'pay-per-use';
  subscription?: string;   // e.g., "Claude Pro", "ChatGPT Plus", "GitHub Copilot"
}

/**
 * Provider with model listing capability (legacy)
 */
export interface ProviderWithModels {
  listModels(): readonly any[];
}

/**
 * Provider with metadata access (for customProvider-based providers)
 */
export interface ProviderWithMetadata {
  getModelMetadata(): readonly any[] | Promise<readonly any[]>;
}

/**
 * Register models from a provider that implements listModels() or getModelMetadata()
 */
export async function registerProviderModels(
  provider: string,
  providerInstance: ProviderWithModels | ProviderWithMetadata
): Promise<ModelInfo[]> {
  // Check if provider has getModelMetadata (customProvider-based)
  let models: readonly any[];

  // Try getModelMetadata first (works with Proxies)
  if (typeof (providerInstance as any).getModelMetadata === 'function') {
    const result = (providerInstance as any).getModelMetadata();
    models = result instanceof Promise ? await result : result;
    console.log(`[ModelRegistry] Provider ${provider}: getModelMetadata returned ${models.length} models`);
  } else if (typeof (providerInstance as any).listModels === 'function') {
    models = (providerInstance as any).listModels();
    console.log(`[ModelRegistry] Provider ${provider}: listModels returned ${models.length} models`);
  } else {
    console.log(`[ModelRegistry] Provider ${provider}: NO metadata method found`);
    models = [];
  }

  return models.map((m: any) => ({
    id: `${provider}:${m.id}`,
    provider,
    model: m.id,
    displayName: m.displayName || m.name,
    description: m.description || m.summary || '',
    contextWindow: m.contextWindow || m.limits?.max_input_tokens || 8000,
    capabilities: m.capabilities || {
      completion: true,
      streaming: m.capabilities?.includes?.('streaming') ?? true,
      reasoning: m.capabilities?.includes?.('reasoning') ?? false,
      vision: m.supported_input_modalities?.includes?.('image') ?? false,
      tools: m.capabilities?.includes?.('tool-calling') ?? false,
    },
    cost: m.cost || 'free',
    subscription: m.subscription,
  }));
}

/**
 * Build model catalog from provider registry
 * Call this after creating the provider registry
 * Supports both legacy listModels() and AI SDK customProvider() approaches
 */
export async function buildModelCatalog(
  providers: Record<string, ProviderWithModels | ProviderWithMetadata>
): Promise<ModelInfo[]> {
  const models: ModelInfo[] = [];

  for (const [providerName, provider] of Object.entries(providers)) {
    const providerModels = await registerProviderModels(providerName, provider);
    models.push(...providerModels);
  }

  return models;
}

/**
 * Get model info by full ID (provider:model)
 */
export function getModelInfo(fullId: string, models: ModelInfo[]): ModelInfo | undefined {
  return models.find(m => m.id === fullId);
}

/**
 * Get all models for a provider
 */
export function getProviderModels(provider: string, models: ModelInfo[]): ModelInfo[] {
  return models.filter(m => m.provider === provider);
}

/**
 * List all available providers
 */
export function getProviders(models: ModelInfo[]): string[] {
  return [...new Set(models.map(m => m.provider))];
}

/**
 * Convert to OpenAI /v1/models format
 */
export function toOpenAIModelsFormat(models: ModelInfo[]) {
  return {
    object: 'list',
    data: models.map(m => ({
      id: m.id,
      object: 'model',
      created: Math.floor(Date.now() / 1000),
      owned_by: m.provider,
      permission: [],
      root: m.id,
      parent: null,
    })),
  };
}

