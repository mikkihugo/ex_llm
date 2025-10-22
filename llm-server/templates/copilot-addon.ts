/**
 * GitHub Copilot Addon
 *
 * Implementation of the AI Addon Template for GitHub Copilot.
 * Supports both API and CLI access to Copilot models.
 */

import { AIAddonTemplate, AIAddonConfig, AIResponse } from './ai-addon-template';
import { getCopilotAccessToken } from '../src/github-copilot-oauth';

const copilotApiConfig: AIAddonConfig = {
  name: 'GitHub Copilot API',
  version: '1.0.0',
  provider: 'copilot-api',
  description: 'GitHub Copilot API access via OAuth authentication',
  models: [
    {
      id: 'copilot-gpt-4.1',
      name: 'Copilot GPT-4.1',
      contextWindow: 128000,
      capabilities: ['completion', 'reasoning']
    },
    {
      id: 'grok-coder-1',
      name: 'Grok Coder 1',
      contextWindow: 128000,
      capabilities: ['completion', 'reasoning', 'coding']
    }
  ],
  auth: {
    type: 'oauth',
    envVars: ['GITHUB_TOKEN', 'GH_TOKEN'],
    setupInstructions: `
GitHub Personal Access Token with Copilot access:
1. Go to https://github.com/settings/tokens
2. Create new token (classic) or use fine-grained
3. Required scopes: 'Copilot' or 'Copilot Chat'
4. Set GITHUB_TOKEN or GH_TOKEN environment variable

Or use GitHub Copilot OAuth flow (advanced):
- Run server OAuth setup for automatic token management
    `
  },
  capabilities: {
    completion: true,
    streaming: false,
    reasoning: true,
    vision: false
  }
};

const copilotCliConfig: AIAddonConfig = {
  name: 'GitHub Copilot CLI',
  version: '1.0.0',
  provider: 'copilot-cli',
  description: 'GitHub Copilot CLI tool access',
  models: [
    {
      id: 'copilot-cli-gpt-4.1',
      name: 'Copilot CLI GPT-4.1',
      contextWindow: 128000,
      capabilities: ['completion', 'reasoning', 'cli']
    }
  ],
  auth: {
    type: 'cli_token',
    envVars: ['GITHUB_TOKEN', 'GH_TOKEN'],
    setupInstructions: 'Install GitHub Copilot CLI and set GITHUB_TOKEN'
  },
  capabilities: {
    completion: true,
    streaming: false,
    reasoning: true,
    vision: false
  }
};

export class CopilotAPIAddon extends AIAddonTemplate {
  constructor() {
    super(copilotApiConfig);
  }

  async chat(messages: any[], options: any = {}): Promise<AIResponse> {
    const token = await getCopilotAccessToken();

    if (!token) {
      throw new Error('GitHub Copilot not authenticated');
    }

    const model = options.model || 'copilot-gpt-4.1';
    const upstreamModel = model === 'copilot-gpt-4.1' ? 'gpt-4' :
                         model === 'grok-coder-1' ? 'grok-coder-1' : model;

    const response = await fetch('https://api.githubcopilot.com/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'editor-plugin-version': 'copilot-chat/0.26.7',
        'user-agent': 'GitHubCopilotChat/0.26.7',
        'copilot-integration-id': 'vscode-chat',
        'openai-intent': 'conversation-panel',
        'x-github-api-version': '2025-04-01',
        'x-request-id': crypto.randomUUID(),
      },
      body: JSON.stringify({
        model: upstreamModel,
        messages: messages,
        stream: false,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Copilot API error: ${response.status} ${response.statusText} - ${errorText}`);
    }

    const data: any = await response.json();

    return {
      text: data.choices?.[0]?.message?.content || '',
      usage: {
        promptTokens: data.usage?.prompt_tokens || 0,
        completionTokens: data.usage?.completion_tokens || 0,
        totalTokens: data.usage?.total_tokens || 0,
      },
      finishReason: data.choices?.[0]?.finish_reason || 'stop',
      model: model
    };
  }

  async validateAuth(): Promise<boolean> {
    try {
      await getCopilotAccessToken();
      return true;
    } catch {
      return false;
    }
  }
}

export class CopilotCLIAddon extends AIAddonTemplate {
  constructor() {
    super(copilotCliConfig);
  }

  async chat(messages: any[], options: any = {}): Promise<AIResponse> {
    const prompt = messages.map(m => `${m.role}: ${m.content}`).join('\n\n');

    try {
      const { execSync } = await import('child_process');
      const output = execSync(`copilot -p "${prompt}"`, {
        encoding: 'utf8',
        timeout: 30000,
        env: {
          ...process.env,
          GITHUB_TOKEN: process.env.GITHUB_TOKEN || process.env.GH_TOKEN
        }
      });

      return {
        text: output.trim(),
        usage: {
          promptTokens: Math.ceil(prompt.length / 4), // Rough estimate
          completionTokens: Math.ceil(output.length / 4),
          totalTokens: Math.ceil((prompt.length + output.length) / 4),
        },
        finishReason: 'stop',
        model: options.model || 'copilot-cli-gpt-4.1'
      };
    } catch (error: any) {
      throw new Error(`Copilot CLI failed: ${error.message}`);
    }
  }

  async validateAuth(): Promise<boolean> {
    try {
      const { execSync } = await import('child_process');
      execSync('copilot --help', { timeout: 5000 });
      return true;
    } catch {
      return false;
    }
  }
}

// Export addon instances
export const copilotAPIAddon = new CopilotAPIAddon();
export const copilotCLIAddon = new CopilotCLIAddon();
export default copilotAPIAddon;