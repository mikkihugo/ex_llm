/**
 * @file Cursor Provider
 * @description This module wraps the base Cursor provider to include static model metadata,
 * making it compatible with the server's model registry system.
 */

import { cursor as baseCursor } from '../../vendor/ai-sdk-provider-cursor/dist/index.js';
import type { CursorProvider as BaseCursorProvider } from '../../vendor/ai-sdk-provider-cursor/dist/index.js';

/**
 * @const {Array<object>} CURSOR_MODELS
 * @description A static list of models available through the Cursor provider.
 * This metadata was discovered by running `cursor-agent --print --model invalid "test" 2>&1`.
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
 * @interface CursorProvider
 * @extends BaseCursorProvider
 * @description Extends the base Cursor provider to include a `listModels` method.
 */
export interface CursorProvider extends BaseCursorProvider {
  listModels(): typeof CURSOR_MODELS;
}

/**
 * @const {CursorProvider} cursor
 * @description The public instance of the Cursor provider, extended with model listing capabilities.
 * The default configuration allows read-only tool usage for safety.
 *
 * @example
 * // To add MCP servers for more tool capabilities:
 * const model = cursor('auto', {
 *   approvalPolicy: 'read-only',
 *   mcpServers: {
 *     'filesystem': {
 *       command: 'npx',
 *       args: ['-y', '@modelcontextprotocol/server-filesystem', '/path/to/project'],
 *     },
 *   },
 * });
 */
export const cursor = Object.assign(baseCursor, {
  listModels: () => CURSOR_MODELS,
}) as CursorProvider;