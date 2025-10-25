/**
 * Cursor Agent Provider
 *
 * CLI-based provider for Cursor Agent (cursor-agent command).
 * Cursor Agent is a proprietary tool that requires a Cursor subscription.
 *
 * Key Features:
 * - Read-only tools: file read, search, grep, etc. (NO write/execute)
 * - MCP tools support: Can use MCP servers for additional capabilities
 * - Auto model selection or explicit model choice (gpt-4.1, sonnet-4, etc.)
 *
 * Auth: `cursor-agent login` (browser OAuth)
 * Docs: https://cursor.com/docs/cli
 */

import type { Message as AIMessage } from 'ai';

/**
 * Model metadata for Cursor Agent provider
 */
export const CURSOR_AGENT_MODELS = [
  {
    id: 'auto',
    displayName: 'Cursor Agent (Auto)',
    description: 'Auto model selection - lets Cursor choose best model (FREE on subscription)',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
    cost: 'subscription' as const,
    subscription: 'Cursor Pro/Business',
  },
  {
    id: 'gpt-4.1',
    displayName: 'Cursor Agent GPT-4.1',
    description: 'Explicit GPT-4.1 selection via Cursor Agent',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
    cost: 'subscription' as const,
    subscription: 'Cursor Pro/Business',
  },
  {
    id: 'sonnet-4',
    displayName: 'Cursor Agent Sonnet 4',
    description: 'Claude Sonnet 4 via Cursor Agent',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: true, tools: true },
    cost: 'subscription' as const,
    subscription: 'Cursor Pro/Business',
  },
  {
    id: 'sonnet-4-thinking',
    displayName: 'Cursor Agent Sonnet 4 (Thinking)',
    description: 'Claude Sonnet 4 with extended thinking via Cursor Agent',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: true, tools: true },
    cost: 'subscription' as const,
    subscription: 'Cursor Pro/Business',
  },
] as const;

/**
 * Configuration for Cursor Agent execution
 */
export interface CursorAgentConfig {
  /** Model to use (default: 'auto') */
  model?: string;
  /** Approval policy for tool execution (default: 'read-only') */
  approvalPolicy?: 'read-only' | 'never' | 'always';
  /** MCP server configurations to enable */
  mcpServers?: MCPServerConfig[];
  /** Working directory for Cursor Agent */
  workingDirectory?: string;
  /** Additional CLI flags */
  additionalFlags?: string[];
}

/**
 * MCP Server configuration
 */
export interface MCPServerConfig {
  /** Server name/ID */
  name: string;
  /** Command to execute */
  command: string;
  /** Command arguments */
  args?: string[];
  /** Environment variables */
  env?: Record<string, string>;
}

/**
 * Result from Cursor Agent execution
 */
export interface CursorAgentResult {
  /** Response text */
  text: string;
  /** Finish reason */
  finishReason: string;
  /** Tool calls detected (if any) */
  toolCalls?: Array<{
    id: string;
    type: 'function';
    function: {
      name: string;
      arguments: string;
    };
  }>;
  /** Raw output for debugging */
  rawOutput?: string;
}

/**
 * Convert AI SDK messages to Cursor Agent prompt format
 */
function messagesToPrompt(messages: AIMessage[]): string {
  return messages
    .map((m) => {
      const role = typeof m.role === 'string' ? m.role : 'user';
      const content = Array.isArray(m.content)
        ? m.content.map(c => typeof c === 'string' ? c : c.text).join('\n')
        : m.content;
      return `${role}: ${content}`;
    })
    .join('\n\n');
}

/**
 * Build MCP server configuration for Cursor Agent
 */
function buildMCPConfig(servers?: MCPServerConfig[]): string | null {
  if (!servers || servers.length === 0) {
    return null;
  }

  // Cursor Agent expects MCP config in JSON format
  const config = {
    mcpServers: servers.reduce((acc, server) => {
      acc[server.name] = {
        command: server.command,
        args: server.args || [],
        env: server.env || {},
      };
      return acc;
    }, {} as Record<string, any>),
  };

  return JSON.stringify(config);
}

/**
 * Execute Cursor Agent with read-only tools + MCP support
 */
export async function executeCursorAgent(
  messages: AIMessage[],
  config: CursorAgentConfig = {},
): Promise<CursorAgentResult> {
  const prompt = messagesToPrompt(messages);
  const model = config.model || 'auto';
  const approvalPolicy = config.approvalPolicy || 'read-only';

  // Build CLI arguments
  const args: string[] = [
    '-p', // Non-interactive mode
    '--print', // Print output directly
    '--output-format', 'stream-json', // Structured output for parsing tool calls
  ];

  // Set model if not auto
  if (model && model !== 'auto') {
    args.push('--model', model);
  }

  // Configure tool approval policy
  // READ-ONLY: Allow only safe read operations (file read, search, grep)
  // NEVER: Auto-approve all tools (use with caution!)
  // ALWAYS: Prompt for approval (not suitable for API use)
  if (approvalPolicy === 'read-only') {
    // Cursor Agent doesn't have explicit read-only mode
    // We'll use rules to restrict to read operations
    args.push('--rules', JSON.stringify({
      allowedTools: [
        'read_file',
        'list_files',
        'search_files',
        'grep',
        'glob',
        // MCP tools are allowed (configured separately)
      ],
      disallowedTools: [
        'write_file',
        'edit_file',
        'shell', // NO shell execution
        'bash',
        'execute',
      ],
    }));
  } else if (approvalPolicy === 'never') {
    args.push('--allow-all-tools');
  }

  // Add MCP server configuration if provided
  const mcpConfig = buildMCPConfig(config.mcpServers);
  if (mcpConfig) {
    args.push('--mcp-config', mcpConfig);
  }

  // Set working directory if provided
  if (config.workingDirectory) {
    args.push('--cwd', config.workingDirectory);
  }

  // Add any additional flags
  if (config.additionalFlags) {
    args.push(...config.additionalFlags);
  }

  // Add prompt as final argument
  args.push(prompt);

  // Execute cursor-agent CLI
  const proc = Bun.spawn(['cursor-agent', ...args], {
    stdout: 'pipe',
    stderr: 'pipe',
    cwd: config.workingDirectory,
  });

  const output = await new Response(proc.stdout).text();
  const exitCode = await proc.exited;

  if (exitCode !== 0) {
    const error = await new Response(proc.stderr).text();
    throw new Error(`cursor-agent failed (${exitCode}): ${error || output}`);
  }

  // Parse stream-json output to extract text and tool calls
  let responseText = '';
  const toolCalls: CursorAgentResult['toolCalls'] = [];
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
        // Record tool call start
        const toolCall = event.tool_call;
        if (toolCall?.shellToolCall) {
          // Shell tool (should be blocked if read-only)
          toolCalls.push({
            id: event.call_id || `call_${crypto.randomUUID()}`,
            type: 'function',
            function: {
              name: 'shell',
              arguments: JSON.stringify({
                command: toolCall.shellToolCall.args?.command,
                workingDirectory: toolCall.shellToolCall.args?.workingDirectory,
              }),
            },
          });
        } else if (toolCall?.mcpToolCall) {
          // MCP tool
          toolCalls.push({
            id: event.call_id || `call_${crypto.randomUUID()}`,
            type: 'function',
            function: {
              name: toolCall.mcpToolCall.name,
              arguments: JSON.stringify(toolCall.mcpToolCall.arguments || {}),
            },
          });
        } else if (toolCall?.fileToolCall) {
          // File operation tool
          toolCalls.push({
            id: event.call_id || `call_${crypto.randomUUID()}`,
            type: 'function',
            function: {
              name: toolCall.fileToolCall.operation || 'file_operation',
              arguments: JSON.stringify(toolCall.fileToolCall.args || {}),
            },
          });
        }
      } else if (event.type === 'result') {
        // Final result contains the complete response
        responseText = event.result || responseText;
      }
    } catch (e) {
      // Skip invalid JSON lines (might be debug output)
      console.warn('[cursor-agent] Failed to parse JSON line:', line.substring(0, 100));
    }
  }

  return {
    text: responseText.trim(),
    finishReason: 'stop',
    toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
    rawOutput: output,
  };
}

/**
 * Extended Cursor Agent provider with model listing
 */
export interface CursorAgentProvider {
  listModels(): typeof CURSOR_AGENT_MODELS;
  execute(messages: AIMessage[], config?: CursorAgentConfig): Promise<CursorAgentResult>;
}

/**
 * Cursor Agent provider instance
 */
export const cursorAgent: CursorAgentProvider = {
  listModels: () => CURSOR_AGENT_MODELS,
  execute: executeCursorAgent,
};
