#!/usr/bin/env bun

/**
 * @file Unified AI provider server.
 * @description This file contains the main server logic for the AI provider gateway.
 * It uses the Vercel AI SDK to create a unified interface for various AI models,
 * including those from Google, Anthropic, OpenAI, and GitHub. The server
 * handles model cataloging, request routing, streaming, and authentication.
 *
 * @see {@link ./docs/PROVIDER_STRATEGY.md} for an overview of the provider strategy.
 * @see {@link ./docs/PRODUCTION_READINESS.md} for production readiness details.
 */

import { generateText, streamText } from 'ai';
import { createGeminiProvider } from './providers/gemini-code';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from './providers/codex';

import { loadCredentialsFromEnv, checkCredentialAvailability, printCredentialStatus } from './load-credentials';
import { copilot } from './providers/copilot';
import { githubModels } from './providers/github-models';
import { ElixirBridge } from './elixir-bridge';
import { jules, createJulesModel } from './providers/google-ai-jules';
import { buildModelCatalog, type ProviderWithModels, type ProviderWithMetadata } from './model-registry';
import { logger } from './logger.js';
import { metrics } from './metrics.js';

// Load credentials
const green = '\x1b[32m';
const blue = '\x1b[34m';
const red = '\x1b[31m';
const reset = '\x1b[0m';
const bold = '\x1b[1m';

console.log(`${blue}🔐${reset} Loading AI provider credentials...`);
loadCredentialsFromEnv();
const allStats = checkCredentialAvailability();
printCredentialStatus(allStats);

/** The port for the main server. */
const PORT = parsePort(process.env.PORT, 3000, 'PORT');

/** A simple, non-secure auth token for internal API access. */
const AUTH_TOKEN = 'singularity-local';

// Initialize AI SDK Providers
const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

// Provider mapping for easy access
const providers = {
  'gemini-code': geminiCode,
  'claude-code': claudeCode,
  'openai-codex': codex,
  'github-copilot': copilot,
  'github-models': githubModels,
};

// Helper function to get language model from provider
function getLanguageModel(providerName: string, modelId: string) {
  const provider = providers[providerName as keyof typeof providers];
  if (!provider) {
    throw new Error(`Provider ${providerName} not found`);
  }

  // Handle different provider types
  if (typeof provider.languageModel === 'function') {
    return provider.languageModel(modelId);
  }

  throw new Error(`Provider ${providerName} does not support languageModel`);
}

// Helper function to handle Jules streaming
async function handleJulesStreaming(
  request: ChatRequest,
  modelEntry: ModelCatalogEntry,
): Promise<Response> {
  const encoder = new TextEncoder();
  const id = `chatcmpl-${crypto.randomUUID()}`;
  const created = Math.floor(Date.now() / 1000);

  const stream = new ReadableStream({
    async start(controller) {
      try {
        // Create Jules model and start streaming
        const model = createJulesModel();
        const streamResult = await model.doStream({
          messages: request.messages,
          temperature: request.temperature ?? 0.7,
        });

        // Send role chunk first
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({
          id,
          object: 'chat.completion.chunk',
          created,
          model: modelEntry.id,
          choices: [{
            index: 0,
            delta: { role: 'assistant' },
            finish_reason: null,
          }],
        })}\n\n`));

        // Stream the content
        for await (const chunk of streamResult.stream()) {
          if (chunk.type === 'text') {
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({
              id,
              object: 'chat.completion.chunk',
              created,
              model: modelEntry.id,
              choices: [{
                index: 0,
                delta: { content: chunk.text },
                finish_reason: null,
              }],
            })}\n\n`));
          }
        }

        // Send final chunk
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({
          id,
          object: 'chat.completion.chunk',
          created,
          model: modelEntry.id,
          choices: [{
            index: 0,
            delta: {},
            finish_reason: 'stop',
          }],
        })}\n\n`));

        controller.enqueue(encoder.encode('data: [DONE]\n\n'));
        controller.close();
      } catch (error) {
        logger.error('Jules streaming error:', error);
        controller.error(error);
      }
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
}

// Helper function to handle Jules generation
async function handleJulesGeneration(request: ChatRequest): Promise<any> {
  const model = createJulesModel();
  const result = await model.doGenerate({
    messages: request.messages,
    temperature: request.temperature ?? 0.7,
  });

  return {
    text: result.text,
    usage: result.usage,
    finishReason: result.finishReason,
    toolCalls: [],
    metadata: result.metadata,
  };
}

// Build model catalog (dynamic with hourly refresh)
let MODELS: Awaited<ReturnType<typeof buildModelCatalog>> = [];
let DYNAMIC_MODEL_CATALOG: ModelCatalogEntry[] = [];

/**
 * Asynchronously refreshes the model catalog from all registered providers.
 *
 * This function clears the existing model catalog and rebuilds it by calling
 * the `buildModelCatalog` function. It also applies post-processing logic,
 * such as setting cost tiers for GitHub Copilot models. If the refresh fails,
 * it logs a warning and continues with the stale catalog to maintain server
 * availability.
 *
 * @returns {Promise<void>} A promise that resolves when the catalog has been refreshed.
 */
async function refreshModelCatalog(): Promise<void> {
  console.log(`${blue}🔄${reset} Refreshing model catalog...`);

  // Ensure GitHub Models are loaded first
  try {
    await githubModels.refreshModels();
  } catch (error: any) {
    console.warn('⚠️  Failed to load GitHub Models:', error.message);
  }

  try {
    MODELS = await buildModelCatalog({
      'gemini-code': geminiCode as unknown as ProviderWithModels,
      'claude-code': claudeCode as unknown as ProviderWithModels,
      'openai-codex': codex as unknown as ProviderWithMetadata,
      'google-jules': jules as unknown as ProviderWithModels,
      'github-copilot': copilot as unknown as ProviderWithMetadata,
      'github-models': githubModels as unknown as ProviderWithMetadata,
    });
  } catch (error: any) {
    console.error('❌ Failed to build model catalog:', error.message);
    console.warn('⚠️  Using existing MODELS catalog to prevent stale data');
    return; // Keep existing MODELS intact
  }

  // Post-process: Apply correct cost tiers to Copilot models
  const FREE_COPILOT_MODELS = new Set(['gpt-4.1', 'gpt-5-mini', 'grok-code-fast-1']);
  MODELS = MODELS.map(m => {
    if (m.provider === 'github-copilot') {
      return {
        ...m,
        cost: FREE_COPILOT_MODELS.has(m.model) ? ('free' as const) : ('limited' as const),
        subscription: 'GitHub Copilot',
      };
    }
    return m;
  });

  console.log(`${blue}✨${reset} AI SDK Provider Registry updated`);
  console.log(`   Providers: ${Object.keys(MODELS.reduce((acc: any, m: any) => ({ ...acc, [m.provider]: true }), {})).join(', ')}`);
  console.log(`   Models: ${MODELS.length} total`);

  const copilotModels = MODELS.filter(m => m.provider === 'github-copilot');
  if (copilotModels.length > 0) {
    console.log(`   Copilot: ${copilotModels.length} models (${copilotModels.filter(m => m.cost === 'free').length} free, ${copilotModels.filter(m => m.cost === 'limited').length} limited)`);
  }

  // Convert MODELS to ModelCatalogEntry format
  DYNAMIC_MODEL_CATALOG = MODELS.map(m => ({
  id: m.id,
  upstreamId: m.model,
  provider: m.provider as any,
  displayName: m.displayName,
  description: m.description,
  ownedBy: m.provider,
  contextWindow: m.contextWindow,
  cost: m.cost,
  subscription: m.subscription,
  capabilities: {
    completion: m.capabilities.completion,
    streaming: m.capabilities.streaming,
    reasoning: m.capabilities.reasoning,
    vision: m.capabilities.vision,
    tools: m.capabilities.tools,
  },
  }));
}

// Initial load + schedule hourly refresh (non-blocking)
(async () => {
  try {
    await refreshModelCatalog();
  } catch (error: any) {
    console.error('❌ Initial model catalog refresh failed:', error.message);
    console.warn('⚠️  Server starting with empty catalog - models will load on first request');
  }

  // Refresh every hour
  setInterval(async () => {
    try {
      await refreshModelCatalog();
    } catch (error: any) {
      console.error('❌ Scheduled model catalog refresh failed:', error.message);
      console.warn('⚠️  Continuing with existing catalog');
    }
  }, 60 * 60 * 1000); // 1 hour
})();

// Initialize Elixir bridge
const elixirBridge = new ElixirBridge();
elixirBridge.connect().catch(err => {
  console.warn('⚠️  Elixir bridge connection failed, using direct mode:', err.message);
});

// ============================================
// Types & Utilities
// ============================================

/**
 * Parses a port number from a string value.
 *
 * @param {string | undefined} value The string value to parse.
 * @param {number} fallback The fallback port to use if parsing fails.
 * @param {string} label A label for the port being parsed, used in warnings.
 * @returns {number} The parsed port number or the fallback.
 */
function parsePort(value: string | undefined, fallback: number, label:string): number {
  if (!value || value.trim().length === 0) {
    return fallback;
  }
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > 65535) {
    console.warn(`Invalid ${label}="${value}"; falling back to ${fallback}`);
    return fallback;
  }
  return parsed;
}

/**
 * @interface Message
 * @description Represents a single message in a chat conversation, following the OpenAI format.
 * @property {'system' | 'user' | 'assistant'} role The role of the message author.
 * @property {string} content The content of the message.
 */
interface Message {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

/**
 * @interface UsageSummary
 * @description Summarizes token usage for a request.
 * @property {number} promptTokens The number of tokens in the prompt.
 * @property {number} completionTokens The number of tokens in the completion.
 * @property {number} totalTokens The total number of tokens used.
 */
interface UsageSummary {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

/**
 * @interface Tool
 * @description Defines a tool that the AI model can call, following the OpenAI format.
 * @property {'function'} type The type of the tool.
 * @property {object} function The function definition.
 * @property {string} function.name The name of the function.
 * @property {string} [function.description] A description of the function.
 * @property {object} [function.parameters] The parameters for the function.
 */
interface Tool {
  type: 'function';
  function: {
    name: string;
    description?: string;
    parameters?: {
      type: 'object';
      properties?: Record<string, any>;
      required?: string[];
    };
  };
}

/**
 * @interface ChatRequest
 * @description Represents an internal request for a chat completion.
 * @property {string} provider The AI provider to use.
 * @property {string} [model] The specific model to use.
 * @property {Message[]} messages An array of messages in the conversation.
 * @property {number} [temperature] The sampling temperature.
 * @property {number} [maxTokens] The maximum number of tokens to generate.
 * @property {Tool[]} [tools] An array of tools the model can use.
 * @property {boolean} [expectJsonObject] Whether to expect a JSON object as a response.
 * @property {boolean} [stream] Whether to stream the response.
 */
interface ChatRequest {
  provider:
    | 'gemini-code-cli'
    | 'gemini-code'
    | 'google-jules'
    | 'claude-code-cli'
    | 'codex-cli'
    | 'cursor-agent-cli'
    | 'copilot-cli'
    | 'copilot-api'
    | 'github-models'
    | 'github-copilot';
  model?: string;
  messages: Message[];
  temperature?: number;
  maxTokens?: number;
  tools?: Tool[];
  expectJsonObject?: boolean;
  stream?: boolean;
}

/**
 * @interface ProviderResult
 * @description Represents the result from a provider after a chat completion.
 * @property {string} text The generated text.
 * @property {string} finishReason The reason the model stopped generating text.
 * @property {UsageSummary} usage Token usage information.
 * @property {string} model The model that was used.
 *property {ChatRequest['provider']} provider The provider that was used.
 * @property {object[]} [toolCalls] Any tool calls made by the model.
 */
interface ProviderResult {
  text: string;
  finishReason: string;
  usage: UsageSummary;
  model: string;
  provider: ChatRequest['provider'];
  toolCalls?: Array<{
    id: string;
    type: 'function';
    function: {
      name: string;
      arguments: string;
    };
  }>;
}

/**
 * Estimates the number of tokens in a given text.
 *
 * This function uses a simple heuristic: 1 token is approximately 4 bytes.
 * It is a rough estimate and may not match the exact token count of a specific model.
 *
 * @param {string | null | undefined} text The text to estimate.
 * @returns {number} The estimated number of tokens.
 */
function estimateTokensFromText(text?: string | null): number {
  if (!text) return 0;
  const bytes = Buffer.byteLength(text, 'utf8');
  if (bytes === 0) return 0;
  return Math.max(1, Math.ceil(bytes / 4));
}

/**
 * Estimates the total number of tokens in an array of messages.
 *
 * @param {Message[]} messages The messages to estimate.
 * @returns {number} The estimated total number of tokens.
 */
function estimateTokensFromMessages(messages: Message[]): number {
  return messages.reduce((sum, message) => sum + estimateTokensFromText(message.content), 0);
}

/**
 * Normalizes the token usage data from different provider formats into a single,
 * consistent `UsageSummary` object.
 *
 * This function handles various keys for input, output, and total tokens that
 * different providers might return. If the provider does not return usage data,
 * it falls back to estimating the tokens based on message and response text length.
 *
 * @param {Message[]} messages The input messages sent to the provider.
 * @param {string} [generatedText] The text generated by the provider.
 * @param {any} [usage] The raw usage data from the provider.
 * @returns {UsageSummary} A normalized usage summary.
 */
function normalizeUsage(
  messages: Message[],
  generatedText?: string,
  usage?: any,
): UsageSummary {
  const promptFromUsage = typeof usage?.inputTokens === 'number' ? usage.inputTokens :
                          typeof usage?.prompt_tokens === 'number' ? usage.prompt_tokens :
                          typeof usage?.input_tokens === 'number' ? usage.input_tokens : undefined;
  const completionFromUsage = typeof usage?.completionTokens === 'number' ? usage.completionTokens :
                               typeof usage?.completion_tokens === 'number' ? usage.completion_tokens :
                               typeof usage?.output_tokens === 'number' ? usage.output_tokens : undefined;
  let totalFromUsage = typeof usage?.totalTokens === 'number' ? usage.totalTokens :
                       typeof usage?.total_tokens === 'number' ? usage.total_tokens :
                       typeof usage?.total === 'number' ? usage.total : undefined;

  if (typeof promptFromUsage === 'number' && typeof completionFromUsage === 'number') {
    if (typeof totalFromUsage !== 'number') {
      totalFromUsage = promptFromUsage + completionFromUsage;
    }

    return {
      promptTokens: promptFromUsage,
      completionTokens: completionFromUsage,
      totalTokens: totalFromUsage,
    };
  }

  const estimatedPrompt = estimateTokensFromMessages(messages);
  const estimatedCompletion = estimateTokensFromText(generatedText);
  const estimatedTotal = estimatedPrompt + estimatedCompletion;

  return {
    promptTokens: estimatedPrompt,
    completionTokens: estimatedCompletion,
    totalTokens: estimatedTotal,
  };
}

/**
 * Converts an array of OpenAI-formatted tools to the AI SDK format.
 *
 * @param {Tool[]} openaiTools An array of tools in OpenAI's format.
 * @returns {Record<string, any>} A record of tools compatible with the AI SDK.
 */
function convertOpenAIToolsToAISDK(openaiTools: Tool[]) {
  const tools: Record<string, any> = {};

  for (const tool of openaiTools) {
    tools[tool.function.name] = {
      description: tool.function.description || '',
      parameters: tool.function.parameters || {},
      /**
       * Tool execution stub - deferred feature.
       *
       * Implementation Status:
       * Tool execution framework is in place, but individual tool handlers need implementation.
       *
       * To implement:
       * 1. Create tool handler registry mapping tool names to handler functions
       * 2. Implement handlers that can:
       *    - Validate input parameters against tool schema
       *    - Route to appropriate service (external API, local function, etc.)
       *    - Handle errors and timeouts gracefully
       *    - Return structured results
       * 3. Examples:
       *    - web_search: Query Bing/Google Search API
       *    - code_execution: Route to sandboxed code executor
       *    - database_query: Execute queries on appropriate database
       *    - file_operations: Handle file I/O (with permission checks)
       *
       * Planned for: v2.0 (AI server phase 2)
       */
      execute: async (params: any) => {
        console.log(`OpenAI tool '${tool.function.name}' called (stubbed):`, params);
        return { result: `OpenAI tool '${tool.function.name}' is currently stubbed out - functionality not implemented` };
      }
    };
  }

  return tools;
}

// ============================================
// Streaming and Chat Completion
// ============================================

/**
 * Handles streaming chat completions.
 *
 * This function takes a chat request, streams the response from the provider using
 * the Vercel AI SDK's `streamText` function, and formats the output as an
 * OpenAI-compatible Server-Sent Events (SSE) stream.
 *
 * @param {ChatRequest} request The chat completion request.
 * @param {ModelCatalogEntry} modelEntry The model catalog entry for the requested model.
 * @returns {Promise<Response>} A promise that resolves to a `Response` object containing the SSE stream.
 */
async function streamChatCompletion(
  request: ChatRequest,
  modelEntry: ModelCatalogEntry,
): Promise<Response> {
  // Map provider to registry
  const providerMap: Record<string, string> = {
    'gemini': 'gemini-code',
    'claude': 'claude-code',
    'claude-code-cli': 'claude-code',
    'codex': 'openai-codex',
    'codex-cli': 'openai-codex',
    'jules': 'google-jules',
    'copilot': 'github-copilot',
    'copilot-api': 'github-copilot',
  };

  const provider = providerMap[request.provider] || request.provider;

  // Handle Jules separately since it doesn't use AI SDK
  if (provider === 'google-jules') {
    return await handleJulesStreaming(request, modelEntry);
  }

  const model = getLanguageModel(provider, request.model || '');

  // Convert tools
  const tools = request.tools ? convertOpenAIToolsToAISDK(request.tools) : undefined;

  // Start streaming
  const result = streamText({
    model: model as any,
    messages: request.messages,
    temperature: request.temperature ?? 0.7,
    maxRetries: 2,
    tools,
  });

  // Convert to OpenAI SSE format
  const encoder = new TextEncoder();
  const id = `chatcmpl-${crypto.randomUUID()}`;
  const created = Math.floor(Date.now() / 1000);

  const stream = new ReadableStream({
    async start(controller) {
      try {
        // Send role chunk first
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({
          id,
          object: 'chat.completion.chunk',
          created,
          model: modelEntry.id,
          choices: [{
            index: 0,
            delta: { role: 'assistant' },
            finish_reason: null,
          }],
        })}\n\n`));

        // Stream text chunks
        for await (const chunk of result.textStream) {
          controller.enqueue(encoder.encode(`data: ${JSON.stringify({
            id,
            object: 'chat.completion.chunk',
            created,
            model: modelEntry.id,
            choices: [{
              index: 0,
              delta: { content: chunk },
              finish_reason: null,
            }],
          })}\n\n`));
        }

        // Get final usage
        const usage = await result.usage;

        // Send finish chunk
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({
          id,
          object: 'chat.completion.chunk',
          created,
          model: modelEntry.id,
          choices: [{
            index: 0,
            delta: {},
            finish_reason: 'stop',
          }],
          usage: {
            prompt_tokens: usage.totalTokens || 0,
            completion_tokens: 0,
            total_tokens: usage.totalTokens,
          },
        })}\n\n`));

        controller.enqueue(encoder.encode('data: [DONE]\n\n'));
        controller.close();
      } catch (error: any) {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({
          id,
          object: 'chat.completion.chunk',
          created,
          model: modelEntry.id,
          choices: [{
            index: 0,
            delta: {},
            finish_reason: 'error',
          }],
          error: { message: error?.message || String(error) },
        })}\n\n`));
        controller.enqueue(encoder.encode('data: [DONE]\n\n'));
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
    },
  });
}

/**
 * Handles non-streaming chat completions.
 *
 * This function uses the Vercel AI SDK's `generateText` function to get a
 * complete response from the provider. It then normalizes the result into
 * a `ProviderResult` object.
 *
 * @param {ChatRequest} request The chat completion request.
 * @returns {Promise<ProviderResult>} A promise that resolves to the provider's result.
 */
async function generateChatCompletion(
  request: ChatRequest,
): Promise<ProviderResult> {
  const providerMap: Record<string, string> = {
    'gemini': 'gemini-code',
    'claude': 'claude-code',
    'claude-code-cli': 'claude-code',
    'codex': 'openai-codex',
    'codex-cli': 'openai-codex',
    'jules': 'google-jules',
    'copilot': 'github-copilot',
    'copilot-api': 'github-copilot',
  };

  const provider = providerMap[request.provider] || request.provider;

  // Handle Jules separately since it doesn't use AI SDK
  if (provider === 'google-jules') {
    return await handleJulesGeneration(request);
  }

  const model = getLanguageModel(provider, request.model || '');

  const tools = request.tools ? convertOpenAIToolsToAISDK(request.tools) : undefined;

  const result = await generateText({
    model: model as any,
    messages: request.messages,
    temperature: request.temperature ?? 0.7,
    maxRetries: 2,
    tools,
  });

  const toolCalls = result.toolCalls?.map((tc: any) => ({
    id: tc.toolCallId,
    type: 'function' as const,
    function: {
      name: tc.toolName,
      arguments: JSON.stringify(tc.args),
    },
  }));

  return {
    text: result.text,
    finishReason: result.finishReason,
    usage: normalizeUsage(request.messages, result.text, result.usage),
    model: request.model || 'unknown',
    provider: request.provider,
    toolCalls,
  };
}

// ============================================
// Model Catalog
// ============================================

/**
 * @interface ModelCatalogEntry
 * @description Represents a single model in the model catalog.
 * @property {string} id The unique identifier for the model.
 * @property {ChatRequest['provider']} provider The provider of the model.
 * @property {string} [displayName] The display name of the model.
 * @property {string} [description] A description of the model.
 * @property {string} [upstreamId] The identifier for the model used by the provider.
 * @property {string} [ownedBy] The entity that owns the model.
 * @property {number} [contextWindow] The context window size for the model.
 * @property {'free' | 'limited' | 'pay-per-use'} [cost] The cost tier of the model.
 * @property {string} [subscription] The subscription required to use the model.
 * @property {object} [capabilities] The capabilities of the model.
 */
interface ModelCatalogEntry {
  id: string;
  provider: ChatRequest['provider'];
  displayName?: string;
  description?: string;
  upstreamId?: string;
  ownedBy?: string;
  contextWindow?: number;
  cost?: 'free' | 'limited' | 'pay-per-use';
  subscription?: string;
  capabilities?: {
    completion?: boolean;
    streaming?: boolean;
    reasoning?: boolean;
    vision?: boolean;
    tools?: boolean;
  };
}

/**
 * @const {ModelCatalogEntry[]}
 * @description A default model catalog used as a fallback if dynamic discovery fails.
 */
const DEFAULT_MODEL_CATALOG: ModelCatalogEntry[] = [
  {
    id: 'claude-sonnet-4.5',
    upstreamId: 'sonnet',
    provider: 'claude-code-cli' as const,
    displayName: 'Claude Sonnet 4.5',
    description: 'Claude Sonnet 4.5 - Best for coding',
    ownedBy: 'anthropic',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: true, tools: true },
  },
];

let modelCatalogCache: ModelCatalogEntry[] | null = null;
let modelIndexCache: Map<string, ModelCatalogEntry> | null = null;

/**
 * Ensures that the model catalog is loaded into the cache.
 *
 * If the cache is empty, this function populates it using the dynamically
 * discovered models or the default catalog as a fallback.
 *
 * @returns {Promise<void>} A promise that resolves when the catalog is loaded.
 */
async function ensureModelCatalogLoaded(): Promise<void> {
  if (modelCatalogCache && modelIndexCache) return;

  // Use dynamically discovered models from buildModelCatalog()
  // Falls back to DEFAULT_MODEL_CATALOG if no models discovered
  modelCatalogCache = DYNAMIC_MODEL_CATALOG.length > 0 ? DYNAMIC_MODEL_CATALOG : DEFAULT_MODEL_CATALOG;
  modelIndexCache = new Map(modelCatalogCache.map((entry) => [entry.id, entry]));
}

/**
 * Resolves a model by its ID from the model catalog.
 *
 * @param {string} modelId The ID of the model to resolve.
 * @returns {Promise<ModelCatalogEntry>} A promise that resolves to the model's catalog entry.
 * @throws {Error} If the model is not found in the catalog.
 */
async function resolveModel(modelId: string): Promise<ModelCatalogEntry> {
  await ensureModelCatalogLoaded();
  const entry = modelIndexCache?.get(modelId);
  if (!entry) {
    throw new Error(`Unknown model: ${modelId}`);
  }
  return entry;
}

/**
 * Converts a model catalog entry to the OpenAI model format.
 *
 * @param {ModelCatalogEntry} entry The model catalog entry to convert.
 * @returns {object} The model information in OpenAI's format.
 */
function toOpenAIModel(entry: ModelCatalogEntry) {
  return {
    object: 'model',
    id: entry.id,
    created: Math.floor(Date.now() / 1000),
    owned_by: entry.ownedBy ?? entry.provider,
    context_window: entry.contextWindow,
    capabilities: entry.capabilities,
    provider: entry.provider,
    upstream_id: entry.upstreamId,
    description: entry.description,
    name: entry.displayName,
    cost: entry.cost,
    subscription: entry.subscription,
  };
}

// ============================================
// Request/Response Conversion
// ============================================

/**
 * Maps an incoming OpenAI-formatted message to the internal `Message` format.
 *
 * This function handles messages with string content as well as array content
 * (e.g., from vision models) by combining array elements into a single string.
 *
 * @param {any} message The incoming message object.
 * @returns {Message} The message in the internal format.
 */
function mapOpenAIMessageToInternal(message: any): Message {
  const role = typeof message?.role === 'string' ? message.role : 'user';
  const content = message?.content;

  if (typeof content === 'string') {
    return { role, content };
  }

  if (Array.isArray(content)) {
    const combined = content
      .map((item) => {
        if (!item) return '';
        if (typeof item === 'string') return item;
        if (typeof item.text === 'string') return item.text;
        return '';
      })
      .filter(Boolean)
      .join('\n');
    return { role, content: combined };
  }

  return { role, content: '' };
}

/**
 * Converts an incoming OpenAI chat completion request to the internal `ChatRequest` format.
 *
 * @param {any} body The body of the incoming HTTP request.
 * @returns {Promise<{ request: ChatRequest; model: ModelCatalogEntry }>} A promise that resolves to the internal chat request and the corresponding model entry.
 * @throws {Error} If the request body is invalid.
 */
async function convertOpenAIChatCompletionRequest(body: any): Promise<{ request: ChatRequest; model: ModelCatalogEntry }> {
  if (!body || typeof body !== 'object') {
    throw new Error('Invalid request payload');
  }

  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    throw new Error('messages array is required');
  }

  if (typeof body.model !== 'string' || body.model.length === 0) {
    throw new Error('model is required');
  }

  const modelEntry = await resolveModel(body.model);
  const messages = body.messages.map(mapOpenAIMessageToInternal);

  const request: ChatRequest = {
    provider: modelEntry.provider,
    model: modelEntry.upstreamId || modelEntry.id,
    messages,
    temperature: body.temperature,
    maxTokens: body.max_tokens,
    tools: body.tools,
    stream: body.stream === true,
  };

  return { request, model: modelEntry };
}

/**
 * Builds an OpenAI-compatible chat completion response from a provider's result.
 *
 * @param {ProviderResult} result The result from the provider.
 * @param {ModelCatalogEntry} modelEntry The model catalog entry for the model used.
 * @returns {object} The chat completion response in OpenAI's format.
 */
function buildOpenAIChatResponse(
  result: ProviderResult,
  modelEntry: ModelCatalogEntry,
) {
  return {
    id: `chatcmpl-${crypto.randomUUID()}`,
    object: 'chat.completion',
    created: Math.floor(Date.now() / 1000),
    model: modelEntry.id,
    choices: [{
      index: 0,
      message: {
        role: 'assistant',
        content: result.text,
        tool_calls: result.toolCalls,
      },
      finish_reason: result.finishReason ?? 'stop',
    }],
    usage: {
      prompt_tokens: result.usage.totalTokens || 0,
      completion_tokens: 0,
      total_tokens: result.usage.totalTokens,
    },
  };
}

// ============================================
// HTTP Server
// ============================================

Bun.serve({
  port: PORT,
  idleTimeout: 120, // 2 minutes for slow Codex MCP initialization
  async fetch(req) {
    const headers = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Content-Type': 'application/json',
    };

    if (req.method === 'OPTIONS') {
      return new Response(null, { headers });
    }

    const url = new URL(req.url);

    // Log all requests for debugging
    console.log(`${req.method} ${url.pathname}${url.search}`);

    // Simple auth check for /v1/* endpoints (internal use, not security)
    if (url.pathname.startsWith('/v1/')) {
      const authHeader = req.headers.get('Authorization');
      const token = authHeader?.replace(/^Bearer\s+/i, '');

      if (token !== AUTH_TOKEN) {
        return new Response(
          JSON.stringify({ error: 'Unauthorized' }),
          { status: 401, headers }
        );
      }
    }

    // GET /v1/models
    if (url.pathname === '/v1/models') {
      if (req.method !== 'GET') {
        return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
      }

      try {
        await ensureModelCatalogLoaded();
        let data = (modelCatalogCache || []).map(toOpenAIModel);

        // Filter by provider query param
        const provider = url.searchParams.get('provider');
        if (provider) {
          data = data.filter((m: any) => m.provider === provider);
        }

        return new Response(JSON.stringify({ object: 'list', data }), { headers });
      } catch (error: any) {
        console.error('Failed to list models:', error);
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers });
      }
    }

    // POST /v1/chat/completions (REFACTORED)
    if (url.pathname === '/v1/chat/completions') {
      if (req.method !== 'POST') {
        return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
      }

      const startTime = Date.now();
      try {
        const body = await req.json() as any;
        const { request: chatRequest, model: modelEntry } = await convertOpenAIChatCompletionRequest(body);

        // STREAMING: Use new streamChatCompletion()
        if (chatRequest.stream) {
          const response = await streamChatCompletion(chatRequest, modelEntry);
          const duration = Date.now() - startTime;
          metrics.recordRequest('chat_completions_stream', duration);
          if (chatRequest.provider && chatRequest.model) {
            metrics.recordModelUsage(chatRequest.provider, chatRequest.model);
          }
          logger.info(`Chat completion (streaming) completed in ${duration}ms`, {
            provider: chatRequest.provider,
            model: chatRequest.model
          });
          return response;
        }

        // NON-STREAMING: Use new generateChatCompletion()
        const result = await generateChatCompletion(chatRequest);
        const responsePayload = buildOpenAIChatResponse(result, modelEntry);
        const duration = Date.now() - startTime;
        
        // Record metrics
        metrics.recordRequest('chat_completions', duration);
        if (chatRequest.provider && chatRequest.model) {
          metrics.recordModelUsage(chatRequest.provider, chatRequest.model, result.usage?.totalTokens);
        }
        logger.info(`Chat completion completed in ${duration}ms`, {
          provider: chatRequest.provider,
          model: chatRequest.model,
          tokens: result.usage?.totalTokens
        });
        
        return new Response(JSON.stringify(responsePayload), { headers });
      } catch (error: any) {
        const duration = Date.now() - startTime;
        metrics.recordRequest('chat_completions', duration, true);
        logger.error('Error handling /v1/chat/completions:', error.message);
        console.error('Error handling /v1/chat/completions:', error);
        const clientError =
          error?.message?.startsWith('Unknown model') ||
          error?.message?.startsWith('Unsupported response_format type');
        const status = clientError ? 400 : 500;
        return new Response(JSON.stringify({ error: error.message }), { status, headers });
      }
    }

    // GET /copilot/auth/start - Start Copilot OAuth device flow
    if (url.pathname === '/copilot/auth/start') {
      if (req.method !== 'GET') {
        return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
      }

      try {
        const { startCopilotOAuth } = await import('./github-copilot-oauth.js');
        const authData = await startCopilotOAuth();
        return new Response(
          JSON.stringify({
            ...authData,
            instructions: `Visit ${authData.verification_uri} and enter code: ${authData.user_code}`,
          }),
          { headers },
        );
      } catch (error: any) {
        console.error('Failed to start Copilot OAuth:', error);
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers });
      }
    }

    // POST /copilot/auth/complete - Complete Copilot OAuth device flow
    if (url.pathname === '/copilot/auth/complete') {
      if (req.method !== 'POST') {
        return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
      }

      try {
        const body = await req.json() as { device_code?: string };
        const deviceCode = body.device_code || url.searchParams.get('code');

        if (!deviceCode) {
          return new Response(
            JSON.stringify({ error: 'Missing device_code parameter' }),
            { status: 400, headers },
          );
        }

        const { completeCopilotOAuth } = await import('./github-copilot-oauth.js');
        const success = await completeCopilotOAuth(deviceCode);

        if (success) {
          return new Response(
            JSON.stringify({
              success: true,
              message: 'Copilot OAuth completed successfully! Tokens saved with auto-refresh enabled.',
            }),
            { headers },
          );
        } else {
          return new Response(
            JSON.stringify({
              success: false,
              error: 'authorization_pending',
              message: 'Authorization pending. Please complete authorization on GitHub.',
            }),
            { status: 202, headers },
          );
        }
      } catch (error: any) {
        console.error('Failed to complete Copilot OAuth:', error);
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers });
      }
    }

    // GET /health
    if (url.pathname === '/health') {
      const health = {
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        models: {
          count: MODELS.length,
          providers: ['gemini-code', 'claude-code', 'openai-codex', 'google-jules', 'github-copilot', 'cursor-agent-cli', 'github-models']
        },
        nats: elixirBridge.isConnected() ? 'connected' : 'disconnected',
        memory: {
          heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
          heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
          rss: Math.round(process.memoryUsage().rss / 1024 / 1024)
        }
      };
      
      return new Response(
        JSON.stringify(health, null, 2),
        { headers }
      );
    }

    // GET /metrics - Basic metrics for monitoring
    if (url.pathname === '/metrics') {
      const metricsData = metrics.getMetrics();
      return new Response(
        JSON.stringify(metricsData, null, 2),
        { headers }
      );
    }

    // GET /provider-tiers - Show provider priority and usage stats
    if (url.pathname === '/provider-tiers') {
      if (req.method !== 'GET') {
        return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
      }

      try {
        const { PROVIDER_TIERS, getUsageStats, getProvidersByPriority } = await import('./provider-router.js');
        return new Response(
          JSON.stringify({
            tiers: PROVIDER_TIERS,
            priority_order: getProvidersByPriority(),
            usage: getUsageStats(),
          }),
          { headers }
        );
      } catch (error: any) {
        console.error('Failed to get provider tiers:', error);
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers });
      }
    }

    return new Response(JSON.stringify({
      error: 'Not found',
      endpoints: [
        'GET  /health',
        'GET  /metrics',
        'GET  /v1/models',
        'POST /v1/chat/completions',
        'GET  /copilot/auth/start',
        'POST /copilot/auth/complete',
        'GET  /provider-tiers',
      ],
    }), {
      status: 404,
      headers,
    });
  },
});

console.log(`${green}🚀${reset} Server ready at ${bold}http://localhost:${PORT}${reset}`);
console.log(`${bold}🔗 Endpoints:${reset} /health  /metrics  /v1/models  /v1/chat/completions`);
console.log(`${bold}✨ Refactored:${reset} Using AI SDK streaming utilities (~100 lines removed)`);

// Start NATS handler for Elixir integration
console.log(`${blue}📡${reset} Starting NATS handler for Elixir integration...`);
import('./nats-handler.js').then(module => {
  module.startNATSHandler();
  console.log(`${green}✓${reset} NATS handler started - listening on llm.request`);
}).catch(error => {
  console.error(`${red}✗${reset} Failed to start NATS handler:`, error);
  console.error('  Elixir→AI Server integration will not work!');
});

// Start HTDAG LLM worker for self-evolution
console.log(`${blue}🧠${reset} Starting HTDAG LLM worker for self-evolution...`);
import('./htdag-llm-worker.js').then(async module => {
  const worker = new module.HTDAGLLMWorker();
  await worker.connect(process.env.NATS_URL || 'nats://localhost:4222');
  console.log(`${green}✓${reset} HTDAG LLM worker started - listening on llm.req.*`);
  
  // Handle shutdown
  process.on('SIGINT', async () => {
    console.log('\n🛑 Shutting down HTDAG LLM worker...');
    await worker.disconnect();
  });
}).catch(error => {
  console.error(`${red}✗${reset} Failed to start HTDAG LLM worker:`, error);
  console.error('  HTDAG self-evolution will not work!');
});
