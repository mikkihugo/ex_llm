#!/usr/bin/env bun

/**
 * Unified AI Providers HTTP Server
 *
 * Bridges multiple AI providers through a single HTTP interface:
 * - Gemini (via ai-sdk-provider-gemini-cli - stable wrapper)
 * - Claude (via ai-sdk-provider-claude-code - stable wrapper)
 * - Codex (via CLI exec using `codex exec`)
 * - Cursor Agent (via CLI exec - no wrapper available)
 * - GitHub Copilot (via CLI exec - no wrapper available)
 *
 * Usage:
 *   bun run ai-server/src/server.ts
 *
 * Environment:
 *   PORT - Server port (default: 3000)
 *   GOOGLE_APPLICATION_CREDENTIALS_JSON - Base64 encoded Gemini ADC JSON
 *   CLAUDE_ACCESS_TOKEN - Claude long-term OAuth token
 *   CURSOR_AUTH_JSON - Base64 encoded Cursor OAuth JSON
 *   GH_TOKEN / GITHUB_TOKEN - GitHub token for Copilot
 */

import { generateText, streamText } from 'ai';
import { createGeminiProvider } from 'ai-sdk-provider-gemini-cli';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { createServer } from 'http';
import { randomBytes, createHash } from 'crypto';
import escapeHtml from 'escape-html';
import { GoogleAuth } from 'google-auth-library';
import { CodexSDK } from 'codex-js-sdk';
import type { CodexResponse, CodexMessageType } from 'codex-js-sdk';
import { loadCredentialsFromEnv, checkCredentialAvailability, printCredentialStatus } from './load-credentials';
import { copilotChatCompletion } from './providers/copilot-api';
import { githubModels } from './providers/github-models';
import { z } from 'zod';
import { jsonrepair } from 'jsonrepair';
import { ElixirBridge } from './elixir-bridge';
import { analyzeTaskComplexity, selectCodexModelForCoding } from './task-complexity';
import { jules, createJulesModel } from './providers/google-ai-jules';

// Import CredentialStats type for type safety

// Load credentials from environment variables if available
const green = '\x1b[32m';
const blue = '\x1b[34m';
const reset = '\x1b[0m';
const bold = '\x1b[1m';

console.log(`${blue}🔐${reset} Loading AI provider credentials...`);
loadCredentialsFromEnv();
const allStats = checkCredentialAvailability();
printCredentialStatus(allStats);

const PORT = parsePort(process.env.PORT, 3000, 'PORT');
const OAUTH_CALLBACK_PORT = parsePort(process.env.OAUTH_CALLBACK_PORT, 1455, 'OAUTH_CALLBACK_PORT');
const OAUTH_TIMEOUT_MS = 10 * 60 * 1000; // 10 minutes
const TOKEN_EXPIRY_BUFFER_MS = 55 * 60 * 1000; // 55 minutes

// Initialize Elixir bridge for ExecutionCoordinator integration
const elixirBridge = new ElixirBridge();
elixirBridge.connect().catch(err => {
  console.warn('⚠️  Elixir bridge connection failed, using direct mode:', err.message);
});

// ============================================
// Codex OAuth Configuration
// ============================================

const CODEX_CLIENT_ID = 'app_EMoamEEZ73f0CkXaXp7hrann';
const CODEX_AUTHORIZE_URL = 'https://auth.openai.com/oauth/authorize';
const CODEX_TOKEN_URL = 'https://auth.openai.com/oauth/token';
const CODEX_REDIRECT_URI = `http://localhost:${OAUTH_CALLBACK_PORT}/auth/callback`;
const CODEX_SCOPE = 'openid profile email offline_access';

function parsePort(value: string | undefined, fallback: number, label: string): number {
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

interface CodexTokenStore {
  accessToken?: string;
  refreshToken?: string;
  expiresAt?: number;
  accountId?: string;
}

interface UsageSummary {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

interface Message {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface PKCEPair {
  verifier: string;
  challenge: string;
}

interface OAuthState {
  state: string;
  pkce: PKCEPair;
}

const codexTokenStore: CodexTokenStore = {};
let currentCodexOAuthState: OAuthState | null = null;

function toNumber(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

function estimateTokensFromText(text?: string | null): number {
  if (!text) return 0;
  const bytes = Buffer.byteLength(text, 'utf8');
  if (bytes === 0) return 0;
  return Math.max(1, Math.ceil(bytes / 4));
}

function estimateTokensFromMessages(messages: Message[]): number {
  return messages.reduce((sum, message) => sum + estimateTokensFromText(message.content), 0);
}

function normalizeUsage(
  messages: Message[],
  generatedText?: string,
  usage?: any,
): UsageSummary {
  const promptFromUsage = toNumber(usage?.promptTokens ?? usage?.prompt_tokens ?? usage?.input_tokens);
  const completionFromUsage = toNumber(usage?.completionTokens ?? usage?.completion_tokens ?? usage?.output_tokens);
  let totalFromUsage = toNumber(usage?.totalTokens ?? usage?.total_tokens ?? usage?.total);

  if (typeof promptFromUsage === 'number' && typeof completionFromUsage === 'number') {
    if (typeof totalFromUsage !== 'number') {
      totalFromUsage = promptFromUsage + completionFromUsage;
    }

    if (typeof totalFromUsage === 'number') {
      return {
        promptTokens: promptFromUsage,
        completionTokens: completionFromUsage,
        totalTokens: totalFromUsage,
      };
    }
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

interface ModelCatalogEntry {
  id: string;
  provider: ChatRequest['provider'];
  displayName?: string;
  description?: string;
  upstreamId?: string;
  ownedBy?: string;
  contextWindow?: number;
  capabilities?: {
    completion?: boolean;
    streaming?: boolean;
    reasoning?: boolean;
    vision?: boolean;
    tools?: boolean;  // Function calling / tool use capability
  };
}

const DEFAULT_MODEL_CATALOG: ModelCatalogEntry[] = [
  {
    id: 'google-jules',
    upstreamId: 'jules-v1',
    provider: 'google-jules' as const,
    displayName: 'Google Jules (Coding Agent)',
    description: 'Google Jules - Autonomous AI coding agent for complex tasks',
    ownedBy: 'google',
    contextWindow: 256000, // 256K context
    capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: true },
  },
  {
    id: 'gemini-2.5-flash',
    upstreamId: 'gemini-2.5-flash',
    provider: 'gemini-code' as const,
    displayName: 'Gemini Code 2.5 Flash (HTTP)',
    description: 'Gemini Flash via HTTP API (primary, faster)',
    ownedBy: 'google',
    contextWindow: 2097152,  // 2M tokens
    capabilities: { completion: true, streaming: false, reasoning: false, vision: false, tools: true },
  },
  {
    id: 'gemini-2.5-flash-cli',
    upstreamId: 'gemini-2.5-flash',
    provider: 'gemini-code-cli' as const,
    displayName: 'Gemini Code 2.5 Flash (CLI)',
    description: 'Gemini Flash via CLI (fallback)',
    ownedBy: 'google',
    contextWindow: 2097152,
    capabilities: { completion: true, streaming: false, reasoning: false, vision: false, tools: false },  // CLI doesn't support tools
  },
  {
    id: 'gemini-2.5-pro',
    upstreamId: 'gemini-2.5-pro',
    provider: 'gemini-code' as const,
    displayName: 'Gemini Code 2.5 Pro (HTTP)',
    description: 'Gemini Pro via HTTP API (primary, faster)',
    ownedBy: 'google',
    contextWindow: 2097152,
    capabilities: { completion: true, streaming: false, reasoning: false, vision: false, tools: true },
  },
  {
    id: 'gemini-2.5-pro-cli',
    upstreamId: 'gemini-2.5-pro',
    provider: 'gemini-code-cli' as const,
    displayName: 'Gemini Code 2.5 Pro (CLI)',
    description: 'Gemini Pro via CLI (fallback)',
    ownedBy: 'google',
    contextWindow: 2097152,
    capabilities: { completion: true, streaming: false, reasoning: false, vision: false, tools: false },  // CLI doesn't support tools
  },
  {
    id: 'claude-sonnet-4.5',
    upstreamId: 'sonnet',
    provider: 'claude-code-cli' as const,
    displayName: 'Claude Sonnet 4.5',
    description: 'Claude Sonnet 4.5 - Best for coding, 64K output (supports extended thinking)',
    ownedBy: 'anthropic',
    contextWindow: 200000,  // 200K standard, 1M enterprise
    capabilities: { completion: true, streaming: true, reasoning: true, vision: true, tools: true },
  },
  {
    id: 'claude-opus-4.1',
    upstreamId: 'opus',
    provider: 'claude-code-cli' as const,
    displayName: 'Claude Opus 4.1',
    description: 'Claude Opus 4.1 - Largest model (supports extended thinking)',
    ownedBy: 'anthropic',
    contextWindow: 200000,  // 200K standard
    capabilities: { completion: true, streaming: true, reasoning: true, vision: true, tools: true },
  },
  {
    id: 'gpt-5-codex',
    upstreamId: 'gpt-5-codex',
    provider: 'codex-cli' as const,
    displayName: 'OpenAI GPT-5 Codex',
    description: 'GPT-5 via Codex CLI (supports MCP tools)',
    ownedBy: 'openai',
    contextWindow: 256000,  // 256K context window
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
  },
  {
    id: 'o3',
    upstreamId: 'o3',
    provider: 'codex-cli' as const,
    displayName: 'OpenAI o3 (Thinking)',
    description: 'OpenAI o3 - Deepest reasoning model with extended thinking',
    ownedBy: 'openai',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
  },
  {
    id: 'o1',
    upstreamId: 'o1',
    provider: 'codex-cli' as const,
    displayName: 'OpenAI o1 (Thinking)',
    description: 'OpenAI o1 - Fast reasoning model',
    ownedBy: 'openai',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
  },
  {
    id: 'cursor-auto',
    upstreamId: 'auto',
    provider: 'cursor-agent-cli' as const,
    displayName: 'Cursor Agent (Auto)',
    description: 'Cursor Agent auto model selection (FREE on subscription)',
    ownedBy: 'cursor',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
  },
  {
    id: 'cursor-gpt-4.1',
    upstreamId: 'gpt-4.1',
    provider: 'cursor-agent-cli' as const,
    displayName: 'Cursor Agent GPT-4.1',
    description: 'Cursor CLI agent runner (explicit GPT-4.1)',
    ownedBy: 'cursor',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
  },
  {
    id: 'copilot-gpt-4.1',
    upstreamId: 'gpt-4.1',
    provider: 'copilot-api' as const,
    displayName: 'GitHub Copilot GPT-4.1',
    description: 'GitHub Copilot API - GPT-4.1 (lighter quota)',
    ownedBy: 'github',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
  },
  {
    id: 'grok-coder-1',
    upstreamId: 'grok-coder-1',
    provider: 'copilot-api' as const,
    displayName: 'Grok Coder 1',
    description: 'xAI Grok Coder 1 via GitHub Copilot',
    ownedBy: 'xai',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
  },
  {
    id: 'gpt-4o-mini',
    upstreamId: 'gpt-4o-mini',
    provider: 'github-models' as const,
    displayName: 'GPT-4o Mini (GitHub Models)',
    description: 'OpenAI GPT-4o Mini via GitHub Models API',
    ownedBy: 'openai',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: true, tools: true },
  },
  {
    id: 'gpt-4o',
    upstreamId: 'gpt-4o',
    provider: 'github-models' as const,
    displayName: 'GPT-4o (GitHub Models)',
    description: 'OpenAI GPT-4o via GitHub Models API',
    ownedBy: 'openai',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: true, tools: true },
  },
  {
    id: 'o1-mini',
    upstreamId: 'o1-mini',
    provider: 'github-models' as const,
    displayName: 'o1 Mini (GitHub Models)',
    description: 'OpenAI o1 Mini via GitHub Models API',
    ownedBy: 'openai',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
  },
  {
    id: 'o1-preview',
    upstreamId: 'o1-preview',
    provider: 'github-models' as const,
    displayName: 'o1 Preview (GitHub Models)',
    description: 'OpenAI o1 Preview via GitHub Models API',
    ownedBy: 'openai',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false, tools: true },
  },
];

let modelCatalogCache: ModelCatalogEntry[] | null = null;
let modelIndexCache: Map<string, ModelCatalogEntry> | null = null;
let catalogLoadingPromise: Promise<void> | null = null;

async function readJsonFile(path: string): Promise<any> {
  try {
    const file = Bun.file(path);
    if (!(await file.exists())) {
      return undefined;
    }
    const text = await file.text();
    return JSON.parse(text);
  } catch (error) {
    console.warn(`Failed to read model registry file at ${path}:`, error);
    return undefined;
  }
}

function mergeCatalog(base: ModelCatalogEntry[], additions: any): ModelCatalogEntry[] {
  if (!additions) return base;
  const list = Array.isArray(additions) ? additions : additions?.data;
  if (!Array.isArray(list)) return base;

  const merged = [...base];
  for (const entry of list) {
    if (!entry || typeof entry !== 'object') continue;
    const id = typeof entry.id === 'string' ? entry.id : undefined;
    const provider = typeof entry.provider === 'string' ? entry.provider : undefined;
    if (!id || !provider) continue;

    const normalized: ModelCatalogEntry = {
      ...entry,
      id,
      provider: provider as ChatRequest['provider'],
    };

    const existingIndex = merged.findIndex((item) => item.id === id);
    if (existingIndex >= 0) {
      merged[existingIndex] = { ...merged[existingIndex], ...normalized };
    } else {
      merged.push(normalized);
    }
  }

  return merged;
}

async function ensureModelCatalogLoaded(): Promise<void> {
  if (modelCatalogCache && modelIndexCache) return;
  if (catalogLoadingPromise) {
    await catalogLoadingPromise;
    return;
  }

  catalogLoadingPromise = (async () => {
    let catalog: ModelCatalogEntry[] = [...DEFAULT_MODEL_CATALOG];

    const envCatalog = process.env.SINGULARITY_MODEL_REGISTRY;
    if (envCatalog) {
      try {
        catalog = mergeCatalog(catalog, JSON.parse(envCatalog));
      } catch (error) {
        console.warn('Failed to parse SINGULARITY_MODEL_REGISTRY:', error);
      }
    }

    const registryPath = process.env.SINGULARITY_MODEL_REGISTRY_PATH;
    if (registryPath) {
      const fileCatalog = await readJsonFile(registryPath);
      catalog = mergeCatalog(catalog, fileCatalog);
    } else {
      // default optional file in repo
      const defaultPath = 'models.catalog.json';
      const fileCatalog = await readJsonFile(defaultPath);
      catalog = mergeCatalog(catalog, fileCatalog);
    }

    modelCatalogCache = catalog;
    modelIndexCache = new Map(catalog.map((entry) => [entry.id, entry]));
    catalogLoadingPromise = null;
  })();

  await catalogLoadingPromise;
}

async function listModelCatalog(): Promise<ModelCatalogEntry[]> {
  await ensureModelCatalogLoaded();
  return modelCatalogCache ?? [];
}

async function resolveModel(modelId: string): Promise<ModelCatalogEntry> {
  await ensureModelCatalogLoaded();
  const entry = modelIndexCache?.get(modelId);
  if (!entry) {
    throw new Error(`Unknown model: ${modelId}`);
  }
  return entry;
}

interface ProviderResult {
  text: string;
  finishReason: string;
  usage: UsageSummary;
  model: string;
  provider: ChatRequest['provider'];
}

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
        if (Array.isArray(item?.text)) {
          return item.text.map((value: any) => (typeof value === 'string' ? value : '')).join('\n');
        }
        return '';
      })
      .filter(Boolean)
      .join('\n');
    return { role, content: combined };
  }

  if (typeof content?.text === 'string') {
    return { role, content: content.text };
  }

  return { role, content: '' };
}

function normalizeTemperature(value: any): number | undefined {
  if (typeof value !== 'number') return undefined;
  if (!Number.isFinite(value)) return undefined;
  return Math.max(0, Math.min(2, value));
}

function normalizeMaxTokens(value: any): number | undefined {
  if (typeof value !== 'number') return undefined;
  if (!Number.isInteger(value)) return undefined;
  return Math.max(1, value);
}

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
  let messages = body.messages.map(mapOpenAIMessageToInternal);

  const responseFormat = body.response_format;
  const formatType = typeof responseFormat === 'string' ? responseFormat : responseFormat?.type;
  let expectJsonObject = false;

  if (formatType) {
    if (formatType === 'json_object') {
      expectJsonObject = true;
    } else if (formatType === 'text') {
      // no-op: treated as default text output
    } else {
      throw new Error(`Unsupported response_format type: ${formatType}`);
    }
  }

  if (expectJsonObject) {
    messages = [{ role: 'system', content: JSON_OBJECT_SYSTEM_PROMPT }, ...messages];
  }

  const request: ChatRequest = {
    provider: modelEntry.provider,
    model: modelEntry.upstreamId || modelEntry.id,
    messages,
    temperature: normalizeTemperature(body.temperature),
    maxTokens: normalizeMaxTokens(body.max_tokens ?? body.max_completion_tokens ?? body.max_completion_tokens),
    tools: body.tools, // Pass through OpenAI tools format
    expectJsonObject,
    stream: body.stream === true,
  };

  return { request, model: modelEntry };
}

function toOpenAIModel(entry: ModelCatalogEntry) {
  return {
    object: 'model',
    id: entry.id,
    created: Math.floor(Date.now() / 1000),
    owned_by: entry.ownedBy ?? entry.provider,
    context_window: entry.contextWindow,
    // Preserve additional metadata for clients that can use it
    capabilities: entry.capabilities,
    provider: entry.provider,
    upstream_id: entry.upstreamId,
    description: entry.description,
    name: entry.displayName,
  };
}

function buildOpenAIChatResponse(
  result: ProviderResult,
  modelEntry: ModelCatalogEntry,
  requestBody: any,
) {
  const created = Math.floor(Date.now() / 1000);
  const usage = result.usage;

  return {
    id: `chatcmpl-${crypto.randomUUID()}`,
    object: 'chat.completion',
    created,
    model: modelEntry.id,
    choices: [
      {
        index: 0,
        message: {
          role: 'assistant',
          content: result.text,
          // TODO: Add tool_calls support when providers return tool calls
          // tool_calls: result.toolCalls,
        },
        finish_reason: result.finishReason ?? 'stop',
        logprobs: null,
      },
    ],
    usage: {
      prompt_tokens: usage.promptTokens,
      completion_tokens: usage.completionTokens,
      total_tokens: usage.totalTokens,
    },
    system_fingerprint: requestBody?.system_fingerprint ?? null,
  };
}

function enforceResponseFormat(result: ProviderResult, request: ChatRequest): ProviderResult {
  if (!request.expectJsonObject) {
    return result;
  }

  const trimmed = result.text?.trim?.();
  try {
    let parsedValue;
    try {
      parsedValue = JSON.parse(trimmed ?? '');
    } catch {
      parsedValue = JSON.parse(jsonrepair(trimmed ?? ''));
    }

    const parsed = JsonObjectSchema.parse(parsedValue);
    const normalized = JSON.stringify(parsed);
    return {
      ...result,
      text: normalized,
    };
  } catch (error: any) {
    throw new Error(`Provider returned non-JSON output while json_object response_format was requested: ${error?.message || error}`);
  }
}

const OPENAI_STREAM_HEADERS = {
  'Content-Type': 'text/event-stream; charset=utf-8',
  'Cache-Control': 'no-cache, no-transform',
  Connection: 'keep-alive',
};

const textEncoder = new TextEncoder();

type StreamTextResultAny = ReturnType<typeof streamText>;

function mapFinishReason(reason: string | undefined | null): string | null {
  if (!reason) return null;
  switch (reason) {
    case 'content-filter':
      return 'content_filter';
    case 'tool-calls':
      return 'tool_calls';
    default:
      return reason;
  }
}

function toOpenAIUsage(usage?: UsageSummary | { inputTokens?: number; outputTokens?: number; totalTokens?: number } | null) {
  if (!usage) return undefined;
  if ('promptTokens' in usage) {
    return {
      prompt_tokens: usage.promptTokens,
      completion_tokens: usage.completionTokens,
      total_tokens: usage.totalTokens,
    };
  }
  return {
    prompt_tokens: usage.inputTokens ?? 0,
    completion_tokens: usage.outputTokens ?? 0,
    total_tokens: usage.totalTokens ?? ((usage.inputTokens ?? 0) + (usage.outputTokens ?? 0)),
  };
}

function createOpenAIStreamFromResult(
  result: ProviderResult,
  modelEntry: ModelCatalogEntry,
  requestBody: any,
): Response {
  const created = Math.floor(Date.now() / 1000);
  const id = `chatcmpl-${crypto.randomUUID()}`;
  const usage = toOpenAIUsage(result.usage);

  const readable = new ReadableStream<Uint8Array>({
    start(controller) {
      const send = (payload: unknown) => {
        controller.enqueue(textEncoder.encode(`data: ${JSON.stringify(payload)}\n\n`));
      };
      const sendDone = () => {
        controller.enqueue(textEncoder.encode('data: [DONE]\n\n'));
      };

      const base = {
        id,
        object: 'chat.completion.chunk',
        created,
        model: modelEntry.id,
      };

      send({
        ...base,
        choices: [
          {
            index: 0,
            delta: { role: 'assistant' },
            finish_reason: null,
            logprobs: null,
          },
        ],
      });

      if (result.text) {
        send({
          ...base,
          choices: [
            {
              index: 0,
              delta: { content: result.text },
              finish_reason: null,
              logprobs: null,
            },
          ],
        });
      }

      send({
        ...base,
        choices: [
          {
            index: 0,
            delta: {},
            finish_reason: mapFinishReason(result.finishReason),
            logprobs: null,
          },
        ],
        usage,
      });

      sendDone();
      controller.close();
    },
  });

  return new Response(readable, { headers: OPENAI_STREAM_HEADERS });
}

type ToolCallState = {
  id: string;
  name: string;
  index: number;
  arguments: string;
};

async function createOpenAIStreamFromStreamResult(
  streamResult: StreamTextResultAny,
  request: ChatRequest,
  modelEntry: ModelCatalogEntry,
  requestBody: any,
): Promise<Response> {
  const created = Math.floor(Date.now() / 1000);
  const id = `chatcmpl-${crypto.randomUUID()}`;

  const fullStream = streamResult.fullStream;

  const readable = new ReadableStream<Uint8Array>({
    async start(controller) {
      const send = (payload: unknown) => {
        controller.enqueue(textEncoder.encode(`data: ${JSON.stringify(payload)}\n\n`));
      };
      const sendDone = () => {
        controller.enqueue(textEncoder.encode('data: [DONE]\n\n'));
      };

      const base = {
        id,
        object: 'chat.completion.chunk',
        created,
        model: modelEntry.id,
      };

      const sendRoleIfNeeded = (() => {
        let roleSent = false;
        return () => {
          if (roleSent) return;
          roleSent = true;
          send({
            ...base,
            choices: [
              {
                index: 0,
                delta: { role: 'assistant' },
                finish_reason: null,
                logprobs: null,
              },
            ],
          });
        };
      })();

      const toolCallStates = new Map<string, ToolCallState>();
      let nextToolCallIndex = 0;
      let finished = false;

      try {
        for await (const part of fullStream) {
          switch (part.type) {
            case 'text-start':
              sendRoleIfNeeded();
              break;
            case 'text-delta':
              sendRoleIfNeeded();
              if (part.text) {
                send({
                  ...base,
                  choices: [
                    {
                      index: 0,
                      delta: { content: part.text },
                      finish_reason: null,
                      logprobs: null,
                    },
                  ],
                });
              }
              break;
            case 'tool-input-start': {
              sendRoleIfNeeded();
              const existing = toolCallStates.get(part.toolCallId);
              if (!existing) {
                const state: ToolCallState = {
                  id: part.toolCallId || `call_${crypto.randomUUID()}`,
                  name: part.toolName || 'tool',
                  index: nextToolCallIndex++,
                  arguments: '',
                };
                toolCallStates.set(part.toolCallId, state);
                send({
                  ...base,
                  choices: [
                    {
                      index: 0,
                      delta: {
                        tool_calls: [
                          {
                            index: state.index,
                            id: state.id,
                            type: 'function',
                            function: {
                              name: state.name,
                              arguments: '',
                            },
                          },
                        ],
                      },
                      finish_reason: null,
                      logprobs: null,
                    },
                  ],
                });
              }
              break;
            }
            case 'tool-input-delta': {
              sendRoleIfNeeded();
              const state = toolCallStates.get(part.toolCallId);
              if (state) {
                state.arguments += part.inputTextDelta ?? '';
                const deltaArgs = part.inputTextDelta ?? '';
                if (deltaArgs.length > 0) {
                  send({
                    ...base,
                    choices: [
                      {
                        index: 0,
                        delta: {
                          tool_calls: [
                            {
                              index: state.index,
                              id: state.id,
                              type: 'function',
                              function: {
                                arguments: deltaArgs,
                              },
                            },
                          ],
                        },
                        finish_reason: null,
                        logprobs: null,
                      },
                    ],
                  });
                }
              }
              break;
            }
            case 'tool-input-available': {
              const state = toolCallStates.get(part.toolCallId);
              if (state && typeof part.input === 'string') {
                state.arguments = part.input;
                send({
                  ...base,
                  choices: [
                    {
                      index: 0,
                      delta: {
                        tool_calls: [
                          {
                            index: state.index,
                            id: state.id,
                            type: 'function',
                            function: {
                              arguments: part.input,
                            },
                          },
                        ],
                      },
                      finish_reason: null,
                      logprobs: null,
                    },
                  ],
                });
              }
              break;
            }
            case 'finish':
              finished = true;
              send({
                ...base,
                choices: [
                  {
                    index: 0,
                    delta: {},
                    finish_reason: mapFinishReason(part.finishReason),
                    logprobs: null,
                  },
                ],
                usage: toOpenAIUsage(part.totalUsage),
              });
              break;
            case 'error':
              send({
                ...base,
                choices: [
                  {
                    index: 0,
                    delta: {},
                    finish_reason: 'error',
                    logprobs: null,
                  },
                ],
              });
              finished = true;
              break;
            default:
              break;
          }
        }

        if (!finished) {
          send({
            ...base,
            choices: [
              {
                index: 0,
                delta: {},
                finish_reason: 'stop',
                logprobs: null,
              },
            ],
            usage: toOpenAIUsage(await streamResult.totalUsage.catch(() => undefined)),
          });
        }

        sendDone();
        controller.close();
      } catch (error: any) {
        controller.enqueue(
          textEncoder.encode(
            `data: ${JSON.stringify({
              id,
              object: 'chat.completion.chunk',
              created,
              model: modelEntry.id,
              choices: [
                {
                  index: 0,
                  delta: {},
                  finish_reason: 'error',
                  logprobs: null,
                },
              ],
              error: { message: error?.message || String(error) },
            })}\n\n`,
          ),
        );
        sendDone();
        controller.close();
      }
    },
  });

  return new Response(readable, { headers: OPENAI_STREAM_HEADERS });
}

function generatePKCE(): PKCEPair {
  const verifier = randomBytes(32).toString('base64url');
  const challenge = createHash('sha256').update(verifier).digest('base64url');
  return { verifier, challenge };
}

function createOAuthState(): string {
  return randomBytes(16).toString('hex');
}

function decodeJWT(token: string): any {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payload = parts[1];
    const decoded = Buffer.from(payload, 'base64').toString('utf-8');
    return JSON.parse(decoded);
  } catch {
    return null;
  }
}





function renderOAuthResponse(res: any, status: number, message: string): void {
  res.statusCode = status;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.end(`<html><body><h2>${status === 200 ? '✓' : '❌'} OAuth ${status === 200 ? 'Success' : 'Error'}</h2><p>${escapeHtml(message)}</p></body></html>`);
}

function validateOAuthParams(code: string | null, state: string | null): { valid: boolean; error?: string } {
  if (!code || typeof code !== 'string' || code.length === 0 || code.length > 2048) {
    return { valid: false, error: 'Invalid authorization code' };
  }
  if (!state || typeof state !== 'string' || state.length === 0 || state.length > 256) {
    return { valid: false, error: 'Invalid state parameter' };
  }
  if (/[<>'"\\]/.test(code) || /[<>'"\\]/.test(state)) {
    return { valid: false, error: 'Invalid characters in parameters' };
  }
  return { valid: true };
}

// @ts-ignore - Unused but kept for future use
function _startCodexCallbackServer(expectedState: string): Promise<string | null> {
  return new Promise((resolve) => {
    const server = createServer((req, res) => {
      try {
        const url = new URL(req.url!, 'http://localhost');
        if (url.pathname !== '/auth/callback') {
          renderOAuthResponse(res, 404, 'Not found');
          return;
        }

        const state = url.searchParams.get('state');
        const code = url.searchParams.get('code');

        const validation = validateOAuthParams(code, state);
        if (!validation.valid) {
          renderOAuthResponse(res, 400, validation.error || 'Invalid parameters');
          return;
        }

        if (state !== expectedState) {
          renderOAuthResponse(res, 400, 'State mismatch - possible CSRF attack');
          return;
        }

        renderOAuthResponse(res, 200, 'Codex OAuth complete. You can close this window.');

        setTimeout(() => {
          server.close();
          resolve(code!);
        }, 100);
      } catch {
        renderOAuthResponse(res, 500, 'Internal server error');
      }
    });

    server.listen(OAUTH_CALLBACK_PORT, '127.0.0.1', () => {
      console.log(`✓ OAuth callback server started on port ${OAUTH_CALLBACK_PORT}`);
    });

    server.on('error', (err: any) => {
      console.error(`Failed to bind port ${OAUTH_CALLBACK_PORT}:`, err?.code);
      resolve(null);
    });

    setTimeout(() => {
      server.close();
      resolve(null);
    }, OAUTH_TIMEOUT_MS);
  });
}

async function exchangeCodexCode(code: string, verifier: string): Promise<boolean> {
  try {
    const response = await fetch(CODEX_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: CODEX_CLIENT_ID,
        code,
        code_verifier: verifier,
        redirect_uri: CODEX_REDIRECT_URI,
      }),
    });

    if (!response.ok) return false;

    const json: any = await response.json();
    if (!json?.access_token || !json?.refresh_token) return false;

    codexTokenStore.accessToken = json.access_token;
    codexTokenStore.refreshToken = json.refresh_token;
    codexTokenStore.expiresAt = Date.now() + json.expires_in * 1000;

    const decoded = decodeJWT(json.access_token);
    codexTokenStore.accountId = decoded?.['https://api.openai.com/auth']?.chatgpt_account_id;

    console.log('✓ Codex authenticated, account:', codexTokenStore.accountId);
    return true;
  } catch {
    return false;
  }
}

// ============================================
// Gemini Code Assist Configuration
// ============================================

const GEMINI_CODE_ENDPOINT = 'https://cloudcode-pa.googleapis.com/v1internal:generateContent';
const GEMINI_CODE_PROJECT = process.env.GEMINI_CODE_PROJECT || 'gemini-code-473918';

let geminiCodeAccessToken: string | null = null;
let geminiCodeTokenExpiry: number = 0;

/**
 * Get ADC (Application Default Credentials) token for Gemini Code Assist
 */
async function getGeminiCodeToken(): Promise<string> {
  // Check if cached token is still valid (refresh 5 min before expiry)
  if (geminiCodeAccessToken && geminiCodeTokenExpiry > Date.now() + 5 * 60 * 1000) {
    return geminiCodeAccessToken;
  }

  try {
    // Get token from gcloud CLI
    const proc = Bun.spawn(['gcloud', 'auth', 'application-default', 'print-access-token'], {
      stdout: 'pipe',
      stderr: 'pipe',
    });

    const token = (await new Response(proc.stdout).text()).trim();
    const exitCode = await proc.exited;

    if (exitCode !== 0) {
      const error = await new Response(proc.stderr).text();
      throw new Error(`Failed to get ADC token: ${error}`);
    }

    // Cache token (Google tokens typically valid for 1 hour)
    geminiCodeAccessToken = token;
    geminiCodeTokenExpiry = Date.now() + TOKEN_EXPIRY_BUFFER_MS;

    return token;
  } catch (error) {
    throw new Error(`Failed to get Gemini Code Assist token: ${error instanceof Error ? error.message : String(error)}`);
  }
}

// ============================================
// Original AI Server Code
// ============================================

// Initialize providers with SDK wrappers
// Default to ADC (google-auth-library) for consistency with gemini-code
const googleAuth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-platform'],
});

const gemini = createGeminiProvider({
  authType: 'google-auth-library' as any,
  googleAuth: googleAuth as any,
});

const JSON_OBJECT_SYSTEM_PROMPT = 'You are a structured output agent. Reply with a single valid JSON object only, without additional commentary or code fences.';
const JsonObjectSchema = z.object({}).passthrough();

// Tool interface following OpenAI format
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
    | 'github-models';
  model?: string;
  messages: Message[];
  temperature?: number;
  maxTokens?: number;
  tools?: Tool[];
  expectJsonObject?: boolean;
  stream?: boolean;
}

// Helper to convert messages to prompt for CLI-based providers
function messagesToPrompt(messages: Message[]): string {
  return messages
    .map((m) => `${m.role}: ${m.content}`)
    .join('\n\n');
}

// Exec wrapper for CLI-based providers
async function execCLI(command: string, args: string[]): Promise<string> {
  const proc = Bun.spawn([command, ...args], {
    stdout: 'pipe',
    stderr: 'pipe',
  });

  const output = await new Response(proc.stdout).text();
  const exitCode = await proc.exited;

  if (exitCode !== 0) {
    const error = await new Response(proc.stderr).text();
    throw new Error(`${command} failed (${exitCode}): ${error || output}`);
  }

  return output.trim();
}

// Provider handlers (using SDK wrappers for stability)
async function handleGeminiCodeCLI(req: ChatRequest) {
  const modelName = req.model === 'gemini-2.5-flash' ? 'gemini-2.5-flash' : 'gemini-2.5-pro';

  const result = await generateText({
    model: gemini(modelName),
    messages: req.messages,
    temperature: req.temperature ?? 0.7,
    maxRetries: 2,
    // TODO: Convert OpenAI tools to AI SDK ToolSet format
    // tools: req.tools ? convertOpenAIToolsToAISDK(req.tools) : undefined,
  });

  return {
    text: result.text,
    finishReason: result.finishReason,
    usage: normalizeUsage(req.messages, result.text, result.usage),
    model: modelName,
    provider: 'gemini-code-cli' as const,
  };
}

async function handleGeminiCode(req: ChatRequest) {
  const modelName = req.model || 'gemini-2.5-flash';

  try {
    // Get ADC token
    const token = await getGeminiCodeToken();

    // Format messages in Gemini Code Assist format
    const contents = req.messages.map(msg => ({
      role: msg.role === 'system' ? 'user' : msg.role,
      parts: [{ text: msg.content }]
    }));

    // Build request in Code Assist format
    const requestBody = {
      model: modelName,
      project: GEMINI_CODE_PROJECT,
      user_prompt_id: crypto.randomUUID(),
      request: {
        contents,
        generationConfig: {
          temperature: req.temperature ?? 0.7,
          maxOutputTokens: req.maxTokens,
        }
      }
    };

    // Call Code Assist API
    const response = await fetch(GEMINI_CODE_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'x-goog-user-project': GEMINI_CODE_PROJECT,
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Gemini Code API error ${response.status}: ${errorText}`);
    }

    const data = await response.json() as any;

    // Extract text from wrapped response
    const text = data.response?.candidates?.[0]?.content?.parts?.[0]?.text || JSON.stringify(data);
    const finishReason = data.response?.candidates?.[0]?.finishReason || 'stop';
    const usage = data.response?.usageMetadata;

    return {
      text,
      finishReason: finishReason.toLowerCase(),
      usage: normalizeUsage(req.messages, text, {
        promptTokens: usage?.promptTokenCount,
        completionTokens: usage?.candidatesTokenCount,
        totalTokens: usage?.totalTokenCount,
      }),
      model: modelName,
      provider: 'gemini-code' as const,
    };
  } catch (error: any) {
    throw new Error(`Gemini Code request failed: ${error.message}`);
  }
}

async function handleClaudeCodeCLI(req: ChatRequest) {
  const modelName = req.model || 'sonnet';

  // Use AI SDK for better integration
  const result = await generateText({
    model: claudeCode(modelName),
    messages: req.messages,
    temperature: req.temperature ?? 0.7,
    maxRetries: 2,
    // TODO: Convert OpenAI tools to AI SDK ToolSet format
    // tools: req.tools ? convertOpenAIToolsToAISDK(req.tools) : undefined,
  });

  return {
    text: result.text,
    finishReason: result.finishReason,
    usage: normalizeUsage(req.messages, result.text, result.usage),
    model: modelName,
    provider: 'claude-code-cli' as const,
  };
}

async function handleCodex(req: ChatRequest): Promise<ProviderResult> {
  const model = req.model || 'gpt-5-codex';
  const prompt = messagesToPrompt(req.messages);

  try {
    // Use codex-js-sdk for better integration
    const sdk = new CodexSDK({
      logLevel: 'error' as any,
      config: {
        approval_policy: 'never' as any, // Auto-approve all commands for API use
        model: 'gpt-5-codex',
        // TODO: Add MCP server configuration from request
        // mcp_servers: req.mcpServers,
      },
    });

    return await new Promise((resolve, reject) => {
      let responseText = '';
      let toolCalls: any[] = [];
      let isComplete = false;
      const timeout = setTimeout(() => {
        if (!isComplete) {
          sdk.stop();
          reject(new Error('Codex request timeout after 60s'));
        }
      }, 60000);

      // Listen for responses
      sdk.onResponse((response: CodexResponse<CodexMessageType>) => {
        const msg = response.msg;

        if (msg.type === 'agent_message') {
          responseText += msg.message;
        } else if (msg.type === 'mcp_tool_call_begin') {
          // Record tool call start
          toolCalls.push({
            id: msg.call_id,
            type: 'function',
            function: {
              name: msg.tool,
              arguments: JSON.stringify(msg.arguments || {}),
            },
          });
        } else if (msg.type === 'mcp_tool_call_end') {
          // Tool call completed - could update toolCalls with results
          // For now, just log that it completed
          console.log(`MCP tool call ${msg.call_id} completed`);
        } else if (msg.type === 'task_complete') {
          isComplete = true;
          clearTimeout(timeout);
          sdk.stop();

          resolve({
            text: responseText.trim() || msg.last_agent_message || '',
            finishReason: 'stop',
            usage: normalizeUsage(req.messages, responseText, {}),
            model,
            provider: 'codex-cli' as const,
            // TODO: Return tool calls in response
            // toolCalls: toolCalls,
          });
        } else if (msg.type === 'error') {
          isComplete = true;
          clearTimeout(timeout);
          sdk.stop();
          reject(new Error(`Codex error: ${msg.message}`));
        }
      });

      sdk.onError((response: CodexResponse<CodexMessageType>) => {
        isComplete = true;
        clearTimeout(timeout);
        sdk.stop();
        reject(new Error(`Codex SDK error: ${JSON.stringify(response)}`));
      });

      // Start SDK and send message
      sdk.start();
      sdk.sendUserMessage([{ type: 'text', text: prompt }]);
    });
  } catch (error: any) {
    throw new Error(`Codex request failed: ${error.message}`);
  }
}

async function handleCursorAgent(req: ChatRequest) {
  const prompt = messagesToPrompt(req.messages);
  const model = req.model || 'gpt-4.1';

  // Use stream-json output to capture tool calls
  const args = ['-p', '--print', '--output-format', 'stream-json'];

  if (req.model) {
    args.push('--model', req.model);
  }

  args.push(prompt);

  const output = await execCLI('cursor-agent', args);

  // Parse the stream-json output to extract text and tool calls
  let responseText = '';
  let toolCalls: any[] = [];
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
          toolCalls.push({
            id: event.call_id,
            type: 'function',
            function: {
              name: 'shell',
              arguments: JSON.stringify({
                command: toolCall.shellToolCall.args?.command,
                workingDirectory: toolCall.shellToolCall.args?.workingDirectory,
              }),
            },
          });
        }
      } else if (event.type === 'result') {
        // Final result contains the complete response
        responseText = event.result || responseText;
      }
    } catch (e) {
      // Skip invalid JSON lines
      console.warn('Failed to parse cursor-agent JSON line:', line);
    }
  }

  return {
    text: responseText.trim(),
    finishReason: 'stop',
    usage: normalizeUsage(req.messages, responseText),
    model,
    provider: 'cursor-agent-cli' as const,
    // TODO: Return tool calls in response
    // toolCalls: toolCalls,
  };
}

async function handleCopilot(req: ChatRequest) {
  const prompt = messagesToPrompt(req.messages);
  const model = req.model || 'claude-sonnet-4.5';

  // Use -p for direct prompt execution with --allow-all-tools for non-interactive mode
  const args = ['-p', prompt, '--allow-all-tools', '--model', model];

  const output = await execCLI('copilot', args);

  return {
    text: output,
    finishReason: 'stop',
    usage: normalizeUsage(req.messages, output),
    model,
    provider: 'copilot-cli' as const,
  };
}

async function handleCopilotAPI(req: ChatRequest) {
  const model = req.model || 'copilot-gpt-5';
  const completion = await copilotChatCompletion({
    model,
    messages: req.messages,
  });

  const content = completion.text;
  if (typeof content !== 'string') {
    throw new Error('Copilot API response missing assistant content.');
  }

  return {
    text: content,
    finishReason: 'stop',
    usage: normalizeUsage(req.messages, content, completion.usage),
    model,
    provider: 'copilot-api' as const,
  };
}

async function handleJules(req: ChatRequest) {
  const lastMessage = req.messages[req.messages.length - 1];
  const taskType = lastMessage.content.toLowerCase().includes('bug') ? 'bug_fix' :
                    lastMessage.content.toLowerCase().includes('test') ? 'test' : 'feature';

  const model = createJulesModel(taskType);
  const result = await model.doGenerate({
    messages: req.messages,
    temperature: req.temperature,
  });

  return {
    text: result.text,
    finishReason: result.finishReason,
    usage: normalizeUsage(req.messages, result.text, result.usage),
    model: 'google-jules',
    provider: 'google-jules' as const,
    metadata: result.metadata,
  };
}

async function executeChatRequest(request: ChatRequest): Promise<ProviderResult> {
  switch (request.provider) {
    case 'google-jules':
      return handleJules(request);
    case 'gemini-code-cli':
      return handleGeminiCodeCLI(request);
    case 'gemini-code':
      return handleGeminiCode(request);
    case 'claude-code-cli':
      return handleClaudeCodeCLI(request);
    case 'codex-cli':
      return handleCodex(request);
    case 'cursor-agent-cli':
      return handleCursorAgent(request);
    case 'copilot-cli':
      return handleCopilot(request);
    case 'copilot-api':
      return handleCopilotAPI(request);
    default:
      throw new Error(`Unknown provider: ${request.provider}`);
  }
}

function executeChatRequestStream(request: ChatRequest): StreamTextResultAny | null {
  if (request.expectJsonObject) {
    return null;
  }

  switch (request.provider) {
    case 'gemini-code-cli': {
      const modelName = request.model === 'gemini-2.5-flash' ? 'gemini-2.5-flash' : 'gemini-2.5-pro';
      return streamText({
        model: gemini(modelName),
        messages: request.messages,
        temperature: request.temperature ?? 0.7,
        maxRetries: 2,
      });
    }
    case 'claude-code-cli': {
      const modelName = request.model || 'sonnet';
      return streamText({
        model: claudeCode(modelName),
        messages: request.messages,
        temperature: request.temperature ?? 0.7,
        maxRetries: 2,
      });
    }
    default:
      return null;
  }
}

// @ts-ignore - Server reference not used but Bun.serve starts the server
const _server = Bun.serve({
  port: PORT,
  async fetch(req) {
    const headers = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Content-Type': 'application/json',
    };

    if (req.method === 'OPTIONS') {
      return new Response(null, { headers });
    }

    const url = new URL(req.url);

    if (url.pathname === '/v1/models') {
      if (req.method !== 'GET') {
        return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
      }

      try {
        const catalog = await listModelCatalog();
        const data = catalog.map(toOpenAIModel);
        return new Response(JSON.stringify({ object: 'list', data }), { headers });
      } catch (error: any) {
        console.error('Failed to list models:', error);
        return new Response(JSON.stringify({ error: error.message || String(error) }), { status: 500, headers });
      }
    }

    // NEW: Orchestrated endpoint that uses ExecutionCoordinator
    if (url.pathname === '/v1/orchestrated/chat') {
      if (req.method !== 'POST') {
        return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
      }

      try {
        const body = await req.json() as any;
        const messages = body.messages || [];
        const lastMessage = messages[messages.length - 1];

        if (!lastMessage || lastMessage.role !== 'user') {
          return new Response(JSON.stringify({ error: 'Last message must be from user' }), { status: 400, headers });
        }

        // Analyze task complexity
        const analysis = analyzeTaskComplexity(lastMessage.content);

        // Select best model (prefer Codex for coding tasks)
        const selectedModel = selectCodexModelForCoding(lastMessage.content);

        // Execute through Elixir ExecutionCoordinator
        const result = await elixirBridge.executeTask({
          task: lastMessage.content,
          language: body.language || 'auto',
          complexity: analysis.complexity,
          context: {
            messages: messages.slice(0, -1), // Previous context
            model_hint: selectedModel.model, // Use Codex model for coding
            preferred_provider: selectedModel.provider,
            temperature: body.temperature || selectedModel.temperature,
          }
        });

        // Format as OpenAI-compatible response
        const response = {
          id: `chatcmpl-${randomBytes(16).toString('hex')}`,
          object: 'chat.completion',
          created: Math.floor(Date.now() / 1000),
          model: result.model_used || body.model || 'auto',
          choices: [{
            index: 0,
            message: {
              role: 'assistant',
              content: result.result,
            },
            finish_reason: 'stop',
          }],
          usage: {
            prompt_tokens: result.metrics.tokens_used || 0,
            completion_tokens: 0,
            total_tokens: result.metrics.tokens_used || 0,
          },
          system_fingerprint: `orchestrated-${result.template_used}`,
          x_metrics: result.metrics, // Custom metrics
        };

        return new Response(JSON.stringify(response), { headers });
      } catch (error: any) {
        console.error('Error handling /v1/orchestrated/chat:', error);
        // Fallback to regular chat if orchestration fails
        console.log('Falling back to regular chat completion...');
        const body = await req.json() as any;
        const { request: chatRequest, model: modelEntry } = await convertOpenAIChatCompletionRequest(body);
        const rawResult = await executeChatRequest({ ...chatRequest, stream: false });
        const formattedResult = enforceResponseFormat(rawResult, chatRequest);
        const responsePayload = buildOpenAIChatResponse(formattedResult, modelEntry, body);
        return new Response(JSON.stringify(responsePayload), { headers });
      }
    }

    if (url.pathname === '/v1/chat/completions') {
      if (req.method !== 'POST') {
        return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
      }

      try {
        const body = await req.json() as any;

        const { request: chatRequest, model: modelEntry } = await convertOpenAIChatCompletionRequest(body);
        if (chatRequest.stream) {
          const streamResult = executeChatRequestStream(chatRequest);
          if (streamResult) {
            return await createOpenAIStreamFromStreamResult(streamResult, chatRequest, modelEntry, body);
          }

          const rawResult = await executeChatRequest({ ...chatRequest, stream: false });
          const formattedResult = enforceResponseFormat(rawResult, chatRequest);
          return createOpenAIStreamFromResult(formattedResult, modelEntry, body);
        }

        const rawResult = await executeChatRequest({ ...chatRequest, stream: false });
        const formattedResult = enforceResponseFormat(rawResult, chatRequest);
        const responsePayload = buildOpenAIChatResponse(formattedResult, modelEntry, body);
        return new Response(JSON.stringify(responsePayload), { headers });
      } catch (error: any) {
        console.error('Error handling /v1/chat/completions:', error);
        const clientError =
          error?.message?.startsWith('Unknown model') ||
          error?.message?.startsWith('Unsupported response_format type');
        const status = clientError ? 400 : 500;
        return new Response(JSON.stringify({ error: error.message || String(error) }), { status, headers });
      }
    }

    // ============================================
    // Codex OAuth Endpoints
    // ============================================

    if (url.pathname === '/codex/auth/start') {
      const pkce = generatePKCE();
      const state = createOAuthState();
      currentCodexOAuthState = { state, pkce };

      const authUrl = new URL(CODEX_AUTHORIZE_URL);
      authUrl.searchParams.set('response_type', 'code');
      authUrl.searchParams.set('client_id', CODEX_CLIENT_ID);
      authUrl.searchParams.set('redirect_uri', CODEX_REDIRECT_URI);
      authUrl.searchParams.set('scope', CODEX_SCOPE);
      authUrl.searchParams.set('code_challenge', pkce.challenge);
      authUrl.searchParams.set('code_challenge_method', 'S256');
      authUrl.searchParams.set('state', state);
      authUrl.searchParams.set('id_token_add_organizations', 'true');
      authUrl.searchParams.set('codex_cli_simplified_flow', 'true');
      authUrl.searchParams.set('originator', 'codex_cli_rs');

      console.log('\n🔐 Codex OAuth started');
      console.log('   Auth URL:', authUrl.toString());

      return new Response(JSON.stringify({
        authUrl: authUrl.toString(),
        message: 'Open the auth URL in your browser',
        callbackUrl: CODEX_REDIRECT_URI,
      }), { headers });
    }

    if (url.pathname === '/codex/auth/complete') {
      if (!currentCodexOAuthState) {
        return new Response(JSON.stringify({ error: 'No OAuth flow in progress' }), {
          status: 400,
          headers,
        });
      }

      const code = url.searchParams.get('code');
      if (!code) {
        return new Response(JSON.stringify({ error: 'No authorization code provided' }), {
          status: 400,
          headers,
        });
      }

      const success = await exchangeCodexCode(code, currentCodexOAuthState.pkce.verifier);
      currentCodexOAuthState = null;

      if (!success) {
        return new Response(JSON.stringify({ error: 'Failed to exchange code' }), {
          status: 500,
          headers,
        });
      }

      return new Response(JSON.stringify({
        success: true,
        accountId: codexTokenStore.accountId,
        expiresAt: codexTokenStore.expiresAt,
      }), { headers });
    }

    if (url.pathname === '/codex/auth/status') {
      const hasToken = !!codexTokenStore.accessToken;
      const isValid = hasToken && (!codexTokenStore.expiresAt || codexTokenStore.expiresAt > Date.now());

      return new Response(JSON.stringify({
        authenticated: hasToken,
        valid: isValid,
        expiresAt: codexTokenStore.expiresAt,
        accountId: codexTokenStore.accountId,
      }), { headers });
    }

    // ============================================
    // General Endpoints
    // ============================================

    if (url.pathname === '/health') {
      return new Response(
        JSON.stringify({
          status: 'ok',
          providers: ['gemini-code-cli', 'gemini-code', 'claude-code-cli', 'codex-cli', 'cursor-agent-cli', 'copilot-cli'],
          codex: {
            authenticated: !!codexTokenStore.accessToken,
            accountId: codexTokenStore.accountId,
          }
        }),
        { headers }
      );
    }

    return new Response(JSON.stringify({
      error: 'Not found',
      endpoints: [
        'GET  /health',
        'GET  /v1/models',
        'POST /v1/chat/completions',
        'GET  /codex/auth/start',
        'GET  /codex/auth/complete?code=...',
        'GET  /codex/auth/status',
      ],
    }), {
      status: 404,
      headers,
    });
  },
});


// Streamlined post-table startup summary
console.log(`${green}🚀${reset} Server ready at ${bold}http://localhost:${PORT}${reset}`);
console.log(`${bold}🔗 Endpoints:${reset} /health  /v1/models  /v1/chat/completions  /codex/auth/start  /codex/auth/complete?code=  /codex/auth/status`);
console.log(`${bold}💡 Tips:${reset} gemini: gcloud auth application-default login  |  claude: claude setup-token  |  codex: codex login  |  cursor: cursor-agent login  |  copilot: set GH_TOKEN  |  github-models: set GITHUB_TOKEN`);
