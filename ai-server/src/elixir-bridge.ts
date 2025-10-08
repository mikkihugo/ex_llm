/**
 * Bridge between AI Server and Elixir ExecutionCoordinator
 *
 * This connects the AI server to the Elixir orchestration layer
 * so requests flow through the proper pipeline:
 *
 * AI Server → ExecutionCoordinator → TemplateOptimizer → Agents → LLM
 */

import { analyzeTaskComplexity, selectOptimalModel, selectCodexModelForCoding } from './task-complexity';
import { nats } from './nats';

export interface ExecutionRequest {
  task: string;
  language?: string;
  complexity?: 'simple' | 'medium' | 'complex';
  context?: Record<string, any>;
}

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

export class ElixirBridge {
  private connected: boolean = false;

  constructor(private natsUrl: string = process.env.NATS_URL || 'nats://localhost:4222') {}

  async connect(): Promise<void> {
    try {
      await nats.connect(this.natsUrl);
      this.connected = true;
      console.log('✅ Connected to NATS for Elixir bridge');
    } catch (error) {
      console.log('⚠️  NATS not available, using direct HTTP fallback');
      this.connected = false;
    }
  }

  /**
   * Execute task through unified NATS server
   */
  async executeTask(request: ExecutionRequest): Promise<ExecutionResponse> {
    // Analyze complexity if not provided
    if (!request.complexity) {
      const analysis = analyzeTaskComplexity(request.task);
      request.complexity = analysis.complexity;
    }

    if (this.connected && this.nc) {
      // Use unified NATS server
      return await this.executeViaUnifiedNats(request);
    } else {
      // Fallback to HTTP API
      return await this.executeViaHttp(request);
    }
  }

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
      // Use unified NATS server
      const response = await (nats as any).nc?.request(
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

  private async executeViaNats(request: ExecutionRequest): Promise<ExecutionResponse> {
    const payload = {
      task: request.task,
      language: request.language || 'auto',
      complexity: request.complexity,
      context: request.context || {}
    };

    try {
      // Use the custom request method from NatsService
      const response = await (nats as any).nc?.request(
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
   * Get template recommendation from TemplateOptimizer
   */
  async getTemplateRecommendation(taskType: string, language: string): Promise<string> {
    if (this.connected) {
      const payload = { task_type: taskType, language };

      try {
        const response = await (nats as any).nc?.request(
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

  private getDefaultTemplate(taskType: string, language: string): string {
    const templates: Record<string, string> = {
      'nats_consumer:elixir': 'elixir-nats-consumer',
      'nats_consumer:rust': 'rust-nats-consumer',
      'api_endpoint:rust': 'rust-api-endpoint',
      'microservice:typescript': 'typescript-microservice',
    };

    return templates[`${taskType}:${language}`] || 'generic-template';
  }

  async disconnect(): Promise<void> {
    await nats.close();
    this.connected = false;
  }
}