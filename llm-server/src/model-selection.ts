/**
 * @file Model Selection and Optimization
 * @description This module provides functions for intelligently selecting the best AI model
 * for a given task based on its complexity, capabilities, and cost.
 */

import type { ModelInfo } from './model-registry';

/**
 * @interface TaskRequirements
 * @description Defines the requirements for a task, used to select an appropriate model.
 */
export interface TaskRequirements {
  complexity: 'simple' | 'medium' | 'complex';
  requiresReasoning?: boolean;
  requiresVision?: boolean;
  requiresTools?: boolean;
  maxTokens?: number;
  costPreference?: 'free' | 'limited' | 'performance';
}

/**
 * @interface ModelScore
 * @description Represents the score of a model for a given task, including the reasoning for the score.
 */
export interface ModelScore {
  model: ModelInfo;
  score: number;
  reasoning: string;
}

/**
 * Selects the optimal model from a list of available models based on task requirements.
 * @param {ModelInfo[]} availableModels - An array of available models.
 * @param {TaskRequirements} requirements - The requirements for the task.
 * @returns {ModelInfo} The best model for the task.
 * @throws {Error} If no suitable models are available.
 */
export function selectOptimalModel(
  availableModels: ModelInfo[],
  requirements: TaskRequirements
): ModelInfo {
  const scores = availableModels.map(model => scoreModel(model, requirements));

  scores.sort((a, b) => b.score - a.score);

  if (scores.length === 0) {
    throw new Error('No models available matching requirements');
  }

  console.log(`[Model Selection] Selected: ${scores[0].model.id}, Score: ${scores[0].score}, Reason: ${scores[0].reasoning}`);

  return scores[0].model;
}

/**
 * Scores a single model based on how well it meets the task requirements.
 * @private
 * @param {ModelInfo} model - The model to score.
 * @param {TaskRequirements} requirements - The requirements for the task.
 * @returns {ModelScore} The model's score and the reasoning behind it.
 */
function scoreModel(model: ModelInfo, requirements: TaskRequirements): ModelScore {
  let score = 0;
  const reasons: string[] = [];

  const complexityScores = {
    simple: { contextWindow: 8000, minScore: 1 },
    medium: { contextWindow: 32000, minScore: 2 },
    complex: { contextWindow: 128000, minScore: 3 },
  };

  const complexityReq = complexityScores[requirements.complexity];

  if (model.contextWindow >= complexityReq.contextWindow) {
    score += complexityReq.minScore;
    reasons.push(`context window of ${model.contextWindow} is sufficient`);
  }

  if (requirements.requiresReasoning && model.capabilities.reasoning) {
    score += 3;
    reasons.push('reasoning capabilities');
  }

  if (requirements.requiresVision && model.capabilities.vision) {
    score += 2;
    reasons.push('vision capabilities');
  }

  if (requirements.requiresTools && model.capabilities.tools) {
    score += 2;
    reasons.push('tool usage capabilities');
  }

  if (requirements.costPreference) {
    if (requirements.costPreference === 'free' && model.cost === 'free') {
      score += 5;
      reasons.push('free tier preferred');
    } else if (requirements.costPreference === 'limited' && (model.cost === 'free' || model.cost === 'limited')) {
      score += 3;
      reasons.push('limited cost tier');
    }
  }

  if (model.capabilities.streaming) {
    score += 1;
    reasons.push('supports streaming');
  }

  return {
    model,
    score,
    reasoning: reasons.join(', '),
  };
}

/**
 * Selects the best Codex model for a coding task.
 * @param {ModelInfo[]} availableModels - An array of available models.
 * @param {'simple' | 'medium' | 'complex'} [taskComplexity='medium'] - The complexity of the coding task.
 * @returns {ModelInfo} The best Codex model for the task.
 * @throws {Error} If no Codex models are available.
 */
export function selectCodexModelForCoding(
  availableModels: ModelInfo[],
  taskComplexity: 'simple' | 'medium' | 'complex' = 'medium'
): ModelInfo {
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
 * Selects a model with a fallback chain in case the optimal model is not available.
 * @param {ModelInfo[]} availableModels - An array of available models.
 * @param {TaskRequirements} requirements - The requirements for the task.
 * @param {string[]} fallbackChain - An array of model IDs to use as fallbacks.
 * @returns {ModelInfo} The selected model.
 * @throws {Error} If no suitable model is found in the primary selection or fallback chain.
 */
export function selectWithFallback(
  availableModels: ModelInfo[],
  requirements: TaskRequirements,
  fallbackChain: string[]
): ModelInfo {
  try {
    return selectOptimalModel(availableModels, requirements);
  } catch (_error) {
    for (const modelId of fallbackChain) {
      const model = availableModels.find(m => m.id === modelId);
      if (model) {
        console.log(`[Model Selection] Using fallback model: ${modelId}`);
        return model;
      }
    }

    throw new Error('No suitable model found, even in fallback chain');
  }
}
