/**
 * @file Dynamic OpenRouter Model Selector
 * @description This module automatically selects the best free OpenRouter model for a given
 * task type and complexity by fetching live data from the OpenRouter API.
 */

import { getBestOpenRouterModel, getOpenRouterModelsByCategory } from './providers/openrouter.js';

/**
 * @typedef {'general' | 'architect' | 'coder' | 'qa'} TaskType
 * @description The type of task to be performed.
 */
type TaskType = 'general' | 'architect' | 'coder' | 'qa';

/**
 * @typedef {'simple' | 'medium' | 'complex'} TaskComplexity
 * @description The complexity of the task.
 */
type TaskComplexity = 'simple' | 'medium' | 'complex';

/**
 * Selects the best OpenRouter model dynamically based on the task type and complexity.
 * @param {TaskType} taskType The type of the task.
 * @param {TaskComplexity} complexity The complexity of the task.
 * @returns {Promise<string | null>} A promise that resolves to the ID of the best model, or null if an error occurs.
 */
export async function selectOpenRouterModel(
  taskType: TaskType,
  complexity: TaskComplexity
): Promise<string | null> {
  try {
    const category = mapToCategory(taskType, complexity);
    const modelId = await getBestOpenRouterModel(category);
    console.log(`[OpenRouter] Selected model "${modelId}" for task type "${taskType}" with complexity "${complexity}".`);
    return modelId;
  } catch (error) {
    console.warn('[OpenRouter] Model selection failed:', error);
    return null;
  }
}

/**
 * Maps a task type and complexity to an OpenRouter model category.
 * @private
 * @param {TaskType} taskType The type of the task.
 * @param {TaskComplexity} complexity The complexity of the task.
 * @returns {'reasoning' | 'code' | 'general' | 'vision' | 'large-context' | 'fast'} The corresponding OpenRouter category.
 */
function mapToCategory(
  taskType: TaskType,
  complexity: TaskComplexity
): 'reasoning' | 'code' | 'general' | 'vision' | 'large-context' | 'fast' {
  if (taskType === 'coder') {
    if (complexity === 'simple') return 'fast';
    return 'code';
  }

  if (taskType === 'architect') {
    if (complexity === 'simple') return 'general';
    return 'reasoning';
  }

  if (taskType === 'qa') {
    return 'general';
  }

  if (complexity === 'simple') return 'fast';
  if (complexity === 'complex') return 'reasoning';
  return 'general';
}

/**
 * Retrieves all available models for a given task type and complexity (for debugging purposes).
 * @param {TaskType} taskType The type of the task.
 * @param {TaskComplexity} complexity The complexity of the task.
 * @returns {Promise<any[]>} A promise that resolves to an array of available models.
 */
export async function getAvailableModelsForTask(
  taskType: TaskType,
  complexity: TaskComplexity
): Promise<any[]> {
  const category = mapToCategory(taskType, complexity);
  return await getOpenRouterModelsByCategory(category);
}
