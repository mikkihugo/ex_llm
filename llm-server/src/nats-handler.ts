#!/usr/bin/env bun

/**
 * @file NATS Handler for LLM Server
 * @description This module handles NATS requests from the Elixir backend,
 * routing them to the appropriate LLM providers. It subscribes to `llm.request`
 * and publishes responses to `llm.response` or errors to `llm.error`.
 */

import { connect, NatsConnection, Subscription } from 'nats';
import { generateText } from 'ai';
import { createGeminiProvider } from './providers/gemini-code.js';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from './providers/codex';
import { copilot } from './providers/copilot';
import { githubModels } from './providers/github-models';
import { julesWithMetadata } from './providers/google-ai-jules';
import { cursor } from './providers/cursor.js';
import { openrouter } from './providers/openrouter.js';
import { selectOpenRouterModel } from './openrouter-selector.js';
import { MODEL_CAPABILITIES } from './data/model-capabilities-loader.js';
import { convertOpenAIToolsToAISDK, type OpenAITool } from './tool-converter.js';
import { analyzeTaskComplexity, type TaskComplexity } from './task-complexity.js';
import { logger } from './logger.js';
import { metrics } from './metrics.js';

// ── Type Safety & Error Handling ──
import type {
  LLMRequest,
  LLMResponse,
  LLMError,
  TaskType,
  ProviderKey,
  CapabilityHint,
  ErrorCode
} from './types';
import { isValidLLMRequest } from './types';

import {
  StandardAPIError,
  ValidationError as APIValidationError,
  ProviderError,
  TimeoutError,
  formatError,
  extractErrorCode as extractErrorCodeFromError
} from './error-formatter';

import { SafeNATSPublisher, createPublisher } from './nats-publisher';

import {
  isProviderAvailable,
  getMissingCredentials,
  logCredentialStatus
} from './credential-validator';

// Type definitions are now imported from ./types.ts
// See: LLMRequest, LLMResponse, LLMError, TaskType, ProviderKey, CapabilityHint

// --- Constants ---

/**
 * @const {object} MODEL_SELECTION_MATRIX
 * @description A matrix for selecting the best model based on task type and complexity.
 */
const MODEL_SELECTION_MATRIX: Record<TaskType, Record<TaskComplexity, Array<{ provider: ProviderKey; model: string }>>> = {
  general: {
    simple: [{ provider: 'gemini', model: 'gemini-2.5-flash' }, { provider: 'copilot', model: 'gpt-5-mini' }, { provider: 'copilot', model: 'grok-code-fast-1' }, { provider: 'codex', model: 'o3-mini-codex' }, { provider: 'cursor', model: 'auto' }],
    medium: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'claude', model: 'sonnet' }, { provider: 'gemini', model: 'gemini-2.5-pro' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'auto' }],
    complex: [{ provider: 'claude', model: 'sonnet' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'claude', model: 'opus' }, { provider: 'copilot', model: 'gpt-4o' }, { provider: 'gemini', model: 'gemini-2.5-pro' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'cheetah' }]
  },
  architect: {
    simple: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'claude', model: 'sonnet' }, { provider: 'openrouter', model: 'auto' }, { provider: 'gemini', model: 'gemini-2.5-flash' }, { provider: 'cursor', model: 'auto' }],
    medium: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'claude', model: 'sonnet' }, { provider: 'openrouter', model: 'auto' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'gemini', model: 'gemini-2.5-pro' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'auto' }],
    complex: [{ provider: 'claude', model: 'opus' }, { provider: 'openrouter', model: 'auto' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'claude', model: 'sonnet' }, { provider: 'copilot', model: 'gpt-4o' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'cheetah' }]
  },
  coder: {
    simple: [{ provider: 'copilot', model: 'gpt-5-mini' }, { provider: 'copilot', model: 'grok-code-fast-1' }, { provider: 'openrouter', model: 'auto' }, { provider: 'gemini', model: 'gemini-2.5-flash' }, { provider: 'codex', model: 'o3-mini-codex' }, { provider: 'cursor', model: 'auto' }],
    medium: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'openrouter', model: 'auto' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'claude', model: 'sonnet' }, { provider: 'cursor', model: 'auto' }],
    complex: [{ provider: 'codex', model: 'gpt-5-codex' }, { provider: 'claude', model: 'opus' }, { provider: 'copilot', model: 'gpt-4o' }, { provider: 'openrouter', model: 'auto' }, { provider: 'claude', model: 'sonnet' }, { provider: 'cursor', model: 'cheetah' }]
  },
  qa: {
    simple: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'gemini', model: 'gemini-2.5-flash' }, { provider: 'claude', model: 'sonnet' }, { provider: 'cursor', model: 'auto' }],
    medium: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'claude', model: 'sonnet' }, { provider: 'gemini', model: 'gemini-2.5-pro' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'auto' }],
    complex: [{ provider: 'claude', model: 'sonnet' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'copilot', model: 'gpt-4o' }, { provider: 'claude', model: 'opus' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'cheetah' }]
  }
};

// Error classes are now imported from ./error-formatter.ts
// See: StandardAPIError, ValidationError, ProviderError, TimeoutError, etc.

/**
 * @class NATSHandler
 * @description Manages the NATS connection, subscriptions, and message handling.
 *
 * Uses type-safe modules for:
 * - Request validation (types.ts)
 * - Error handling (error-formatter.ts)
 * - NATS publishing (nats-publisher.ts)
 * - Credential validation (credential-validator.ts)
 */
class NATSHandler {
  private nc: NatsConnection | null = null;
  private publisher: SafeNATSPublisher | null = null;
  private subscriptions: Subscription[] = [];
  private subscriptionTasks: Promise<void>[] = [];
  private processingCount: number = 0;
  private readonly MAX_CONCURRENT = 10;

  /**
   * Connects to the NATS server and validates credentials.
   *
   * Logs credential status at startup so issues are visible immediately.
   * Publisher is initialized for safe NATS message handling.
   */
  async connect() {
    try {
      // Log credential status before connecting
      logCredentialStatus();

      const natsUrl = process.env.NATS_URL || 'nats://localhost:4222';
      this.nc = await connect({
        servers: natsUrl
      });

      // Initialize safe NATS publisher
      this.publisher = createPublisher(this.nc);

      logger.info('[NATS] Connected to NATS server', {
        url: natsUrl
      });

      await this.subscribeToLLMRequests();
    } catch (error) {
      logger.error('[NATS] Failed to connect to NATS', {
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined
      });
      throw error;
    }
  }

  /**
   * Subscribes to the LLM request topic.
   */
  async subscribeToLLMRequests() {
    if (!this.nc) throw new Error('NATS not connected');
    const subscription = this.nc.subscribe('llm.request');
    this.subscriptions.push(subscription);
    const processor = this.handleLLMRequestStream(subscription);
    const taskWithCleanup = processor.catch(error => {
      console.error('[NATS] Unhandled error in LLM request stream:', error);
      const index = this.subscriptionTasks.indexOf(taskWithCleanup);
      if (index > -1) this.subscriptionTasks.splice(index, 1);
      throw error;
    });
    this.subscriptionTasks.push(taskWithCleanup);
  }

  private async handleLLMRequestStream(subscription: Subscription) {
    for await (const msg of subscription) {
      if (this.processingCount >= this.MAX_CONCURRENT) {
        console.warn(`[NATS] Max concurrent processing (${this.MAX_CONCURRENT}) reached. Skipping message.`);
        continue;
      }
      this.processingCount++;
      this.handleSingleLLMRequest(msg).finally(() => {
        this.processingCount--;
      });
    }
  }

  /**
   * Handle a single LLM request from NATS with full type safety and error handling.
   *
   * Flow:
   * 1. Parse and validate JSON using type guards
   * 2. Process with 30-second timeout
   * 3. Publish response or error to NATS
   * 4. Record metrics
   *
   * Never throws - all errors are caught and published to NATS.
   */
  private async handleSingleLLMRequest(msg: any): Promise<void> {
    let request: LLMRequest | null = null;
    const startTime = Date.now();

    try {
      // ──── Step 1: Parse JSON ────
      let parsedData: unknown;
      try {
        parsedData = JSON.parse(msg.data.toString());
      } catch (parseError) {
        throw new APIValidationError(
          `Invalid JSON in request: ${parseError instanceof Error ? parseError.message : 'parse error'}`
        );
      }

      // ──── Step 2: Validate schema using type guards ────
      if (!isValidLLMRequest(parsedData)) {
        throw new APIValidationError('Request does not match LLMRequest schema');
      }
      request = parsedData;

      logger.info('[NATS] Received LLM request', {
        model: request.model,
        taskType: request.task_type,
        correlationId: request.correlation_id
      });

      // ──── Step 3: Process with timeout (30s max) ────
      const response = await Promise.race([
        this.processLLMRequest(request),
        this.createTimeoutPromise(30000)
      ]);

      // ──── Step 4: Publish response safely ────
      if (!this.publisher) {
        logger.error('[NATS] Publisher not initialized when handling request', {
          correlationId: request.correlation_id
        });
        return;
      }

      if (msg.reply) {
        await this.publisher.publishToReply(msg.reply, response);
      } else {
        await this.publisher.publishResponse('llm.response', response);
      }

      // ──── Step 5: Record metrics ────
      const duration = Date.now() - startTime;
      metrics.recordRequest('nats_llm_request', duration, false);
      if (response.model) {
        const [provider, model] = response.model.split(':');
        metrics.recordModelUsage(provider || 'unknown', model || response.model, response.tokens_used);
      }

      logger.info('[NATS] LLM request completed successfully', {
        model: response.model,
        duration: `${duration}ms`,
        correlationId: request.correlation_id
      });

    } catch (error) {
      // ──── Step 6: Handle errors safely ────
      const duration = Date.now() - startTime;
      metrics.recordRequest('nats_llm_request', duration, true);

      logger.error('[NATS] Error processing LLM request', {
        error: error instanceof Error ? error.message : String(error),
        correlationId: request?.correlation_id,
        stack: error instanceof Error ? error.stack : undefined
      });

      // Format error consistently
      const lmmError = formatError(error, request?.correlation_id);

      // Publish error safely
      if (!this.publisher) {
        logger.error('[NATS] Cannot publish error - publisher not initialized', {
          correlationId: request?.correlation_id
        });
        return;
      }

      if (msg.reply) {
        await this.publisher.publishToReply(msg.reply, lmmError);
      } else {
        await this.publisher.publishError('llm.error', lmmError);
      }
    }
  }

  async processLLMRequest(request: LLMRequest): Promise<LLMResponse> {
    const selection = this.resolveModelSelection(request);
    const { model, provider, complexity } = selection;
    const { messages, max_tokens = 4000, temperature = 0.7, stream = false, tools } = request;

    let aiSDKTools;
    if (tools && tools.length > 0) {
      aiSDKTools = convertOpenAIToolsToAISDK(tools);
    }

    logger.info('[NATS] Model selection', { requestedModel: request.model, selectedModel: model, provider, complexity, correlationId: request.correlation_id });

    if (stream) {
      throw new Error('Streaming not implemented yet');
    }
    const partialResponse = await this.handleNonStreamingRequest(provider, model, messages, { max_tokens, temperature, tools: aiSDKTools }, this.normalizeTaskType(request), complexity);
    
    return {
      text: partialResponse.text,
      model: `${provider}:${model}`,
      tokens_used: partialResponse.tokens_used,
      cost_cents: partialResponse.cost_cents,
      timestamp: new Date().toISOString(),
      correlation_id: request.correlation_id
    };
  }

  private resolveModelSelection(request: LLMRequest): { model: string; provider: ProviderKey; complexity: TaskComplexity } {
    const providerHint = request.provider ? this.normalizeProvider(request.provider) : null;

    if (request.model && request.model !== 'auto') {
      const provider = providerHint ?? this.getProviderFromModel(request.model);
      if (!provider) {
        throw new ProviderError(
          'model_selection',
          `Unable to determine provider for model: ${request.model}`
        );
      }

      // ← Check if provider has credentials
      if (!isProviderAvailable(provider as ProviderKey)) {
        const missing = getMissingCredentials(provider as ProviderKey);
        throw new ProviderError(
          provider,
          `Provider ${provider} not available. Missing credentials: ${missing.join(', ')}`
        );
      }

      const complexity = request.complexity ?? this.inferComplexity(request, this.taskTypeFromRequest(request));
      return { model: request.model, provider: provider as ProviderKey, complexity };
    }

    // For auto-selection, find an available provider
    const taskType = this.taskTypeFromRequest(request);
    const complexity = request.complexity ?? this.inferComplexity(request, taskType);
    const candidates = this.getModelCandidates(taskType, complexity, providerHint as ProviderKey | null, request.capabilities);

    // Filter to only available providers
    const available = candidates.filter(c => isProviderAvailable(c.provider));
    if (available.length === 0) {
      throw new ProviderError(
        'auto_select',
        `No models available for task_type=${taskType} complexity=${complexity}. Check credential status with logCredentialStatus().`
      );
    }

    const choice = available[0];
    return { model: choice.model, provider: choice.provider, complexity };
  }

  private taskTypeFromRequest(request: LLMRequest): TaskType {
    if (request.task_type) {
      const mapped = this.normalizeTaskTypeString(request.task_type);
      if (mapped) return mapped;
    }
    if (request.capabilities?.some(c => this.normalizeCapability(c) === 'code')) return 'coder';
    if (request.capabilities?.some(c => this.normalizeCapability(c) === 'reasoning')) return 'architect';
    return 'general';
  }

  private normalizeTaskType(request: LLMRequest): TaskType {
    return this.taskTypeFromRequest(request);
  }

  private normalizeTaskTypeString(raw: string): TaskType | null {
    const value = raw.toLowerCase();
    if (['architect', 'planner', 'analysis'].includes(value)) return 'architect';
    if (['coder', 'developer', 'implementation'].includes(value)) return 'coder';
    if (['qa', 'tester', 'validation'].includes(value)) return 'qa';
    return null;
  }

  private normalizeCapability(raw: string): CapabilityHint | null {
    const value = raw.toLowerCase();
    if (['code', 'coding'].includes(value)) return 'code';
    if (['reasoning', 'analysis'].includes(value)) return 'reasoning';
    if (['creativity', 'creative'].includes(value)) return 'creativity';
    if (['speed', 'fast'].includes(value)) return 'speed';
    if (['cost', 'cheap'].includes(value)) return 'cost';
    return null;
  }

  private inferComplexity(request: LLMRequest, taskType: TaskType): TaskComplexity {
    const text = request.messages?.map(m => m.content).join('\n') ?? '';
    return analyzeTaskComplexity(text, {
      requiresCode: taskType === 'coder',
      requiresReasoning: taskType === 'architect',
      contextLength: text.length
    }).complexity;
  }

  private calculateCapabilityScore(candidate: { provider: ProviderKey; model: string }, capabilities: CapabilityHint[]): number {
    const profile = MODEL_CAPABILITIES[candidate.model];
    if (!profile) return 50;
    let score = 0, weight = 0;
    capabilities.forEach((cap, i) => {
      const norm = this.normalizeCapability(cap);
      if (!norm) return;
      const w = capabilities.length - i;
      score += profile[norm] * w;
      weight += w;
    });
    return weight > 0 ? score / weight : 50;
  }

  private getModelCandidates(taskType: TaskType, complexity: TaskComplexity, providerHint: ProviderKey | null, capabilities?: CapabilityHint[]) {
    const preferences = MODEL_SELECTION_MATRIX[taskType] ?? MODEL_SELECTION_MATRIX.general;
    let candidates = preferences[complexity] ?? [];
    if (providerHint) {
      const filtered = candidates.filter(c => c.provider === providerHint);
      if (filtered.length > 0) candidates = filtered;
    }
    if (capabilities && capabilities.length > 0) {
      const scored = candidates.map(c => ({ ...c, score: this.calculateCapabilityScore(c, capabilities) }));
      scored.sort((a, b) => b.score - a.score);
      return scored;
    }
    return candidates;
  }

  private normalizeProvider(provider: string): string | null {
    const value = provider.toLowerCase();
    if (value.includes('claude')) return 'claude';
    if (value.includes('gemini')) return 'gemini';
    if (value.includes('codex')) return 'codex';
    if (value.includes('copilot')) return 'copilot';
    if (value.includes('cursor')) return 'cursor';
    if (value.includes('grok')) return 'copilot';
    if (value.includes('github')) return 'github';
    if (value.includes('jules')) return 'jules';
    return null;
  }

  private async handleNonStreamingRequest(provider: string, model: string, messages: any[], options: any, taskType?: TaskType, complexity?: TaskComplexity) {
    switch (provider) {
      case 'claude': return this.callClaude(model, messages, options);
      case 'gemini': return this.callGemini(model, messages, options);
      case 'codex': return this.callCodex(model, messages, options);
      case 'copilot': return this.callCopilot(model, messages, options);
      case 'cursor': return this.callCursor(model, messages, options);
      case 'openrouter': return this.callOpenRouter(model, messages, options, taskType || 'general', complexity || 'medium');
      case 'github': return this.callGitHubModels(model, messages, options);
      case 'jules': return this.callJules(model, messages, options);
      default: throw new ProviderError(provider, `Unknown provider: ${provider}`);
    }
  }

  private async callClaude(model: string, messages: any[], options: any) {
    const result = await generateText({ model: claudeCode(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage?.totalTokens, cost_cents: this.calculateClaudeCost(result.usage?.totalTokens || 0, model) };
  }

  private async callGemini(model: string, messages: any[], options: any) {
    const result = await generateText({ model: createGeminiProvider({ authType: 'oauth-personal' })(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage?.totalTokens, cost_cents: this.calculateGeminiCost(result.usage?.totalTokens || 0, model) };
  }

  private async callCodex(model: string, messages: any[], options: any) {
    const result = await generateText({ model: codex.languageModel(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage?.totalTokens, cost_cents: this.calculateCodexCost(result.usage?.totalTokens || 0, model) };
  }

  private async callCopilot(model: string, messages: any[], options: any) {
    const result = await generateText({ model: copilot.languageModel(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage?.totalTokens, cost_cents: 0 };
  }

  private async callGitHubModels(model: string, messages: any[], options: any) {
    const result = await generateText({ model: githubModels.languageModel(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage?.totalTokens, cost_cents: 0 };
  }

  private async callCursor(model: string, messages: any[], options: any) {
    const result = await generateText({ model: cursor.languageModel(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage?.totalTokens, cost_cents: 0 };
  }

  private async callOpenRouter(model: string, messages: any[], options: any, taskType: TaskType, complexity: TaskComplexity) {
    const selectedModel = model === 'auto' ? await selectOpenRouterModel(taskType, complexity) || 'auto' : model;
    if (selectedModel === 'auto') throw new Error('Could not select an OpenRouter model.');
    const result = await generateText({ model: openrouter(selectedModel), ...options, messages });
    return { text: result.text, tokens_used: result.usage.totalTokens, cost_cents: 0 };
  }

  private async callJules(model: string, messages: any[], options: any) {
    const result = await generateText({ model: julesWithMetadata(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage.totalTokens, cost_cents: 0 };
  }

  /**
   * Create a promise that rejects after specified timeout.
   *
   * Used with Promise.race() to enforce maximum request duration.
   * Prevents infinite hangs if provider becomes unresponsive.
   *
   * @param ms - Timeout in milliseconds
   * @returns Promise that rejects with TimeoutError after ms
   */
  private createTimeoutPromise(ms: number): Promise<LLMResponse> {
    return new Promise((_, reject) => {
      setTimeout(() => {
        reject(new TimeoutError(ms));
      }, ms);
    });
  }

  private getProviderFromModel(model: string): string | null {
    if (model.startsWith('claude')) return 'claude';
    if (model.startsWith('gemini')) return 'gemini';
    if (model.startsWith('gpt-')) return 'copilot'; // Default to copilot for gpt models
    if (model.startsWith('o3-')) return 'codex';
    return null;
  }

  private calculateClaudeCost(tokens: number, model: string): number {
    // Claude subscription models (free via Claude Pro/Max)
    const pricing = { 'sonnet': 0, 'opus': 0 };
    const rate = pricing[model as keyof typeof pricing] || 0; // Default to free (subscription)
    return Math.round((tokens / 1_000_000) * rate * 100);
  }

  private calculateGeminiCost(tokens: number, model: string): number {
    const pricing = { 'gemini-2.5-flash': 0.075, 'gemini-2.5-pro': 1.25 };
    const rate = pricing[model as keyof typeof pricing] || 1.25;
    return Math.round((tokens / 1_000_000) * rate * 100);
  }

  private calculateCodexCost(_tokens: number, _model: string): number {
    return 0; // Subscription-based
  }

  // Publishing is now handled by SafeNATSPublisher (nats-publisher.ts)
  // Error formatting is now handled by formatError() (error-formatter.ts)

  async close() {
    for (const sub of this.subscriptions) sub.unsubscribe();
    this.subscriptions = [];
    await Promise.allSettled(this.subscriptionTasks);
    this.subscriptionTasks = [];
    if (this.nc) {
      await this.nc.close();
      console.log('[NATS] Disconnected from NATS');
    }
  }
}

/**
 * Starts the NATS handler and connects to the NATS server.
 */
async function startNATSHandler() {
  const handler = new NATSHandler();
  try {
    await handler.connect();
    console.log('[NATS] NATS Handler started successfully.');
    process.on('SIGINT', async () => {
      console.log('[NATS] Shutting down NATS handler...');
      await handler.close();
      process.exit(0);
    });
  } catch (error) {
    console.error('[NATS] Failed to start NATS handler:', error);
    process.exit(1);
  }
}

export { NATSHandler, startNATSHandler };

if (import.meta.main) {
  startNATSHandler();
}
