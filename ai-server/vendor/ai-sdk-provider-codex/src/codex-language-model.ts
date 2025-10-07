import { generateText, streamText } from 'ai';
import type { LanguageModelV2 } from '@ai-sdk/provider';
import { createGeminiProvider } from '../../src/providers/gemini-code';
import { Codex } from '@openai/codex-sdk';
import type {
  ThreadEvent,
  ThreadItem,
  Usage as CodexUsage,
} from '@openai/codex-sdk';

export interface CodexModelConfig {
  model?: string;
  logLevel?: 'error' | 'warn' | 'info' | 'debug';
  approvalPolicy?: 'always' | 'never' | 'auto';
  mcpServers?: Record<string, any>;
  reasoningEffort?: 'none' | 'low' | 'medium' | 'high';
  reasoningSummary?: 'none' | 'auto' | 'concise' | 'detailed';
}

export class CodexLanguageModel implements LanguageModelV2 {
  readonly specificationVersion = 'v2' as const;
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
    if (this.modelId.startsWith('gemini')) {
      const gemini = createGeminiProvider({ authType: 'oauth-personal' });
      const result = await generateText({
        model: gemini(this.modelId as any),
        ...options,
      });
      return result as any;
    }

    const { promptText, messagesForUsage } = this.convertMessagesToPrompt(options.prompt, options.tools);

    try {
      const turn = await this.runCodexTurn(promptText);

      return {
        text: turn.text,
        finishReason: turn.finishReason,
        usage: this.normalizeUsageFromCodex(turn.usage, messagesForUsage, turn.text),
        toolCalls: turn.toolCalls,
      } as any;
    } catch (error) {
      throw new Error(`Codex error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  private createCodexClient() {
    return new Codex({
      config: {
        model: this.modelId,
        approval_policy: (this.config.approvalPolicy || 'never') as any,
        model_reasoning_effort: this.config.reasoningEffort,
        model_reasoning_summary: this.config.reasoningSummary,
        mcp_servers: this.config.mcpServers,
      },
    });
  }

  private async runCodexTurn(prompt: string) {
    const codex = this.createCodexClient();
    const thread = codex.startThread();
    const turn = await thread.run(prompt);

    return {
      text: turn.finalResponse || '',
      finishReason: 'stop' as const,
      usage: turn.usage,
      toolCalls: this.extractToolCalls(turn.items),
    };
  }

  private convertMessagesToPrompt(prompt: any[], tools?: Record<string, any>): { promptText: string; messagesForUsage: string[] } {
    const ordered: string[] = [];

    for (const message of prompt) {
      const role = message.role || 'user';
      const parts = this.extractMessageTextParts(message.content);
      const text = parts.join('\n');
      if (text.trim().length === 0) {
        continue;
      }

      ordered.push(`${role.toUpperCase()}:\n${text}`);
    }

    let promptText = ordered.join("\n\n");

    if (tools) {
      const toolInstruction = this.buildToolInstructionBlock(tools);
      if (toolInstruction) {
        ordered.push(`SYSTEM:\n${toolInstruction}`);
        promptText = ordered.join("\n\n");
      }
    }

    return {
      promptText,
      messagesForUsage: ordered,
    };
  }

  private buildToolInstructionBlock(tools: Record<string, any> | undefined): string | null {
    if (!tools || typeof tools !== 'object') {
      return null;
    }

    const entries = Object.entries(tools);
    if (entries.length === 0) {
      return null;
    }

    const lines: string[] = ['You have access to the following callable tools. When a tool is required, respond with JSON {"tool": "<name>", "arguments": {...}} and wait for the result before continuing.'];

    for (const [name, definition] of entries) {
      const description = typeof definition?.description === 'string' ? definition.description.trim() : '';
      const parameters = definition?.parameters ? JSON.stringify(definition.parameters) : undefined;
      const lineParts = [`- ${name}`];
      if (description) {
        lineParts.push(`description: ${description}`);
      }
      if (parameters) {
        lineParts.push(`schema: ${parameters}`);
      }
      lines.push(lineParts.join(' '));
    }

    return lines.join('\n');
  }

  private extractMessageTextParts(content: any): string[] {
    if (typeof content === 'string') {
      return [content];
    }

    if (Array.isArray(content)) {
      return content
        .map((part: any) => {
          if (typeof part === 'string') return part;
          if (part?.type === 'text') return part.text || '';
          if (part?.type === 'tool-result' && typeof part?.text === 'string') {
            return `Tool Result:\n${part.text}`;
          }
          return '';
        })
        .filter(Boolean);
    }

    if (typeof content?.text === 'string') {
      return [content.text];
    }

    return [];
  }

  private extractToolCalls(items: ThreadItem[] | undefined) {
    if (!items) return undefined;

    const toolCalls = items
      .filter((item) => (item as any).type === 'mcp_tool_call')
      .map((item) => ({
        toolCallType: 'function' as const,
        toolCallId: (item as any).id,
        toolName: `${(item as any).server}:${(item as any).tool}`,
        args: JSON.stringify({}),
      }));

    return toolCalls.length > 0 ? toolCalls : undefined;
  }

  private normalizeUsageFromCodex(usage: CodexUsage | null, promptMessages: string[], completionText: string) {
    if (usage) {
      const promptTokens = usage.input_tokens ?? 0;
      const completionTokens = usage.output_tokens ?? 0;
      const totalTokens = promptTokens + completionTokens;

      return {
        promptTokens,
        completionTokens,
        totalTokens,
      };
    }

    const estimatedPrompt = this.estimateTokensFromStrings(promptMessages);
    const estimatedCompletion = this.estimateTokensFromStrings([completionText]);

    return {
      promptTokens: estimatedPrompt,
      completionTokens: estimatedCompletion,
      totalTokens: estimatedPrompt + estimatedCompletion,
    };
  }

  private estimateTokensFromStrings(strings: string[]): number {
    return strings.reduce((sum, value) => {
      if (!value) return sum;
      const bytes = Buffer.byteLength(value, 'utf8');
      if (bytes === 0) return sum;
      return sum + Math.max(1, Math.ceil(bytes / 4));
    }, 0);
  }

  async doStream(options: Parameters<LanguageModelV1['doStream']>[0]): Promise<Awaited<ReturnType<LanguageModelV1['doStream']>>> {
    const { promptText, messagesForUsage } = this.convertMessagesToPrompt(options.prompt, options.tools);

    const codex = this.createCodexClient();
    const thread = codex.startThread();
    const { events } = await thread.runStreamed(promptText);

    const context: {
      accumulatedText: string;
      usage: CodexUsage | null;
      toolCalls: Array<{
        toolCallType: 'function';
        toolCallId: string;
        toolName: string;
        args: string;
      }>;
    } = {
      accumulatedText: '',
      usage: null,
      toolCalls: [],
    };

    const stream = new ReadableStream({
      start: async (controller) => {
        try {
          for await (const event of events) {
            this.handleStreamEvent(event, controller, context);
          }

          controller.enqueue({
            type: 'finish' as const,
            finishReason: 'stop' as const,
            usage: this.normalizeUsageFromCodex(context.usage, messagesForUsage, context.accumulatedText),
            toolCalls: context.toolCalls.length ? context.toolCalls : undefined,
          });
          controller.close();
        } catch (error) {
          controller.error(error);
        }
      },
    });

    return {
      stream,
      rawCall: { rawPrompt: promptText, rawSettings: { model: this.modelId } },
      warnings: undefined,
    };
  }

  private handleStreamEvent(
    event: ThreadEvent,
    controller: ReadableStreamDefaultController<any>,
    context: {
      accumulatedText: string;
      usage: CodexUsage | null;
      toolCalls: any[];
    },
  ) {
    switch (event.type) {
      case 'item.started':
      case 'item.updated':
      case 'item.completed': {
        if (event.item.type === 'agent_message') {
          const nextText = event.item.text || '';
          const delta = nextText.slice(context.accumulatedText.length);
          if (delta.length > 0) {
            controller.enqueue({
              type: 'text-delta' as const,
              textDelta: delta,
            });
            context.accumulatedText = nextText;
          }
        }

        if (event.item.type === 'mcp_tool_call') {
          context.toolCalls.push({
            toolCallType: 'function' as const,
            toolCallId: event.item.id,
            toolName: `${event.item.server}:${event.item.tool}`,
            args: JSON.stringify({ status: event.item.status }),
          });
        }
        break;
      }
      case 'turn.completed': {
        context.usage = event.usage;
        break;
      }
      case 'turn.failed': {
        throw new Error(event.error?.message || 'Codex turn failed');
      }
      case 'error': {
        throw new Error(event.message || 'Codex stream error');
      }
      default:
        break;
    }
  }

}
