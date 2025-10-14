/**
 * @file GitHub Copilot Provider
 * @description This module wraps the base `createCopilotProvider` to integrate it
 * with the application's GitHub Copilot OAuth flow. It provides a unified
 * interface for listing Copilot models and creating language model instances.
 */

import { createCopilotProvider } from '../../vendor/ai-sdk-provider-copilot/dist/copilot-provider.js';
import { customProvider } from 'ai';
import { getCopilotAccessToken } from '../github-copilot-oauth';

/**
 * @description The base Copilot provider instance created from the vendored package.
 * @private
 */
const baseCopilotProvider = createCopilotProvider();

/**
 * Model metadata for GitHub Copilot provider
 */
export const COPILOT_MODELS = [
  {
    id: 'gpt-4.1',
    displayName: 'GPT-4.1',
    description: 'Latest GPT-4.1 model via GitHub Copilot (FREE tier)',
    contextWindow: 131072,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: true },
    cost: 'free' as const,
    subscription: 'GitHub Copilot',
  },
  {
    id: 'gpt-5-mini',
    displayName: 'GPT-5 Mini',
    description: 'GPT-5 Mini model via GitHub Copilot (FREE tier)',
    contextWindow: 131072,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: true },
    cost: 'free' as const,
    subscription: 'GitHub Copilot',
  },
  {
    id: 'grok-code-fast-1',
    displayName: 'Grok Code Fast',
    description: 'Grok Code Fast model via GitHub Copilot (FREE tier)',
    contextWindow: 131072,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: true },
    cost: 'free' as const,
    subscription: 'GitHub Copilot',
  },
  {
    id: 'gpt-4o',
    displayName: 'GPT-4o',
    description: 'GPT-4o model via GitHub Copilot (FREE unlimited)',
    contextWindow: 131072,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: true, tools: true },
    cost: 'free' as const,
    subscription: 'GitHub Copilot',
  },
  {
    id: 'claude-3.5-sonnet',
    displayName: 'Claude 3.5 Sonnet',
    description: 'Claude 3.5 Sonnet via GitHub Copilot (limited quota)',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: true, tools: true },
    cost: 'limited' as const,
    subscription: 'GitHub Copilot',
  },
];

/**
 * Create Copilot provider using AI SDK's customProvider()
 */
function createCopilotProviderInstance() {
  // Build languageModels record from available models
  const languageModels: Record<string, any> = {};

  for (const model of COPILOT_MODELS) {
    languageModels[model.id] = baseCopilotProvider(model.id, { token: getCopilotAccessToken });
  }

  // Create custom provider
  const baseProvider = customProvider({
    languageModels,
  });

  // Add metadata accessor for integration tests
  return Object.assign(baseProvider, {
    getModelMetadata: () => COPILOT_MODELS,
  });
}

/**
 * @const {object} copilot
 * @description The singleton instance of the Copilot provider with AI SDK v5 compatibility.
 */
export const copilot = createCopilotProviderInstance();