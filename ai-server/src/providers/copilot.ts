/**
 * @file GitHub Copilot Provider
 * @description This module wraps the base `createCopilotProvider` to integrate it
 * with the application's GitHub Copilot OAuth flow. It provides a unified
 * interface for listing Copilot models and creating language model instances.
 */

import { createCopilotProvider } from '../../vendor/ai-sdk-provider-copilot/dist/copilot-provider.js';
import { getCopilotAccessToken } from '../github-copilot-oauth';

/**
 * @description The base Copilot provider instance created from the vendored package.
 * @private
 */
const baseCopilotProvider = createCopilotProvider();

/**
 * @const {object} copilot
 * @description An object that serves as the public interface for the GitHub Copilot provider.
 * It includes a static list of available models and a factory function for creating
 * language model instances with proper authentication.
 *
 * @property {Function} listModels - Returns a static list of available Copilot models,
 * including their capabilities and cost tiers.
 * @property {Function} languageModel - A factory function that returns a Copilot language
 * model instance for a given model ID, configured with the OAuth access token.
 */
export const copilot = {
  /**
   * @returns {Array<object>} A static list of predefined Copilot models.
   */
  listModels: () => [
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
  ],
  /**
   * Creates a language model instance for a specific Copilot model.
   * @param {string} modelId The ID of the model to use.
   * @returns {any} A language model instance configured with the OAuth token handler.
   */
  languageModel: (modelId: string) => baseCopilotProvider(modelId, { token: getCopilotAccessToken }),
};