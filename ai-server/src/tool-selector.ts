/**
 * @file Dynamic Tool Selection
 * @description Intelligently select which tools to provide based on:
 * - Model capacity (context window / tool_capacity score)
 * - Task requirements (what tools does the task need?)
 * - Tool priority (most important tools first)
 */

import type { ModelInfo } from './model-registry';

/**
 * Tool metadata for selection
 */
export interface ToolMetadata {
  name: string;
  description: string;
  category: 'file' | 'shell' | 'code' | 'search' | 'analysis';
  priority: number;  // 1-10, higher = more important
  tokensEstimate: number;  // Approximate tokens consumed by tool definition
  requiredFor?: string[];  // Keywords that indicate this tool is needed
}

/**
 * Tool registry with metadata (database-first tools)
 */
export const TOOL_REGISTRY: Record<string, ToolMetadata> = {
  // Tier 1: Essential Code Access
  getCode: {
    name: 'getCode',
    description: 'Get code file with AST, symbols, metadata',
    category: 'code',
    priority: 10,  // Most common
    tokensEstimate: 120,
    requiredFor: ['read', 'show', 'display', 'view', 'get', 'file', 'code'],
  },
  searchCode: {
    name: 'searchCode',
    description: 'Semantic code search using embeddings',
    category: 'search',
    priority: 9,  // Very common
    tokensEstimate: 130,
    requiredFor: ['search', 'find', 'where', 'locate', 'similar', 'like'],
  },
  listCodeFiles: {
    name: 'listCodeFiles',
    description: 'List indexed code files',
    category: 'code',
    priority: 8,
    tokensEstimate: 100,
    requiredFor: ['list', 'ls', 'files', 'show files', 'directory'],
  },

  // Tier 2: Symbol Navigation
  findSymbol: {
    name: 'findSymbol',
    description: 'Find symbol definition',
    category: 'analysis',
    priority: 8,
    tokensEstimate: 110,
    requiredFor: ['definition', 'find', 'where defined', 'locate', 'function', 'class'],
  },
  findReferences: {
    name: 'findReferences',
    description: 'Find symbol references',
    category: 'analysis',
    priority: 7,
    tokensEstimate: 110,
    requiredFor: ['references', 'usage', 'used', 'calls', 'callers'],
  },
  listSymbols: {
    name: 'listSymbols',
    description: 'List symbols in file',
    category: 'analysis',
    priority: 7,
    tokensEstimate: 100,
    requiredFor: ['symbols', 'functions', 'classes', 'exports', 'api'],
  },

  // Tier 3: Dependencies
  getDependencies: {
    name: 'getDependencies',
    description: 'Get file dependencies',
    category: 'analysis',
    priority: 6,
    tokensEstimate: 110,
    requiredFor: ['dependencies', 'imports', 'requires', 'uses'],
  },
  getDependencyGraph: {
    name: 'getDependencyGraph',
    description: 'Get dependency graph',
    category: 'analysis',
    priority: 5,
    tokensEstimate: 150,
    requiredFor: ['graph', 'dependencies', 'architecture', 'structure'],
  },
};

/**
 * Analyze task to determine required tools
 */
export function analyzeTaskRequirements(taskDescription: string): {
  requiredTools: string[];
  confidence: 'high' | 'medium' | 'low';
} {
  const lowerTask = taskDescription.toLowerCase();
  const required = new Set<string>();

  // Check each tool's keywords
  for (const [toolName, metadata] of Object.entries(TOOL_REGISTRY)) {
    if (metadata.requiredFor) {
      for (const keyword of metadata.requiredFor) {
        if (lowerTask.includes(keyword)) {
          required.add(toolName);
          break;
        }
      }
    }
  }

  // Determine confidence
  let confidence: 'high' | 'medium' | 'low' = 'low';
  if (required.size === 1 || required.size === 2) {
    confidence = 'high';  // Clear single/dual tool task
  } else if (required.size > 0) {
    confidence = 'medium';  // Multiple tools detected
  }

  return {
    requiredTools: Array.from(required),
    confidence,
  };
}

/**
 * Select tools based on model capacity and task requirements
 */
export function selectToolsForTask(options: {
  model: ModelInfo;
  taskDescription: string;
  availableTools: Record<string, any>;
  maxTools?: number;
}): {
  selectedTools: Record<string, any>;
  reasoning: string;
} {
  const { model, taskDescription, availableTools } = options;

  // Get model's tool capacity
  const maxTools = options.maxTools ?? model.capabilityScores?.tool_capacity ?? 10;

  // Analyze task requirements
  const { requiredTools, confidence } = analyzeTaskRequirements(taskDescription);

  console.log(`[tool-selector] Task analysis for "${taskDescription}":`, {
    requiredTools,
    confidence,
    modelCapacity: maxTools,
  });

  // Strategy based on confidence
  let selected: string[] = [];
  let reasoning = '';

  if (confidence === 'high' && requiredTools.length <= maxTools) {
    // High confidence + fits in budget → use exactly what's needed
    selected = requiredTools;
    reasoning = `High confidence: Task requires ${requiredTools.join(', ')}`;
  } else if (confidence === 'medium' && requiredTools.length <= maxTools) {
    // Medium confidence + fits → use detected tools
    selected = requiredTools;
    reasoning = `Medium confidence: Task likely needs ${requiredTools.join(', ')}`;
  } else if (requiredTools.length > maxTools) {
    // Too many tools detected → prioritize by importance
    selected = prioritizeTools(requiredTools, maxTools);
    reasoning = `Model capacity (${maxTools} tools) exceeded, prioritized to: ${selected.join(', ')}`;
  } else {
    // Low confidence → provide essential tools
    selected = getEssentialTools(maxTools);
    reasoning = `Low confidence: Providing ${maxTools} essential tools`;
  }

  // Build selected tool set
  const selectedTools: Record<string, any> = {};
  for (const toolName of selected) {
    if (availableTools[toolName]) {
      selectedTools[toolName] = availableTools[toolName];
    }
  }

  console.log(`[tool-selector] Selected ${selected.length}/${Object.keys(availableTools).length} tools:`, selected);

  return { selectedTools, reasoning };
}

/**
 * Prioritize tools by priority score
 */
function prioritizeTools(toolNames: string[], maxCount: number): string[] {
  return toolNames
    .map(name => ({ name, priority: TOOL_REGISTRY[name]?.priority ?? 0 }))
    .sort((a, b) => b.priority - a.priority)
    .slice(0, maxCount)
    .map(t => t.name);
}

/**
 * Get essential tools for unknown tasks
 */
function getEssentialTools(maxCount: number): string[] {
  const essentials = Object.entries(TOOL_REGISTRY)
    .sort(([, a], [, b]) => b.priority - a.priority)
    .slice(0, maxCount)
    .map(([name]) => name);

  return essentials;
}

/**
 * Estimate total tokens consumed by tool definitions
 */
export function estimateToolTokens(toolNames: string[]): number {
  return toolNames.reduce((total, name) => {
    return total + (TOOL_REGISTRY[name]?.tokensEstimate ?? 100);
  }, 0);
}

/**
 * Check if model can handle tool set
 */
export function canModelHandleTools(model: ModelInfo, toolNames: string[]): {
  canHandle: boolean;
  reason: string;
} {
  const maxTools = model.capabilityScores?.tool_capacity ?? 10;
  const toolCount = toolNames.length;

  if (toolCount > maxTools * 1.5) {
    return {
      canHandle: false,
      reason: `Too many tools (${toolCount}) for model capacity (${maxTools})`,
    };
  }

  const estimatedTokens = estimateToolTokens(toolNames);
  const availableContext = model.contextWindow * 0.1;  // Assume tools can use 10% of context

  if (estimatedTokens > availableContext) {
    return {
      canHandle: false,
      reason: `Tool definitions (~${estimatedTokens} tokens) exceed available context (~${availableContext} tokens)`,
    };
  }

  return {
    canHandle: true,
    reason: `Model can handle ${toolCount} tools (~${estimatedTokens} tokens)`,
  };
}

/**
 * Auto-select tools with smart defaults
 */
export function autoSelectTools(options: {
  model: ModelInfo;
  messages: any[];
  availableTools: Record<string, any>;
}): {
  selectedTools: Record<string, any>;
  reasoning: string;
} {
  // Extract task description from last user message
  const lastMessage = options.messages
    .filter((m: any) => m.role === 'user')
    .pop();

  const taskDescription = typeof lastMessage?.content === 'string'
    ? lastMessage.content
    : JSON.stringify(lastMessage?.content);

  return selectToolsForTask({
    model: options.model,
    taskDescription,
    availableTools: options.availableTools,
  });
}
