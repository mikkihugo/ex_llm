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
import { convertOpenAIToolsToAISDK, type OpenAITool } from './tool-converter.js';

interface LLMRequest {
  model: string;
  provider?: string;
  messages: Array<{ role: string; content: string }>;
  max_tokens?: number;
  temperature?: number;
  stream?: boolean;
  correlation_id?: string;
  tools?: OpenAITool[];  // Tools from Elixir in OpenAI format
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
    this.subscriptionTasks.push(processor);

    processor.catch(error => {
      console.error('❌ Unhandled error in LLM request stream:', error);
    });
  }

  private async handleLLMRequestStream(subscription: Subscription) {
    for await (const msg of subscription) {
      let request: LLMRequest | null = null;
      try {
        request = JSON.parse(msg.data.toString()) as LLMRequest;
        this.validateRequest(request);
        console.log('📨 Received LLM request:', request.model);

        const response = await this.processLLMRequest(request);
        await this.publishResponse(response);
      } catch (error) {
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
  }

  private validateRequest(request: LLMRequest) {
    if (!request || typeof request !== 'object') {
      throw new ValidationError('Request payload must be an object');
    }

    if (!request.model || typeof request.model !== 'string') {
      throw new ValidationError('Request must include a model string');
    }

    if (!Array.isArray(request.messages) || request.messages.length === 0) {
      throw new ValidationError('Request must include at least one message');
    }

    if (request.provider !== undefined && typeof request.provider !== 'string') {
      throw new ValidationError('Provider must be a string when provided');
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
    const { model, messages, max_tokens = 4000, temperature = 0.7, stream = false, tools } = request;

    // Convert tools from OpenAI format to AI SDK format
    let aiSDKTools = undefined;
    if (tools && tools.length > 0) {
      console.log(`📦 Converting ${tools.length} tools from OpenAI format to AI SDK format`);
      aiSDKTools = convertOpenAIToolsToAISDK(tools, async (toolName, args) => {
        // Execute tool by calling Elixir via NATS
        console.log(`🔧 Executing tool: ${toolName}`, args);
        const result = await this.nc!.request(`tools.execute.${toolName}`, JSON.stringify(args));
        return JSON.parse(result.data.toString());
      });
    }

    // Determine provider from request
    const provider = this.determineProvider(request);

    // Route to appropriate provider
    let result;

    if (stream) {
      // Handle streaming requests
      result = await this.handleStreamingRequest(provider, model, messages, { max_tokens, temperature, tools: aiSDKTools });
    } else {
      // Handle non-streaming requests
      result = await this.handleNonStreamingRequest(provider, model, messages, { max_tokens, temperature, tools: aiSDKTools });
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

  private determineProvider(request: LLMRequest): string {
    if (request.provider) {
      const normalized = this.normalizeProvider(request.provider);
      if (normalized) {
        return normalized;
      }
      throw new ProviderNotFoundError(`Unknown provider: ${request.provider}`);
    }

    const inferred = this.getProviderFromModel(request.model);
    if (inferred) {
      return inferred;
    }

    throw new ProviderNotFoundError(`Unable to determine provider for model: ${request.model}`);
  }

  private normalizeProvider(provider: string): string | null {
    const value = provider.toLowerCase();
    if (value.includes('claude')) return 'claude';
    if (value.includes('gemini')) return 'gemini';
    if (value.includes('codex')) return 'codex';
    if (value.includes('copilot') || value.includes('cursor') || value.includes('grok')) return 'copilot';
    if (value.includes('github')) return 'github';
    if (value.includes('jules')) return 'jules';
    return null;
  }

  async handleNonStreamingRequest(provider: string, model: string, messages: any[], options: any) {
    switch (provider) {
      case 'claude':
        return await this.callClaude(model, messages, options);
      case 'gemini':
        return await this.callGemini(model, messages, options);
      case 'codex':
        return await this.callCodex(model, messages, options);
      case 'copilot':
        return await this.callCopilot(model, messages, options);
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
    if (model.startsWith('gpt-5') || model.startsWith('o3')) return 'codex';
    if (model.startsWith('gpt-4')) return 'copilot';
    if (model.startsWith('grok')) return 'copilot';
    if (model.startsWith('cursor')) return 'copilot';
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
export { NATSHandler };

// Start if this file is run directly
if (import.meta.main) {
  startNATSHandler();
}
