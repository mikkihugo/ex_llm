/**
 * GitHub Copilot Provider Wrapper
 * Integrates ai-sdk-provider-copilot with GitHub Copilot OAuth flow
 */

import { createCopilotWithOAuth } from '../../vendor/ai-sdk-provider-copilot/dist/index.js';
import { getCopilotAccessToken } from '../github-copilot-oauth';

/**
 * GitHub Copilot provider instance with OAuth integration
 *
 * Features:
 * - ✅ AI SDK tools support (Elixir executes)
 * - ✅ Streaming support
 * - ✅ Dynamic model loading from GitHub Copilot API
 * - ✅ GitHub Copilot OAuth flow integration
 * - ✅ Automatic token refresh
 * - ✅ Cost tier tagging (free vs limited)
 *
 * Authentication:
 * Uses GitHub Copilot OAuth flow via getCopilotAccessToken()
 * which handles:
 * 1. GitHub OAuth token → Copilot API token exchange
 * 2. Token caching with expiration
 * 3. Automatic refresh
 */
const baseCopilot = createCopilotWithOAuth(getCopilotAccessToken);

/**
 * Extended Copilot provider with synchronous listModels method and callable interface
 */
export const copilot = Object.assign(baseCopilot, {
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
      description: 'GPT-4o model via GitHub Copilot (limited quota)',
      contextWindow: 131072,
      capabilities: { completion: true, streaming: true, reasoning: true, vision: true, tools: true },
      cost: 'limited' as const,
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
  // Make provider callable for AI SDK compatibility
  languageModel: (modelId: string) => baseCopilot.languageModel(modelId),
});
