/**
 * @file Google Gemini Provider
 * @description This module wraps the base Gemini provider to include static model metadata
 * and set a default Google Cloud Project ID if one is not already configured.
 */

import { createGeminiProvider as baseCreateGeminiProvider } from 'ai-sdk-provider-gemini-cli';
import type { GeminiProvider as BaseGeminiProvider, GeminiProviderOptions } from 'ai-sdk-provider-gemini-cli';

export type { GeminiProviderOptions };

/**
 * @const {Array<object>} GEMINI_CODE_MODELS
 * @description A static list of available Gemini models and their metadata.
 */
export const GEMINI_CODE_MODELS = [
  {
    id: 'gemini-2.5-flash',
    displayName: 'Gemini Code 2.5 Flash',
    description: 'Fast, efficient model (FREE via Gemini Code Assist)',
    contextWindow: 1048576,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: false, tools: true },
    cost: 'free' as const,
  },
  {
    id: 'gemini-2.5-pro',
    displayName: 'Gemini Code 2.5 Pro',
    description: 'Most capable Gemini model (FREE via Gemini Code Assist)',
    contextWindow: 1048576,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: false, tools: true },
    cost: 'free' as const,
  },
] as const;

/**
 * @interface GeminiProvider
 * @extends BaseGeminiProvider
 * @description Extends the base Gemini provider to include a `listModels` method.
 */
export interface GeminiProvider extends BaseGeminiProvider {
  listModels(): typeof GEMINI_CODE_MODELS;
}

/**
 * Creates a Gemini provider instance, extended with a `listModels` method.
 * @param {GeminiProviderOptions} [options] Configuration options for the Gemini provider.
 * @returns {GeminiProvider} A configured Gemini provider instance.
 */
export function createGeminiProvider(options?: GeminiProviderOptions): GeminiProvider {
  // TODO: The personal OAuth flow for Gemini is not yet implemented.
  // This will likely involve a similar process to the GitHub Copilot OAuth flow.
  // For now, the provider defaults to using an API key.
  // Set a default Google Cloud Project ID if not provided in the environment.
  if (!process.env.GOOGLE_CLOUD_PROJECT) {
    process.env.GOOGLE_CLOUD_PROJECT = 'gemini-code-473918';
  }

  const baseProvider = baseCreateGeminiProvider(options);

  // Extend the base provider with the listModels method.
  return Object.assign(baseProvider, {
    listModels: () => GEMINI_CODE_MODELS,
  }) as GeminiProvider;
}