/**
 * @file Provider Capabilities and Tool Auto-Translation
 * @description Provider-agnostic interface for tool configuration with automatic
 * translation to provider-specific formats (AI SDK tools, MCP servers, OpenAI functions).
 */

/**
 * Provider capability matrix - what tool formats each provider supports
 */
export interface ProviderCapabilities {
  /** Native AI SDK tool calling support */
  supportsAISDKTools: boolean;
  /** MCP server support for external tools */
  supportsMCP: boolean;
  /** OpenAI-style function calling */
  supportsOpenAIFunctions: boolean;
  /** Built-in internal tools (file operations, shell commands) */
  supportsInternalTools: 'none' | 'read' | 'write';
}

/**
 * Provider capability registry
 * Maps provider names to their capabilities
 */
export const PROVIDER_CAPABILITIES: Record<string, ProviderCapabilities> = {
  'openai-codex': {
    supportsAISDKTools: true,      // Native AI SDK support via Codex SDK
    supportsMCP: true,              // Can wrap as MCP if needed
    supportsOpenAIFunctions: true,  // OpenAI-compatible
    supportsInternalTools: 'write', // Full file + shell access via sandboxMode
  },
  'claude-code': {
    supportsAISDKTools: true,       // Native AI SDK support
    supportsMCP: false,             // Not yet supported
    supportsOpenAIFunctions: false, // Anthropic format, not OpenAI
    supportsInternalTools: 'write', // Full access via Claude Code CLI
  },
  'cursor-agent-cli': {
    supportsAISDKTools: false,      // ❌ Custom tools NOT supported
    supportsMCP: true,              // ✅ MCP servers only
    supportsOpenAIFunctions: false,
    supportsInternalTools: 'read',  // Read-only by default
  },
  'github-copilot': {
    supportsAISDKTools: true,       // Native AI SDK support
    supportsMCP: false,
    supportsOpenAIFunctions: true,  // OpenAI-compatible
    supportsInternalTools: 'none',  // No built-in file access
  },
  'github-models': {
    supportsAISDKTools: true,       // Native AI SDK support
    supportsMCP: false,
    supportsOpenAIFunctions: true,  // OpenAI-compatible
    supportsInternalTools: 'none',  // No built-in file access
  },
  'gemini-code': {
    supportsAISDKTools: true,       // Native AI SDK support
    supportsMCP: false,
    supportsOpenAIFunctions: false, // Google format, not OpenAI
    supportsInternalTools: 'none',  // No built-in file access
  },
  'google-jules': {
    supportsAISDKTools: false,      // Custom Jules interface
    supportsMCP: false,
    supportsOpenAIFunctions: false,
    supportsInternalTools: 'write', // Full autonomous agent
  },
};

/**
 * Unified tool policy configuration (provider-agnostic)
 */
export interface ToolPolicy {
  /** Built-in internal tools (file access, shell commands) */
  internalTools?: 'none' | 'read' | 'write';

  /** Custom AI SDK tools */
  customTools?: Record<string, any>;

  /** MCP servers for external tools */
  mcpServers?: Record<string, {
    command: string;
    args?: string[];
    env?: Record<string, string>;
  }>;
}

/**
 * Get provider capabilities by provider name
 */
export function getProviderCapabilities(provider: string): ProviderCapabilities | undefined {
  return PROVIDER_CAPABILITIES[provider];
}

/**
 * Check if a provider supports a specific capability
 */
export function providerSupports(
  provider: string,
  capability: keyof Omit<ProviderCapabilities, 'supportsInternalTools'>
): boolean {
  const caps = getProviderCapabilities(provider);
  return caps?.[capability] ?? false;
}
