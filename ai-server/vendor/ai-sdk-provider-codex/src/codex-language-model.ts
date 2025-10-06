import type { LanguageModelV1 } from '@ai-sdk/provider';
import { CodexSDK } from 'codex-js-sdk';
import type { CodexResponse, CodexMessageType, InputItem } from 'codex-js-sdk';

export interface CodexModelConfig {
  model?: string;
  logLevel?: 'error' | 'warn' | 'info' | 'debug';
  approvalPolicy?: 'always' | 'never' | 'auto';
  mcpServers?: Record<string, any>;
  reasoningEffort?: 'none' | 'low' | 'medium' | 'high';
  reasoningSummary?: 'none' | 'auto' | 'concise' | 'detailed';
}

export class CodexLanguageModel implements LanguageModelV1 {
  readonly specificationVersion = 'v1' as const;
  readonly provider = 'openai.codex' as const;
  readonly modelId: string;
  readonly config: CodexModelConfig;

  constructor(modelId: string, config: CodexModelConfig = {}) {
    this.modelId = modelId;
    this.config = config;
  }

  get defaultObjectGenerationMode() {
    return 'tool' as const;
  }

  async doGenerate(options: Parameters<LanguageModelV1['doGenerate']>[0]): Promise<Awaited<ReturnType<LanguageModelV1['doGenerate']>>> {
    const sdk = new CodexSDK({
      logLevel: (this.config.logLevel || 'error') as any,
      config: {
        approval_policy: (this.config.approvalPolicy || 'never') as any,
        model: this.modelId,
        mcp_servers: this.config.mcpServers,
        model_reasoning_effort: this.config.reasoningEffort,
        model_reasoning_summary: this.config.reasoningSummary,
      },
    });

    return new Promise((resolve, reject) => {
      let responseText = '';
      let toolCalls: any[] = [];
      let isComplete = false;

      const timeout = setTimeout(() => {
        if (!isComplete) {
          sdk.stop();
          reject(new Error('Codex request timeout after 60s'));
        }
      }, 60000);

      sdk.onResponse((response: CodexResponse<CodexMessageType>) => {
        const msg = response.msg;

        if (msg.type === 'agent_message') {
          responseText += msg.message;
        } else if (msg.type === 'agent_reasoning') {
          // Extended thinking/reasoning - include in response
          responseText += `\n[Thinking: ${msg.text}]\n`;
        } else if (msg.type === 'mcp_tool_call_begin') {
          toolCalls.push({
            toolCallType: 'function' as const,
            toolCallId: msg.call_id,
            toolName: msg.tool,
            args: JSON.stringify(msg.arguments || {}),
          });
        } else if (msg.type === 'task_complete') {
          isComplete = true;
          clearTimeout(timeout);

          resolve({
            text: responseText,
            finishReason: 'stop' as const,
            usage: {
              promptTokens: 0,
              completionTokens: 0,
            },
            toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
          } as any);
        } else if (msg.type === 'error') {
          isComplete = true;
          clearTimeout(timeout);
          reject(new Error(`Codex error: ${(msg as any).error || 'Unknown error'}`));
        }
      });

      // Convert AI SDK messages to Codex input
      const inputItems = this.convertMessages(options.prompt);
      sdk.start();
      sdk.sendUserMessage(inputItems);
    });
  }

  async doStream(options: Parameters<LanguageModelV1['doStream']>[0]): Promise<Awaited<ReturnType<LanguageModelV1['doStream']>>> {
    // Codex doesn't support proper streaming via SDK yet
    // Fall back to doGenerate and return as single chunk
    const result = await this.doGenerate(options);

    // Create a ReadableStream from the generator
    const stream = new ReadableStream({
      async start(controller) {
        controller.enqueue({
          type: 'text-delta' as const,
          textDelta: result.text || '',
        });
        controller.enqueue({
          type: 'finish' as const,
          finishReason: result.finishReason,
          usage: result.usage,
        });
        controller.close();
      }
    });

    return {
      stream,
      rawCall: { rawPrompt: null, rawSettings: {} },
      warnings: undefined,
    };
  }

  private convertMessages(prompt: any): InputItem[] {
    // Convert AI SDK prompt format to Codex InputItem[]
    if (typeof prompt === 'string') {
      return [{ type: 'text', text: prompt }];
    }

    if (Array.isArray(prompt)) {
      const text = prompt
        .map((msg: any) => {
          if (msg.role === 'user') return msg.content;
          if (msg.role === 'assistant') return msg.content;
          return '';
        })
        .filter(Boolean)
        .join('\n\n');

      return [{ type: 'text', text }];
    }

    return [{ type: 'text', text: String(prompt) }];
  }
}
