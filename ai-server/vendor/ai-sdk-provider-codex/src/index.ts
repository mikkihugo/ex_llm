import { createCodexProvider as baseCreateCodexProvider, codex as baseCodex } from './codex-provider';
import { customProvider } from 'ai';
import type { Provider } from 'ai';
export { CodexLanguageModel } from './codex-language-model';
export type { CodexProvider as BaseCodexProvider } from './codex-provider';
export type { CodexModelConfig } from './codex-language-model';

/**
 * Model metadata for OpenAI Codex provider
 *
 * Tested 2025-10-06:
 * ✅ gpt-5 - Works
 * ✅ gpt-5-codex - Works (with thinking)
 * ✅ gpt-5-mini - Works
 * ❌ o3 - 400 Unsupported model
 * ❌ o1 - 400 Unsupported model
 * ❌ codex-1 - 400 Unsupported model
 */
export const CODEX_MODELS = [
  {
    id: 'gpt-5',
    displayName: 'GPT-5',
    description: 'OpenAI GPT-5 (default, supports extended thinking)',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: true },
    cost: 'free' as const,
    subscription: 'ChatGPT Plus/Pro',
  },
  {
    id: 'gpt-5-codex',
    displayName: 'GPT-5 Codex',
    description: 'GPT-5 optimized for software engineering (supports extended thinking)',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: true },
    cost: 'free' as const,
    subscription: 'ChatGPT Plus/Pro',
  },
  {
    id: 'gpt-5-mini',
    displayName: 'GPT-5 Mini',
    description: 'Smaller, faster GPT-5 (supports extended thinking)',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: true },
    cost: 'free' as const,
    subscription: 'ChatGPT Plus/Pro',
  },
] as const;

/**
 * Extended Codex provider with metadata access
 */
export interface CodexProvider extends Provider {
  getModelMetadata(): typeof CODEX_MODELS;
}

/**
 * Create Codex provider using AI SDK's customProvider()
 */
export function createCodexProvider(): CodexProvider {
  const baseProv = baseCreateCodexProvider();

  // Build languageModels record from available models
  const languageModels: Record<string, any> = {};
  for (const model of CODEX_MODELS) {
    languageModels[model.id] = baseProv(model.id);
  }

  // Create custom provider (language models only)
  const baseProvider: any = customProvider({
    languageModels,
  });

  // Add metadata accessor
  return Object.assign(baseProvider, {
    getModelMetadata: () => CODEX_MODELS,
  });
}

/**
 * Codex provider instance with metadata access
 */
export const codex = createCodexProvider();
