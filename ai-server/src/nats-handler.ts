#!/usr/bin/env bun

/**
 * @file NATS Handler for AI Server
 * @description This module handles NATS requests from the Elixir backend,
 * routing them to the appropriate AI providers. It subscribes to `ai.llm.request`
 * and publishes responses to `ai.llm.response` or errors to `ai.llm.error`.
 */

import { connect, NatsConnection, Subscription } from 'nats';
import { generateText } from 'ai';
import { createGeminiProvider } from './providers/gemini-code.js';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from 'ai-sdk-provider-codex';
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

// --- Type Definitions ---

/**
 * @typedef {'general' | 'architect' | 'coder' | 'qa'} TaskType
 * @description The type of task to be performed by the AI model.
 */
type TaskType = 'general' | 'architect' | 'coder' | 'qa';
/**
 * @typedef {'code' | 'reasoning' | 'creativity' | 'speed' | 'cost'} CapabilityHint
 * @description A hint to the model selection logic to prioritize a certain capability.
 */
type CapabilityHint = 'code' | 'reasoning' | 'creativity' | 'speed' | 'cost';

/**
 * @interface LLMRequest
 * @description Defines the structure of an incoming LLM request from NATS.
 */
interface LLMRequest {
  model?: string;
  provider?: string;
  messages: Array<{ role: string; content: string }>;
  max_tokens?: number;
  temperature?: number;
  stream?: boolean;
  correlation_id?: string;
  tools?: OpenAITool[];
  complexity?: TaskComplexity;
  task_type?: string;
  capabilities?: CapabilityHint[];
}

/**
 * @interface LLMResponse
 * @description Defines the structure of a successful LLM response published to NATS.
 */
interface LLMResponse {
  text: string;
  model: string;
  tokens_used?: number;
  cost_cents?: number;
  timestamp: string;
  correlation_id?: string;
}

/**
 * @interface LLMError
 * @description Defines the structure of an error response published to NATS.
 */
interface LLMError {
  error: string;
  error_code: string;
  correlation_id?: string;
  timestamp: string;
}

/**
 * @typedef {'claude' | 'gemini' | 'codex' | 'copilot' | 'github' | 'jules' | 'cursor' | 'openrouter'} ProviderKey
 * @description A key representing a supported AI provider.
 */
type ProviderKey = 'claude' | 'gemini' | 'codex' | 'copilot' | 'github' | 'jules' | 'cursor' | 'openrouter';

// --- Constants ---

/**
 * @const {object} MODEL_SELECTION_MATRIX
 * @description A matrix for selecting the best model based on task type and complexity.
 */
const MODEL_SELECTION_MATRIX: Record<TaskType, Record<TaskComplexity, Array<{ provider: ProviderKey; model: string }>>> = {
  general: {
    simple: [{ provider: 'gemini', model: 'gemini-2.5-flash' }, { provider: 'copilot', model: 'gpt-5-mini' }, { provider: 'copilot', model: 'grok-code-fast-1' }, { provider: 'codex', model: 'o3-mini-codex' }, { provider: 'cursor', model: 'auto' }],
    medium: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'claude', model: 'claude-3-5-sonnet-20241022' }, { provider: 'gemini', model: 'gemini-2.5-pro' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'auto' }],
    complex: [{ provider: 'claude', model: 'claude-sonnet-4.5' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'claude', model: 'opus-4.1' }, { provider: 'copilot', model: 'gpt-4o' }, { provider: 'gemini', model: 'gemini-2.5-pro' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'cheetah' }]
  },
  architect: {
    simple: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'claude', model: 'claude-3-5-sonnet-20241022' }, { provider: 'openrouter', model: 'auto' }, { provider: 'gemini', model: 'gemini-2.5-flash' }, { provider: 'cursor', model: 'auto' }],
    medium: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'claude', model: 'claude-3-5-sonnet-20241022' }, { provider: 'openrouter', model: 'auto' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'gemini', model: 'gemini-2.5-pro' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'auto' }],
    complex: [{ provider: 'claude', model: 'claude-sonnet-4.5' }, { provider: 'openrouter', model: 'auto' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'claude', model: 'opus-4.1' }, { provider: 'copilot', model: 'gpt-4o' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'cheetah' }]
  },
  coder: {
    simple: [{ provider: 'copilot', model: 'gpt-5-mini' }, { provider: 'copilot', model: 'grok-code-fast-1' }, { provider: 'openrouter', model: 'auto' }, { provider: 'gemini', model: 'gemini-2.5-flash' }, { provider: 'codex', model: 'o3-mini-codex' }, { provider: 'cursor', model: 'auto' }],
    medium: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'openrouter', model: 'auto' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'claude', model: 'claude-3-5-sonnet-20241022' }, { provider: 'cursor', model: 'auto' }],
    complex: [{ provider: 'codex', model: 'gpt-5-codex' }, { provider: 'claude', model: 'claude-sonnet-4.5' }, { provider: 'copilot', model: 'gpt-4o' }, { provider: 'openrouter', model: 'auto' }, { provider: 'claude', model: 'opus-4.1' }, { provider: 'cursor', model: 'cheetah' }]
  },
  qa: {
    simple: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'gemini', model: 'gemini-2.5-flash' }, { provider: 'claude', model: 'claude-3-5-sonnet-20241022' }, { provider: 'cursor', model: 'auto' }],
    medium: [{ provider: 'copilot', model: 'gpt-4o' }, { provider: 'claude', model: 'claude-3-5-sonnet-20241022' }, { provider: 'gemini', model: 'gemini-2.5-pro' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'auto' }],
    complex: [{ provider: 'claude', model: 'claude-3-5-sonnet-20241022' }, { provider: 'codex', model: 'gpt-5-codex' }, { provider: 'copilot', model: 'gpt-4o' }, { provider: 'copilot', model: 'gpt-4.1' }, { provider: 'cursor', model: 'cheetah' }]
  }
};

/**
 * @class ValidationError
 * @extends Error
 * @description Custom error for request validation failures.
 */
class ValidationError extends Error {
  readonly code = 'VALIDATION_ERROR';
  constructor(message: string) {
    super(`validation error: ${message}`);
    this.name = 'ValidationError';
  }
}

/**
 * @class ProviderNotFoundError
 * @extends Error
 * @description Custom error for when a provider cannot be found.
 */
class ProviderNotFoundError extends Error {
  readonly code = 'PROVIDER_NOT_FOUND';
  constructor(message: string) {
    super(message);
    this.name = 'ProviderNotFoundError';
  }
}

/**
 * @class NATSHandler
 * @description Manages the NATS connection, subscriptions, and message handling.
 */
class NATSHandler {
  private nc: NatsConnection | null = null;
  private subscriptions: Subscription[] = [];
  private subscriptionTasks: Promise<void>[] = [];
  private processingCount: number = 0;
  private readonly MAX_CONCURRENT = 10;

  /**
   * Connects to the NATS server.
   */
  async connect() {
    try {
      this.nc = await connect({
        servers: process.env.NATS_URL || 'nats://localhost:4222'
      });
      console.log('[NATS] Connected to NATS');
      await this.subscribeToLLMRequests();
    } catch (error) {
      console.error('[NATS] Failed to connect:', error);
      throw error;
    }
  }

  /**
   * Subscribes to the LLM request topic.
   */
  async subscribeToLLMRequests() {
    if (!this.nc) throw new Error('NATS not connected');
    const subscription = this.nc.subscribe('ai.llm.request');
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
        console.warn(`[NATS] Max concurrent processing (${this.MAX_CONCURRENT}) reached. NAKing message.`);
        msg.nak();
        continue;
      }
      this.processingCount++;
      this.handleSingleLLMRequest(msg).finally(() => {
        this.processingCount--;
      });
    }
  }

  private async handleSingleLLMRequest(msg: any) {
    let request: LLMRequest | null = null;
    const startTime = Date.now();
    try {
      request = JSON.parse(msg.data.toString()) as LLMRequest;
      this.validateRequest(request);
      logger.info('[NATS] Received LLM request', { model: request.model, correlationId: request.correlation_id });
      const response = await this.processLLMRequest(request);
      await this.publishResponse(response);
      const duration = Date.now() - startTime;
      metrics.recordRequest('nats_llm_request', duration);
      if (response.model) {
        const [provider, model] = response.model.split(':');
        metrics.recordModelUsage(provider || 'unknown', model || response.model, response.tokens_used);
      }
      logger.info('[NATS] LLM request completed', { model: response.model, duration: `${duration}ms`, correlationId: request.correlation_id });
    } catch (error) {
      const duration = Date.now() - startTime;
      metrics.recordRequest('nats_llm_request', duration, true);
      logger.error('[NATS] Error processing LLM request', { error: error instanceof Error ? error.message : 'Unknown error', correlationId: request?.correlation_id });
      const errorResponse: LLMError = {
        error: error instanceof Error ? error.message : 'Unknown error',
        error_code: this.extractErrorCode(error),
        correlation_id: request?.correlation_id,
        timestamp: new Date().toISOString()
      };
      await this.publishError(errorResponse);
    }
  }

  private validateRequest(request: LLMRequest) {
    if (!request || typeof request !== 'object') throw new ValidationError('Request payload must be an object');
    if (request.model !== undefined && typeof request.model !== 'string') throw new ValidationError('Model must be a string');
    if (!Array.isArray(request.messages) || request.messages.length === 0) throw new ValidationError('Request must include at least one message');
    for (let i = 0; i < request.messages.length; i++) {
      const m = request.messages[i];
      if (!m || typeof m !== 'object' || typeof m.role !== 'string' || typeof m.content !== 'string') throw new ValidationError(`Message at index ${i} is invalid`);
    }
  }

  async processLLMRequest(request: LLMRequest): Promise<LLMResponse> {
    const selection = this.resolveModelSelection(request);
    const { model, provider, complexity } = selection;
    const { messages, max_tokens = 4000, temperature = 0.7, stream = false, tools } = request;

    let aiSDKTools;
    if (tools && tools.length > 0) {
      aiSDKTools = convertOpenAIToolsToAISDK(tools, async (toolName, args) => {
        if (!this.nc) throw new Error('NATS not connected - cannot execute tool');
        try {
          const result = await this.nc.request(`tools.execute.${toolName}`, JSON.stringify(args), { timeout: 30000 });
          return JSON.parse(result.data.toString());
        } catch (err) {
          console.error(`[NATS] Tool execution failed for ${toolName}:`, err);
          throw err;
        }
      });
    }

    logger.info('[NATS] Model selection', { requestedModel: request.model, selectedModel: model, provider, complexity, correlationId: request.correlation_id });

    if (stream) {
      return this.handleStreamingRequest(provider, model, messages, { max_tokens, temperature, tools: aiSDKTools });
    }
    return this.handleNonStreamingRequest(provider, model, messages, { max_tokens, temperature, tools: aiSDKTools }, this.normalizeTaskType(request), complexity);
  }

  private resolveModelSelection(request: LLMRequest): { model: string; provider: ProviderKey; complexity: TaskComplexity } {
    const providerHint = request.provider ? this.normalizeProvider(request.provider) : null;
    if (request.model && request.model !== 'auto') {
      const provider = providerHint ?? this.getProviderFromModel(request.model);
      if (!provider) throw new ProviderNotFoundError(`Unable to determine provider for model: ${request.model}`);
      const complexity = request.complexity ?? this.inferComplexity(request, this.taskTypeFromRequest(request));
      return { model: request.model, provider: provider as ProviderKey, complexity };
    }
    const taskType = this.taskTypeFromRequest(request);
    const complexity = request.complexity ?? this.inferComplexity(request, taskType);
    const candidates = this.getModelCandidates(taskType, complexity, providerHint as ProviderKey | null, request.capabilities);
    if (candidates.length === 0) throw new ProviderNotFoundError(`No models available for task_type=${taskType} complexity=${complexity}`);
    const choice = candidates[0];
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
      default: throw new ProviderNotFoundError(`Unknown provider: ${provider}`);
    }
  }

  private async handleStreamingRequest(provider: string, model: string, messages: any[], options: any) {
    // TODO: Implement streaming for each provider.
    throw new Error('Streaming not implemented yet');
  }

  private async callClaude(model: string, messages: any[], options: any) {
    const result = await generateText({ model: claudeCode(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage.totalTokens, cost_cents: this.calculateClaudeCost(result.usage.totalTokens, model) };
  }

  private async callGemini(model: string, messages: any[], options: any) {
    const result = await generateText({ model: createGeminiProvider({ authType: 'oauth-personal' })(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage.totalTokens, cost_cents: this.calculateGeminiCost(result.usage.totalTokens, model) };
  }

  private async callCodex(model: string, messages: any[], options: any) {
    const result = await generateText({ model: codex(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage.totalTokens, cost_cents: this.calculateCodexCost(result.usage.totalTokens, model) };
  }

  private async callCopilot(model: string, messages: any[], options: any) {
    const result = await generateText({ model: copilot(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage.totalTokens, cost_cents: 0 };
  }

  private async callGitHubModels(model: string, messages: any[], options: any) {
    const result = await generateText({ model: githubModels(model), ...options, messages });
    return { text: result.text, tokens_used: result.usage.totalTokens, cost_cents: 0 };
  }

  private async callCursor(model: string, messages: any[], options: any) {
    const result = await generateText({ model: cursor(model, { approvalPolicy: 'read-only' }), ...options, messages });
    return { text: result.text, tokens_used: result.usage.totalTokens, cost_cents: 0 };
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

  private getProviderFromModel(model: string): string | null {
    if (model.startsWith('claude')) return 'claude';
    if (model.startsWith('gemini')) return 'gemini';
    if (model.startsWith('gpt-')) return 'copilot'; // Default to copilot for gpt models
    if (model.startsWith('o3-')) return 'codex';
    return null;
  }

  private calculateClaudeCost(tokens: number, model: string): number {
    const pricing = { 'claude-3-5-sonnet-20241022': 3.0 };
    const rate = pricing[model as keyof typeof pricing] || 3.0;
    return Math.round((tokens / 1_000_000) * rate * 100);
  }

  private calculateGeminiCost(tokens: number, model: string): number {
    const pricing = { 'gemini-1.5-flash': 0.075, 'gemini-2.5-pro': 1.25 };
    const rate = pricing[model as keyof typeof pricing] || 1.25;
    return Math.round((tokens / 1_000_000) * rate * 100);
  }

  private calculateCodexCost(tokens: number, model: string): number {
    return 0; // Subscription-based
  }

  private extractErrorCode(error: unknown): string {
    return (error && typeof error === 'object' && 'code' in error && typeof (error as any).code === 'string') ? (error as any).code : 'LLM_ERROR';
  }

  private async publishResponse(response: LLMResponse) {
    if (!this.nc) throw new Error('NATS not connected');
    this.nc.publish('ai.llm.response', JSON.stringify(response));
    logger.info('[NATS] Published LLM response', { model: response.model, correlationId: response.correlation_id });
  }

  private async publishError(error: LLMError) {
    if (!this.nc) throw new Error('NATS not connected');
    this.nc.publish('ai.llm.error', JSON.stringify(error));
    logger.error('[NATS] Published LLM error', { errorCode: error.error_code, correlationId: error.correlation_id });
  }

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
