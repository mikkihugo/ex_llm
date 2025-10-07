/**
 * Dynamic OpenRouter Model Selector
 *
 * Automatically selects best FREE OpenRouter model for task type + complexity
 * No hardcoded model IDs - fetches live from API
 */

import { getBestOpenRouterModel, getOpenRouterModelsByCategory } from './providers/openrouter.js';

type TaskType = 'general' | 'architect' | 'coder' | 'qa';
type TaskComplexity = 'simple' | 'medium' | 'complex';

/**
 * Select best OpenRouter model dynamically based on task
 */
export async function selectOpenRouterModel(
  taskType: TaskType,
  complexity: TaskComplexity
): Promise<string | null> {
  try {
    // Map task type + complexity to category
    const category = mapToCategory(taskType, complexity);

    // Get best model for category (live API)
    const modelId = await getBestOpenRouterModel(category);

    console.log(`🔀 OpenRouter: Selected ${modelId} for ${taskType}/${complexity}`);

    return modelId;
  } catch (error) {
    console.warn('OpenRouter model selection failed:', error);
    return null; // Return null to try next provider in matrix
  }
}

/**
 * Map task type + complexity to OpenRouter category
 */
function mapToCategory(
  taskType: TaskType,
  complexity: TaskComplexity
): 'reasoning' | 'code' | 'general' | 'vision' | 'large-context' | 'fast' {
  // Coder tasks → code category
  if (taskType === 'coder') {
    if (complexity === 'simple') return 'fast';
    if (complexity === 'complex') return 'code'; // Qwen3 Coder 480B
    return 'code';
  }

  // Architect tasks → reasoning category
  if (taskType === 'architect') {
    if (complexity === 'simple') return 'general';
    return 'reasoning'; // DeepSeek R1
  }

  // QA tasks → general category
  if (taskType === 'qa') {
    return 'general';
  }

  // General tasks
  if (complexity === 'simple') return 'fast';
  if (complexity === 'complex') return 'reasoning';
  return 'general';
}

/**
 * Get all available models for task (for debugging)
 */
export async function getAvailableModelsForTask(
  taskType: TaskType,
  complexity: TaskComplexity
): Promise<any[]> {
  const category = mapToCategory(taskType, complexity);
  return await getOpenRouterModelsByCategory(category);
}
