/**
 * Enhances capability scores with real data from OpenRouter API
 *
 * Combines:
 * - OpenRouter: Real pricing, speed benchmarks, context length
 * - models.dev: Model comparisons (future)
 * - Heuristics: Fill gaps for models not in external sources
 */

export interface OpenRouterModel {
  id: string;
  name: string;
  description: string;
  context_length: number;
  pricing: {
    prompt: string;    // Cost per 1M tokens
    completion: string;
  };
  top_provider?: {
    max_completion_tokens?: number;
  };
}

export interface EnhancedCapabilityScore {
  code: number;
  reasoning: number;
  creativity: number;
  speed: number;
  cost: number;
  confidence: 'high' | 'medium' | 'low';
  reasoning_text: string;
  data_sources: string[];  // Where the data came from
}

/**
 * Fetch all models from OpenRouter API
 */
export async function fetchOpenRouterModels(): Promise<OpenRouterModel[]> {
  try {
    const response = await fetch('https://openrouter.ai/api/v1/models');
    const data = await response.json();
    return data.data || [];
  } catch (error) {
    console.error('Failed to fetch OpenRouter models:', error);
    return [];
  }
}

/**
 * Convert OpenRouter pricing to cost score (1-10)
 */
function pricingToCostScore(pricing: { prompt: string; completion: string }): number {
  const promptCost = parseFloat(pricing.prompt);
  const completionCost = parseFloat(pricing.completion);
  const avgCost = (promptCost + completionCost) / 2;

  // Score based on cost per 1M tokens
  if (avgCost === 0) return 10;           // FREE
  if (avgCost < 0.000001) return 10;      // Essentially free (<$0.001 per 1M)
  if (avgCost < 0.00001) return 9;        // Very cheap
  if (avgCost < 0.0001) return 8;         // Cheap
  if (avgCost < 0.001) return 7;          // Moderate
  if (avgCost < 0.01) return 5;           // Expensive
  if (avgCost < 0.1) return 3;            // Very expensive
  return 1;                                // Extremely expensive
}

/**
 * Infer code capability from model description
 */
function inferCodeScore(model: OpenRouterModel, baseScore: number): number {
  const desc = model.description.toLowerCase();
  const name = model.name.toLowerCase();

  // Strong code indicators
  if (desc.includes('code') || desc.includes('coding') || desc.includes('programming')) {
    return Math.min(10, baseScore + 2);
  }
  if (name.includes('codex') || name.includes('code') || name.includes('codestral')) {
    return Math.min(10, baseScore + 2);
  }

  return baseScore;
}

/**
 * Infer reasoning capability from model description
 */
function inferReasoningScore(model: OpenRouterModel, baseScore: number): number {
  const desc = model.description.toLowerCase();
  const name = model.name.toLowerCase();

  // Strong reasoning indicators
  if (desc.includes('reasoning') || desc.includes('complex tasks')) {
    return Math.min(10, baseScore + 2);
  }
  if (name.includes('o1') || name.includes('o3') || name.includes('deepseek-r')) {
    return Math.min(10, baseScore + 2);
  }
  if (desc.includes('step-by-step') || desc.includes('chain of thought')) {
    return Math.min(10, baseScore + 1);
  }

  return baseScore;
}

/**
 * Infer speed from context window and model size
 */
function inferSpeedScore(model: OpenRouterModel): number {
  const name = model.name.toLowerCase();

  // Fast model indicators
  if (name.includes('flash') || name.includes('fast') || name.includes('mini') || name.includes('nano')) {
    return 10;
  }
  if (name.includes('haiku') || name.includes('small')) {
    return 9;
  }

  // Large models tend to be slower
  if (name.includes('405b') || name.includes('70b') || name.includes('large')) {
    return 5;
  }

  // Medium by default
  return 7;
}

/**
 * Enhance capability score with OpenRouter data
 */
export function enhanceWithOpenRouter(
  modelId: string,
  baseScore: EnhancedCapabilityScore,
  openrouterModels: OpenRouterModel[]
): EnhancedCapabilityScore {
  // Try to find matching OpenRouter model
  const orModel = openrouterModels.find(m =>
    m.id.toLowerCase().includes(modelId.toLowerCase()) ||
    modelId.toLowerCase().includes(m.id.toLowerCase())
  );

  if (!orModel) {
    // No OpenRouter data, use base score
    return {
      ...baseScore,
      data_sources: baseScore.data_sources || ['heuristics']
    };
  }

  // Enhance with OpenRouter data
  const costScore = pricingToCostScore(orModel.pricing);
  const codeScore = inferCodeScore(orModel, baseScore.code);
  const reasoningScore = inferReasoningScore(orModel, baseScore.reasoning);
  const speedScore = inferSpeedScore(orModel);

  return {
    code: codeScore,
    reasoning: reasoningScore,
    creativity: baseScore.creativity,  // Keep heuristic for now
    speed: speedScore,
    cost: costScore,
    confidence: 'high',  // Higher confidence with real data
    reasoning_text: `OpenRouter data: $${parseFloat(orModel.pricing.prompt).toFixed(6)}/1M tokens prompt, ${orModel.context_length.toLocaleString()} context. ${baseScore.reasoning_text}`,
    data_sources: ['openrouter', 'heuristics']
  };
}

/**
 * Bulk enhance all models with OpenRouter data
 */
export async function enhanceAllModelsWithOpenRouter(
  baseScores: Record<string, any>
): Promise<Record<string, EnhancedCapabilityScore>> {
  console.log('📊 Fetching real data from OpenRouter API...\n');

  const openrouterModels = await fetchOpenRouterModels();
  console.log(`✅ Found ${openrouterModels.length} models on OpenRouter\n`);

  const enhanced: Record<string, EnhancedCapabilityScore> = {};

  for (const [modelId, baseScore] of Object.entries(baseScores)) {
    enhanced[modelId] = enhanceWithOpenRouter(modelId, baseScore as any, openrouterModels);
  }

  const enhancedCount = Object.values(enhanced).filter(s => s.data_sources.includes('openrouter')).length;
  console.log(`✨ Enhanced ${enhancedCount}/${Object.keys(enhanced).length} models with OpenRouter data\n`);

  return enhanced;
}
