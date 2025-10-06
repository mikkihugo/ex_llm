/**
 * Models Registry - Fetch and combine model metadata
 *
 * Combines:
 * 1. models.dev API (context limits, costs, capabilities)
 * 2. Local provider metadata (subscription info, custom models)
 */

import type { ModelInfo } from './model-registry';

export interface ModelsDev {
  providers: Record<string, ProviderInfo>;
}

export interface ProviderInfo {
  id: string;
  name: string;
  api?: string;
  env: string[];
  npm?: string;
  models: Record<string, ModelMetadata>;
}

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
const CACHE_TTL = 1000 * 60 * 60; // 1 hour

let cachedData: ModelsDev | null = null;
let cacheTime: number = 0;

/**
 * Fetch model metadata from models.dev
 */
export async function fetchModelsDevData(): Promise<ModelsDev> {
  // Return cached data if fresh
  const now = Date.now();
  if (cachedData && now - cacheTime < CACHE_TTL) {
    return cachedData;
  }

  try {
    console.log('🔄 Fetching model metadata from models.dev...');
    const response = await fetch(MODELS_DEV_URL, {
      headers: {
        'User-Agent': 'Singularity-AI-Server/1.0'
      }
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch: ${response.status}`);
    }

    const data = await response.json();
    cachedData = { providers: data };
    cacheTime = now;

    console.log(`✅ Fetched metadata for ${Object.keys(data).length} providers`);
    return cachedData;
  } catch (error) {
    console.error('⚠️  Failed to fetch models.dev data:', error);
    // Return cached data even if stale, or empty
    return cachedData || { providers: {} };
  }
}

/**
 * Enrich local model info with models.dev metadata
 */
export function enrichModelInfo(
  localModel: ModelInfo,
  modelsDevData: ModelsDev
): ModelInfo {
  // Try to find matching model in models.dev
  // Match by model ID or provider/model combination
  for (const [providerKey, providerData] of Object.entries(modelsDevData.providers)) {
    for (const [modelKey, modelData] of Object.entries(providerData.models)) {
      // Match by ID or model name
      if (
        modelData.id === localModel.id ||
        modelData.id.includes(localModel.id) ||
        localModel.id.includes(modelData.name.toLowerCase().replace(/\s+/g, '-'))
      ) {
        return {
          ...localModel,
          contextWindow: modelData.limit.context,
          maxOutputTokens: modelData.limit.output,
          capabilities: {
            ...localModel.capabilities,
            reasoning: modelData.reasoning || localModel.capabilities.reasoning,
            tools: modelData.tool_call || localModel.capabilities.tools,
            vision: modelData.attachment || localModel.capabilities.vision,
          },
          // Add metadata
          metadata: {
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

  // No match found, return original
  return localModel;
}

/**
 * Enrich all models with models.dev data
 */
export async function enrichAllModels(
  localModels: ModelInfo[]
): Promise<ModelInfo[]> {
  const modelsDevData = await fetchModelsDevData();

  return localModels.map(model => enrichModelInfo(model, modelsDevData));
}

/**
 * Get provider info from models.dev
 */
export async function getProviderInfo(providerId: string): Promise<ProviderInfo | null> {
  const data = await fetchModelsDevData();

  // Try exact match first
  if (data.providers[providerId]) {
    return data.providers[providerId];
  }

  // Try fuzzy match
  const lowerProviderId = providerId.toLowerCase();
  for (const [key, provider] of Object.entries(data.providers)) {
    if (key.toLowerCase().includes(lowerProviderId) || provider.id.toLowerCase().includes(lowerProviderId)) {
      return provider;
    }
  }

  return null;
}

/**
 * Get all available models from models.dev
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
 * Search models by criteria
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

// Auto-refresh every hour
setInterval(() => {
  fetchModelsDevData().catch(err => {
    console.error('Failed to refresh models.dev data:', err);
  });
}, CACHE_TTL);
