/**
 * @file Unified LLM Interface
 * @description Provider-agnostic interface for LLM calls with automatic tool translation.
 *
 * Requesters use a single unified interface, and the system automatically translates
 * to provider-specific formats.
 */

import { generateText, streamText, type LanguageModel } from 'ai';
import { getProviderCapabilities, type ToolPolicy } from './provider-capabilities';
import { translateToolPolicy } from './tool-translator';
import { autoSelectTools } from './tool-selector';
import type { ModelInfo } from './model-registry';

/**
 * Unified request interface (provider-agnostic)
 */
export interface UnifiedLLMRequest {
  /** Model ID in format: provider:model */
  model: string;

  /** Messages for the conversation */
  messages: any[];

  /** Tool policy (automatically translated per provider) */
  toolPolicy?: ToolPolicy;

  /** Auto-select tools based on task and model capacity (default: true) */
  autoSelectTools?: boolean;

  /** Standard generation options */
  temperature?: number;
  maxTokens?: number;
  topP?: number;

  /** Streaming mode */
  stream?: boolean;
}

/**
 * Parse model ID into provider and model name
 */
function parseModelId(modelId: string): { provider: string; model: string } {
  const parts = modelId.split(':');
  if (parts.length !== 2) {
    throw new Error(`Invalid model ID format: ${modelId}. Expected format: provider:model`);
  }
  return { provider: parts[0], model: parts[1] };
}

/**
 * Get language model instance from provider registry
 */
function getLanguageModel(providerName: string, modelName: string, providers: Record<string, any>): LanguageModel {
  const provider = providers[providerName];
  if (!provider) {
    throw new Error(`Provider ${providerName} not found`);
  }

  if (typeof provider.languageModel === 'function') {
    return provider.languageModel(modelName);
  }

  throw new Error(`Provider ${providerName} does not support languageModel`);
}

/**
 * Main unified interface - automatically translates tool policy to provider format
 *
 * @example
 * ```typescript
 * // Same interface works with ANY provider
 * const result = await unifiedGenerate({
 *   model: 'openai-codex:gpt-5-codex',
 *   messages: [{ role: 'user', content: 'Write a function' }],
 *   toolPolicy: {
 *     internalTools: 'read',  // Auto-translated to sandboxMode for Codex
 *     customTools: { myTool: {...} }  // Auto-translated to best format
 *   }
 * }, providers);
 *
 * // Switch to Cursor - same interface!
 * const result2 = await unifiedGenerate({
 *   model: 'cursor-agent-cli:auto',
 *   messages: [{ role: 'user', content: 'Write a function' }],
 *   toolPolicy: {
 *     internalTools: 'read',  // Auto-translated to approvalPolicy for Cursor
 *     customTools: { myTool: {...} }  // Auto-translated to MCP servers for Cursor
 *   }
 * }, providers);
 * ```
 */
export async function unifiedGenerate(
  request: UnifiedLLMRequest,
  providers: Record<string, any>,
  modelCatalog?: ModelInfo[]
) {
  const { provider, model } = parseModelId(request.model);

  // Get provider capabilities
  const capabilities = getProviderCapabilities(provider);
  if (!capabilities) {
    throw new Error(`Unknown provider: ${provider}`);
  }

  // Get language model instance
  const languageModel = getLanguageModel(provider, model, providers);

  // Get model info for tool selection
  const modelInfo = modelCatalog?.find(m => m.id === request.model);

  // Auto-select tools if enabled and we have custom tools
  let toolPolicy = request.toolPolicy;
  if ((request.autoSelectTools ?? true) && toolPolicy?.customTools && modelInfo) {
    const { selectedTools, reasoning } = autoSelectTools({
      model: modelInfo,
      messages: request.messages,
      availableTools: toolPolicy.customTools,
    });

    console.log(`[unified-llm] Auto-selected tools: ${reasoning}`);

    toolPolicy = {
      ...toolPolicy,
      customTools: selectedTools,
    };
  }

  // Auto-translate tool policy to provider-specific options
  const providerOptions = toolPolicy
    ? translateToolPolicy(provider, toolPolicy, capabilities)
    : {};

  console.log(`[unified-llm] Calling ${provider}:${model} with auto-translated options:`,
    JSON.stringify(providerOptions, null, 2));

  // Call AI SDK with translated options
  if (request.stream) {
    return streamText({
      model: languageModel,
      messages: request.messages,
      temperature: request.temperature,
      maxTokens: request.maxTokens,
      topP: request.topP,
      ...providerOptions,
    });
  } else {
    return generateText({
      model: languageModel,
      messages: request.messages,
      temperature: request.temperature,
      maxTokens: request.maxTokens,
      topP: request.topP,
      ...providerOptions,
    });
  }
}

/**
 * Streaming version of unified interface
 */
export async function unifiedStream(
  request: Omit<UnifiedLLMRequest, 'stream'>,
  providers: Record<string, any>
) {
  return unifiedGenerate({ ...request, stream: true }, providers);
}
