/**
 * Gemini Code Provider Wrapper
 * Re-exports ai-sdk-provider-gemini-cli with model metadata
 */

import { createGeminiProvider as baseCreateGeminiProvider } from 'ai-sdk-provider-gemini-cli';
import type { GeminiProvider as BaseGeminiProvider, GeminiProviderOptions } from 'ai-sdk-provider-gemini-cli';

export type { GeminiProviderOptions };

/**
 * Model metadata for Gemini Code provider
 */
export const GEMINI_CODE_MODELS = [
  {
    id: 'gemini-2.5-flash',
    displayName: 'Gemini Code 2.5 Flash',
    description: 'Fast, efficient model (FREE via Gemini Code Assist)',
    contextWindow: 1048576,  // 1M tokens
    capabilities: { completion: true, streaming: true, reasoning: false, vision: false, tools: true },
    cost: 'free' as const,
  },
  {
    id: 'gemini-2.5-pro',
    displayName: 'Gemini Code 2.5 Pro',
    description: 'Most capable Gemini model (FREE via Gemini Code Assist)',
    contextWindow: 1048576,  // 1M tokens
    capabilities: { completion: true, streaming: true, reasoning: false, vision: false, tools: true },
    cost: 'free' as const,
  },
] as const;

/**
 * Extended Gemini provider with model listing capability
 */
export interface GeminiProvider extends BaseGeminiProvider {
  listModels(): typeof GEMINI_CODE_MODELS;
}

/**
 * Create Gemini provider with model listing
 */
export function createGeminiProvider(options?: GeminiProviderOptions): GeminiProvider {
  // Set default GCP project if not in env (not a secret, just project ID)
  if (!process.env.GOOGLE_CLOUD_PROJECT) {
    process.env.GOOGLE_CLOUD_PROJECT = 'gemini-code-473918';
  }

  const baseProvider = baseCreateGeminiProvider(options);

  // Extend with listModels()
  return Object.assign(baseProvider, {
    listModels: () => GEMINI_CODE_MODELS,
  }) as GeminiProvider;
}
