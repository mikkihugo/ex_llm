import type { LanguageModelV1 } from '@ai-sdk/provider';
import { Codex } from '@openai/codex-sdk';
import type { Message } from '@openai/codex-sdk';

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
    const codex = new Codex({
      // Config options for the Codex CLI
      config: {
        model: this.modelId,
        approval_policy: (this.config.approvalPolicy || 'never') as any,
        model_reasoning_effort: this.config.reasoningEffort,
        model_reasoning_summary: this.config.reasoningSummary,
      },
    });

    // Start a thread
    const thread = codex.startThread();

    // Convert AI SDK messages to a single prompt
    const prompt = this.convertMessagesToPrompt(options.prompt);

    try {
      // Run the prompt and get the result
      const turn = await thread.run(prompt, {
        tools: this.convertTools(options.tools),
      });

      return {
        text: turn.finalResponse || '',
        finishReason: 'stop' as const,
        usage: {
          promptTokens: turn.usage?.promptTokens || 0,
          completionTokens: turn.usage?.completionTokens || 0,
        },
        toolCalls: turn.items
          ?.filter((item: any) => item.type === 'tool_call')
          .map((item: any) => ({
            toolCallType: 'function' as const,
            toolCallId: item.id,
            toolName: item.name,
            args: JSON.stringify(item.input || {}),
          })),
      } as any;
    } catch (error) {
      throw new Error(`Codex error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  private convertMessagesToPrompt(prompt: any[]): string {
    // Convert AI SDK prompt array to a single string
    return prompt
      .map((msg) => {
        if (typeof msg.content === 'string') {
          return msg.content;
        }
        if (Array.isArray(msg.content)) {
          return msg.content.map((part: any) => part.text || '').join('\n');
        }
        return '';
      })
      .join('\n\n');
  }

  private convertTools(tools: any): any {
    if (!tools) return undefined;
    // Convert AI SDK tools to Codex tool format if needed
    return tools;
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

}
