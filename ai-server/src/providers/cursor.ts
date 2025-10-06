/**
 * Cursor Provider Wrapper
 * Re-exports ai-sdk-provider-cursor with model metadata
 */

import { cursor as baseCursor } from '../../vendor/ai-sdk-provider-cursor/dist/index.js';
import type { CursorProvider as BaseCursorProvider } from '../../vendor/ai-sdk-provider-cursor/dist/index.js';

/**
 * Model metadata for Cursor provider
 *
 * Models discovered from CLI: cursor-agent --print --model invalid "test" 2>&1
 * Available: auto, cheetah, sonnet-4.5, sonnet-4.5-thinking, gpt-5, opus-4.1, grok
 */
export const CURSOR_MODELS = [
  {
    id: 'auto',
    displayName: 'Cursor Agent (Auto)',
    description: 'Auto model selection - Cursor picks best model (FREE unlimited)',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
    cost: 'free' as const,
    subscription: 'Cursor Pro/Business',
  },
  {
    id: 'cheetah',
    displayName: 'Cursor Cheetah (Fast)',
    description: 'Mystery fast model - 2x faster than Sonnet 4.5 (FREE unlimited) ⚡',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
    cost: 'free' as const,
    subscription: 'Cursor Pro/Business',
  },
  {
    id: 'grok',
    displayName: 'Grok 4 (xAI)',
    description: 'xAI Grok 4 - unique perspective, first-principles thinking, architecture analysis',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
    cost: 'limited' as const,
    subscription: 'Cursor Pro/Business (quota limited)',
  },
  {
    id: 'sonnet-4.5',
    displayName: 'Claude Sonnet 4.5',
    description: 'Latest Claude Sonnet - high quality code generation',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: true, tools: true },
    cost: 'limited' as const,
    subscription: 'Cursor Pro/Business (quota limited)',
  },
  {
    id: 'sonnet-4.5-thinking',
    displayName: 'Claude Sonnet 4.5 (Thinking)',
    description: 'Sonnet 4.5 with extended reasoning for complex problems',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: true, tools: true },
    cost: 'limited' as const,
    subscription: 'Cursor Pro/Business (quota limited)',
  },
  {
    id: 'gpt-5',
    displayName: 'GPT-5 (OpenAI)',
    description: 'OpenAI GPT-5 - general purpose coding',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
    cost: 'limited' as const,
    subscription: 'Cursor Pro/Business (quota limited)',
  },
  {
    id: 'opus-4.1',
    displayName: 'Claude Opus 4.1',
    description: 'Highest quality Claude - most capable for complex tasks',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: true, tools: true },
    cost: 'limited' as const,
    subscription: 'Cursor Pro/Business (quota limited)',
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
