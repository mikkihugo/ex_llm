/**
 * @file Claude Code Provider
 * @description This module wraps the base Claude Code provider to include static
 * model metadata, making it compatible with the server's model registry system.
 */

import { claudeCode as baseClaudeCode } from 'ai-sdk-provider-claude-code';
import type { ClaudeCodeProvider as BaseClaudeCodeProvider } from 'ai-sdk-provider-claude-code';

/**
 * @const {Array<object>} CLAUDE_CODE_MODELS
 * @description A static list of available Claude models and their metadata.
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
 * @interface ClaudeCodeProvider
 * @extends BaseClaudeCodeProvider
 * @description Extends the base Claude Code provider to include a `listModels` method.
 */
export interface ClaudeCodeProvider extends BaseClaudeCodeProvider {
  listModels(): typeof CLAUDE_CODE_MODELS;
}

/**
 * @const {ClaudeCodeProvider} claudeCode
 * @description The public instance of the Claude Code provider, extended with model listing capabilities.
 */
export const claudeCode = Object.assign(baseClaudeCode, {
  listModels: () => CLAUDE_CODE_MODELS,
}) as ClaudeCodeProvider;