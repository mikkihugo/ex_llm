/**
 * Cursor Agent Language Model
 *
 * AI SDK LanguageModelV1 implementation for Cursor Agent CLI.
 * Executes cursor-agent with READ-ONLY tools + optional MCP servers.
 */

import type { LanguageModelV2 } from '@ai-sdk/provider';

export interface MCPServerConfig {
  command: string;
  args?: string[];
  env?: Record<string, string>;
}

export interface CursorModelConfig {
  /** Cursor model to use (default: auto) */
  model?: string;

  /** Log level for debugging */
  logLevel?: 'error' | 'warn' | 'info' | 'debug';

  /**
   * Approval policy for built-in tools:
   * - 'read-only': Safe read operations only (read_file, list_files, search_files, grep, glob)
   * - 'never': Auto-approve all tools (use with caution - allows shell/write operations!)
   *
   * Default: 'read-only'
   */
  approvalPolicy?: 'read-only' | 'never';

  /**
   * MCP servers to enable (name -> config)
   *
   * IMPORTANT: This is the ONLY way to add custom tools to Cursor Agent.
   * AI SDK tools parameter is NOT supported - use MCP servers instead.
   *
   * Example:
   * ```ts
   * mcpServers: {
   *   'filesystem': {
   *     command: 'npx',
   *     args: ['-y', '@modelcontextprotocol/server-filesystem', '/path'],
   *   },
   * }
   * ```
   */
  mcpServers?: Record<string, MCPServerConfig>;

  /** Working directory for cursor-agent */
  workingDirectory?: string;

  /** Additional CLI flags */
  additionalFlags?: string[];
}

export class CursorLanguageModel implements LanguageModelV2 {
  readonly specificationVersion = 'v2' as const;
  readonly provider = 'cursor' as const;
  readonly modelId: string;
  readonly config: CursorModelConfig;

  constructor(modelId: string, config: CursorModelConfig = {}) {
    this.modelId = modelId;
    this.config = config;
  }

  get defaultObjectGenerationMode() {
    return 'tool' as const;
  }

  async doGenerate(options: Parameters<LanguageModelV1['doGenerate']>[0]): Promise<Awaited<ReturnType<LanguageModelV1['doGenerate']>>> {
    // IMPORTANT: Cursor Agent CLI does NOT support custom tools from AI SDK
    // It only supports:
    // 1. Built-in tools (read_file, search_files, etc.)
    // 2. MCP server tools (via mcpServers config)
    if (options.mode?.type === 'regular' && options.mode.tools && Object.keys(options.mode.tools).length > 0) {
      const toolNames = Object.keys(options.mode.tools).join(', ');
      console.warn(
        `[cursor-agent] WARNING: Custom AI SDK tools (${toolNames}) will be IGNORED. ` +
        `Cursor Agent only supports built-in tools and MCP servers. ` +
        `Use mcpServers config or switch to Codex/Claude Code for custom tools.`
      );
    }

    const prompt = this.convertMessages(options.prompt);
    const model = this.config.model || this.modelId || 'auto';
    const approvalPolicy = this.config.approvalPolicy || 'read-only';
    const logLevel = this.config.logLevel || 'error';

    // Build CLI arguments
    const args: string[] = [
      '-p', // Non-interactive mode
      '--print', // Print output directly
      '--output-format', 'stream-json', // Structured output for parsing
    ];

    // Set model if not auto
    if (model && model !== 'auto') {
      args.push('--model', model);
    }

    // Configure tool approval policy
    if (approvalPolicy === 'read-only') {
      // Cursor Agent --rules flag for read-only tools
      // Only allow: read_file, list_files, search_files, grep, glob
      // Disallow: write_file, edit_file, shell, bash, execute
      args.push('--allow-tools', 'read_file,list_files,search_files,grep,glob');
    } else if (approvalPolicy === 'never') {
      args.push('--allow-all-tools');
    }

    // Add MCP server configuration if provided
    if (this.config.mcpServers && Object.keys(this.config.mcpServers).length > 0) {
      const mcpConfig = JSON.stringify({
        mcpServers: this.config.mcpServers,
      });
      args.push('--mcp-config', mcpConfig);
    }

    // Set working directory if provided
    if (this.config.workingDirectory) {
      args.push('--cwd', this.config.workingDirectory);
    }

    // Add any additional flags
    if (this.config.additionalFlags) {
      args.push(...this.config.additionalFlags);
    }

    // Add prompt as final argument
    args.push(prompt);

    // Execute cursor-agent CLI
    const proc = await this.execCommand('cursor-agent', args, this.config.workingDirectory);
    const output = proc.stdout;
    const stderr = proc.stderr;
    const exitCode = proc.exitCode;

    if (exitCode !== 0) {
      const error = stderr || output;
      throw new Error(`cursor-agent failed (${exitCode}): ${error}`);
    }

    if (logLevel === 'debug' || logLevel === 'info') {
      console.log('[cursor-agent] Raw output:', output.substring(0, 500));
    }

    // Parse stream-json output
    const result = this.parseStreamJson(output, logLevel);

    return {
      text: result.text,
      finishReason: 'stop' as const,
      usage: {
        promptTokens: this.estimateTokens(prompt),
        completionTokens: this.estimateTokens(result.text),
      },
      toolCalls: result.toolCalls,
      rawResponse: {
        headers: {},
      },
    } as any;
  }

  async doStream(options: Parameters<LanguageModelV1['doStream']>[0]): Promise<Awaited<ReturnType<LanguageModelV1['doStream']>>> {
    // Cursor Agent doesn't support proper streaming via CLI yet
    // Fall back to doGenerate and return as single chunk
    const result = await this.doGenerate(options);

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

  private convertMessages(prompt: any): string {
    // Convert AI SDK prompt format to Cursor Agent string prompt
    if (typeof prompt === 'string') {
      return prompt;
    }

    if (Array.isArray(prompt)) {
      return prompt
        .map((msg: any) => {
          const role = msg.role || 'user';
          const content = Array.isArray(msg.content)
            ? msg.content.map((c: any) => typeof c === 'string' ? c : c.text).join('\n')
            : msg.content;
          return `${role}: ${content}`;
        })
        .join('\n\n');
    }

    return String(prompt);
  }

  private parseStreamJson(output: string, logLevel: string): { text: string; toolCalls?: any[] } {
    let responseText = '';
    const toolCalls: any[] = [];
    const lines = output.trim().split('\n');

    for (const line of lines) {
      if (!line.trim()) continue;

      try {
        const event = JSON.parse(line);

        if (event.type === 'assistant' && event.message) {
          // Extract text from assistant messages
          for (const content of event.message.content || []) {
            if (content.type === 'text') {
              responseText += content.text;
            }
          }
        } else if (event.type === 'tool_call' && event.subtype === 'started') {
          // Record tool call
          const toolCall = event.tool_call;
          if (toolCall) {
            let toolName = 'unknown';
            let toolArgs = {};

            if (toolCall.shellToolCall) {
              toolName = 'shell';
              toolArgs = {
                command: toolCall.shellToolCall.args?.command,
                workingDirectory: toolCall.shellToolCall.args?.workingDirectory,
              };
            } else if (toolCall.mcpToolCall) {
              toolName = toolCall.mcpToolCall.name || 'mcp_tool';
              toolArgs = toolCall.mcpToolCall.arguments || {};
            } else if (toolCall.fileToolCall) {
              toolName = toolCall.fileToolCall.operation || 'file_operation';
              toolArgs = toolCall.fileToolCall.args || {};
            }

            toolCalls.push({
              toolCallType: 'function' as const,
              toolCallId: event.call_id || `call_${crypto.randomUUID()}`,
              toolName,
              args: JSON.stringify(toolArgs),
            });
          }
        } else if (event.type === 'result') {
          // Final result contains the complete response
          responseText = event.result || responseText;
        }
      } catch (e) {
        // Skip invalid JSON lines
        if (logLevel === 'debug' || logLevel === 'warn') {
          console.warn('[cursor-agent] Failed to parse JSON line:', line.substring(0, 100));
        }
      }
    }

    return {
      text: responseText.trim(),
      toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
    };
  }

  private estimateTokens(text: string): number {
    if (!text) return 0;
    // Rough estimate: 1 token ≈ 4 bytes
    return Math.ceil(Buffer.byteLength(text, 'utf8') / 4);
  }

  private async execCommand(command: string, args: string[], cwd?: string): Promise<{ stdout: string; stderr: string; exitCode: number }> {
    // Use Bun runtime if available, otherwise fall back to Node's child_process
    if (typeof (globalThis as any).Bun !== 'undefined') {
      const BunRuntime = (globalThis as any).Bun;
      const proc = BunRuntime.spawn([command, ...args], {
        stdout: 'pipe',
        stderr: 'pipe',
        cwd,
      });

      const stdout = await new Response(proc.stdout).text();
      const stderr = await new Response(proc.stderr).text();
      const exitCode = await proc.exited;

      return { stdout, stderr, exitCode };
    } else {
      // Fallback for Node.js
      const { execFileSync } = await import('child_process');
      try {
        const stdout = execFileSync(command, args, {
          cwd,
          encoding: 'utf8',
          maxBuffer: 10 * 1024 * 1024, // 10MB
        });
        return { stdout, stderr: '', exitCode: 0 };
      } catch (error: any) {
        return {
          stdout: error.stdout || '',
          stderr: error.stderr || error.message,
          exitCode: error.status || 1,
        };
      }
    }
  }
}
