/**
 * @file Bridge between AI Server and Elixir ExecutionCoordinator.
 * @description This module provides a communication bridge between the Node.js AI server
 * and the Elixir-based backend. It uses NATS messaging for robust, asynchronous
 * communication, with an HTTP fallback for environments where NATS is not available.
 * The primary purpose is to offload complex task execution to the Elixir backend,
 * which coordinates a pipeline of agents and optimizers.
 *
 * The typical request flow is:
 * AI Server → ElixirBridge → NATS → ExecutionCoordinator → TemplateOptimizer → Agents → LLM
 */

import { analyzeTaskComplexity, selectOptimalModel, selectCodexModelForCoding } from './task-complexity';
import { nats } from './nats';

/**
 * @interface ExecutionRequest
 * @description Defines the structure for a task execution request sent to the Elixir backend.
 * @property {string} task A description of the task to be executed.
 * @property {string} [language] The programming language for the task.
 * @property {'simple' | 'medium' | 'complex'} [complexity] The estimated complexity of the task.
 * @property {Record<string, any>} [context] Additional context for the task.
 */
export interface ExecutionRequest {
  task: string;
  language?: string;
  complexity?: 'simple' | 'medium' | 'complex';
  context?: Record<string, any>;
}

/**
 * @interface ExecutionResponse
 * @description Defines the structure of the response received from the Elixir backend.
 * @property {string} result The output or result of the executed task.
 * @property {string} template_used The ID of the template used for the task.
 * @property {string} model_used The ID of the AI model used.
 * @property {object} metrics Performance and cost metrics for the task.
 * @property {number} metrics.time_ms The time taken in milliseconds.
 * @property {number} metrics.tokens_used The number of tokens used.
 * @property {number} metrics.cost_usd The estimated cost in USD.
 * @property {boolean} metrics.cache_hit Whether the response was served from cache.
 */
export interface ExecutionResponse {
  result: string;
  template_used: string;
  model_used: string;
  metrics: {
    time_ms: number;
    tokens_used: number;
    cost_usd: number;
    cache_hit: boolean;
  };
}

/**
 * @class ElixirBridge
 * @description Manages the connection and communication with the Elixir backend.
 */
export class ElixirBridge {
  private connected: boolean = false;
  private nc: any; // NATS connection client

  /**
   * @constructor
   * @param {string} [natsUrl] The URL for the NATS server. Defaults to `nats://localhost:4222`.
   */
  constructor(private natsUrl: string = process.env.NATS_URL || 'nats://localhost:4222') {}

  /**
   * Connects to the NATS server.
   * @returns {Promise<void>} A promise that resolves when the connection is established.
   */
  async connect(): Promise<void> {
    try {
      this.nc = await nats.connect(this.natsUrl);
      this.connected = true;
      console.log('✅ Connected to NATS for Elixir bridge');
    } catch (error) {
      console.log('⚠️  NATS not available, using direct HTTP fallback');
      this.connected = false;
    }
  }

  /**
   * Checks if the bridge is connected to NATS.
   * @returns {boolean} True if connected, false otherwise.
   */
  isConnected(): boolean {
    return this.connected;
  }

  /**
   * Executes a task by sending it to the Elixir backend.
   * @param {ExecutionRequest} request The task execution request.
   * @returns {Promise<ExecutionResponse>} A promise that resolves with the execution response.
   */
  async executeTask(request: ExecutionRequest): Promise<ExecutionResponse> {
    // Analyze complexity if not provided
    if (!request.complexity) {
      const analysis = analyzeTaskComplexity(request.task);
      request.complexity = analysis.complexity;
    }

    if (this.connected && this.nc) {
      return await this.executeViaUnifiedNats(request);
    } else {
      // Fallback to HTTP API
      return await this.executeViaHttp(request);
    }
  }

  /**
   * Sends a task execution request via the unified NATS server.
   * @private
   * @param {ExecutionRequest} request The execution request.
   * @returns {Promise<ExecutionResponse>} A promise that resolves with the execution response.
   */
  private async executeViaUnifiedNats(request: ExecutionRequest): Promise<ExecutionResponse> {
    const payload = {
      type: 'generate_code',
      data: {
        task: request.task,
        language: request.language || 'auto',
        context: request.context || {}
      },
      complexity: request.complexity,
      correlation_id: `ai-server-${Date.now()}`
    };

    try {
      const response = await this.nc.request(
        'nats.request',
        new TextEncoder().encode(JSON.stringify(payload)),
        { timeout: 30000 }
      );

      if (!response) {
        throw new Error('No response from unified NATS server');
      }

      const result = JSON.parse(new TextDecoder().decode(response.data));
      
      if (result.success) {
        return {
          result: result.data.text || result.data.result || 'No result',
          template_used: result.data.template_used || 'unified',
          model_used: result.data.model_used || 'unified',
          metrics: result.metrics || {
            time_ms: 0,
            tokens_used: 0,
            cost_usd: 0,
            cache_hit: false
          }
        };
      } else {
        throw new Error(result.error || 'Unified NATS server error');
      }
    } catch (error) {
      console.error('Unified NATS execution failed:', error);
      throw error;
    }
  }

  /**
   * @deprecated This method uses an older NATS topic and will be removed. Use executeViaUnifiedNats instead.
   * @private
   * @param {ExecutionRequest} request The execution request.
   * @returns {Promise<ExecutionResponse>} A promise that resolves with the execution response.
   */
  private async executeViaNats(request: ExecutionRequest): Promise<ExecutionResponse> {
    // TODO: Remove this deprecated method once all services are migrated to the unified NATS topic.
    const payload = {
      task: request.task,
      language: request.language || 'auto',
      complexity: request.complexity,
      context: request.context || {}
    };

    try {
      const response = await this.nc.request(
        'execution.request',
        new TextEncoder().encode(JSON.stringify(payload)),
        { timeout: 30000 }
      );

      if (!response) {
        throw new Error('No response from NATS');
      }

      const result = JSON.parse(new TextDecoder().decode(response.data));
      return result;
    } catch (error) {
      console.error('NATS execution failed:', error);
      throw error;
    }
  }

  /**
   * Sends a task execution request via HTTP as a fallback.
   * @private
   * @param {ExecutionRequest} request The execution request.
   * @returns {Promise<ExecutionResponse>} A promise that resolves with the execution response.
   */
  private async executeViaHttp(request: ExecutionRequest): Promise<ExecutionResponse> {
    // HTTP fallback to Elixir Phoenix endpoint
    const url = process.env.ELIXIR_API_URL || 'http://localhost:4000/api/execute';

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error(`HTTP execution failed: ${response.statusText}`);
    }

    return await response.json();
  }

  /**
   * Gets a template recommendation from the TemplateOptimizer via NATS.
   * @param {string} taskType The type of the task.
   * @param {string} language The programming language.
   * @returns {Promise<string>} A promise that resolves with the recommended template ID.
   */
  async getTemplateRecommendation(taskType: string, language: string): Promise<string> {
    if (this.connected) {
      const payload = { task_type: taskType, language };

      try {
        const response = await this.nc.request(
          'template.recommend',
          new TextEncoder().encode(JSON.stringify(payload)),
          { timeout: 5000 }
        );

        if (response) {
          const result = JSON.parse(new TextDecoder().decode(response.data));
          return result.template_id;
        }
      } catch (error) {
        console.warn('Template recommendation failed, using default');
      }
    }

    // Fallback to default templates
    return this.getDefaultTemplate(taskType, language);
  }

  /**
   * Gets a default template as a fallback.
   * @private
   * @param {string} taskType The type of the task.
   * @param {string} language The programming language.
   * @returns {string} The default template ID.
   */
  private getDefaultTemplate(taskType: string, language: string): string {
    const templates: Record<string, string> = {
      'nats_consumer:elixir': 'elixir-nats-consumer',
      'nats_consumer:rust': 'rust-nats-consumer',
      'api_endpoint:rust': 'rust-api-endpoint',
      'microservice:typescript': 'typescript-microservice',
    };

    return templates[`${taskType}:${language}`] || 'generic-template';
  }

  /**
   * Disconnects from the NATS server.
   * @returns {Promise<void>}
   */
  async disconnect(): Promise<void> {
    if (this.nc) {
      await this.nc.close();
    }
    this.connected = false;
  }
}