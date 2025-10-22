/**
 * @file Tool Auto-Translation
 * @description Automatically translates AI SDK tools to provider-specific formats
 * (MCP servers, OpenAI functions, etc.)
 */

import type { ToolPolicy } from './provider-capabilities';

/**
 * Convert AI SDK tools to MCP server configuration
 * Used for providers that only support MCP (e.g., Cursor)
 */
export function convertToolsToMCP(tools: Record<string, any>): Record<string, {
  command: string;
  args?: string[];
  env?: Record<string, string>;
}> {
  const mcpServers: Record<string, any> = {};

  // For each AI SDK tool, create an MCP server wrapper
  for (const [toolName, toolDef] of Object.entries(tools)) {
    // Create a lightweight MCP server that wraps the tool
    // This would typically be a Node.js script that:
    // 1. Accepts MCP protocol messages
    // 2. Calls the actual tool implementation
    // 3. Returns results in MCP format

    mcpServers[toolName] = {
      command: 'node',
      args: [
        // Path to MCP wrapper script
        `./mcp-wrappers/${toolName}-mcp-server.js`,
      ],
      env: {
        TOOL_NAME: toolName,
        // Pass tool configuration as env vars
        TOOL_CONFIG: JSON.stringify(toolDef),
      },
    };
  }

  return mcpServers;
}

/**
 * Convert AI SDK tools to OpenAI function calling format
 * Used for providers that support OpenAI-style functions
 */
export function convertToolsToOpenAIFunctions(tools: Record<string, any>): any[] {
  const functions: any[] = [];

  for (const [toolName, toolDef] of Object.entries(tools)) {
    // Extract schema from AI SDK tool
    const { description, parameters } = toolDef;

    functions.push({
      name: toolName,
      description: description || `Execute ${toolName}`,
      parameters: parameters || {
        type: 'object',
        properties: {},
        required: [],
      },
    });
  }

  return functions;
}

/**
 * Translate internal tools policy to provider-specific format
 */
export function translateInternalTools(
  provider: string,
  internalTools: 'none' | 'read' | 'write' = 'none'
): any {
  switch (provider) {
    case 'openai-codex':
      // Codex uses sandboxMode
      if (internalTools === 'none') return { sandboxMode: undefined };
      if (internalTools === 'read') return { sandboxMode: 'read-only' };
      if (internalTools === 'write') return { sandboxMode: 'workspace-write' };
      break;

    case 'cursor-agent-cli':
      // Cursor uses approvalPolicy
      if (internalTools === 'none') return { approvalPolicy: undefined };
      if (internalTools === 'read') return { approvalPolicy: 'read-only' };
      // Cursor doesn't support write mode for internal tools
      if (internalTools === 'write') return { approvalPolicy: 'never' };
      break;

    case 'claude-code':
      // Claude Code has built-in file access, configuration TBD
      return {};

    default:
      return {};
  }

  return {};
}

/**
 * Auto-translate tool policy to provider-specific options
 * This is the main entry point that requesters use
 */
export function translateToolPolicy(
  provider: string,
  policy: ToolPolicy,
  capabilities: any
): any {
  const providerOptions: any = {};

  // 1. Handle internal tools (file access, shell commands)
  if (policy.internalTools) {
    Object.assign(providerOptions, translateInternalTools(provider, policy.internalTools));
  }

  // 2. Handle custom tools
  if (policy.customTools && Object.keys(policy.customTools).length > 0) {
    if (capabilities.supportsAISDKTools) {
      // Best case - use AI SDK tools directly
      providerOptions.tools = policy.customTools;
    } else if (capabilities.supportsMCP) {
      // Convert AI SDK tools → MCP servers
      console.log(`[tool-translator] Converting ${Object.keys(policy.customTools).length} AI SDK tools to MCP servers for ${provider}`);
      const mcpFromTools = convertToolsToMCP(policy.customTools);
      providerOptions.mcpServers = {
        ...providerOptions.mcpServers,
        ...mcpFromTools,
      };
    } else if (capabilities.supportsOpenAIFunctions) {
      // Convert AI SDK tools → OpenAI functions
      console.log(`[tool-translator] Converting ${Object.keys(policy.customTools).length} AI SDK tools to OpenAI functions for ${provider}`);
      providerOptions.functions = convertToolsToOpenAIFunctions(policy.customTools);
    } else {
      console.warn(`[tool-translator] Provider ${provider} does not support custom tools - ignoring`);
    }
  }

  // 3. Handle MCP servers (always pass through if specified)
  if (policy.mcpServers && Object.keys(policy.mcpServers).length > 0) {
    if (capabilities.supportsMCP) {
      providerOptions.mcpServers = {
        ...providerOptions.mcpServers,
        ...policy.mcpServers,
      };
    } else {
      console.warn(`[tool-translator] Provider ${provider} does not support MCP servers - ignoring`);
    }
  }

  return providerOptions;
}
