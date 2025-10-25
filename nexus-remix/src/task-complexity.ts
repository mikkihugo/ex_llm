/**
 * @file Task Complexity Analyzer
 * @description This module provides functions to analyze the complexity of a given task
 * and select an appropriate AI model based on a predefined configuration. It helps in
 * choosing the most cost-effective and capable model for a specific job.
 */

/**
 * @typedef {'simple' | 'medium' | 'complex'} TaskComplexity
 * @description Represents the estimated complexity of a task.
 */
export type TaskComplexity = 'simple' | 'medium' | 'complex';

/**
 * @interface TaskAnalysis
 * @description Defines the result of a task complexity analysis, including the
 * estimated complexity, the reasoning behind the estimation, and a suggested model.
 */
export interface TaskAnalysis {
  complexity: TaskComplexity;
  reasoning: string;
  suggestedModel: string;
  estimatedTokens: number;
  estimatedCost: number;
}

/**
 * @interface ModelConfig
 * @description Defines the configuration for a specific AI model.
 */
export interface ModelConfig {
  provider: string;
  model: string;
  costPerMillion: number;
  maxTokens: number;
  temperature: number;
}

/**
 * @const {Record<TaskComplexity, ModelConfig[]>} MODEL_CONFIGS
 * @description A map of task complexities to a list of suitable model configurations.
 * @private
 */
const MODEL_CONFIGS: Record<TaskComplexity, ModelConfig[]> = {
  simple: [
    { provider: 'gemini-code', model: 'gemini-2.5-flash', costPerMillion: 0.075, maxTokens: 2000, temperature: 0.3 },
    { provider: 'github-models', model: 'gpt-4o-mini', costPerMillion: 0.15, maxTokens: 2000, temperature: 0.3 },
    { provider: 'cursor-agent-cli', model: 'cursor-auto', costPerMillion: 0, maxTokens: 2000, temperature: 0.3 },
  ],
  medium: [
    { provider: 'codex-cli', model: 'gpt-5-codex', costPerMillion: 30, maxTokens: 256000, temperature: 0.5 },
    { provider: 'codex-cli', model: 'o1', costPerMillion: 15, maxTokens: 128000, temperature: 0.5 },
    { provider: 'copilot-api', model: 'copilot-gpt-4.1', costPerMillion: 5, maxTokens: 128000, temperature: 0.5 },
    { provider: 'cursor-agent-cli', model: 'cursor-gpt-4.1', costPerMillion: 0, maxTokens: 128000, temperature: 0.5 },
    { provider: 'github-models', model: 'gpt-4o', costPerMillion: 2.5, maxTokens: 128000, temperature: 0.5 },
    { provider: 'gemini-code', model: 'gemini-2.5-pro', costPerMillion: 1.25, maxTokens: 2097152, temperature: 0.5 },
    { provider: 'copilot-api', model: 'grok-coder-1', costPerMillion: 2, maxTokens: 128000, temperature: 0.5 },
  ],
  complex: [
    { provider: 'codex-cli', model: 'gpt-5-codex', costPerMillion: 30, maxTokens: 256000, temperature: 0.7 },
    { provider: 'codex-cli', model: 'o3', costPerMillion: 60, maxTokens: 128000, temperature: 0.7 },
    { provider: 'claude-code-cli', model: 'claude-opus-4.1', costPerMillion: 15, maxTokens: 200000, temperature: 0.7 },
    { provider: 'claude-code-cli', model: 'claude-sonnet-4.5', costPerMillion: 3, maxTokens: 200000, temperature: 0.7 },
  ],
};

/**
 * Analyzes the complexity of a task based on its description and other contextual factors.
 * @param {string} task The task description.
 * @param {object} [options] Additional context for the analysis.
 * @returns {TaskAnalysis} The result of the complexity analysis.
 */
export function analyzeTaskComplexity(task: string, options?: {
  requiresReasoning?: boolean;
  requiresCode?: boolean;
  requiresCreativity?: boolean;
  contextLength?: number;
}): TaskAnalysis {
  let complexity: TaskComplexity = 'simple';
  let score = 0;
  const reasons: string[] = [];

  const wordCount = task.split(/\s+/).length;
  if (wordCount > 500) {
    score += 3;
    reasons.push('long task description');
  } else if (wordCount > 200) {
    score += 2;
    reasons.push('moderate task length');
  }

  const complexKeywords = ['architecture', 'design', 'refactor', 'optimize', 'analyze', 'implement', 'integrate', 'migrate', 'scale', 'distributed', 'security', 'performance', 'algorithm', 'framework'];
  const mediumKeywords = ['create', 'build', 'develop', 'test', 'debug', 'fix', 'update', 'modify', 'extend', 'api', 'database', 'service'];
  const simpleKeywords = ['write', 'add', 'change', 'rename', 'format', 'comment', 'document', 'list', 'show', 'get', 'find', 'check'];
  const taskLower = task.toLowerCase();

  if (complexKeywords.some(kw => taskLower.includes(kw))) {
    score += 3;
    reasons.push('complex operation keywords');
  }
  if (mediumKeywords.some(kw => taskLower.includes(kw))) {
    score += 2;
    reasons.push('medium complexity keywords');
  }
  if (simpleKeywords.some(kw => taskLower.includes(kw))) {
    score += 1;
    reasons.push('simple operation keywords');
  }

  if (options?.requiresCode || taskLower.includes('code') || taskLower.includes('function') || taskLower.includes('implement') || taskLower.includes('write') || taskLower.includes('create')) {
    score += 4;
    reasons.push('code generation required');
  }
  if (options?.requiresReasoning || taskLower.includes('explain') || taskLower.includes('why')) {
    score += 2;
    reasons.push('reasoning required');
  }
  if (options?.requiresCreativity || taskLower.includes('design') || taskLower.includes('creative')) {
    score += 3;
    reasons.push('creative thinking required');
  }
  if (options?.contextLength) {
    if (options.contextLength > 10000) {
      score += 3;
      reasons.push('large context window needed');
    } else if (options.contextLength > 4000) {
      score += 2;
      reasons.push('moderate context required');
    }
  }
  if (taskLower.includes('sparc') || taskLower.includes('specification') || taskLower.includes('pseudocode')) {
    score += 2;
    reasons.push('SPARC methodology');
  }

  if (score >= 8) {
    complexity = 'complex';
  } else if (score >= 4) {
    complexity = 'medium';
  } else {
    complexity = 'simple';
  }

  const models = MODEL_CONFIGS[complexity];
  const selectedModel = models[0];

  const estimatedTokens = Math.max(wordCount * 1.3, complexity === 'simple' ? 500 : complexity === 'medium' ? 1500 : 3000);
  const estimatedCost = (estimatedTokens / 1_000_000) * selectedModel.costPerMillion;

  return {
    complexity,
    reasoning: reasons.join(', '),
    suggestedModel: `${selectedModel.provider}:${selectedModel.model}`,
    estimatedTokens: Math.round(estimatedTokens),
    estimatedCost: Math.round(estimatedCost * 10000) / 10000,
  };
}

/**
 * Selects the optimal model for a given task based on available providers and other options.
 * @param {string} task The task description.
 * @param {Set<string>} availableProviders A set of available provider names.
 * @param {object} [options] Additional options for model selection.
 * @returns {ModelConfig} The configuration of the selected model.
 */
export function selectOptimalModel(
  task: string,
  availableProviders: Set<string>,
  options?: {
    preferredProvider?: string;
    maxCost?: number;
    requiresSpeed?: boolean;
  }
): ModelConfig {
  const analysis = analyzeTaskComplexity(task);
  const models = MODEL_CONFIGS[analysis.complexity];
  let availableModels = models.filter(m => availableProviders.has(m.provider));

  if (options?.preferredProvider) {
    const preferred = availableModels.filter(m => m.provider === options.preferredProvider);
    if (preferred.length > 0) {
      availableModels = preferred;
    }
  }
  if (options?.maxCost) {
    availableModels = availableModels.filter(m => m.costPerMillion <= (options.maxCost || 0) * 1_000_000);
  }
  if (options?.requiresSpeed) {
    availableModels.sort((a, b) => {
      if (a.model.includes('flash')) return -1;
      if (b.model.includes('flash')) return 1;
      if (a.model.includes('haiku')) return -1;
      if (b.model.includes('haiku')) return 1;
      return 0;
    });
  }
  return availableModels[0] || models[0];
}

/**
 * Gets a model recommendation for a task, including an explanation.
 * @param {string} task The task description.
 * @returns {{ model: ModelConfig; analysis: TaskAnalysis; explanation: string; }} The recommendation.
 */
export function getModelRecommendation(task: string): {
  model: ModelConfig;
  analysis: TaskAnalysis;
  explanation: string;
} {
  const analysis = analyzeTaskComplexity(task);
  const models = MODEL_CONFIGS[analysis.complexity];
  const model = models[0];
  const explanation = `Based on task complexity (${analysis.complexity}), I recommend ${model.model} because: ${analysis.reasoning}. Estimated cost: $${analysis.estimatedCost.toFixed(4)} for ~${analysis.estimatedTokens} tokens.`;
  return { model, analysis, explanation };
}

/**
 * Selects the best Codex model for a coding task, prioritizing models with full context.
 * @param {string} task The coding task description.
 * @returns {ModelConfig} The configuration of the selected Codex model.
 */
export function selectCodexModelForCoding(task: string): ModelConfig {
  const taskLower = task.toLowerCase();
  const analysis = analyzeTaskComplexity(task);

  const codexModels = [
    { provider: 'google-jules', model: 'google-jules', costPerMillion: 25, maxTokens: 256000, temperature: 0.2 },
    { provider: 'codex-cli', model: 'gpt-5-codex', costPerMillion: 30, maxTokens: 256000, temperature: 0.2 },
    { provider: 'codex-cli', model: 'o3', costPerMillion: 60, maxTokens: 128000, temperature: 0.2 },
    { provider: 'codex-cli', model: 'o1', costPerMillion: 15, maxTokens: 128000, temperature: 0.2 },
    { provider: 'copilot-api', model: 'copilot-gpt-4.1', costPerMillion: 5, maxTokens: 128000, temperature: 0.2 },
  ];

  const codingKeywords = ['code', 'implement', 'function', 'class', 'api', 'algorithm', 'refactor', 'debug', 'optimize'];
  const isCodingTask = codingKeywords.some(kw => taskLower.includes(kw));

  if (isCodingTask) {
    if (analysis.complexity === 'simple') {
      return codexModels[2];
    } else if (analysis.complexity === 'medium') {
      return codexModels[0];
    } else {
      if (taskLower.includes('algorithm') || taskLower.includes('optimize') || taskLower.includes('architecture')) {
        return codexModels[1];
      }
      return codexModels[0];
    }
  }
  return MODEL_CONFIGS[analysis.complexity][0];
}