/**
 * GitHub Models Provider
 * Uses AI SDK's customProvider() with dynamic model loading
 */

import { customProvider } from 'ai';
import type { Provider } from 'ai';

export interface GitHubModelsConfig {
  token?: string | (() => Promise<string | null>);
  baseURL?: string;
}

export interface GitHubModelsProvider {
  languageModel(modelId: string): any;  // V2 language model
  textEmbeddingModel?(modelId: string): any;  // Optional embedding model
  imageModel?(modelId: string): any;  // Optional image model
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

      // Determine model type based on capabilities and tier
      let modelType: 'chat' | 'embedding' | 'unknown' = 'unknown';
      if (tier === 'embeddings' || model.id.includes('embedding') || model.id.includes('embed')) {
        modelType = 'embedding';
      } else if (model.capabilities?.includes?.('text-generation') || model.capabilities?.includes?.('chat') || tier !== 'embeddings') {
        modelType = 'chat';
      }

      return {
        id: model.id,
        displayName: model.friendly_name || model.id,
        description: `${model.friendly_name || model.id} via GitHub Models (${modelType === 'embedding' ? 'Embedding' : Math.floor(maxInput / 1000)}K input${modelType === 'chat' ? `, ${Math.floor(maxOutput / 1000)}K output` : ''})`,
        contextWindow: maxInput + maxOutput,
        type: modelType,
        capabilities: {
          completion: modelType === 'chat',
          streaming: modelType === 'chat',
          reasoning: false,
          vision: model.supported_input_modalities?.includes?.('image') ?? false,
          tools: model.capabilities?.includes?.('tool-calling') ?? false,
        },
        cost: 'free' as const,
        subscription: undefined,
        // Keep original data for reference
        _raw: {
          ...model,
          limits: {
            max_input_tokens: maxInput,
            max_output_tokens: maxOutput,
            model_max_input_tokens: model.limits?.max_input_tokens,
            model_max_output_tokens: model.limits?.max_output_tokens,
          },
        },
      };
    });
  }

  function buildProvider(models: any[]): Provider {
    // Build languageModels record from fetched models
    const languageModels: Record<string, any> = {};

    for (const model of models) {
      // Create a proper V2 language model implementation
      languageModels[model.id] = {
        specificationVersion: 'v2' as const,
        provider: 'openai.chat' as const,
        modelId: model.id,
        defaultObjectGenerationMode: 'json' as const,
        supportedUrls: [],
        doGenerate: async (options: any) => {
          const token = await getToken();

          // Check if this is an embedding model (different endpoint)
          if (model.id.includes('text-embedding') || model.id.includes('embed')) {
            // Use embeddings endpoint for embedding models
            const response = await fetch(`${config.baseURL ?? 'https://models.github.ai'}/inference/embeddings`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`,
              },
              body: JSON.stringify({
                input: options.prompt?.[0]?.content || options.prompt,
                model: model.id,
              }),
            });

            if (!response.ok) {
              throw new Error(`GitHub Models API error: ${response.status} ${response.statusText}`);
            }

            const data = await response.json() as {
              data: Array<{ embedding: number[] }>;
              usage?: { prompt_tokens?: number; total_tokens?: number };
              model?: string;
            };

            return {
              text: JSON.stringify(data.data[0]?.embedding || []),
              usage: {
                promptTokens: data.usage?.prompt_tokens || 0,
                completionTokens: 0,
                totalTokens: data.usage?.total_tokens || 0,
              },
              finishReason: 'stop',
              response: {
                id: `embed_${Date.now()}`,
                timestamp: new Date(),
                modelId: model.id,
              },
            };
          }

          // Regular chat completion models
          // Check if this is a newer OpenAI model that uses max_completion_tokens
          const isNewerOpenAIModel = model.id.startsWith('openai/') && (
            model.id.includes('gpt-5') ||
            model.id.includes('o1') ||
            model.id.includes('o3') ||
            model.id.includes('o4')
          );

          const requestBody: any = {
            model: model.id,
            messages: options.prompt,
            stream: false,
          };

          // Use appropriate token limit parameter
          if (isNewerOpenAIModel) {
            requestBody.max_completion_tokens = options.maxTokens || 1000;
          } else {
            requestBody.max_tokens = options.maxTokens || 1000;
          }

          // Add temperature if provided
          if (options.temperature !== undefined) {
            requestBody.temperature = options.temperature;
          }

          // Make direct API call to GitHub Models
          const response = await fetch(`${config.baseURL ?? 'https://models.github.ai'}/inference/chat/completions`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${token}`,
            },
            body: JSON.stringify(requestBody),
          });

          if (!response.ok) {
            throw new Error(`GitHub Models API error: ${response.status} ${response.statusText}`);
          }

          const data = await response.json() as {
            choices: Array<{ message?: { content?: string }; finish_reason?: string }>;
            usage?: { prompt_tokens?: number; completion_tokens?: number; total_tokens?: number };
            id?: string;
          };

          return {
            text: data.choices[0]?.message?.content || '',
            usage: {
              promptTokens: data.usage?.prompt_tokens || 0,
              completionTokens: data.usage?.completion_tokens || 0,
              totalTokens: data.usage?.total_tokens || 0,
            },
            finishReason: data.choices[0]?.finish_reason || 'stop',
            response: {
              id: data.id,
              timestamp: new Date(),
              modelId: model.id,
            },
          };
        },
        doStream: async (options: any) => {
          const token = await getToken();

          // Make direct API call to GitHub Models for streaming
          const response = await fetch(`${config.baseURL ?? 'https://models.github.ai'}/inference/chat/completions`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${token}`,
            },
            body: JSON.stringify({
              model: model.id,
              messages: options.prompt,
              max_tokens: options.maxTokens,
              temperature: options.temperature,
              stream: true,
              ...options,
            }),
          });

          if (!response.ok) {
            throw new Error(`GitHub Models API error: ${response.status} ${response.statusText}`);
          }

          // Return a streaming response
          return {
            [Symbol.asyncIterator]: async function* () {
              const reader = response.body?.getReader();
              if (!reader) throw new Error('No response body');

              const decoder = new TextDecoder();
              let buffer = '';

              try {
                while (true) {
                  const { done, value } = await reader.read();
                  if (done) break;

                  buffer += decoder.decode(value, { stream: true });
                  const lines = buffer.split('\n');
                  buffer = lines.pop() || '';

                  for (const line of lines) {
                    if (line.startsWith('data: ')) {
                      const data = line.slice(6);
                      if (data === '[DONE]') continue;

                      try {
                        const parsed = JSON.parse(data);
                        const delta = parsed.choices?.[0]?.delta?.content;
                        if (delta) {
                          yield {
                            type: 'text-delta' as const,
                            textDelta: delta,
                          };
                        }
                      } catch (e) {
                        // Ignore parse errors
                      }
                    }
                  }
                }
              } finally {
                reader.releaseLock();
              }

              yield {
                type: 'finish' as const,
                finishReason: 'stop' as const,
                usage: {
                  promptTokens: 0,
                  completionTokens: 0,
                  totalTokens: 0,
                },
              };
            },
          };
        },
      };
    }

    // Create custom provider with all models
    const provider = customProvider({
      languageModels,
    });

    // Add languageModel method for compatibility
    (provider as any).languageModel = (modelId: string) => {
      return languageModels[modelId] || languageModels['openai/gpt-4o-mini']; // fallback
    };

    return provider;
  }

  // Build initial provider with empty models (will be refreshed)
  currentProvider = buildProvider([]);

  // Wrapper that delegates to current provider
  const providerWrapper = new Proxy({} as any, {
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
