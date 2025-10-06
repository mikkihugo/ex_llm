/**
 * AI SDK Provider for GitHub Copilot
 *
 * Provides AI SDK integration for GitHub Copilot API with:
 * - AI SDK tools support (Elixir executes)
 * - Streaming support
 * - Multiple models (GPT-4.1, Grok Coder)
 * - Subscription-based (GitHub Copilot subscription required)
 *
 * Usage:
 * ```ts
 * import { copilot } from 'ai-sdk-provider-copilot';
 * import { generateText } from 'ai';
 *
 * const result = await generateText({
 *   model: copilot('gpt-4.1'),
 *   prompt: 'Write a function to calculate fibonacci',
 *   tools: {
 *     execute: {
 *       description: 'Execute code',
 *       parameters: z.object({ code: z.string() }),
 *     },
 *   },
 * });
 * ```
 */

import { createCopilotProvider as baseCreateCopilotProvider, copilot as baseCopilot, type CopilotProvider as BaseCopilotProvider } from './copilot-provider';
import { customProvider } from 'ai';
import type { Provider } from 'ai';
export { CopilotLanguageModel } from './copilot-language-model';
export type { CopilotProvider as BaseCopilotProviderType } from './copilot-provider';
export type { CopilotModelConfig } from './copilot-language-model';

/**
 * Free-tier models (no quota limits within subscription)
 */
const FREE_TIER_MODELS = new Set(['gpt-4.1', 'gpt-5-mini', 'grok-code-fast-1']);

/**
 * Fetch models from GitHub Copilot API and apply cost tiers
 */
async function fetchCopilotModels(tokenFn?: () => Promise<string | null>): Promise<any[]> {
  try {
    // Get GitHub token
    const githubToken = tokenFn ? await tokenFn() : process.env.GITHUB_TOKEN || process.env.COPILOT_TOKEN;
    if (!githubToken) {
      console.warn('[Copilot] No GitHub token found, returning empty model list');
      return [];
    }

    // Get Copilot API token
    const tokenResponse = await fetch('https://api.github.com/copilot_internal/v2/token', {
      headers: {
        Authorization: `Bearer ${githubToken}`,
        'editor-version': 'vscode/1.99.3',
      },
    });

    if (!tokenResponse.ok) {
      console.warn('[Copilot] Failed to get Copilot token:', tokenResponse.status);
      return [];
    }

    const { token: copilotToken } = (await tokenResponse.json()) as { token: string };

    // Fetch models
    const modelsResponse = await fetch('https://api.githubcopilot.com/models', {
      headers: {
        Authorization: `Bearer ${copilotToken}`,
        'editor-version': 'vscode/1.99.3',
        'editor-plugin-version': 'copilot-chat/0.26.7',
        'user-agent': 'GitHubCopilotChat/0.26.7',
      },
    });

    if (!modelsResponse.ok) {
      console.warn('[Copilot] Failed to fetch models:', modelsResponse.status);
      return [];
    }

    const { data: models } = (await modelsResponse.json()) as { data: any[] };

    // Filter to chat models only and apply cost tiers
    return models
      .filter((m: any) => m.capabilities?.type === 'chat' && m.model_picker_enabled)
      .map((m: any) => ({
        id: m.id,
        displayName: m.name,
        description: `${m.name} via GitHub Copilot (${Math.floor(m.capabilities.limits.max_context_window_tokens / 1000)}K context${FREE_TIER_MODELS.has(m.id) ? ', no quota limits' : ', quota-limited'})`,
        contextWindow: m.capabilities.limits.max_context_window_tokens,
        capabilities: {
          completion: true,
          streaming: m.capabilities.supports.streaming ?? true,
          reasoning: m.capabilities.supports.structured_outputs ?? false,
          vision: m.capabilities.supports.vision ?? false,
          tools: m.capabilities.supports.tool_calls ?? true,
        },
        cost: FREE_TIER_MODELS.has(m.id) ? ('free' as const) : ('limited' as const),
        subscription: 'GitHub Copilot',
      }));
  } catch (error) {
    console.error('[Copilot] Error fetching models:', error);
    return [];
  }
}

/**
 * Cached model metadata (lazily loaded)
 */
let cachedModels: any[] | null = null;

/**
 * Get Copilot models (with caching)
 */
async function getCopilotModels(tokenFn?: () => Promise<string | null>): Promise<any[]> {
  if (!cachedModels) {
    cachedModels = await fetchCopilotModels(tokenFn);
  }
  return cachedModels;
}

/**
 * Model metadata for GitHub Copilot provider (sync accessor for compatibility)
 * Returns cached models or empty array if not yet fetched
 */
export const COPILOT_MODELS = cachedModels || [];

/**
 * Extended Copilot provider with metadata access
 */
export interface CopilotProvider extends Provider {
  getModelMetadata(): Promise<any[]>;
}

/**
 * Create Copilot provider using AI SDK's customProvider()
 */
export function createCopilotProvider(tokenFn?: () => Promise<string | null>): CopilotProvider {
  const baseProv = baseCreateCopilotProvider();

  // Create a proxy that dynamically creates language models
  const languageModelProxy = new Proxy({} as Record<string, any>, {
    get(target, prop: string) {
      // Return cached model if exists
      if (prop in target) {
        return target[prop];
      }

      // Create and cache model
      target[prop] = tokenFn
        ? baseProv(prop, { token: tokenFn })
        : baseProv(prop);

      return target[prop];
    },
  });

  // Create custom provider with dynamic model access
  const baseProvider: any = customProvider({
    languageModels: languageModelProxy,
  });

  // Add async metadata accessor
  return Object.assign(baseProvider, {
    getModelMetadata: () => getCopilotModels(tokenFn),
  });
}

/**
 * Copilot provider instance with metadata access
 *
 * Requires GitHub Copilot subscription and GitHub token.
 *
 * Authentication:
 * - Set COPILOT_TOKEN or GITHUB_TOKEN environment variable
 * - Or pass token via config: copilot('gpt-4.1', { token: 'ghp_...' })
 * - Or use createCopilotWithOAuth() for token function
 */
export const copilot = createCopilotProvider();

/**
 * Create Copilot provider with OAuth function integration
 *
 * Usage:
 * ```ts
 * import { createCopilotWithOAuth } from 'ai-sdk-provider-copilot';
 * import { getCopilotAccessToken } from './your-oauth-module';
 *
 * const copilot = createCopilotWithOAuth(getCopilotAccessToken);
 * const model = copilot.languageModel('gpt-4.1');
 * ```
 */
export function createCopilotWithOAuth(
  tokenFn: () => Promise<string | null>
): CopilotProvider {
  return createCopilotProvider(tokenFn);
}
