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

// Note: Tool execution is handled separately from tool definition in AI SDK v5+
// The tools defined here are metadata-only; actual execution happens via the AI SDK runtime
// When execution is needed, implement getNatsClient() and executeViaNATS() patterns

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
  inputSchema: z.object({
    path: z.string().describe('File path'),
    codebaseId: z.string().optional().describe('Codebase ID (default: current project)'),
    includeAST: z.boolean().optional().describe('Include parsed AST'),
    includeSymbols: z.boolean().optional().describe('Include symbol definitions'),
  }),
});

/**
 * Semantic code search using pgvector embeddings
 */
export const searchCodeTool = tool({
  description: 'Semantic code search using embeddings (finds similar code)',
  inputSchema: z.object({
    query: z.string().describe('Natural language search query'),
    limit: z.number().optional().describe('Max results (default: 10)'),
    minSimilarity: z.number().optional().describe('Minimum similarity 0-1 (default: 0.7)'),
    codebaseId: z.string().optional().describe('Codebase ID'),
  }),
});

/**
 * List all indexed code files
 */
export const listCodeFilesTool = tool({
  description: 'List all indexed code files from database',
  inputSchema: z.object({
    codebaseId: z.string().optional().describe('Codebase ID'),
    language: z.string().optional().describe('Filter by language (elixir, typescript, rust, etc.)'),
    pattern: z.string().optional().describe('Glob pattern to filter paths'),
  }),
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
  inputSchema: z.object({
    symbol: z.string().describe('Symbol name to find'),
    codebaseId: z.string().optional().describe('Codebase ID'),
    symbolType: z.enum(['function', 'class', 'module', 'variable']).optional().describe('Symbol type'),
  }),
});

/**
 * Find all references to a symbol
 */
export const findReferencesTool = tool({
  description: 'Find all references to a symbol (where it is used)',
  inputSchema: z.object({
    symbol: z.string().describe('Symbol name'),
    codebaseId: z.string().optional().describe('Codebase ID'),
  }),
});

/**
 * List all symbols in a file
 */
export const listSymbolsTool = tool({
  description: 'List all symbols (functions, classes, etc.) in a file',
  inputSchema: z.object({
    path: z.string().describe('File path'),
    codebaseId: z.string().optional().describe('Codebase ID'),
    symbolType: z.enum(['function', 'class', 'module', 'variable', 'all']).optional().describe('Filter by type'),
  }),
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
  inputSchema: z.object({
    path: z.string().describe('File path'),
    codebaseId: z.string().optional().describe('Codebase ID'),
    includeTransitive: z.boolean().optional().describe('Include transitive dependencies'),
  }),
});

/**
 * Get dependency graph for codebase
 */
export const getDependencyGraphTool = tool({
  description: 'Get full dependency graph for codebase',
  inputSchema: z.object({
    codebaseId: z.string().optional().describe('Codebase ID'),
    format: z.enum(['json', 'mermaid', 'dot']).optional().describe('Output format'),
  }),
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
 *
 * Note: Security policy parameter reserved for future implementation
 */
export function createStandardTools(_policy?: ToolSecurityPolicy) {
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
 * Note: Currently a no-op as NATS execution is not implemented
 */
export async function closeNatsTools() {
  // No-op: NATS connection management will be handled when tool execution is implemented
  console.log('[nats-tools] closeNatsTools called (no-op in current implementation)');
}
