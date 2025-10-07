/**
 * OpenRouter Provider
 * Access to 100+ LLM models via unified API
 *
 * ⚠️  IMPORTANT: OpenRouter is PAY-PER-USE (not subscription)
 * Only FREE models are exposed to comply with AI_PROVIDER_POLICY.md
 *
 * Free tier includes: DeepSeek, Qwen, Mistral, Gemma, Llama, etc.
 *
 * Auto-generated model list from OpenRouter API (51 FREE models)
 * Run: bun run scripts/list-openrouter-free.ts
 */

import { createOpenRouter } from '@openrouter/ai-sdk-provider';

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

/**
 * Fetch ALL FREE models from OpenRouter API dynamically
 *
 * Updates: Hourly cache (OpenRouter updates models frequently)
 * No fallback - throws error if API fails
 */
let cachedModels: ModelMetadata[] | null = null;
let lastFetchTime = 0;
const CACHE_TTL = 60 * 60 * 1000; // 1 hour

async function fetchFreeModels(): Promise<ModelMetadata[]> {
  const now = Date.now();

  // Return cached if fresh (< 1 hour old)
  if (cachedModels && (now - lastFetchTime) < CACHE_TTL) {
    return cachedModels;
  }

  const response = await fetch('https://openrouter.ai/api/v1/models', {
    headers: {
      'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY || ''}`,
    },
  });

  if (!response.ok) {
    throw new Error(`OpenRouter API error: ${response.statusText}`);
  }

  const data = await response.json() as { data: any[] };

  const freeModels = data.data
    .filter(m => m.pricing.prompt === "0" && m.pricing.completion === "0")
    .map(m => categorizeAndFormat(m));

  // Update cache
  cachedModels = freeModels;
  lastFetchTime = now;

  console.log(`✅ OpenRouter: Loaded ${freeModels.length} FREE models (cached for 1h)`);

  return freeModels;
}

function categorizeModel(id: string, name: string, description: string = '', modality?: string): ModelMetadata['category'] {
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
 * OpenRouter provider instance with metadata
 *
 * Auto-fetches latest FREE models on first use (hourly cache)
 *
 * Usage:
 * ```ts
 * import { openrouter } from './providers/openrouter';
 *
 * const result = await generateText({
 *   model: openrouter('deepseek/deepseek-r1:free'),
 *   messages: [{ role: 'user', content: 'Hello' }]
 * });
 * ```
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
 * Get best model by category (uses live API)
 */
export async function getBestOpenRouterModel(category: 'reasoning' | 'code' | 'general' | 'vision' | 'large-context' | 'fast' = 'general'): Promise<string> {
  const models = await fetchFreeModels();
  const model = models.find(m => m.category === category);

  if (!model) {
    throw new Error(`No OpenRouter models found for category: ${category}`);
  }

  return model.id;
}

/**
 * Get all models by category
 */
export async function getOpenRouterModelsByCategory(category: ModelMetadata['category']): Promise<ModelMetadata[]> {
  const models = await fetchFreeModels();
  return models.filter(m => m.category === category);
}
