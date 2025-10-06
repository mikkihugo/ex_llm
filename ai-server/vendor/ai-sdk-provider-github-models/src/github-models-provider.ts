/**
 * GitHub Models Provider
 * Uses AI SDK's customProvider() with dynamic model loading
 */

import { createOpenAI } from '@ai-sdk/openai';
import { customProvider } from 'ai';
import type { Provider } from 'ai';

export interface GitHubModelsConfig {
  token?: string | (() => Promise<string | null>);
  baseURL?: string;
}

export interface GitHubModelsProvider extends Provider {
  refreshModels(): Promise<void>;  // Async - fetches and updates provider
  getModelMetadata(): any[];  // Get raw model metadata
}

/**
 * Create GitHub Models provider
 */
export function createGitHubModelsProvider(config: GitHubModelsConfig = {}): GitHubModelsProvider {
  const getToken = async (): Promise<string> => {
    const { token } = config;

    if (typeof token === 'function') {
      const result = await token();
      if (!result) {
        throw new Error('GitHub token function returned null');
      }
      return result;
    }

    if (token) {
      return token;
    }

    const envToken = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
    if (!envToken) {
      throw new Error(
        'GitHub token not found. Set GITHUB_TOKEN environment variable or pass token in config.'
      );
    }

    return envToken;
  };

  const tokenValue = typeof config.token === 'string'
    ? config.token
    : process.env.GITHUB_TOKEN || process.env.GH_TOKEN || '';

  // Base OpenAI provider for GitHub Models endpoint
  const baseOpenAI = createOpenAI({
    apiKey: tokenValue,
    baseURL: config.baseURL ?? 'https://models.github.ai',
  });

  // Model cache
  let cachedModels: any[] = [];
  let cacheTime: number = 0;
  const CACHE_TTL = 5 * 60 * 1000; // 5 minutes
  let currentProvider: Provider | null = null;

  async function fetchModels(): Promise<any[]> {
    const token = await getToken();

    const response = await fetch('https://models.github.ai/catalog/models', {
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': `Bearer ${token}`,
        'X-GitHub-Api-Version': '2022-11-28',
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch models: ${response.status} ${response.statusText}`);
    }

    const models = await response.json() as any[];

    // Apply GitHub Models free tier limits (not the model's theoretical max)
    // Source: https://docs.github.com/en/github-models/use-github-models/prototyping-with-ai-models#rate-limits
    return models.map((model: any) => {
      const tier = model.rate_limit_tier;
      let maxInput: number;
      let maxOutput: number;

      // GitHub free tier per-request limits
      if (tier === 'low') {
        maxInput = 8000;
        maxOutput = 4000;
      } else if (tier === 'high') {
        maxInput = 8000;
        maxOutput = 4000;
      } else if (tier === 'embeddings') {
        maxInput = 64000;
        maxOutput = model.limits?.max_output_tokens || 0;
      } else if (tier === 'custom') {
        // Mini/Nano/DeepSeek/Grok models
        maxInput = 4000;
        maxOutput = 4000;
      } else {
        // Fallback to model's limits if tier unknown
        maxInput = model.limits?.max_input_tokens || 8000;
        maxOutput = model.limits?.max_output_tokens || 4000;
      }

      return {
        ...model,
        limits: {
          max_input_tokens: maxInput,
          max_output_tokens: maxOutput,
          // Keep original for reference
          model_max_input_tokens: model.limits?.max_input_tokens,
          model_max_output_tokens: model.limits?.max_output_tokens,
        },
      };
    });
  }

  function buildProvider(models: any[]): Provider {
    // Build languageModels record from fetched models
    const languageModels: Record<string, any> = {};

    for (const model of models) {
      // Use model.id as the key (e.g., "openai/gpt-4.1")
      languageModels[model.id] = baseOpenAI(model.id);
    }

    // Create custom provider with all models
    return customProvider({
      languageModels,
      fallbackProvider: baseOpenAI,
    });
  }

  // Build initial provider with empty models (will be refreshed)
  currentProvider = buildProvider([]);

  // Wrapper that delegates to current provider
  const providerWrapper = new Proxy({} as Provider, {
    get(target, prop) {
      if (prop === 'refreshModels') {
        return async () => {
          const models = await fetchModels();
          cachedModels = models;
          cacheTime = Date.now();
          currentProvider = buildProvider(models);
        };
      }
      if (prop === 'getModelMetadata') {
        return () => cachedModels;
      }
      // Delegate all other calls to current provider
      return currentProvider ? (currentProvider as any)[prop] : undefined;
    },
  }) as GitHubModelsProvider;

  return providerWrapper;
}
