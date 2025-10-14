#!/usr/bin/env bun

/**
 * @file HTDAG LLM Worker for AI Server
 * @description Handles HTDAG-specific LLM requests via NATS for self-evolution.
 * 
 * Subscribes to:
 * - llm.req.* (model-specific requests)
 * 
 * Publishes to:
 * - llm.resp.<run_id>.<node_id> (direct replies)
 * - llm.tokens.<run_id>.<node_id> (token streaming)
 * - llm.health (worker heartbeat)
 * 
 * This integrates with the existing AI server infrastructure while providing
 * the NATS-first architecture needed for HTDAG self-evolution.
 */

import { connect, NatsConnection, Msg, StringCodec } from 'nats';
import { generateText, streamText } from 'ai';
import { createGeminiProvider } from './providers/gemini-code.js';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from './providers/codex';
import { logger } from './logger.js';

/**
 * HTDAG LLM Request format from Elixir
 */
interface HTDAGLLMRequest {
  run_id: string;
  node_id: string;
  corr_id: string;
  model_id: string;
  input: {
    type: 'chat';
    messages: Array<{ role: string; content: string }>;
  };
  params: {
    temperature?: number;
    max_tokens?: number;
    stream?: boolean;
  };
  span_ctx?: Record<string, any>;
}

/**
 * HTDAG LLM Response format
 */
interface HTDAGLLMResponse {
  corr_id: string;
  output: string;
  usage: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
  finish_reason: string;
  error?: string;
}

/**
 * Token chunk for streaming
 */
interface TokenChunk {
  corr_id: string;
  chunk: string;
  seq: number;
  done: boolean;
}

class HTDAGLLMWorker {
  private nc: NatsConnection | null = null;
  private codec = StringCodec();
  private subscriptions: any[] = [];
  
  /**
   * Connect to NATS and start worker
   */
  async connect(natsUrl: string = 'nats://localhost:4222') {
    try {
      this.nc = await connect({ servers: natsUrl });
      logger.info('HTDAG LLM Worker connected to NATS', { url: natsUrl });
      
      // Subscribe to model-specific subjects
      await this.subscribeToModels();
      
      // Start heartbeat
      this.startHeartbeat();
      
      return this.nc;
    } catch (error) {
      logger.error('Failed to connect to NATS', { error });
      throw error;
    }
  }
  
  /**
   * Subscribe to llm.req.* subjects for all supported models
   */
  private async subscribeToModels() {
    if (!this.nc) throw new Error('Not connected to NATS');
    
    const models = [
      'claude-sonnet-4.5',
      'claude-3-5-sonnet-20241022',
      'gemini-2.5-pro',
      'gemini-1.5-flash',
      'gpt-5-codex',
      'o3-mini-codex',
      'auto', // Auto-selection based on complexity
    ];
    
    for (const model of models) {
      const subject = `llm.req.${model}`;
      const sub = this.nc.subscribe(subject);
      
      logger.info('Subscribed to HTDAG LLM subject', { subject });
      
      this.subscriptions.push(sub);
      
      // Process messages
      (async () => {
        for await (const msg of sub) {
          await this.handleRequest(msg);
        }
      })().catch(err => {
        logger.error('Subscription message processing loop failed', { subject, error: err });
      });
    }
  }
  
  /**
   * Handle incoming HTDAG LLM request
   */
  private async handleRequest(msg: Msg) {
    const startTime = Date.now();
    
    try {
      const requestData = this.codec.decode(msg.data);
      const request: HTDAGLLMRequest = JSON.parse(requestData);
      
      logger.info('Processing HTDAG LLM request', {
        run_id: request.run_id,
        node_id: request.node_id,
        model_id: request.model_id,
        corr_id: request.corr_id,
        stream: request.params.stream,
      });
      
      // Select model provider
      const { provider, modelName } = this.selectModel(request.model_id);
      
      // Handle streaming or non-streaming
      if (request.params.stream) {
        await this.handleStreamingRequest(request, provider, modelName, msg);
      } else {
        await this.handleNonStreamingRequest(request, provider, modelName, msg);
      }
      
      const duration = Date.now() - startTime;
      logger.info('HTDAG LLM request completed', {
        run_id: request.run_id,
        corr_id: request.corr_id,
        duration_ms: duration,
      });
      
    } catch (error) {
      logger.error('Error handling HTDAG LLM request', { error });
      
      // Send error response
      if (msg.reply) {
        const errorResponse: HTDAGLLMResponse = {
          corr_id: 'unknown',
          output: '',
          usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
          finish_reason: 'error',
          error: String(error),
        };
        
        msg.respond(this.codec.encode(JSON.stringify(errorResponse)));
      }
    }
  }
  
  /**
   * Handle non-streaming request
   */
  private async handleNonStreamingRequest(
    request: HTDAGLLMRequest,
    provider: any,
    modelName: string,
    msg: Msg
  ) {
    const result = await generateText({
      model: provider(modelName),
      messages: request.input.messages as any,
      temperature: request.params.temperature || 0.7,
    });
    
    const response: HTDAGLLMResponse = {
      corr_id: request.corr_id,
      output: result.text,
      usage: {
        prompt_tokens: result.usage.totalTokens ? Math.floor(result.usage.totalTokens * 0.7) : 0, // Estimate based on total
        completion_tokens: result.usage.totalTokens ? Math.floor(result.usage.totalTokens * 0.3) : 0,
        total_tokens: result.usage.totalTokens || 0,
      },
      finish_reason: result.finishReason || 'stop',
    };
    
    // Reply to msg.reply or to llm.resp.<run_id>.<node_id>
    const replySubject = msg.reply || `llm.resp.${request.run_id}.${request.node_id}`;
    
    if (msg.reply) {
      msg.respond(this.codec.encode(JSON.stringify(response)));
    } else if (this.nc) {
      this.nc.publish(replySubject, this.codec.encode(JSON.stringify(response)));
    }
  }
  
  /**
   * Handle streaming request
   */
  private async handleStreamingRequest(
    request: HTDAGLLMRequest,
    provider: any,
    modelName: string,
    msg: Msg
  ) {
    const result = streamText({
      model: provider(modelName),
      messages: request.input.messages as any,
      temperature: request.params.temperature || 0.7,
    });
    
    // Stream tokens to llm.tokens.<run_id>.<node_id>
    const tokenSubject = `llm.tokens.${request.run_id}.${request.node_id}`;
    let seq = 0;
    let fullText = '';
    
    for await (const chunk of result.textStream) {
      const tokenChunk: TokenChunk = {
        corr_id: request.corr_id,
        chunk: chunk,
        seq: seq++,
        done: false,
      };
      
      fullText += chunk;
      
      if (this.nc) {
        this.nc.publish(tokenSubject, this.codec.encode(JSON.stringify(tokenChunk)));
      }
    }
    
    // Send final done token
    if (this.nc) {
      const doneChunk: TokenChunk = {
        corr_id: request.corr_id,
        chunk: '',
        seq: seq,
        done: true,
      };
      this.nc.publish(tokenSubject, this.codec.encode(JSON.stringify(doneChunk)));
    }
    
    // Send final response
    const usage = await result.usage;
    const finishReason = await result.finishReason;
    
    const response: HTDAGLLMResponse = {
      corr_id: request.corr_id,
      output: fullText,
      usage: {
        prompt_tokens: usage.totalTokens ? Math.floor(usage.totalTokens * 0.7) : 0,
        completion_tokens: usage.totalTokens ? Math.floor(usage.totalTokens * 0.3) : 0,
        total_tokens: usage.totalTokens || 0,
      },
      finish_reason: finishReason || 'stop',
    };
    
    const replySubject = msg.reply || `llm.resp.${request.run_id}.${request.node_id}`;
    
    if (msg.reply) {
      msg.respond(this.codec.encode(JSON.stringify(response)));
    } else if (this.nc) {
      this.nc.publish(replySubject, this.codec.encode(JSON.stringify(response)));
    }
  }
  
  /**
   * Select model provider based on model_id
   */
  private selectModel(modelId: string): { provider: any; modelName: string } {
    // Map model_id to provider and model name
    if (modelId.startsWith('claude')) {
      return { provider: claudeCode, modelName: modelId };
    } else if (modelId.startsWith('gemini')) {
      const gemini = createGeminiProvider({ authType: 'oauth-personal' });
      return { provider: gemini, modelName: modelId };
    } else if (modelId.includes('codex')) {
      return { provider: codex, modelName: modelId };
    } else if (modelId === 'auto') {
      // Default to fast model
      const gemini = createGeminiProvider({ authType: 'oauth-personal' });
      return { provider: gemini, modelName: 'gemini-1.5-flash' };
    } else {
      // Fallback to Gemini
      const gemini = createGeminiProvider({ authType: 'oauth-personal' });
      return { provider: gemini, modelName: 'gemini-1.5-flash' };
    }
  }
  
  /**
   * Start heartbeat to llm.health
   */
  private startHeartbeat() {
    if (!this.nc) return;
    
    setInterval(() => {
      if (this.nc) {
        const heartbeat = {
          worker_id: 'htdag-llm-worker-1',
          timestamp: new Date().toISOString(),
          status: 'healthy',
          models: [
            'claude-sonnet-4.5',
            'gemini-2.5-pro',
            'gemini-1.5-flash',
            'auto',
          ],
        };
        
        this.nc.publish('llm.health', this.codec.encode(JSON.stringify(heartbeat)));
      }
    }, 30000); // Every 30 seconds
  }
  
  /**
   * Disconnect from NATS
   */
  async disconnect() {
    if (this.nc) {
      await this.nc.drain();
      logger.info('HTDAG LLM Worker disconnected from NATS');
    }
  }
}

// Export for integration with main server
export { HTDAGLLMWorker };

// Allow running standalone
if (import.meta.main) {
  const worker = new HTDAGLLMWorker();
  
  await worker.connect(process.env.NATS_URL || 'nats://localhost:4222');
  
  logger.info('HTDAG LLM Worker started successfully');
  
  // Handle shutdown
  process.on('SIGINT', async () => {
    logger.info('Shutting down HTDAG LLM Worker...');
    await worker.disconnect();
    process.exit(0);
  });
}
