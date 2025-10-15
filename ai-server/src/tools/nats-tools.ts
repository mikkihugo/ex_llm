/**
 * @file NATS-Based Database-First Tools
 * @description Thin tool wrappers that query codebase database via NATS.
 *
 * DATABASE-FIRST ARCHITECTURE:
 * - All code access via PostgreSQL code_chunks table
 * - Pre-parsed AST, symbols, embeddings available
 * - No filesystem I/O (except write operations)
 * - Security, audit, caching in one place
 */

import { tool } from 'ai';
import { z } from 'zod';
import { connect, type NatsConnection } from 'nats';

/**
 * NATS subjects for database-first tool execution
 */
export const TOOL_SUBJECTS = {
  // Code Access (from code_chunks table)
  CODE_GET: 'tools.code.get',
  CODE_SEARCH: 'tools.code.search',
  CODE_LIST: 'tools.code.list',

  // Symbol Navigation (from AST)
  SYMBOL_FIND: 'tools.symbol.find',
  SYMBOL_REFS: 'tools.symbol.refs',
  SYMBOL_LIST: 'tools.symbol.list',

  // Dependencies (from import analysis)
  DEPS_GET: 'tools.deps.get',
  DEPS_GRAPH: 'tools.deps.graph',

  // Patterns (from extracted patterns)
  PATTERN_SEARCH: 'tools.pattern.search',

  // Git (from database, not git CLI)
  GIT_LOG: 'tools.git.log',
  GIT_BLAME: 'tools.git.blame',
} as const;

/**
 * NATS client singleton
 */
let natsClient: NatsConnection | null = null;

async function getNatsClient(): Promise<NatsConnection> {
  if (!natsClient) {
    const natsUrl = process.env.NATS_URL || 'nats://localhost:4222';
    natsClient = await connect({ servers: natsUrl });
    console.log('[nats-tools] Connected to NATS:', natsUrl);
  }
  return natsClient;
}

/**
 * Execute tool via NATS request-reply pattern
 */
async function executeViaNATS(subject: string, request: any, timeoutMs: number = 30000): Promise<any> {
  const nc = await getNatsClient();

  console.log(`[nats-tools] Sending request to ${subject}:`, request);

  // Use JSON.stringify/parse like nats-handler does
  const requestData = JSON.stringify(request);
  const response = await nc.request(subject, requestData, { timeout: timeoutMs });
  const result = JSON.parse(new TextDecoder().decode(response.data));

  console.log(`[nats-tools] Received response from ${subject}:`, result);

  if (result.error) {
    throw new Error(result.error);
  }

  return result.data;
}

/**
 * ============================================================================
 * TIER 1: ESSENTIAL CODE ACCESS (Database-First)
 * ============================================================================
 */

/**
 * Get code file with metadata (AST, symbols, embeddings)
 * Queries code_chunks table, not filesystem
 */
export const getCodeTool = tool({
  description: 'Get code file with AST, symbols, and metadata from database',
  parameters: z.object({
    path: z.string().describe('File path'),
    codebaseId: z.string().optional().describe('Codebase ID (default: current project)'),
    includeAST: z.boolean().optional().describe('Include parsed AST'),
    includeSymbols: z.boolean().optional().describe('Include symbol definitions'),
  }),
  execute: async ({ path, codebaseId, includeAST, includeSymbols }) => {
    return await executeViaNATS(TOOL_SUBJECTS.CODE_GET, {
      path,
      codebase_id: codebaseId,
      include_ast: includeAST,
      include_symbols: includeSymbols,
    });
  },
});

/**
 * Semantic code search using pgvector embeddings
 */
export const searchCodeTool = tool({
  description: 'Semantic code search using embeddings (finds similar code)',
  parameters: z.object({
    query: z.string().describe('Natural language search query'),
    limit: z.number().optional().describe('Max results (default: 10)'),
    minSimilarity: z.number().optional().describe('Minimum similarity 0-1 (default: 0.7)'),
    codebaseId: z.string().optional().describe('Codebase ID'),
  }),
  execute: async ({ query, limit, minSimilarity, codebaseId }) => {
    return await executeViaNATS(TOOL_SUBJECTS.CODE_SEARCH, {
      query,
      limit,
      min_similarity: minSimilarity,
      codebase_id: codebaseId,
    });
  },
});

/**
 * List all indexed code files
 */
export const listCodeFilesTool = tool({
  description: 'List all indexed code files from database',
  parameters: z.object({
    codebaseId: z.string().optional().describe('Codebase ID'),
    language: z.string().optional().describe('Filter by language (elixir, typescript, rust, etc.)'),
    pattern: z.string().optional().describe('Glob pattern to filter paths'),
  }),
  execute: async ({ codebaseId, language, pattern }) => {
    return await executeViaNATS(TOOL_SUBJECTS.CODE_LIST, {
      codebase_id: codebaseId,
      language,
      pattern,
    });
  },
});

/**
 * ============================================================================
 * TIER 2: SYMBOL NAVIGATION (AST-Based)
 * ============================================================================
 */

/**
 * Find where a symbol is defined
 */
export const findSymbolTool = tool({
  description: 'Find where symbol (function, class, variable) is defined',
  parameters: z.object({
    symbol: z.string().describe('Symbol name to find'),
    codebaseId: z.string().optional().describe('Codebase ID'),
    symbolType: z.enum(['function', 'class', 'module', 'variable']).optional().describe('Symbol type'),
  }),
  execute: async ({ symbol, codebaseId, symbolType }) => {
    return await executeViaNATS(TOOL_SUBJECTS.SYMBOL_FIND, {
      symbol,
      codebase_id: codebaseId,
      symbol_type: symbolType,
    });
  },
});

/**
 * Find all references to a symbol
 */
export const findReferencesTool = tool({
  description: 'Find all references to a symbol (where it is used)',
  parameters: z.object({
    symbol: z.string().describe('Symbol name'),
    codebaseId: z.string().optional().describe('Codebase ID'),
  }),
  execute: async ({ symbol, codebaseId }) => {
    return await executeViaNATS(TOOL_SUBJECTS.SYMBOL_REFS, {
      symbol,
      codebase_id: codebaseId,
    });
  },
});

/**
 * List all symbols in a file
 */
export const listSymbolsTool = tool({
  description: 'List all symbols (functions, classes, etc.) in a file',
  parameters: z.object({
    path: z.string().describe('File path'),
    codebaseId: z.string().optional().describe('Codebase ID'),
    symbolType: z.enum(['function', 'class', 'module', 'variable', 'all']).optional().describe('Filter by type'),
  }),
  execute: async ({ path, codebaseId, symbolType }) => {
    return await executeViaNATS(TOOL_SUBJECTS.SYMBOL_LIST, {
      path,
      codebase_id: codebaseId,
      symbol_type: symbolType,
    });
  },
});

/**
 * ============================================================================
 * TIER 3: DEPENDENCIES (Import Analysis)
 * ============================================================================
 */

/**
 * Get file dependencies (what it imports)
 */
export const getDependenciesTool = tool({
  description: 'Get file dependencies (imports/requires)',
  parameters: z.object({
    path: z.string().describe('File path'),
    codebaseId: z.string().optional().describe('Codebase ID'),
    includeTransitive: z.boolean().optional().describe('Include transitive dependencies'),
  }),
  execute: async ({ path, codebaseId, includeTransitive }) => {
    return await executeViaNATS(TOOL_SUBJECTS.DEPS_GET, {
      path,
      codebase_id: codebaseId,
      include_transitive: includeTransitive,
    });
  },
});

/**
 * Get dependency graph for codebase
 */
export const getDependencyGraphTool = tool({
  description: 'Get full dependency graph for codebase',
  parameters: z.object({
    codebaseId: z.string().optional().describe('Codebase ID'),
    format: z.enum(['json', 'mermaid', 'dot']).optional().describe('Output format'),
  }),
  execute: async ({ codebaseId, format }) => {
    return await executeViaNATS(TOOL_SUBJECTS.DEPS_GRAPH, {
      codebase_id: codebaseId,
      format,
    });
  },
});

/**
 * Security policy configuration
 */
export interface ToolSecurityPolicy {
  /** Codebase IDs allowed for access */
  allowedCodebases?: string[];
  /** Languages allowed (elixir, typescript, rust, etc.) */
  allowedLanguages?: string[];
}

/**
 * Create standard database-first tool set
 *
 * Returns tools organized by tier for easy selection:
 * - essential: Tier 1 (getCode, searchCode, listFiles)
 * - standard: Tier 1 + Tier 2 (adds symbol navigation)
 * - full: All tiers (adds dependencies, patterns, git)
 */
export function createStandardTools(policy?: ToolSecurityPolicy) {
  const essential = {
    getCode: getCodeTool,
    searchCode: searchCodeTool,
    listCodeFiles: listCodeFilesTool,
  };

  const standard = {
    ...essential,
    findSymbol: findSymbolTool,
    findReferences: findReferencesTool,
    listSymbols: listSymbolsTool,
  };

  const full = {
    ...standard,
    getDependencies: getDependenciesTool,
    getDependencyGraph: getDependencyGraphTool,
  };

  return { essential, standard, full };
}

/**
 * Get essential tools only (for small models)
 */
export function getEssentialTools() {
  return {
    getCode: getCodeTool,
    searchCode: searchCodeTool,
    listCodeFiles: listCodeFilesTool,
  };
}

/**
 * Get standard tools (for medium models)
 */
export function getStandardTools() {
  return {
    ...getEssentialTools(),
    findSymbol: findSymbolTool,
    findReferences: findReferencesTool,
    listSymbols: listSymbolsTool,
  };
}

/**
 * Get all tools (for large models)
 */
export function getFullTools() {
  return {
    ...getStandardTools(),
    getDependencies: getDependenciesTool,
    getDependencyGraph: getDependencyGraphTool,
  };
}

/**
 * Close NATS connection on shutdown
 */
export async function closeNatsTools() {
  if (natsClient) {
    await natsClient.close();
    natsClient = null;
    jsonCodec = null;
    console.log('[nats-tools] NATS connection closed');
  }
}
