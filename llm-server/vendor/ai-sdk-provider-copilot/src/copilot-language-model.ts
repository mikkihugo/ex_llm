/**
 * GitHub Copilot Language Model
 *
 * AI SDK LanguageModelV2 implementation for GitHub Copilot API.
 * Uses api.githubcopilot.com REST API with GitHub token authentication.
 */

import type { LanguageModelV1 } from '@ai-sdk/provider';

export interface CopilotModelConfig {
  /**
   * GitHub token for authentication
   * OR function to get Copilot access token (for OAuth flow)
   */
  token?: string | (() => Promise<string | null>);
  /** Log level for debugging */
  logLevel?: 'error' | 'warn' | 'info' | 'debug';
}

export class CopilotLanguageModel implements LanguageModelV1 {
  readonly specificationVersion = 'v2' as any;
  readonly provider = 'github.copilot' as const;
  readonly modelId: string;
  readonly config: CopilotModelConfig;

  constructor(modelId: string, config: CopilotModelConfig = {}) {
    this.modelId = modelId;
    this.config = config;
  }

  get defaultObjectGenerationMode() {
    return 'tool' as const;
  }

  async doGenerate(options: Parameters<LanguageModelV1['doGenerate']>[0]): Promise<Awaited<ReturnType<LanguageModelV1['doGenerate']>>> {
    const token = await this.getToken();

    if (!token) {
      throw new Error('GitHub Copilot token not found. Set COPILOT_TOKEN or GITHUB_TOKEN environment variable, or provide token/tokenFn in config.');
    }

    const messages = this.convertMessages(options.prompt);
    const logLevel = this.config.logLevel || 'error';

    if (logLevel === 'debug' || logLevel === 'info') {
      console.log('[copilot] Sending request:', { model: this.modelId, messageCount: messages.length });
    }

    // Call GitHub Copilot API
    const response = await fetch('https://api.githubcopilot.com/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'editor-version': 'vscode/1.99.3',
        'editor-plugin-version': 'copilot-chat/0.26.7',
        'user-agent': 'GitHubCopilotChat/0.26.7',
        'copilot-integration-id': 'vscode-chat',
        'openai-intent': 'conversation-panel',
        'x-github-api-version': '2025-04-01',
        'x-request-id': crypto.randomUUID(),
      },
      body: JSON.stringify({
        model: this.modelId,
        messages: messages,
        stream: false,
        // Add tools if provided
        ...(options.mode?.type === 'regular' && options.mode.tools ? {
          tools: this.convertTools(options.mode.tools),
        } : {}),
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Copilot API error: ${response.status} ${response.statusText} - ${errorText}`);
    }

    const data: any = await response.json();

    if (logLevel === 'debug') {
      console.log('[copilot] Response:', JSON.stringify(data).substring(0, 500));
    }

    const content = data.choices?.[0]?.message?.content || '';
    const toolCalls = data.choices?.[0]?.message?.tool_calls;
    const finishReason = data.choices?.[0]?.finish_reason || 'stop';

    // Convert tool calls to AI SDK format
    const aiToolCalls = toolCalls?.map((tc: any) => ({
      toolCallType: 'function' as const,
      toolCallId: tc.id,
      toolName: tc.function.name,
      args: tc.function.arguments,
    }));

    // V2 format requires content array instead of text field
    return {
      content: content ? [{ type: 'text' as const, text: content }] : [],
      finishReason: this.mapFinishReason(finishReason),
      usage: {
        promptTokens: data.usage?.prompt_tokens || this.estimateTokens(messages),
        completionTokens: data.usage?.completion_tokens || this.estimateTokens(content),
      },
      toolCalls: aiToolCalls,
      rawResponse: {
        headers: {},
      },
    } as any;
  }

  async doStream(options: Parameters<LanguageModelV1['doStream']>[0]): Promise<Awaited<ReturnType<LanguageModelV1['doStream']>>> {
    const token = await this.getToken();

    if (!token) {
      throw new Error('GitHub Copilot token not found. Set COPILOT_TOKEN or GITHUB_TOKEN environment variable, or provide token/tokenFn in config.');
    }

    const messages = this.convertMessages(options.prompt);

    // Call GitHub Copilot API with streaming
    const response = await fetch('https://api.githubcopilot.com/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'editor-version': 'vscode/1.99.3',
        'editor-plugin-version': 'copilot-chat/0.26.7',
        'user-agent': 'GitHubCopilotChat/0.26.7',
        'copilot-integration-id': 'vscode-chat',
        'openai-intent': 'conversation-panel',
        'x-github-api-version': '2025-04-01',
        'x-request-id': crypto.randomUUID(),
      },
      body: JSON.stringify({
        model: this.modelId,
        messages: messages,
        stream: true,
        ...(options.mode?.type === 'regular' && options.mode.tools ? {
          tools: this.convertTools(options.mode.tools),
        } : {}),
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Copilot API error: ${response.status} ${response.statusText} - ${errorText}`);
    }

    if (!response.body) {
      throw new Error('Response body is null');
    }

    const stream = this.createStreamFromResponse(response.body);

    return {
      stream,
      rawCall: { rawPrompt: null, rawSettings: {} },
      warnings: undefined,
    };
  }

  private convertMessages(prompt: any): Array<{ role: string; content: string }> {
    if (Array.isArray(prompt)) {
      return prompt.map((msg: any) => ({
        role: msg.role || 'user',
        content: Array.isArray(msg.content)
          ? msg.content.map((c: any) => typeof c === 'string' ? c : c.text).join('\n')
          : msg.content,
      }));
    }

    return [{ role: 'user', content: String(prompt) }];
  }

  private convertTools(tools: Record<string, any>): any[] {
    return Object.entries(tools).map(([name, tool]) => ({
      type: 'function',
      function: {
        name,
        description: tool.description || '',
        parameters: tool.parameters || {},
      },
    }));
  }

  private mapFinishReason(reason: string): 'stop' | 'length' | 'content-filter' | 'tool-calls' | 'error' | 'other' | 'unknown' {
    switch (reason) {
      case 'stop': return 'stop';
      case 'length': return 'length';
      case 'content_filter': return 'content-filter';
      case 'tool_calls': return 'tool-calls';
      default: return 'unknown';
    }
  }

  private async getToken(): Promise<string | null> {
    // If token is a function (e.g., getCopilotAccessToken), call it
    if (typeof this.config.token === 'function') {
      return await this.config.token();
    }

    // Otherwise use string token or environment variable
    return this.config.token || process.env.COPILOT_TOKEN || process.env.GITHUB_TOKEN || null;
  }

  private estimateTokens(input: any): number {
    const text = typeof input === 'string' ? input : JSON.stringify(input);
    return Math.ceil(Buffer.byteLength(text, 'utf8') / 4);
  }

  private createStreamFromResponse(body: ReadableStream<Uint8Array>): ReadableStream {
    const reader = body.getReader();
    const decoder = new TextDecoder();

    return new ReadableStream({
      async start(controller) {
        let buffer = '';

        try {
          while (true) {
            const { done, value } = await reader.read();

            if (done) {
              controller.close();
              break;
            }

            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split('\n');
            buffer = lines.pop() || '';

            for (const line of lines) {
              if (!line.trim() || line.trim() === 'data: [DONE]') continue;
              if (!line.startsWith('data: ')) continue;

              try {
                const data = JSON.parse(line.substring(6));
                const delta = data.choices?.[0]?.delta;

                if (delta?.content) {
                  controller.enqueue({
                    type: 'text-delta' as const,
                    textDelta: delta.content,
                  });
                }

                if (data.choices?.[0]?.finish_reason) {
                  controller.enqueue({
                    type: 'finish' as const,
                    finishReason: data.choices[0].finish_reason,
                    usage: {
                      promptTokens: data.usage?.prompt_tokens || 0,
                      completionTokens: data.usage?.completion_tokens || 0,
                    },
                  });
                }
              } catch (e) {
                console.warn('[copilot] Failed to parse SSE line:', line);
              }
            }
          }
        } catch (error: any) {
          controller.enqueue({
            type: 'error' as const,
            error,
          });
          controller.close();
        }
      },
    });
  }
}
