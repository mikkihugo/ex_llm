/**
 * @file Models Registry - Integration with models.dev
 * @description This module is responsible for fetching, caching, and enriching model
 * metadata from the external `models.dev` API. It combines this external data
 * with local provider information to create a comprehensive and up-to-date
 * model catalog.
 */

import type { ModelInfo } from './model-registry';

/**
 * @interface ModelsDev
 * @description Represents the top-level structure of the data fetched from the models.dev API.
 */
export interface ModelsDev {
  providers: Record<string, ProviderInfo>;
}

/**
 * @interface ProviderInfo
 * @description Defines the structure for information about a single AI provider from models.dev.
 */
export interface ProviderInfo {
  id: string;
  name: string;
  api?: string;
  env: string[];
  npm?: string;
  models: Record<string, ModelMetadata>;
}

/**
 * @interface ModelMetadata
 * @description Defines the detailed metadata for a single AI model from models.dev.
 */
export interface ModelMetadata {
  id: string;
  name: string;
  release_date: string;
  attachment: boolean;
  reasoning: boolean;
  temperature: boolean;
  tool_call: boolean;
  cost: {
    input: number;
    output: number;
    cache_read?: number;
    cache_write?: number;
  };
  limit: {
    context: number;
    output: number;
  };
  experimental?: boolean;
  options?: Record<string, any>;
}

const MODELS_DEV_URL = 'https://models.dev/api.json';
const CACHE_TTL = 1000 * 60 * 60 * 24 * 7; // 7 days
const CACHE_FILE = '.cache/models-dev.json';

let cachedData: ModelsDev | null = null;
let cacheTime: number = 0;

/**
 * Loads cached models.dev data from the local disk.
 * @private
 * @returns {Promise<{ data: ModelsDev; time: number } | null>} The cached data or null if not found or expired.
 */
async function loadFromDisk(): Promise<{ data: ModelsDev; time: number } | null> {
  try {
    const file = Bun.file(CACHE_FILE);
    if (await file.exists()) {
      const content = await file.json();
      console.log(`[ModelsRegistry] Loaded ${Object.keys(content.data.providers).length} providers from disk cache.`);
      return content;
    }
  } catch (error) {
    console.error('[ModelsRegistry] Failed to load disk cache:', error);
  }
  return null;
}

/**
 * Saves models.dev data to the local disk cache.
 * @private
 * @param {ModelsDev} data The data to save.
 * @param {number} time The timestamp of the save operation.
 */
async function saveToDisk(data: ModelsDev, time: number): Promise<void> {
  try {
    await Bun.write(CACHE_FILE, JSON.stringify({ data, time }, null, 2));
    console.log(`[ModelsRegistry] Saved models.dev data to disk cache.`);
  } catch (error) {
    console.error('[ModelsRegistry] Failed to save disk cache:', error);
  }
}

/**
 * Fetches model metadata from the models.dev API, utilizing in-memory and disk caching.
 * @returns {Promise<ModelsDev>} A promise that resolves to the models.dev data.
 */
export async function fetchModelsDevData(): Promise<ModelsDev> {
  const now = Date.now();

  // 1. Check in-memory cache
  if (cachedData && now - cacheTime < CACHE_TTL) {
    return cachedData;
  }

  // 2. Check disk cache
  const diskCache = await loadFromDisk();
  if (diskCache && now - diskCache.time < CACHE_TTL) {
    cachedData = diskCache.data;
    cacheTime = diskCache.time;
    return cachedData;
  }

  // 3. Fetch from API
  try {
    console.log('[ModelsRegistry] Fetching fresh model metadata from models.dev...');
    const response = await fetch(MODELS_DEV_URL, {
      headers: {
        'User-Agent': 'Singularity-AI-Server/1.0'
      }
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch from models.dev: ${response.status}`);
    }

    const data = await response.json() as ModelsDev;
    cachedData = data;
    cacheTime = now;

    await saveToDisk(cachedData, cacheTime);

    console.log(`[ModelsRegistry] Fetched metadata for ${Object.keys(data.providers).length} providers.`);
    return cachedData;
  } catch (error) {
    console.error('[ModelsRegistry] Failed to fetch models.dev data:', error);

    // 4. Fallback to stale cache if fetch fails
    if (diskCache) {
      console.log('[ModelsRegistry] Using stale disk cache as fallback.');
      return diskCache.data;
    }

    return cachedData || { providers: {} };
  }
}

/**
 * Enriches a local model's information with additional metadata from models.dev.
 * @param {ModelInfo} localModel The local model information to enrich.
 * @param {ModelsDev} modelsDevData The data from models.dev.
 * @returns {ModelInfo} The enriched model information.
 */
export function enrichModelInfo(
  localModel: ModelInfo,
  modelsDevData: ModelsDev
): ModelInfo {
  for (const providerData of Object.values(modelsDevData.providers)) {
    for (const modelData of Object.values(providerData.models)) {
      if (
        modelData.id === localModel.id ||
        modelData.id.includes(localModel.id) ||
        localModel.id.includes(modelData.name.toLowerCase().replace(/\s+/g, '-'))
      ) {
        return {
          ...localModel,
          contextWindow: modelData.limit.context,
          // @ts-ignore
          maxOutputTokens: modelData.limit.output,
          capabilities: {
            ...localModel.capabilities,
            reasoning: modelData.reasoning || localModel.capabilities.reasoning,
            tools: modelData.tool_call || localModel.capabilities.tools,
            vision: modelData.attachment || localModel.capabilities.vision,
          },
          // @ts-ignore
          metadata: {
            // @ts-ignore
            ...localModel.metadata,
            releaseDate: modelData.release_date,
            experimental: modelData.experimental,
            knowledgeCutoff: (modelData as any).knowledge_cutoff,
            costPerMillion: {
              input: modelData.cost.input,
              output: modelData.cost.output,
              cacheRead: modelData.cost.cache_read,
              cacheWrite: modelData.cost.cache_write,
            }
          }
        };
      }
    }
  }
  return localModel;
}

/**
 * Enriches a list of local models with metadata from models.dev.
 * @param {ModelInfo[]} localModels The list of local models to enrich.
 * @returns {Promise<ModelInfo[]>} A promise that resolves to the list of enriched models.
 */
export async function enrichAllModels(
  localModels: ModelInfo[]
): Promise<ModelInfo[]> {
  const modelsDevData = await fetchModelsDevData();
  return localModels.map(model => enrichModelInfo(model, modelsDevData));
}

/**
 * Retrieves information for a specific provider from the models.dev data.
 * @param {string} providerId The ID of the provider to retrieve.
 * @returns {Promise<ProviderInfo | null>} A promise that resolves to the provider's information or null if not found.
 */
export async function getProviderInfo(providerId: string): Promise<ProviderInfo | null> {
  const data = await fetchModelsDevData();
  if (data.providers[providerId]) {
    return data.providers[providerId];
  }
  const lowerProviderId = providerId.toLowerCase();
  for (const [key, provider] of Object.entries(data.providers)) {
    if (key.toLowerCase().includes(lowerProviderId) || provider.id.toLowerCase().includes(lowerProviderId)) {
      return provider;
    }
  }
  return null;
}

/**
 * Retrieves a list of all available models from models.dev.
 * @returns {Promise<Array<{ provider: string; model: ModelMetadata }>>} A promise that resolves to a list of all models.
 */
export async function getAllAvailableModels(): Promise<Array<{
  provider: string;
  model: ModelMetadata;
}>> {
  const data = await fetchModelsDevData();
  const models: Array<{ provider: string; model: ModelMetadata }> = [];
  for (const [providerKey, providerData] of Object.entries(data.providers)) {
    for (const modelData of Object.values(providerData.models)) {
      models.push({
        provider: providerKey,
        model: modelData
      });
    }
  }
  return models;
}

/**
 * Searches for models that match a given set of criteria.
 * @param {object} criteria The search criteria.
 * @returns {Promise<Array<{ provider: string; model: ModelMetadata }>>} A promise that resolves to a list of matching models.
 */
export async function searchModels(criteria: {
  provider?: string;
  reasoning?: boolean;
  toolCall?: boolean;
  maxCostPerMillion?: number;
  minContextWindow?: number;
}): Promise<Array<{ provider: string; model: ModelMetadata }>> {
  const allModels = await getAllAvailableModels();
  return allModels.filter(({ provider, model }) => {
    if (criteria.provider && !provider.includes(criteria.provider)) {
      return false;
    }
    if (criteria.reasoning !== undefined && model.reasoning !== criteria.reasoning) {
      return false;
    }
    if (criteria.toolCall !== undefined && model.tool_call !== criteria.toolCall) {
      return false;
    }
    if (criteria.maxCostPerMillion && model.cost.output > criteria.maxCostPerMillion) {
      return false;
    }
    if (criteria.minContextWindow && model.limit.context < criteria.minContextWindow) {
      return false;
    }
    return true;
  });
}

// Auto-refresh the cache periodically.
setInterval(() => {
  fetchModelsDevData().catch(err => {
    console.error('[ModelsRegistry] Failed to auto-refresh models.dev data:', err);
  });
}, CACHE_TTL);
