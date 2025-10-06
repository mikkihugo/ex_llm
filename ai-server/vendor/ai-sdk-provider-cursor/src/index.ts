/**
 * AI SDK Provider for Cursor Agent
 *
 * Provides AI SDK integration for Cursor Agent CLI with:
 * - Read-only tools (file read, search, grep, glob)
 * - Optional MCP server support
 * - Subscription-based (Cursor Pro/Business required)
 *
 * Usage:
 * ```ts
 * import { cursor } from 'ai-sdk-provider-cursor';
 * import { generateText } from 'ai';
 *
 * const result = await generateText({
 *   model: cursor.languageModel('auto'),
 *   prompt: 'Search for async functions in this codebase',
 * });
 * ```
 */

import { createCursorProvider as baseCreateCursorProvider, cursor as baseCursor, type CursorProvider as BaseCursorProvider } from './cursor-provider';
import { customProvider } from 'ai';
import type { Provider } from 'ai';
export { CursorLanguageModel } from './cursor-language-model';
export type { CursorProvider as BaseCursorProviderType } from './cursor-provider';
export type { CursorModelConfig, MCPServerConfig } from './cursor-language-model';

/**
 * Model metadata for Cursor Agent provider
 */
export const CURSOR_MODELS = [
  {
    id: 'auto',
    displayName: 'Cursor Agent (Auto) - FREE',
    description: 'Auto model selection - FREE with Cursor subscription (model unknown but capable)',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
    cost: 'free' as const,
    subscription: 'Cursor Pro/Business (FREE tier within subscription)',
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
 * Extended Cursor provider with metadata access
 */
export interface CursorProvider extends Provider {
  getModelMetadata(): typeof CURSOR_MODELS;
}

/**
 * Create Cursor provider using AI SDK's customProvider()
 */
export function createCursorProvider(): CursorProvider {
  const baseProv = baseCreateCursorProvider();

  // Build languageModels record from available models
  const languageModels: Record<string, any> = {};
  for (const model of CURSOR_MODELS) {
    languageModels[model.id] = baseProv(model.id);
  }

  // Create custom provider (language models only)
  const baseProvider: any = customProvider({
    languageModels,
  });

  // Add metadata accessor
  return Object.assign(baseProvider, {
    getModelMetadata: () => CURSOR_MODELS,
  });
}

/**
 * Cursor provider instance with metadata access
 */
export const cursor = createCursorProvider();
