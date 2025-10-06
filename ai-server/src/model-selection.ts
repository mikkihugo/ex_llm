/**
 * Model Selection and Optimization
 *
 * Intelligent model selection based on task complexity, context, and cost optimization.
 */

import type { ModelInfo } from './model-registry';

export interface TaskRequirements {
  complexity: 'simple' | 'medium' | 'complex';
  requiresReasoning?: boolean;
  requiresVision?: boolean;
  requiresTools?: boolean;
  maxTokens?: number;
  costPreference?: 'free' | 'limited' | 'performance';
}

export interface ModelScore {
  model: ModelInfo;
  score: number;
  reasoning: string;
}

/**
 * Select optimal model based on task requirements
 */
export function selectOptimalModel(
  availableModels: ModelInfo[],
  requirements: TaskRequirements
): ModelInfo {
  const scores = availableModels.map(model => scoreModel(model, requirements));

  // Sort by score descending
  scores.sort((a, b) => b.score - a.score);

  if (scores.length === 0) {
    throw new Error('No models available matching requirements');
  }

  console.log('[model-selection] Selected:', scores[0].model.id, 'Score:', scores[0].score, 'Reason:', scores[0].reasoning);

  return scores[0].model;
}

/**
 * Score a model based on task requirements
 */
function scoreModel(model: ModelInfo, requirements: TaskRequirements): ModelScore {
  let score = 0;
  const reasons: string[] = [];

  // Complexity scoring
  const complexityScores = {
    simple: { contextWindow: 8000, minScore: 1 },
    medium: { contextWindow: 32000, minScore: 2 },
    complex: { contextWindow: 128000, minScore: 3 },
  };

  const complexityReq = complexityScores[requirements.complexity];

  if (model.contextWindow >= complexityReq.contextWindow) {
    score += complexityReq.minScore;
    reasons.push(`context ${model.contextWindow}K sufficient`);
  }

  // Capability requirements
  if (requirements.requiresReasoning && model.capabilities.reasoning) {
    score += 3;
    reasons.push('has reasoning');
  }

  if (requirements.requiresVision && model.capabilities.vision) {
    score += 2;
    reasons.push('has vision');
  }

  if (requirements.requiresTools && model.capabilities.tools) {
    score += 2;
    reasons.push('has tools');
  }

  // Cost preference
  if (requirements.costPreference) {
    if (requirements.costPreference === 'free' && model.cost === 'free') {
      score += 5;
      reasons.push('free tier');
    } else if (requirements.costPreference === 'limited' && (model.cost === 'free' || model.cost === 'limited')) {
      score += 3;
      reasons.push('limited cost');
    }
  }

  // Streaming bonus
  if (model.capabilities.streaming) {
    score += 1;
    reasons.push('streaming');
  }

  return {
    model,
    score,
    reasoning: reasons.join(', '),
  };
}

/**
 * Select best Codex model for coding tasks
 */
export function selectCodexModelForCoding(
  availableModels: ModelInfo[],
  taskComplexity: 'simple' | 'medium' | 'complex' = 'medium'
): ModelInfo {
  // Filter for Codex models
  const codexModels = availableModels.filter(m =>
    m.provider === 'codex' || m.id.includes('codex')
  );

  if (codexModels.length === 0) {
    throw new Error('No Codex models available');
  }

  return selectOptimalModel(codexModels, {
    complexity: taskComplexity,
    requiresTools: true,
    costPreference: 'free',
  });
}

/**
 * Select model with fallback chain
 */
export function selectWithFallback(
  availableModels: ModelInfo[],
  requirements: TaskRequirements,
  fallbackChain: string[]
): ModelInfo {
  // Try primary selection
  try {
    return selectOptimalModel(availableModels, requirements);
  } catch (_error) {
    // Try fallback chain
    for (const modelId of fallbackChain) {
      const model = availableModels.find(m => m.id === modelId);
      if (model) {
        console.log('[model-selection] Using fallback:', modelId);
        return model;
      }
    }

    throw new Error('No suitable model found, even in fallback chain');
  }
}
