/**
 * @file OpenRouter Provider
 * @description This module provides a custom provider for the Vercel AI SDK to interface
 * with the OpenRouter API. It dynamically fetches and caches a list of free models,
 * categorizes them, and provides functions for model selection.
 * @important This provider is configured to only expose FREE models to comply with the
 * AI_PROVIDER_POLICY.md. OpenRouter itself is a pay-per-use service.
 */

import { createOpenRouter } from '@openrouter/ai-sdk-provider';

/**
 * @interface ModelMetadata
 * @description Defines the structure for metadata of a single OpenRouter model.
 */
interface ModelMetadata {
  id: string;
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
  cost: 'free';
  subscription: string;
  category: 'reasoning' | 'code' | 'general' | 'vision' | 'large-context' | 'fast';
}

let cachedModels: ModelMetadata[] | null = null;
let lastFetchTime = 0;
const CACHE_TTL = 60 * 60 * 1000; // 1 hour

/**
 * Fetches and caches the list of free models from the OpenRouter API.
 * @private
 * @returns {Promise<ModelMetadata[]>} A promise that resolves to an array of free models.
 * @throws {Error} If the API request fails.
 */
async function fetchFreeModels(): Promise<ModelMetadata[]> {
  const now = Date.now();
  if (cachedModels && (now - lastFetchTime) < CACHE_TTL) {
    return cachedModels;
  }

  const response = await fetch('https://openrouter.ai/api/v1/models', {
    headers: {
      'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY || ''}`,
    },
  });

  if (!response.ok) {
    throw new Error(`[OpenRouter] API error: ${response.statusText}`);
  }

  const data = await response.json() as { data: any[] };

  const freeModels = data.data
    .filter(m => m.pricing.prompt === "0" && m.pricing.completion === "0")
    .map(m => categorizeAndFormat(m));

  cachedModels = freeModels;
  lastFetchTime = now;

  console.log(`[OpenRouter] Loaded ${freeModels.length} FREE models (cached for 1h).`);
  return freeModels;
}

/**
 * Categorizes a model based on its ID, name, and description.
 * @private
 * @param {string} id The model ID.
 * @param {string} name The model name.
 * @param {string} [description=''] The model description.
 * @param {string} [modality] The model's modality.
 * @returns {ModelMetadata['category']} The category of the model.
 */
function categorizeModel(id: string, name: string, description = '', modality?: string): ModelMetadata['category'] {
  const idLower = id.toLowerCase();
  const nameLower = name.toLowerCase();
  const descLower = description.toLowerCase();

  if (idLower.includes('coder') || idLower.includes('devstral') || nameLower.includes('coder')) return 'code';
  if (idLower.includes('-r1') || nameLower.includes('reasoning') || descLower.includes('reasoning')) return 'reasoning';
  if (idLower.includes('vl') || modality === 'multimodal') return 'vision';
  if (idLower.includes('gemini-2.0') || idLower.includes('longcat')) return 'large-context';
  if ((idLower.includes('8b') || idLower.includes('7b')) && !idLower.includes('72b')) return 'fast';

  return 'general';
}

/**
 * Formats and categorizes a raw model object from the OpenRouter API.
 * @private
 * @param {any} model The raw model object.
 * @returns {ModelMetadata} The formatted model metadata.
 */
function categorizeAndFormat(model: any): ModelMetadata {
  const category = categorizeModel(
    model.id,
    model.name,
    model.description,
    model.architecture?.modality
  );

  const isVision = category === 'vision' || model.architecture?.modality === 'multimodal';

  return {
    id: model.id,
    displayName: model.name,
    description: model.description || `${model.name} - FREE model`,
    contextWindow: model.context_length,
    capabilities: {
      completion: true,
      streaming: true,
      reasoning: category === 'reasoning' || model.id.includes('-r1'),
      vision: isVision,
      tools: true,
    },
    cost: 'free' as const,
    subscription: 'OpenRouter (free tier)',
    category,
  };
}

/**
 * @const {object} openrouter
 * @description The public instance of the OpenRouter provider, extended with dynamic model listing.
 *
 * @example
 * import { openrouter } from './providers/openrouter';
 * const result = await generateText({
 *   model: openrouter('deepseek/deepseek-r1:free'),
 *   messages: [{ role: 'user', content: 'Hello' }]
 * });
 */
export const openrouter = Object.assign(
  createOpenRouter({
    apiKey: process.env.OPENROUTER_API_KEY || '',
  }),
  {
    listModels: async () => await fetchFreeModels(),
  }
);

/**
 * Gets the best model for a given category from the live OpenRouter API.
 * @param {'reasoning' | 'code' | 'general' | 'vision' | 'large-context' | 'fast'} [category='general'] The category to search for.
 * @returns {Promise<string>} A promise that resolves to the ID of the best model.
 * @throws {Error} If no models are found for the specified category.
 */
export async function getBestOpenRouterModel(category: 'reasoning' | 'code' | 'general' | 'vision' | 'large-context' | 'fast' = 'general'): Promise<string> {
  const models = await fetchFreeModels();
  const model = models.find(m => m.category === category);
  if (!model) {
    throw new Error(`[OpenRouter] No models found for category: ${category}`);
  }
  return model.id;
}

/**
 * Gets all available models for a given category.
 * @param {ModelMetadata['category']} category The category to retrieve models for.
 * @returns {Promise<ModelMetadata[]>} A promise that resolves to an array of models in the category.
 */
export async function getOpenRouterModelsByCategory(category: ModelMetadata['category']): Promise<ModelMetadata[]> {
  const models = await fetchFreeModels();
  return models.filter(m => m.category === category);
}