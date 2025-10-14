/**
 * @file AI Model Registry
 * @description This module provides utilities for discovering, registering, and
 * managing AI models from various providers. It supports caching and dynamic
 * model capability scoring.
 */

/**
 * @interface ModelInfo
 * @description Defines the structure for storing detailed information about a single AI model.
 */
export interface ModelInfo {
  id: string;
  provider: string;
  model: string;
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
  subscription?: string;
  capabilityScores?: {
    code: number;
    reasoning: number;
    creativity: number;
    speed: number;
    cost: number;
    tool_capacity: number;
    confidence?: 'high' | 'medium' | 'low';
    reasoning_text?: string;
  };
}

/**
 * @interface ProviderWithModels
 * @description Represents a provider with a synchronous `listModels` method.
 * @deprecated Prefer `ProviderWithMetadata` for asynchronous operations.
 */
export interface ProviderWithModels {
  listModels(): readonly any[];
}

/**
 * @interface ProviderWithMetadata
 * @description Represents a provider with a `getModelMetadata` method that can be synchronous or asynchronous.
 */
export interface ProviderWithMetadata {
  getModelMetadata(): readonly any[] | Promise<readonly any[]>;
}

/**
 * Registers models from a given provider by calling its metadata listing function.
 * @param {string} provider The name of the provider.
 * @param {ProviderWithModels | ProviderWithMetadata} providerInstance The provider instance.
 * @returns {Promise<ModelInfo[]>} A promise that resolves to an array of model information.
 */
export async function registerProviderModels(
  provider: string,
  providerInstance: ProviderWithModels | ProviderWithMetadata
): Promise<ModelInfo[]> {
  let models: readonly any[];

  if (typeof (providerInstance as any).getModelMetadata === 'function') {
    const result = (providerInstance as any).getModelMetadata();
    models = result instanceof Promise ? await result : result;
  } else if (typeof (providerInstance as any).listModels === 'function') {
    models = (providerInstance as any).listModels();
  } else {
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

const MODEL_CATALOG_CACHE_FILE = '.cache/model-catalog.json';
const MODEL_CATALOG_CACHE_TTL = 1000 * 60 * 5; // 5 minutes

/**
 * Loads the model catalog from a disk cache.
 * @private
 * @returns {Promise<{ models: ModelInfo[]; time: number } | null>} The cached data or null if not found.
 */
async function loadCatalogFromDisk(): Promise<{ models: ModelInfo[]; time: number } | null> {
  try {
    const file = Bun.file(MODEL_CATALOG_CACHE_FILE);
    if (await file.exists()) {
      const content = await file.json();
      console.log(`[ModelRegistry] Loaded ${content.models.length} models from disk cache.`);
      return content;
    }
  } catch (error) {
    console.error('[ModelRegistry] Failed to load catalog cache:', error);
  }
  return null;
}

/**
 * Saves the model catalog to a disk cache.
 * @private
 * @param {ModelInfo[]} models The models to save.
 * @param {number} time The timestamp of the save operation.
 */
async function saveCatalogToDisk(models: ModelInfo[], time: number): Promise<void> {
  try {
    await Bun.write(MODEL_CATALOG_CACHE_FILE, JSON.stringify({ models, time }, null, 2));
    console.log(`[ModelRegistry] Saved ${models.length} models to disk cache.`);
  } catch (error) {
    console.error('[ModelRegistry] Failed to save catalog cache:', error);
  }
}

/**
 * Builds a comprehensive catalog of all models from all registered providers.
 * @param {Record<string, ProviderWithModels | ProviderWithMetadata>} providers A map of provider names to instances.
 * @param {object} [options] Configuration options.
 * @param {boolean} [options.useCache=true] Whether to use the disk cache.
 * @returns {Promise<ModelInfo[]>} A promise that resolves to the complete model catalog.
 */
export async function buildModelCatalog(
  providers: Record<string, ProviderWithModels | ProviderWithMetadata>,
  options: { useCache?: boolean; enrichWithModelsDevData?: boolean } = {}
): Promise<ModelInfo[]> {
  const { useCache = true } = options;
  const now = Date.now();

  if (useCache) {
    const diskCache = await loadCatalogFromDisk();
    if (diskCache && now - diskCache.time < MODEL_CATALOG_CACHE_TTL) {
      // Refresh in the background for subsequent requests
      setTimeout(async () => {
        const freshModels = await buildModelCatalog(providers, { useCache: false });
        await saveCatalogToDisk(freshModels, Date.now());
      }, 5000);
      return diskCache.models;
    }
  }

  const models: ModelInfo[] = [];
  for (const [providerName, provider] of Object.entries(providers)) {
    const providerModels = await registerProviderModels(providerName, provider);
    models.push(...providerModels);
  }

  if (useCache) {
    await saveCatalogToDisk(models, now);
  }

  return models;
}

/**
 * Retrieves information for a specific model by its full ID.
 * @param {string} fullId The full ID of the model (e.g., "provider:model-name").
 * @param {ModelInfo[]} models The array of models to search.
 * @returns {ModelInfo | undefined} The model information or undefined if not found.
 */
export function getModelInfo(fullId: string, models: ModelInfo[]): ModelInfo | undefined {
  return models.find(m => m.id === fullId);
}

/**
 * Retrieves all models for a specific provider.
 * @param {string} provider The name of the provider.
 * @param {ModelInfo[]} models The array of models to search.
 * @returns {ModelInfo[]} An array of models from the specified provider.
 */
export function getProviderModels(provider: string, models: ModelInfo[]): ModelInfo[] {
  return models.filter(m => m.provider === provider);
}

/**
 * Lists all unique provider names from the model catalog.
 * @param {ModelInfo[]} models The array of models.
 * @returns {string[]} An array of unique provider names.
 */
export function getProviders(models: ModelInfo[]): string[] {
  return [...new Set(models.map(m => m.provider))];
}

/**
 * Converts the model catalog to the OpenAI `/v1/models` API format.
 * @param {ModelInfo[]} models The array of models to convert.
 * @returns {object} The model catalog in OpenAI's format.
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

/**
 * Calculates a tool capacity score (1-10) based on the model's context window size.
 * @param {number} contextWindow The context window size of the model.
 * @returns {number} A score from 1 to 10 representing tool capacity.
 */
export function calculateToolCapacityScore(contextWindow: number): number {
  if (contextWindow < 16_000) return 2;
  if (contextWindow < 64_000) return 4;
  if (contextWindow < 200_000) return 6;
  if (contextWindow < 1_000_000) return 8;
  return 10;
}

/**
 * Gets the maximum number of tools a model is estimated to support based on its context window.
 * @param {number} contextWindow The context window size of the model.
 * @returns {number} The estimated maximum number of tools.
 */
export function getMaxToolsForModel(contextWindow: number): number {
  if (contextWindow < 16_000) return 4;
  if (contextWindow < 64_000) return 8;
  if (contextWindow < 200_000) return 12;
  if (contextWindow < 1_000_000) return 20;
  return 30;
}

