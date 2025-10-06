/**
 * Cursor Provider Wrapper
 * Re-exports ai-sdk-provider-cursor with model metadata
 */

import { cursor as baseCursor } from '../../vendor/ai-sdk-provider-cursor/dist/index.js';
import type { CursorProvider as BaseCursorProvider } from '../../vendor/ai-sdk-provider-cursor/dist/index.js';

/**
 * Model metadata for Cursor provider
 */
export const CURSOR_MODELS = [
  {
    id: 'auto',
    displayName: 'Cursor Agent (Auto)',
    description: 'Auto model selection - lets Cursor choose best model (FREE on subscription)',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
    cost: 'subscription' as const,
    subscription: 'Cursor Pro/Business',
  },
  {
    id: 'gpt-4.1',
    displayName: 'Cursor Agent GPT-4.1',
    description: 'Explicit GPT-4.1 selection via Cursor Agent',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
    cost: 'subscription' as const,
    subscription: 'Cursor Pro/Business',
  },
  {
    id: 'sonnet-4',
    displayName: 'Cursor Agent Sonnet 4',
    description: 'Claude Sonnet 4 via Cursor Agent',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: true, tools: true },
    cost: 'subscription' as const,
    subscription: 'Cursor Pro/Business',
  },
  {
    id: 'sonnet-4-thinking',
    displayName: 'Cursor Agent Sonnet 4 (Thinking)',
    description: 'Claude Sonnet 4 with extended thinking via Cursor Agent',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: true, tools: true },
    cost: 'subscription' as const,
    subscription: 'Cursor Pro/Business',
  },
] as const;

/**
 * Extended Cursor provider with model listing capability
 */
export interface CursorProvider extends BaseCursorProvider {
  listModels(): typeof CURSOR_MODELS;
}

/**
 * Cursor provider instance with model listing
 *
 * Default config: read-only tools (file read, search, grep, glob)
 * No write/execute operations allowed for safety.
 *
 * To add MCP servers:
 * ```ts
 * const model = cursor('auto', {
 *   approvalPolicy: 'read-only',
 *   mcpServers: {
 *     'filesystem': {
 *       command: 'npx',
 *       args: ['-y', '@modelcontextprotocol/server-filesystem', '/path/to/project'],
 *     },
 *   },
 * });
 * ```
 */
export const cursor = Object.assign(baseCursor, {
  listModels: () => CURSOR_MODELS,
}) as CursorProvider;
