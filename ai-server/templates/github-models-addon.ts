/**
 * GitHub Models Addon
 *
 * Concrete implementation of the AI Addon Template for GitHub Models.
 * Uses Vercel AI SDK for standardized integration.
 */

import { openai } from '@ai-sdk/openai';
import { generateText } from 'ai';
import { AIAddonTemplate, AIAddonConfig, AIResponse } from './ai-addon-template';

const githubModelsConfig: AIAddonConfig = {
  name: 'GitHub Models',
  version: '1.0.0',
  provider: 'github-models',
  description: 'GitHub Models via Azure AI inference with OpenAI-compatible API',
  models: [
    {
      id: 'gpt-4o-mini',
      name: 'GPT-4o Mini',
      contextWindow: 128000,
      pricing: { input: 0.15, output: 0.60 }, // per 1M tokens
      capabilities: ['completion', 'vision', 'fast']
    },
    {
      id: 'gpt-4o',
      name: 'GPT-4o',
      contextWindow: 128000,
      pricing: { input: 2.50, output: 10.00 }, // per 1M tokens
      capabilities: ['completion', 'vision', 'reasoning']
    },
    {
      id: 'o1-mini',
      name: 'o1 Mini',
      contextWindow: 128000,
      pricing: { input: 3.00, output: 12.00 }, // per 1M tokens
      capabilities: ['completion', 'reasoning', 'advanced']
    },
    {
      id: 'o1-preview',
      name: 'o1 Preview',
      contextWindow: 128000,
      pricing: { input: 15.00, output: 60.00 }, // per 1M tokens
      capabilities: ['completion', 'reasoning', 'advanced', 'research']
    }
  ],
  auth: {
    type: 'oauth',
    envVars: ['GITHUB_TOKEN', 'GH_TOKEN'],
    setupInstructions: `
GitHub Personal Access Token with Models read access:
1. Go to https://github.com/settings/tokens
2. Create new token (classic)
3. Select scopes: 'Models: Read' and 'Codespaces'
4. Set GITHUB_TOKEN or GH_TOKEN environment variable
    `
  },
  capabilities: {
    completion: true,
    streaming: false,
    reasoning: true,
    vision: true
  }
};

export class GitHubModelsAddon extends AIAddonTemplate {
  private models: Map<string, any> = new Map();

  constructor() {
    super(githubModelsConfig);
  }

  async initialize(config: any): Promise<void> {
    await super.initialize(config);

    // Initialize Vercel AI SDK models
    for (const model of this.config.models) {
      this.models.set(model.id, this.createGitHubModel(model.id));
    }
  }

  private createGitHubModel(modelName: string) {
    const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;

    if (!token) {
      throw new Error('GitHub token not found. Set GITHUB_TOKEN or GH_TOKEN.');
    }

    return openai(modelName, {
      apiKey: token,
      baseURL: 'https://models.inference.ai.azure.com',
      headers: {
        'azureml-model-deployment': modelName,
      },
    });
  }

  async chat(messages: any[], options: any = {}): Promise<AIResponse> {
    const modelName = options.model || 'gpt-4o-mini';
    const model = this.models.get(modelName);

    if (!model) {
      throw new Error(`Model ${modelName} not found in GitHub Models addon`);
    }

    const result = await generateText({
      model,
      messages,
      temperature: options.temperature ?? 0.7,
      maxTokens: options.maxTokens ?? 4096,
    });

    return {
      text: result.text,
      usage: {
        promptTokens: result.usage?.promptTokens || 0,
        completionTokens: result.usage?.completionTokens || 0,
        totalTokens: result.usage?.totalTokens || 0,
      },
      finishReason: result.finishReason || 'stop',
      model: modelName
    };
  }

  async validateAuth(): Promise<boolean> {
    const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
    if (!token) return false;

    try {
      // Quick validation by attempting to create a model
      const testModel = this.createGitHubModel('gpt-4o-mini');
      return !!testModel;
    } catch {
      return false;
    }
  }
}

// Export the addon instance
export const githubModelsAddon = new GitHubModelsAddon();
export default githubModelsAddon;