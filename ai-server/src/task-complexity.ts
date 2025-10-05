/**
 * Task Complexity Analyzer for Model Selection
 *
 * Analyzes task complexity to choose optimal model:
 * - Simple → Fast/cheap models (Gemini Flash, Claude Haiku)
 * - Medium → Balanced models (Claude Sonnet, GPT-4)
 * - Complex → Powerful models (Claude Opus, GPT-4 Turbo)
 */

export type TaskComplexity = 'simple' | 'medium' | 'complex';

export interface TaskAnalysis {
  complexity: TaskComplexity;
  reasoning: string;
  suggestedModel: string;
  estimatedTokens: number;
  estimatedCost: number;
}

export interface ModelConfig {
  provider: string;
  model: string;
  costPerMillion: number;
  maxTokens: number;
  temperature: number;
}

// Model configurations by complexity (using actual available models from server.ts)
const MODEL_CONFIGS: Record<TaskComplexity, ModelConfig[]> = {
  simple: [
    { provider: 'gemini-code', model: 'gemini-2.5-flash', costPerMillion: 0.075, maxTokens: 2000, temperature: 0.3 },
    { provider: 'github-models', model: 'gpt-4o-mini', costPerMillion: 0.15, maxTokens: 2000, temperature: 0.3 },
    { provider: 'cursor-agent-cli', model: 'cursor-auto', costPerMillion: 0, maxTokens: 2000, temperature: 0.3 }, // Free with subscription
  ],
  medium: [
    { provider: 'codex-cli', model: 'gpt-5-codex', costPerMillion: 30, maxTokens: 256000, temperature: 0.5 }, // GPT-5 256K CONTEXT PRIORITY
    { provider: 'codex-cli', model: 'o1', costPerMillion: 15, maxTokens: 128000, temperature: 0.5 }, // o1 128K CONTEXT
    { provider: 'copilot-api', model: 'copilot-gpt-4.1', costPerMillion: 5, maxTokens: 128000, temperature: 0.5 }, // GPT-4.1
    { provider: 'cursor-agent-cli', model: 'cursor-gpt-4.1', costPerMillion: 0, maxTokens: 128000, temperature: 0.5 }, // GPT-4.1 free
    { provider: 'github-models', model: 'gpt-4o', costPerMillion: 2.5, maxTokens: 128000, temperature: 0.5 }, // GPT-4o
    { provider: 'gemini-code', model: 'gemini-2.5-pro', costPerMillion: 1.25, maxTokens: 2097152, temperature: 0.5 }, // 2M CONTEXT!
    { provider: 'copilot-api', model: 'grok-coder-1', costPerMillion: 2, maxTokens: 128000, temperature: 0.5 },
  ],
  complex: [
    { provider: 'codex-cli', model: 'gpt-5-codex', costPerMillion: 30, maxTokens: 256000, temperature: 0.7 }, // GPT-5 256K CONTEXT PRIORITY
    { provider: 'codex-cli', model: 'o3', costPerMillion: 60, maxTokens: 128000, temperature: 0.7 }, // o3 128K CONTEXT - deep reasoning
    { provider: 'claude-code-cli', model: 'claude-opus-4.1', costPerMillion: 15, maxTokens: 200000, temperature: 0.7 }, // 200K context
    { provider: 'claude-code-cli', model: 'claude-sonnet-4.5', costPerMillion: 3, maxTokens: 200000, temperature: 0.7 }, // 200K context
  ],
};

/**
 * Analyze task complexity based on various factors
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

  // Length-based analysis
  const wordCount = task.split(/\s+/).length;
  if (wordCount > 500) {
    score += 3;
    reasons.push('long task description');
  } else if (wordCount > 200) {
    score += 2;
    reasons.push('moderate task length');
  }

  // Keyword-based complexity detection
  const complexKeywords = [
    'architecture', 'design', 'refactor', 'optimize', 'analyze',
    'implement', 'integrate', 'migrate', 'scale', 'distributed',
    'security', 'performance', 'algorithm', 'framework'
  ];

  const mediumKeywords = [
    'create', 'build', 'develop', 'test', 'debug', 'fix',
    'update', 'modify', 'extend', 'api', 'database', 'service'
  ];

  const simpleKeywords = [
    'write', 'add', 'change', 'rename', 'format', 'comment',
    'document', 'list', 'show', 'get', 'find', 'check'
  ];

  const taskLower = task.toLowerCase();

  // Check for complex patterns
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

  // Check for code-related tasks - BOOST score for Codex model selection
  if (options?.requiresCode || taskLower.includes('code') || taskLower.includes('function') ||
      taskLower.includes('implement') || taskLower.includes('write') || taskLower.includes('create')) {
    score += 4; // Increased from 2 to prioritize Codex models
    reasons.push('code generation required - prefer Codex');
  }

  // Check for reasoning requirements
  if (options?.requiresReasoning || taskLower.includes('explain') || taskLower.includes('why')) {
    score += 2;
    reasons.push('reasoning required');
  }

  // Check for creativity
  if (options?.requiresCreativity || taskLower.includes('design') || taskLower.includes('creative')) {
    score += 3;
    reasons.push('creative thinking required');
  }

  // Context length factor
  if (options?.contextLength) {
    if (options.contextLength > 10000) {
      score += 3;
      reasons.push('large context window needed');
    } else if (options.contextLength > 4000) {
      score += 2;
      reasons.push('moderate context required');
    }
  }

  // SPARC methodology tasks
  if (taskLower.includes('sparc') || taskLower.includes('specification') || taskLower.includes('pseudocode')) {
    score += 2;
    reasons.push('SPARC methodology');
  }

  // Determine final complexity
  if (score >= 8) {
    complexity = 'complex';
  } else if (score >= 4) {
    complexity = 'medium';
  } else {
    complexity = 'simple';
  }

  // Select best model for complexity
  const models = MODEL_CONFIGS[complexity];
  const selectedModel = models[0]; // Pick first as default

  // Estimate tokens (rough approximation)
  const estimatedTokens = Math.max(
    wordCount * 1.3, // Input tokens estimate
    complexity === 'simple' ? 500 : complexity === 'medium' ? 1500 : 3000 // Output estimate
  );

  const estimatedCost = (estimatedTokens / 1_000_000) * selectedModel.costPerMillion;

  return {
    complexity,
    reasoning: reasons.join(', '),
    suggestedModel: `${selectedModel.provider}:${selectedModel.model}`,
    estimatedTokens: Math.round(estimatedTokens),
    estimatedCost: Math.round(estimatedCost * 10000) / 10000 // 4 decimal places
  };
}

/**
 * Select optimal model based on task analysis and available providers
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

  // Filter by available providers
  let availableModels = models.filter(m => availableProviders.has(m.provider));

  // Apply preferences
  if (options?.preferredProvider) {
    const preferred = availableModels.filter(m => m.provider === options.preferredProvider);
    if (preferred.length > 0) {
      availableModels = preferred;
    }
  }

  // Filter by max cost
  if (options?.maxCost) {
    availableModels = availableModels.filter(m => m.costPerMillion <= options.maxCost * 1_000_000);
  }

  // Sort by speed if required (Gemini Flash is fastest)
  if (options?.requiresSpeed) {
    availableModels.sort((a, b) => {
      if (a.model.includes('flash')) return -1;
      if (b.model.includes('flash')) return 1;
      if (a.model.includes('haiku')) return -1;
      if (b.model.includes('haiku')) return 1;
      return 0;
    });
  }

  // Return best available or fallback
  return availableModels[0] || models[0];
}

/**
 * Get model recommendation with explanation
 */
export function getModelRecommendation(task: string): {
  model: ModelConfig;
  analysis: TaskAnalysis;
  explanation: string;
} {
  const analysis = analyzeTaskComplexity(task);
  const models = MODEL_CONFIGS[analysis.complexity];
  const model = models[0];

  const explanation = `Based on task complexity (${analysis.complexity}), I recommend ${model.model} because: ${analysis.reasoning}. ` +
    `Estimated cost: $${analysis.estimatedCost.toFixed(4)} for ~${analysis.estimatedTokens} tokens.`;

  return {
    model,
    analysis,
    explanation
  };
}

/**
 * Select best Codex model for coding tasks
 * Prioritizes Codex models (GPT-5, o3, o1) for code generation
 */
export function selectCodexModelForCoding(task: string): ModelConfig {
  const taskLower = task.toLowerCase();
  const analysis = analyzeTaskComplexity(task);

  // Coding models in order of preference (Jules for autonomous tasks!)
  const codexModels = [
    { provider: 'google-jules', model: 'google-jules', costPerMillion: 25, maxTokens: 256000, temperature: 0.2 }, // JULES AUTONOMOUS!
    { provider: 'codex-cli', model: 'gpt-5-codex', costPerMillion: 30, maxTokens: 256000, temperature: 0.2 }, // GPT-5 256K CONTEXT!
    { provider: 'codex-cli', model: 'o3', costPerMillion: 60, maxTokens: 128000, temperature: 0.2 }, // o3 128K CONTEXT
    { provider: 'codex-cli', model: 'o1', costPerMillion: 15, maxTokens: 128000, temperature: 0.2 }, // o1 128K CONTEXT
    { provider: 'copilot-api', model: 'copilot-gpt-4.1', costPerMillion: 5, maxTokens: 128000, temperature: 0.2 }, // GPT-4.1 128K
  ];

  // Check if this is definitely a coding task
  const codingKeywords = ['code', 'implement', 'function', 'class', 'api', 'algorithm', 'refactor', 'debug', 'optimize'];
  const isCodingTask = codingKeywords.some(kw => taskLower.includes(kw));

  if (isCodingTask) {
    // Codex CLI models have FULL context - prioritize them!
    if (analysis.complexity === 'simple') {
      return codexModels[2]; // o1 - fast, full context, $15/M
    }
    // For medium coding tasks, use GPT-5-codex
    else if (analysis.complexity === 'medium') {
      return codexModels[0]; // gpt-5-codex - FULL CONTEXT, $30/M
    }
    // For complex coding tasks, use o3 for deep reasoning
    else {
      // Use o3 for maximum reasoning with full context
      if (taskLower.includes('algorithm') || taskLower.includes('optimize') || taskLower.includes('architecture')) {
        return codexModels[1]; // o3 - deepest reasoning, FULL CONTEXT, $60/M
      }
      return codexModels[0]; // gpt-5-codex - best overall for complex code
    }
  }

  // Fallback to standard selection
  return MODEL_CONFIGS[analysis.complexity][0];
}