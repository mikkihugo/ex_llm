/**
 * @file OpenRouter Capability Enhancer
 * @description This module enhances the heuristic-based model capability scores with
 * real-world data from the OpenRouter API. It fetches pricing, context length, and other
 * metadata to provide more accurate and data-driven scores.
 */

/**
 * @interface OpenRouterModel
 * @description Defines the structure of a model object as returned by the OpenRouter API.
 */
export interface OpenRouterModel {
  id: string;
  name: string;
  description: string;
  context_length: number;
  pricing: {
    prompt: string;
    completion: string;
  };
  top_provider?: {
    max_completion_tokens?: number;
  };
}

/**
 * @interface EnhancedCapabilityScore
 * @description Defines the structure of a capability score that has been enhanced
 * with data from external sources like OpenRouter.
 */
export interface EnhancedCapabilityScore {
  code: number;
  reasoning: number;
  creativity: number;
  speed: number;
  cost: number;
  confidence: 'high' | 'medium' | 'low';
  reasoning_text: string;
  data_sources: string[];
}

/**
 * Fetches all model data from the OpenRouter API.
 * @returns {Promise<OpenRouterModel[]>} A promise that resolves to an array of OpenRouter models.
 */
export async function fetchOpenRouterModels(): Promise<OpenRouterModel[]> {
  try {
    const response = await fetch('https://openrouter.ai/api/v1/models');
    if (!response.ok) {
      throw new Error(`[OpenRouterEnhancer] API error: ${response.statusText}`);
    }
    const data = await response.json() as { data?: OpenRouterModel[] };
    return data.data || [];
  } catch (error) {
    console.error('[OpenRouterEnhancer] Failed to fetch OpenRouter models:', error);
    return [];
  }
}

/**
 * Converts OpenRouter pricing information to a cost score on a scale of 1-10.
 * @private
 * @param {object} pricing The pricing object from the OpenRouter API.
 * @returns {number} A cost score from 1 (most expensive) to 10 (free).
 */
function pricingToCostScore(pricing: { prompt: string; completion: string }): number {
  const promptCost = parseFloat(pricing.prompt);
  const completionCost = parseFloat(pricing.completion);
  const avgCost = (promptCost + completionCost) / 2;

  if (avgCost === 0) return 10;
  if (avgCost < 0.000001) return 10;
  if (avgCost < 0.00001) return 9;
  if (avgCost < 0.0001) return 8;
  if (avgCost < 0.001) return 7;
  if (avgCost < 0.01) return 5;
  if (avgCost < 0.1) return 3;
  return 1;
}

/**
 * Infers a code capability score based on the model's name and description.
 * @private
 * @param {OpenRouterModel} model The model to score.
 * @param {number} baseScore The base score to enhance.
 * @returns {number} The inferred code score.
 */
function inferCodeScore(model: OpenRouterModel, baseScore: number): number {
  const desc = model.description.toLowerCase();
  const name = model.name.toLowerCase();
  if (desc.includes('code') || name.includes('codex') || name.includes('codestral')) {
    return Math.min(10, baseScore + 2);
  }
  return baseScore;
}

/**
 * Infers a reasoning capability score based on the model's name and description.
 * @private
 * @param {OpenRouterModel} model The model to score.
 * @param {number} baseScore The base score to enhance.
 * @returns {number} The inferred reasoning score.
 */
function inferReasoningScore(model: OpenRouterModel, baseScore: number): number {
  const desc = model.description.toLowerCase();
  const name = model.name.toLowerCase();
  if (desc.includes('reasoning') || name.includes('o1') || name.includes('o3') || name.includes('deepseek-r')) {
    return Math.min(10, baseScore + 2);
  }
  if (desc.includes('step-by-step') || desc.includes('chain of thought')) {
    return Math.min(10, baseScore + 1);
  }
  return baseScore;
}

/**
 * Infers a speed score based on the model's name.
 * @private
 * @param {OpenRouterModel} model The model to score.
 * @returns {number} The inferred speed score.
 */
function inferSpeedScore(model: OpenRouterModel): number {
  const name = model.name.toLowerCase();
  if (name.includes('flash') || name.includes('fast') || name.includes('mini') || name.includes('nano')) return 10;
  if (name.includes('haiku') || name.includes('small')) return 9;
  if (name.includes('405b') || name.includes('70b') || name.includes('large')) return 5;
  return 7;
}

/**
 * Enhances a model's base capability score with data from the OpenRouter API.
 * @param {string} modelId The ID of the model to enhance.
 * @param {EnhancedCapabilityScore} baseScore The base heuristic score.
 * @param {OpenRouterModel[]} openrouterModels An array of models from the OpenRouter API.
 * @returns {EnhancedCapabilityScore} The enhanced capability score.
 */
export function enhanceWithOpenRouter(
  modelId: string,
  baseScore: EnhancedCapabilityScore,
  openrouterModels: OpenRouterModel[]
): EnhancedCapabilityScore {
  const orModel = openrouterModels.find(m => m.id.toLowerCase().includes(modelId.toLowerCase()) || modelId.toLowerCase().includes(m.id.toLowerCase()));

  if (!orModel) {
    return { ...baseScore, data_sources: baseScore.data_sources || ['heuristics'] };
  }

  const costScore = pricingToCostScore(orModel.pricing);
  const codeScore = inferCodeScore(orModel, baseScore.code);
  const reasoningScore = inferReasoningScore(orModel, baseScore.reasoning);
  const speedScore = inferSpeedScore(orModel);

  return {
    ...baseScore,
    code: codeScore,
    reasoning: reasoningScore,
    speed: speedScore,
    cost: costScore,
    confidence: 'high',
    reasoning_text: `OpenRouter data: $${parseFloat(orModel.pricing.prompt).toFixed(6)}/1M tokens, ${orModel.context_length.toLocaleString()} context. ${baseScore.reasoning_text}`,
    data_sources: ['openrouter', 'heuristics'],
  };
}

/**
 * Fetches data from OpenRouter and enhances a map of base scores.
 * @param {Record<string, any>} baseScores A map of model IDs to their base scores.
 * @returns {Promise<Record<string, EnhancedCapabilityScore>>} A promise that resolves to the map of enhanced scores.
 */
export async function enhanceAllModelsWithOpenRouter(
  baseScores: Record<string, any>
): Promise<Record<string, EnhancedCapabilityScore>> {
  console.log('[OpenRouterEnhancer] Fetching real data from OpenRouter API...');
  const openrouterModels = await fetchOpenRouterModels();
  console.log(`[OpenRouterEnhancer] Found ${openrouterModels.length} models on OpenRouter.`);

  const enhanced: Record<string, EnhancedCapabilityScore> = {};
  for (const [modelId, baseScore] of Object.entries(baseScores)) {
    enhanced[modelId] = enhanceWithOpenRouter(modelId, baseScore as any, openrouterModels);
  }

  const enhancedCount = Object.values(enhanced).filter(s => s.data_sources.includes('openrouter')).length;
  console.log(`[OpenRouterEnhancer] Enhanced ${enhancedCount}/${Object.keys(enhanced).length} models with OpenRouter data.`);

  return enhanced;
}