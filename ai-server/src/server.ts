#!/usr/bin/env bun

/**
 * Unified AI Providers HTTP Server
 *
 * Bridges multiple AI providers through a single HTTP interface:
 * - Gemini (via ai-sdk-provider-gemini-cli - stable wrapper)
 * - Claude (via ai-sdk-provider-claude-code - stable wrapper)
 * - Codex (via OAuth to ChatGPT backend)
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

import { generateText } from 'ai';
import { createGeminiProvider } from 'ai-sdk-provider-gemini-cli';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { createServer } from 'http';
import { randomBytes, createHash } from 'crypto';
import escapeHtml from 'escape-html';
import { loadCredentialsFromEnv, checkCredentialAvailability, printCredentialStatus } from './load-credentials';

// Load credentials from environment variables if available
console.log('🔐 Loading credentials...');
const envStats = loadCredentialsFromEnv();
const allStats = checkCredentialAvailability();
printCredentialStatus(allStats);

const PORT = parsePort(process.env.PORT, 3000, 'PORT');
const OAUTH_CALLBACK_PORT = parsePort(process.env.OAUTH_CALLBACK_PORT, 1455, 'OAUTH_CALLBACK_PORT');
const OAUTH_TIMEOUT_MS = 10 * 60 * 1000; // 10 minutes
const TOKEN_EXPIRY_BUFFER_MS = 55 * 60 * 1000; // 55 minutes

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
  };
}

const DEFAULT_MODEL_CATALOG: ModelCatalogEntry[] = [
  {
    id: 'gemini-2.5-flash',
    upstreamId: 'gemini-2.5-flash',
    provider: 'gemini-code',
    displayName: 'Gemini Code 2.5 Flash',
    description: 'Google Gemini Code Assist (Flash) via Cloud Code',
    ownedBy: 'google',
    contextWindow: 8388608,
    capabilities: { completion: true, streaming: false, reasoning: false, vision: false },
  },
  {
    id: 'gemini-2.5-pro',
    upstreamId: 'gemini-2.5-pro',
    provider: 'gemini-code-cli',
    displayName: 'Gemini Code 2.5 Pro (SDK)',
    description: 'Gemini Code Assist via gemini-cli provider',
    ownedBy: 'google',
    contextWindow: 2097152,
    capabilities: { completion: true, streaming: false, reasoning: false, vision: false },
  },
  {
    id: 'claude-3.5-sonnet',
    upstreamId: 'sonnet',
    provider: 'claude-code-cli',
    displayName: 'Claude 3.5 Sonnet (SDK)',
    description: 'Anthropic Claude via claude-code cli SDK',
    ownedBy: 'anthropic',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: true },
  },
  {
    id: 'gpt-5-codex',
    upstreamId: 'gpt-5-codex',
    provider: 'codex',
    displayName: 'OpenAI Codex GPT-5',
    description: 'ChatGPT Codex backend via OAuth',
    ownedBy: 'openai',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false },
  },
  {
    id: 'cursor-gpt-5',
    upstreamId: 'gpt-5',
    provider: 'cursor-agent',
    displayName: 'Cursor Agent GPT-5',
    description: 'Cursor CLI agent runner',
    ownedBy: 'cursor',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false },
  },
  {
    id: 'copilot-claude-sonnet-4.5',
    upstreamId: 'claude-sonnet-4.5',
    provider: 'copilot',
    displayName: 'GitHub Copilot Claude Sonnet 4.5',
    description: 'GitHub Copilot CLI with Claude backend',
    ownedBy: 'github',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: false, reasoning: true, vision: false },
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
          return item.text.map((value) => (typeof value === 'string' ? value : '')).join('\n');
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

function coerceLegacyMessages(rawMessages: any[]): Message[] {
  if (!Array.isArray(rawMessages)) return [];
  return rawMessages.map((message) => mapOpenAIMessageToInternal(message));
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
  const messages = body.messages.map(mapOpenAIMessageToInternal);

  const request: ChatRequest = {
    provider: modelEntry.provider,
    model: modelEntry.upstreamId || modelEntry.id,
    messages,
    temperature: normalizeTemperature(body.temperature),
    maxTokens: normalizeMaxTokens(body.max_tokens ?? body.max_completion_tokens ?? body.max_completion_tokens),
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

async function refreshCodexToken(): Promise<boolean> {
  if (!codexTokenStore.refreshToken) return false;

  try {
    const response = await fetch(CODEX_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: codexTokenStore.refreshToken,
        client_id: CODEX_CLIENT_ID,
      }),
    });

    if (!response.ok) {
      console.error('Codex token refresh failed:', response.status);
      return false;
    }

    const json: any = await response.json();
    if (!json?.access_token || !json?.refresh_token) return false;

    codexTokenStore.accessToken = json.access_token;
    codexTokenStore.refreshToken = json.refresh_token;
    codexTokenStore.expiresAt = Date.now() + json.expires_in * 1000;

    const decoded = decodeJWT(json.access_token);
    codexTokenStore.accountId = decoded?.['https://api.openai.com/auth']?.chatgpt_account_id;

    console.log('✓ Codex token refreshed');
    return true;
  } catch (error) {
    console.error('Codex token refresh error:', error);
    return false;
  }
}

async function ensureValidCodexToken(): Promise<boolean> {
  if (!codexTokenStore.accessToken) return false;
  if (codexTokenStore.expiresAt && codexTokenStore.expiresAt - Date.now() < 5 * 60 * 1000) {
    return await refreshCodexToken();
  }
  return true;
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

function startCodexCallbackServer(expectedState: string): Promise<string | null> {
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
const gemini = createGeminiProvider({
  authType: 'google-auth-library' as any,
});

interface ChatRequest {
  provider: 'gemini-code-cli' | 'gemini-code' | 'claude-code-cli' | 'codex' | 'cursor-agent' | 'copilot';
  model?: string;
  messages: Message[];
  temperature?: number;
  maxTokens?: number;
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
    maxTokens: req.maxTokens,
    maxRetries: 2,
  });

  return {
    text: result.text,
    finishReason: result.finishReason,
    usage: normalizeUsage(req.messages, result.text, result.usage),
    model: modelName,
    provider: 'gemini-code-cli',
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

    const data = await response.json();

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
      provider: 'gemini-code',
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
    maxTokens: req.maxTokens,
    maxRetries: 2,
  });

  return {
    text: result.text,
    finishReason: result.finishReason,
    usage: normalizeUsage(req.messages, result.text, result.usage),
    model: modelName,
    provider: 'claude-code-cli',
  };
}

async function handleCodex(req: ChatRequest) {
  // Use OAuth-based API instead of CLI
  const valid = await ensureValidCodexToken();

  if (!valid || !codexTokenStore.accessToken || !codexTokenStore.accountId) {
    throw new Error('Codex not authenticated. Use /codex/auth/start to authenticate.');
  }

  const model = req.model || 'gpt-5-codex';

  try {
    const response = await fetch('https://chatgpt.com/backend-api/codex/responses', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${codexTokenStore.accessToken}`,
        'chatgpt-account-id': codexTokenStore.accountId,
        'OpenAI-Beta': 'responses=experimental',
        'originator': 'codex_cli_rs',
        'session_id': crypto.randomUUID(),
      },
      body: JSON.stringify({
        model,
        messages: req.messages,
        temperature: req.temperature ?? 0.7,
        max_tokens: req.maxTokens,
      }),
    });

    if (!response.ok) {
      throw new Error(`Codex API error: ${response.status}`);
    }

    const data = await response.json();
    const text = data.choices?.[0]?.message?.content || JSON.stringify(data);

    return {
      text,
      finishReason: data.choices?.[0]?.finish_reason || 'stop',
      usage: normalizeUsage(req.messages, text, data.usage),
      model,
      provider: 'codex',
    };
  } catch (error: any) {
    throw new Error(`Codex request failed: ${error.message}`);
  }
}

async function handleCursorAgent(req: ChatRequest) {
  const prompt = messagesToPrompt(req.messages);
  const model = req.model || 'gpt-5';

  // Use -p for direct prompt execution with --print for non-interactive mode
  const args = ['-p', '--print', '--output-format', 'text', '--model', model, prompt];

  const output = await execCLI('cursor-agent', args);

  return {
    text: output,
    finishReason: 'stop',
    usage: normalizeUsage(req.messages, output),
    model,
    provider: 'cursor-agent',
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
    provider: 'copilot',
  };
}

async function executeChatRequest(request: ChatRequest): Promise<ProviderResult> {
  switch (request.provider) {
    case 'gemini-code-cli':
      return handleGeminiCodeCLI(request);
    case 'gemini-code':
      return handleGeminiCode(request);
    case 'claude-code-cli':
      return handleClaudeCodeCLI(request);
    case 'codex':
      return handleCodex(request);
    case 'cursor-agent':
      return handleCursorAgent(request);
    case 'copilot':
      return handleCopilot(request);
    default:
      throw new Error(`Unknown provider: ${request.provider}`);
  }
}

const server = Bun.serve({
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

    if (url.pathname === '/v1/chat/completions') {
      if (req.method !== 'POST') {
        return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
      }

      try {
        const body = await req.json();

        if (body?.stream === true) {
          return new Response(JSON.stringify({ error: 'Streaming responses are not yet supported.' }), {
            status: 400,
            headers,
          });
        }

        const { request: chatRequest, model: modelEntry } = await convertOpenAIChatCompletionRequest(body);
        const result = await executeChatRequest(chatRequest);
        const responsePayload = buildOpenAIChatResponse(result, modelEntry, body);
        return new Response(JSON.stringify(responsePayload), { headers });
      } catch (error: any) {
        console.error('Error handling /v1/chat/completions:', error);
        const status = error?.message?.startsWith('Unknown model') ? 400 : 500;
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
          providers: ['gemini-code-cli', 'gemini-code', 'claude-code-cli', 'codex', 'cursor-agent', 'copilot'],
          codex: {
            authenticated: !!codexTokenStore.accessToken,
            accountId: codexTokenStore.accountId,
          }
        }),
        { headers }
      );
    }

    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers,
      });
    }

    if (url.pathname !== '/chat') {
      return new Response(JSON.stringify({
        error: 'Not found',
        endpoints: [
          'GET  /health',
          'GET  /codex/auth/start',
          'GET  /codex/auth/complete?code=...',
          'GET  /codex/auth/status',
          'POST /chat',
        ]
      }), {
        status: 404,
        headers,
      });
    }

    try {
      const body: ChatRequest = await req.json();

      if (!body.provider) {
        return new Response(
          JSON.stringify({ error: 'Missing provider field' }),
          { status: 400, headers }
        );
      }

      if (!body.messages || body.messages.length === 0) {
        return new Response(
          JSON.stringify({ error: 'Missing or empty messages array' }),
          { status: 400, headers }
        );
      }

      let provider: ChatRequest['provider'];

      switch (body.provider) {
        case 'gemini-code-cli':
        case 'gemini-code':
        case 'claude-code-cli':
        case 'codex':
        case 'cursor-agent':
        case 'copilot':
          provider = body.provider;
          break;
        default:
          return new Response(
            JSON.stringify({ error: `Unknown provider: ${body.provider}` }),
            { status: 400, headers }
          );
      }

      const messages = coerceLegacyMessages(body.messages);
      const chatRequest: ChatRequest = {
        provider,
        model: typeof body.model === 'string' ? body.model : undefined,
        messages,
        temperature: normalizeTemperature(body.temperature),
        maxTokens: normalizeMaxTokens(body.maxTokens ?? body.max_tokens),
      };

      const result = await executeChatRequest(chatRequest);

      return new Response(JSON.stringify(result), { headers });
    } catch (error: any) {
      console.error('Error processing request:', error);
      return new Response(
        JSON.stringify({
          error: error.message || String(error),
          stack: error.stack,
        }),
        { status: 500, headers }
      );
    }
  },
});

console.log(`\n🚀 AI Providers HTTP server listening on http://localhost:${PORT}`);
console.log(`\nProviders:`);
console.log(`  - gemini-code-cli (SDK with ADC)`);
console.log(`  - gemini-code (Direct Code Assist API with ADC)`);
console.log(`  - claude-code-cli (SDK with OAuth)`);
console.log(`  - codex (OAuth) ${codexTokenStore.accessToken ? '✓ authenticated' : '⚠ not authenticated'}`);
console.log(`  - cursor-agent (OAuth)`);
console.log(`  - copilot (GitHub OAuth)`);
console.log(`\nEndpoints:`);
console.log(`  GET  /health                      - Health check`);
console.log(`  POST /chat                        - Chat with AI providers`);
console.log(`  GET  /codex/auth/start            - Start Codex OAuth flow`);
console.log(`  GET  /codex/auth/complete?code=   - Complete Codex OAuth`);
console.log(`  GET  /codex/auth/status           - Check Codex auth status`);
console.log(`\nAuthentication notes:`);
console.log(`  - gemini-code-cli: ADC (gcloud auth application-default login)`);
console.log(`  - gemini-code: ADC (gcloud auth application-default login)`);
console.log(`  - claude-code-cli: Run 'claude setup-token' (requires Claude subscription)`);
console.log(`  - codex: OAuth via /codex/auth/start`);
console.log(`  - cursor-agent: Run 'cursor-agent login' (stores OAuth in ~/.config/cursor/auth.json)`);
console.log(`  - copilot: Set GH_TOKEN/GITHUB_TOKEN or run '/login' in copilot`);
console.log(`\nTo use Codex:`);
console.log(`  1. GET http://localhost:${PORT}/codex/auth/start`);
console.log(`  2. Open the returned authUrl in your browser`);
console.log(`  3. After OAuth callback, GET /codex/auth/complete?code=<code>`);
console.log(`\nTo use Gemini Code Assist (gemini-code):`);
console.log(`  1. Enable API: gcloud services enable cloudcode-pa.googleapis.com`);
console.log(`  2. Setup ADC: gcloud auth application-default login`);
console.log(`  3. Set project: gcloud config set project ${GEMINI_CODE_PROJECT}`);
console.log();
