/**
 * Claude Code Provider Wrapper
 * Re-exports ai-sdk-provider-claude-code with model metadata
 */

import { claudeCode as baseClaudeCode } from 'ai-sdk-provider-claude-code';
import type { ClaudeCodeProvider as BaseClaudeCodeProvider } from 'ai-sdk-provider-claude-code';

/**
 * Model metadata for Claude Code provider
 */
export const CLAUDE_CODE_MODELS = [
  {
    id: 'sonnet',
    displayName: 'Claude Sonnet 4.5',
    description: 'Best for coding, 64K output (supports extended thinking)',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: false, tools: true },
    cost: 'subscription' as const,
    subscription: 'Claude Pro/Max',
  },
  {
    id: 'opus',
    displayName: 'Claude Opus 4.1',
    description: 'Largest model (supports extended thinking)',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: false, tools: true },
    cost: 'subscription' as const,
    subscription: 'Claude Pro/Max',
  },
] as const;

/**
 * Extended Claude Code provider with model listing capability
 */
export interface ClaudeCodeProvider extends BaseClaudeCodeProvider {
  listModels(): typeof CLAUDE_CODE_MODELS;
}

/**
 * Claude Code provider instance with model listing
 */
export const claudeCode = Object.assign(baseClaudeCode, {
  listModels: () => CLAUDE_CODE_MODELS,
}) as ClaudeCodeProvider;
