#!/usr/bin/env bun

/**
 * NATS Handler for AI Server
 *
 * Handles NATS requests from Elixir and routes them to appropriate AI providers.
 * Subscribes to ai.llm.request and publishes responses to ai.llm.response.
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

type TaskType = 'general' | 'architect' | 'coder' | 'qa';

type CapabilityHint = 'code' | 'reasoning' | 'creativity' | 'speed' | 'cost';

interface LLMRequest {
  model?: string;
  provider?: string;
  messages: Array<{ role: string; content: string }>;
  max_tokens?: number;
  temperature?: number;
  stream?: boolean;
  correlation_id?: string;
  tools?: OpenAITool[];  // Tools from Elixir in OpenAI format
  complexity?: TaskComplexity;
  task_type?: string;
  capabilities?: CapabilityHint[];
}

interface LLMResponse {
  text: string;
  model: string;
  tokens_used?: number;
  cost_cents?: number;
  timestamp: string;
  correlation_id?: string;
}

interface LLMError {
  error: string;
  error_code: string;
  correlation_id?: string;
  timestamp: string;
}

type ProviderKey = 'claude' | 'gemini' | 'codex' | 'copilot' | 'github' | 'jules' | 'cursor' | 'openrouter';

const MODEL_SELECTION_MATRIX: Record<TaskType, Record<TaskComplexity, Array<{ provider: ProviderKey; model: string }>>> = {
  general: {
    simple: [
      { provider: 'gemini', model: 'gemini-2.5-flash' },
      { provider: 'copilot', model: 'gpt-5-mini' },  // Small fast OpenAI via Copilot
      { provider: 'copilot', model: 'grok-code-fast-1' },  // Grok fast model
      { provider: 'codex', model: 'o3-mini-codex' },  // Small OpenAI via Codex
      { provider: 'cursor', model: 'auto' }  // FREE unlimited fallback
    ],
    medium: [
      { provider: 'copilot', model: 'gpt-4o' },  // FREE unlimited GPT-4o
      { provider: 'claude', model: 'claude-3-5-sonnet-20241022' },
      { provider: 'gemini', model: 'gemini-2.5-pro' },
      { provider: 'codex', model: 'gpt-5-codex' },
      { provider: 'copilot', model: 'gpt-4.1' },
      { provider: 'cursor', model: 'auto' }  // FREE unlimited fallback
    ],
    complex: [
      { provider: 'claude', model: 'claude-sonnet-4.5' },
      { provider: 'codex', model: 'gpt-5-codex' },
      { provider: 'claude', model: 'opus-4.1' },  // Fallback: best reasoning + creativity
      { provider: 'copilot', model: 'gpt-4o' },  // FREE unlimited GPT-4o
      { provider: 'gemini', model: 'gemini-2.5-pro' },
      { provider: 'copilot', model: 'gpt-4.1' },
      { provider: 'cursor', model: 'cheetah' }  // FREE unlimited fast fallback
    ]
  },
  architect: {
    simple: [
      { provider: 'copilot', model: 'gpt-4o' },  // FREE unlimited GPT-4o
      { provider: 'claude', model: 'claude-3-5-sonnet-20241022' },
      { provider: 'openrouter', model: 'auto' },  // Dynamic: best for architect/simple
      { provider: 'gemini', model: 'gemini-2.5-flash' },
      { provider: 'cursor', model: 'auto' }  // FREE unlimited fallback
    ],
    medium: [
      { provider: 'copilot', model: 'gpt-4o' },  // FREE unlimited GPT-4o
      { provider: 'claude', model: 'claude-3-5-sonnet-20241022' },
      { provider: 'openrouter', model: 'auto' },  // Dynamic: best for architect/medium (DeepSeek R1)
      { provider: 'codex', model: 'gpt-5-codex' },
      { provider: 'gemini', model: 'gemini-2.5-pro' },
      { provider: 'copilot', model: 'gpt-4.1' },
      { provider: 'cursor', model: 'auto' }  // FREE unlimited fallback
    ],
    complex: [
      { provider: 'claude', model: 'claude-sonnet-4.5' },
      { provider: 'openrouter', model: 'auto' },  // Dynamic: best for architect/complex (DeepSeek R1)
      { provider: 'codex', model: 'gpt-5-codex' },
      { provider: 'claude', model: 'opus-4.1' },  // Fallback: excellent reasoning + creativity
      { provider: 'copilot', model: 'gpt-4o' },  // FREE unlimited GPT-4o
      { provider: 'copilot', model: 'gpt-4.1' },
      { provider: 'cursor', model: 'cheetah' }  // FREE unlimited fast fallback
    ]
  },
  coder: {
    simple: [
      { provider: 'copilot', model: 'gpt-5-mini' },  // Small fast OpenAI for coding
      { provider: 'copilot', model: 'grok-code-fast-1' },  // Grok fast for code
      { provider: 'openrouter', model: 'auto' },  // Dynamic: best for coder/simple (fast models)
      { provider: 'gemini', model: 'gemini-2.5-flash' },
      { provider: 'codex', model: 'o3-mini-codex' },
      { provider: 'cursor', model: 'auto' }  // FREE unlimited fallback
    ],
    medium: [
      { provider: 'copilot', model: 'gpt-4o' },  // FREE unlimited GPT-4o
      { provider: 'codex', model: 'gpt-5-codex' },
      { provider: 'openrouter', model: 'auto' },  // Dynamic: best for coder/medium (Qwen3 Coder)
      { provider: 'copilot', model: 'gpt-4.1' },
      { provider: 'claude', model: 'claude-3-5-sonnet-20241022' },
      { provider: 'cursor', model: 'auto' }  // FREE unlimited fallback
    ],
    complex: [
      { provider: 'codex', model: 'gpt-5-codex' },
      { provider: 'claude', model: 'claude-sonnet-4.5' },
      { provider: 'copilot', model: 'gpt-4o' },  // FREE unlimited GPT-4o
      { provider: 'openrouter', model: 'auto' },  // Dynamic: best for coder/complex (Qwen3 Coder 480B!)
      { provider: 'claude', model: 'opus-4.1' },  // Fallback: strong code + reasoning
      { provider: 'cursor', model: 'cheetah' }  // FREE unlimited fast fallback
    ]
  },
  qa: {
    simple: [
      { provider: 'copilot', model: 'gpt-4o' },  // FREE unlimited GPT-4o
      { provider: 'gemini', model: 'gemini-2.5-flash' },
      { provider: 'claude', model: 'claude-3-5-sonnet-20241022' },
      { provider: 'cursor', model: 'auto' }  // FREE unlimited fallback
    ],
    medium: [
      { provider: 'copilot', model: 'gpt-4o' },  // FREE unlimited GPT-4o
      { provider: 'claude', model: 'claude-3-5-sonnet-20241022' },
      { provider: 'gemini', model: 'gemini-2.5-pro' },
      { provider: 'copilot', model: 'gpt-4.1' },
      { provider: 'cursor', model: 'auto' }  // FREE unlimited fallback
    ],
    complex: [
      { provider: 'claude', model: 'claude-3-5-sonnet-20241022' },
      { provider: 'codex', model: 'gpt-5-codex' },
      { provider: 'copilot', model: 'gpt-4o' },  // FREE unlimited GPT-4o
      { provider: 'copilot', model: 'gpt-4.1' },
      { provider: 'cursor', model: 'cheetah' }  // FREE unlimited fast fallback
    ]
  }
};

// MODEL_CAPABILITIES loaded from ./data/model-capabilities.json
// Run `bun run generate:capabilities` to auto-generate scores

class ValidationError extends Error {
  readonly code = 'VALIDATION_ERROR';

  constructor(message: string) {
    super(`validation error: ${message}`);
    this.name = 'ValidationError';
  }
}

class ProviderNotFoundError extends Error {
  readonly code = 'PROVIDER_NOT_FOUND';

  constructor(message: string) {
    super(message);
    this.name = 'ProviderNotFoundError';
  }
}

class NATSHandler {
  private nc: NatsConnection | null = null;
  private subscriptions: Subscription[] = [];
  private subscriptionTasks: Promise<void>[] = [];
  private processingCount: number = 0;
  private readonly MAX_CONCURRENT = 10;  // Maximum concurrent message processing

  async connect() {
    try {
      this.nc = await connect({
        servers: process.env.NATS_URL || 'nats://localhost:4222'
      });
      
      console.log('🔗 Connected to NATS');
      
      // Subscribe to LLM requests
      await this.subscribeToLLMRequests();
      
    } catch (error) {
      console.error('❌ Failed to connect to NATS:', error);
      throw error;
    }
  }

  async subscribeToLLMRequests() {
    if (!this.nc) {
      throw new Error('NATS not connected');
    }

    const subscription = this.nc.subscribe('ai.llm.request');
    this.subscriptions.push(subscription);

    const processor = this.handleLLMRequestStream(subscription);
    
    // Track task and clean up on error
    const taskWithCleanup = processor.catch(error => {
      console.error('❌ Unhandled error in LLM request stream:', error);
      
      // Remove from tracking
      const index = this.subscriptionTasks.indexOf(taskWithCleanup);
      if (index > -1) {
        this.subscriptionTasks.splice(index, 1);
      }
      
      throw error; // Re-throw to maintain error visibility
    });
    
    this.subscriptionTasks.push(taskWithCleanup);
  }

  private async handleLLMRequestStream(subscription: Subscription) {
    for await (const msg of subscription) {
      // Backpressure: Limit concurrent processing
      if (this.processingCount >= this.MAX_CONCURRENT) {
        console.warn(`⚠️  Max concurrent processing (${this.MAX_CONCURRENT}) reached - NAK message`);
        msg.nak(); // Negative acknowledge - requeue message
        continue;
      }

      // Process message asynchronously with concurrency tracking
      this.processingCount++;
      
      this.handleSingleLLMRequest(msg)
        .finally(() => {
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
      logger.info('📨 Received LLM request via NATS', { model: request.model, correlationId: request.correlation_id });

      const response = await this.processLLMRequest(request);
      await this.publishResponse(response);
      
      const duration = Date.now() - startTime;
      metrics.recordRequest('nats_llm_request', duration);
      if (response.model) {
        const [provider, model] = response.model.split(':');
        metrics.recordModelUsage(provider || 'unknown', model || response.model, response.tokens_used);
      }
      logger.info('✅ NATS LLM request completed', { 
        model: response.model, 
        duration: `${duration}ms`,
        correlationId: request.correlation_id 
      });
    } catch (error) {
      const duration = Date.now() - startTime;
      metrics.recordRequest('nats_llm_request', duration, true);
      logger.error('❌ Error processing LLM request via NATS', { 
        error: error instanceof Error ? error.message : 'Unknown error',
        correlationId: request?.correlation_id 
      });
      console.error('❌ Error processing LLM request:', error);

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
    if (!request || typeof request !== 'object') {
      throw new ValidationError('Request payload must be an object');
    }

    if (request.model !== undefined && typeof request.model !== 'string') {
      throw new ValidationError('Model must be a string when provided');
    }

    if (!Array.isArray(request.messages) || request.messages.length === 0) {
      throw new ValidationError('Request must include at least one message');
    }

    if (request.provider !== undefined && typeof request.provider !== 'string') {
      throw new ValidationError('Provider must be a string when provided');
    }

    if (request.complexity !== undefined && !['simple', 'medium', 'complex'].includes(request.complexity)) {
      throw new ValidationError('Complexity must be simple, medium, or complex when provided');
    }

    if (request.task_type !== undefined && typeof request.task_type !== 'string') {
      throw new ValidationError('Task type must be a string when provided');
    }

    if (request.capabilities !== undefined) {
      if (!Array.isArray(request.capabilities)) {
        throw new ValidationError('Capabilities must be an array when provided');
      }
      if (request.capabilities.some(cap => typeof cap !== 'string')) {
        throw new ValidationError('Capabilities entries must be strings');
      }
    }

    for (let index = 0; index < request.messages.length; index++) {
      const message = request.messages[index];
      if (!message || typeof message !== 'object') {
        throw new ValidationError(`Message at index ${index} must be an object`);
      }
      if (typeof message.role !== 'string' || message.role.length === 0) {
        throw new ValidationError(`Message at index ${index} must include a role`);
      }
      if (typeof message.content !== 'string' || message.content.length === 0) {
        throw new ValidationError(`Message at index ${index} must include content`);
      }
    }
  }

  async processLLMRequest(request: LLMRequest): Promise<LLMResponse> {
    const selection = this.resolveModelSelection(request);
    const model = selection.model;
    const provider = selection.provider;
    const complexity = selection.complexity;
    const messages = request.messages;
    const max_tokens = request.max_tokens ?? 4000;
    const temperature = request.temperature ?? 0.7;
    const stream = request.stream ?? false;
    const tools = request.tools;

    // Convert tools from OpenAI format to AI SDK format
    let aiSDKTools = undefined;
    if (tools && tools.length > 0) {
      console.log(`📦 Converting ${tools.length} tools from OpenAI format to AI SDK format`);
      aiSDKTools = convertOpenAIToolsToAISDK(tools, async (toolName, args) => {
        // Execute tool by calling Elixir via NATS
        console.log(`🔧 Executing tool: ${toolName}`, args);
        
        // Validate NATS connection
        if (!this.nc) {
          throw new Error('NATS not connected - cannot execute tool');
        }
        
        try {
          // Execute with timeout (30 seconds)
          const result = await this.nc.request(
            `tools.execute.${toolName}`, 
            JSON.stringify(args),
            { timeout: 30000 }
          );
          
          // Parse response with error handling
          try {
            return JSON.parse(result.data.toString());
          } catch (parseError) {
            console.error(`❌ Failed to parse tool response for ${toolName}:`, parseError);
            throw new Error(`Invalid JSON response from tool ${toolName}`);
          }
        } catch (natsError) {
          console.error(`❌ NATS request failed for tool ${toolName}:`, natsError);
          throw natsError;
        }
      });
    }

    console.log('🧠 Model selection', {
      requestedModel: request.model,
      selectedModel: model,
      provider,
      taskType: this.normalizeTaskType(request),
      complexity,
      correlationId: request.correlation_id
    });

    // Route to appropriate provider
    let result;

    const taskType = this.normalizeTaskType(request);

    if (stream) {
      // Handle streaming requests
      result = await this.handleStreamingRequest(provider, model, messages, { max_tokens, temperature, tools: aiSDKTools });
    } else {
      // Handle non-streaming requests
      result = await this.handleNonStreamingRequest(provider, model, messages, { max_tokens, temperature, tools: aiSDKTools }, taskType, complexity);
    }

    return {
      text: result.text,
      model: model,
      tokens_used: result.tokens_used,
      cost_cents: result.cost_cents,
      timestamp: new Date().toISOString(),
      correlation_id: request.correlation_id
    };
  }

  private resolveModelSelection(request: LLMRequest): { model: string; provider: ProviderKey; complexity: TaskComplexity } {
    const normalizedProviderHint = request.provider ? this.normalizeProvider(request.provider) : null;

    if (request.model && request.model !== 'auto') {
      const provider = normalizedProviderHint ?? this.getProviderFromModel(request.model);
      if (!provider) {
        throw new ProviderNotFoundError(`Unable to determine provider for model: ${request.model}`);
      }

      const complexity = request.complexity ?? this.inferComplexity(request, this.taskTypeFromRequest(request));
      return { model: request.model, provider: provider as ProviderKey, complexity };
    }

    const taskType = this.taskTypeFromRequest(request);
    const complexity = request.complexity ?? this.inferComplexity(request, taskType);
    const candidates = this.getModelCandidates(
      taskType,
      complexity,
      normalizedProviderHint as ProviderKey | null,
      request.capabilities  // Pass capabilities for scoring
    );

    if (candidates.length === 0) {
      throw new ProviderNotFoundError(`No models available for task_type=${taskType} complexity=${complexity}`);
    }

    const choice = candidates[0];
    return { model: choice.model, provider: choice.provider, complexity };
  }

  private taskTypeFromRequest(request: LLMRequest): TaskType {
    if (request.task_type) {
      const mapped = this.normalizeTaskTypeString(request.task_type);
      if (mapped) {
        return mapped;
      }
    }

    if (request.capabilities && request.capabilities.some(cap => this.normalizeCapability(cap) === 'code')) {
      return 'coder';
    }

    if (request.capabilities && request.capabilities.some(cap => this.normalizeCapability(cap) === 'reasoning')) {
      return 'architect';
    }

    return 'general';
  }

  private normalizeTaskType(request: LLMRequest): TaskType {
    return this.taskTypeFromRequest(request);
  }

  private normalizeTaskTypeString(raw: string): TaskType | null {
    const value = raw.toLowerCase();
    if (['architect', 'architecture', 'planner', 'analysis', 'research'].includes(value)) return 'architect';
    if (['coder', 'developer', 'implementation', 'build', 'codegen'].includes(value)) return 'coder';
    if (['qa', 'tester', 'reviewer', 'validation', 'code_review', 'code-review', 'testing'].includes(value)) return 'qa';
    if (['general', 'auto', 'default'].includes(value)) return 'general';
    return null;
  }

  private normalizeCapability(raw: string): CapabilityHint | null {
    const value = raw.toLowerCase();
    if (['code', 'codegen', 'coding'].includes(value)) return 'code';
    if (['reasoning', 'analysis', 'architect'].includes(value)) return 'reasoning';
    if (['creativity', 'creative', 'design'].includes(value)) return 'creativity';
    if (['speed', 'fast'].includes(value)) return 'speed';
    if (['cost', 'cheap'].includes(value)) return 'cost';
    return null;
  }

  private inferComplexity(request: LLMRequest, taskType: TaskType): TaskComplexity {
    const text = request.messages?.map(message => message.content).join('\n') ?? '';
    const contextLength = text.length;
    const hasCapability = (capability: CapabilityHint) =>
      request.capabilities?.some(cap => this.normalizeCapability(cap) === capability) ?? false;

    const analysis = analyzeTaskComplexity(text, {
      requiresCode: taskType === 'coder' || hasCapability('code'),
      requiresReasoning: taskType === 'architect' || hasCapability('reasoning'),
      requiresCreativity: hasCapability('creativity'),
      contextLength
    });

    return analysis.complexity;
  }

  private calculateCapabilityScore(
    candidate: { provider: ProviderKey; model: string },
    capabilities: CapabilityHint[]
  ): number {
    const profile = MODEL_CAPABILITIES[candidate.model];
    if (!profile) return 50; // Default score

    let score = 0;
    let weight = 0;

    capabilities.forEach((cap, index) => {
      const normalized = this.normalizeCapability(cap);
      if (!normalized) return;

      // First capability gets more weight
      const capWeight = capabilities.length - index;
      score += profile[normalized] * capWeight;
      weight += capWeight;
    });

    return weight > 0 ? score / weight : 50;
  }

  private getModelCandidates(taskType: TaskType, complexity: TaskComplexity, providerHint: ProviderKey | null, capabilities?: CapabilityHint[]) {
    const preferences = MODEL_SELECTION_MATRIX[taskType] ?? MODEL_SELECTION_MATRIX.general;
    let candidates = preferences[complexity] ?? [];

    if (providerHint) {
      const filtered = candidates.filter(candidate => candidate.provider === providerHint);
      if (filtered.length > 0) {
        candidates = filtered;
      } else {
        const fallback = MODEL_SELECTION_MATRIX.general[complexity].filter(candidate => candidate.provider === providerHint);
        if (fallback.length > 0) {
          candidates = fallback;
        }
      }
    }

    if (candidates.length === 0 && preferences !== MODEL_SELECTION_MATRIX.general) {
      candidates = MODEL_SELECTION_MATRIX.general[complexity] ?? [];
    }

    // Apply capability-based scoring and re-ranking
    if (capabilities && capabilities.length > 0) {
      const scored = candidates.map(candidate => ({
        ...candidate,
        score: this.calculateCapabilityScore(candidate, capabilities)
      }));

      // Sort by score DESC
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

  async handleNonStreamingRequest(provider: string, model: string, messages: any[], options: any, taskType?: TaskType, complexity?: TaskComplexity) {
    switch (provider) {
      case 'claude':
        return await this.callClaude(model, messages, options);
      case 'gemini':
        return await this.callGemini(model, messages, options);
      case 'codex':
        return await this.callCodex(model, messages, options);
      case 'copilot':
        return await this.callCopilot(model, messages, options);
      case 'cursor':
        return await this.callCursor(model, messages, options);
      case 'openrouter':
        return await this.callOpenRouter(model, messages, options, taskType || 'general', complexity || 'medium');
      case 'github':
        return await this.callGitHubModels(model, messages, options);
      case 'jules':
        return await this.callJules(model, messages, options);
      default:
        throw new ProviderNotFoundError(`Unknown provider: ${provider}`);
    }
  }

  async handleStreamingRequest(provider: string, model: string, messages: any[], options: any) {
    // TODO: Implement streaming for each provider
    throw new Error('Streaming not implemented yet');
  }

  async callClaude(model: string, messages: any[], options: any) {
    try {
      const result = await generateText({
        model: claudeCode(model),
        messages: messages,
        maxTokens: options.max_tokens,
        temperature: options.temperature
      });
      
      return {
        text: result.text,
        tokens_used: result.usage?.totalTokens || 0,
        cost_cents: this.calculateClaudeCost(result.usage?.totalTokens || 0, model)
      };
    } catch (error) {
      console.error('Claude API error:', error);
      throw error;
    }
  }

  async callGemini(model: string, messages: any[], options: any) {
    try {
      const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });
      const result = await generateText({
        model: geminiCode(model),
        messages: messages,
        maxTokens: options.max_tokens,
        temperature: options.temperature
      });
      
      return {
        text: result.text,
        tokens_used: result.usage?.totalTokens || 0,
        cost_cents: this.calculateGeminiCost(result.usage?.totalTokens || 0, model)
      };
    } catch (error) {
      console.error('Gemini API error:', error);
      throw error;
    }
  }

  async callCodex(model: string, messages: any[], options: any) {
    try {
      const result = await generateText({
        model: codex(model),
        messages: messages,
        maxTokens: options.max_tokens,
        temperature: options.temperature,
        tools: options.tools  // Pass tools to Codex
      });

      return {
        text: result.text,
        tokens_used: result.usage?.totalTokens || 0,
        cost_cents: this.calculateCodexCost(result.usage?.totalTokens || 0, model)
      };
    } catch (error) {
      console.error('Codex API error:', error);
      throw error;
    }
  }

  async callCopilot(model: string, messages: any[], options: any) {
    try {
      const result = await generateText({
        model: copilot(model),
        messages: messages,
        maxTokens: options.max_tokens,
        temperature: options.temperature
      });
      
      return {
        text: result.text,
        tokens_used: result.usage?.totalTokens || 0,
        cost_cents: 0 // Copilot is subscription-based
      };
    } catch (error) {
      console.error('Copilot API error:', error);
      throw error;
    }
  }

  async callGitHubModels(model: string, messages: any[], options: any) {
    try {
      const result = await generateText({
        model: githubModels(model),
        messages: messages,
        maxTokens: options.max_tokens,
        temperature: options.temperature
      });
      
      return {
        text: result.text,
        tokens_used: result.usage?.totalTokens || 0,
        cost_cents: 0 // GitHub Models is free
      };
    } catch (error) {
      console.error('GitHub Models API error:', error);
      throw error;
    }
  }

  async callCursor(model: string, messages: any[], options: any) {
    try {
      // Cursor in read-only mode (safe for fallback)
      const result = await generateText({
        model: cursor(model, {
          approvalPolicy: 'read-only'  // Only read operations allowed
        }),
        messages: messages,
        maxTokens: options.max_tokens,
        temperature: options.temperature
      });

      return {
        text: result.text,
        tokens_used: result.usage?.totalTokens || 0,
        cost_cents: 0 // Cursor is FREE unlimited (auto/cheetah models)
      };
    } catch (error) {
      console.error('Cursor API error:', error);
      throw error;
    }
  }

  async callOpenRouter(model: string, messages: any[], options: any, taskType: TaskType, complexity: TaskComplexity) {
    try {
      // If model is 'auto', dynamically select best model for task
      let selectedModel = model;
      if (model === 'auto') {
        const dynamicModel = await selectOpenRouterModel(taskType, complexity);
        if (!dynamicModel) {
          throw new Error(`No OpenRouter model available for ${taskType}/${complexity}`);
        }
        selectedModel = dynamicModel;
      }

      const result = await generateText({
        model: openrouter(selectedModel),
        messages: messages,
        maxTokens: options.max_tokens,
        temperature: options.temperature
      });

      return {
        text: result.text,
        tokens_used: result.usage?.totalTokens || 0,
        cost_cents: 0 // All OpenRouter FREE models
      };
    } catch (error) {
      console.error('OpenRouter API error:', error);
      throw error;
    }
  }

  async callJules(model: string, messages: any[], options: any) {
    try {
      const result = await generateText({
        model: julesWithMetadata(model),
        messages: messages,
        maxTokens: options.max_tokens,
        temperature: options.temperature
      });

      return {
        text: result.text,
        tokens_used: result.usage?.totalTokens || 0,
        cost_cents: 0 // Jules is free
      };
    } catch (error) {
      console.error('Jules API error:', error);
      throw error;
    }
  }

  getProviderFromModel(model: string): string | null {
    if (model.startsWith('claude')) return 'claude';
    if (model.startsWith('gemini')) return 'gemini';
    if (model.startsWith('gpt-4')) return 'copilot';
    if (model.startsWith('gpt-5')) return 'codex';
    if (model.startsWith('o3')) return 'codex';
    if (model.startsWith('grok')) return 'copilot';
    if (model.startsWith('cursor')) return 'cursor';
    if (model.startsWith('github')) return 'github';
    if (model.startsWith('jules')) return 'jules';
    return null;
  }

  calculateClaudeCost(tokens: number, model: string): number {
    // Claude pricing (per 1M tokens)
    const pricing = {
      'claude-3-5-haiku-20241022': 1.0,
      'claude-3-5-sonnet-20241022': 3.0,
      'claude-sonnet-4.5': 3.0
    };
    
    const rate = pricing[model as keyof typeof pricing] || 3.0;
    return Math.round((tokens / 1000000) * rate * 100);
  }

  calculateGeminiCost(tokens: number, model: string): number {
    // Gemini pricing (per 1M tokens)
    const pricing = {
      'gemini-1.5-flash': 0.075,
      'gemini-2.5-pro': 1.25
    };
    
    const rate = pricing[model as keyof typeof pricing] || 1.25;
    return Math.round((tokens / 1000000) * rate * 100);
  }

  calculateCodexCost(tokens: number, model: string): number {
    // Codex pricing (per 1M tokens) - subscription-based
    return 0;
  }

  private extractErrorCode(error: unknown): string {
    if (error && typeof error === 'object' && 'code' in error) {
      const code = (error as { code?: unknown }).code;
      if (typeof code === 'string' && code.length > 0) {
        return code;
      }
    }

    return 'LLM_ERROR';
  }

  async publishResponse(response: LLMResponse) {
    if (!this.nc) {
      throw new Error('NATS not connected');
    }
    
    await this.nc.publish('ai.llm.response', JSON.stringify(response));
    console.log('📤 Published LLM response:', response.model);
  }

  async publishError(error: LLMError) {
    if (!this.nc) {
      throw new Error('NATS not connected');
    }
    
    await this.nc.publish('ai.llm.error', JSON.stringify(error));
    console.log('📤 Published LLM error:', error.error_code);
  }

  async close() {
    for (const subscription of this.subscriptions) {
      try {
        subscription.unsubscribe();
      } catch (error) {
        console.error('⚠️ Failed to unsubscribe from NATS subject:', error);
      }
    }
    this.subscriptions = [];

    if (this.subscriptionTasks.length > 0) {
      await Promise.allSettled(this.subscriptionTasks);
    }
    this.subscriptionTasks = [];

    if (this.nc) {
      await this.nc.close();
      console.log('🔌 Disconnected from NATS');
    }
  }
}

// Start the NATS handler
async function startNATSHandler() {
  const handler = new NATSHandler();
  
  try {
    await handler.connect();
    console.log('🚀 NATS Handler started');
    
    // Handle graceful shutdown
    process.on('SIGINT', async () => {
      console.log('🛑 Shutting down NATS handler...');
      await handler.close();
      process.exit(0);
    });
    
  } catch (error) {
    console.error('❌ Failed to start NATS handler:', error);
    process.exit(1);
  }
}

// Export for use in other modules
export { NATSHandler, startNATSHandler };

// Start if this file is run directly
if (import.meta.main) {
  startNATSHandler();
}
