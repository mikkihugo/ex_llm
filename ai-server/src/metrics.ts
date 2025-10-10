/**
 * Basic Metrics Collection
 * 
 * Tracks request counts, latencies, and errors for monitoring.
 */

import { logger } from './logger.js';

interface MetricData {
  count: number;
  totalTime?: number;
  errors?: number;
  lastUpdated: number;
}

class MetricsCollector {
  private metrics: Map<string, MetricData> = new Map();
  private startTime: number = Date.now();

  // Record a request
  recordRequest(endpoint: string, duration?: number, error?: boolean): void {
    const key = `request.${endpoint}`;
    const metric = this.metrics.get(key) || { count: 0, totalTime: 0, errors: 0, lastUpdated: Date.now() };
    
    metric.count++;
    if (duration !== undefined) {
      metric.totalTime = (metric.totalTime || 0) + duration;
    }
    if (error) {
      metric.errors = (metric.errors || 0) + 1;
    }
    metric.lastUpdated = Date.now();
    
    this.metrics.set(key, metric);

    // Log metric
    logger.metric(`${key}.count`, metric.count);
    if (duration !== undefined) {
      logger.metric(`${key}.duration_ms`, duration);
    }
    if (error) {
      logger.metric(`${key}.errors`, metric.errors || 0);
    }
  }

  // Record model usage
  recordModelUsage(provider: string, model: string, tokens?: number): void {
    const key = `model.${provider}.${model}`;
    const metric = this.metrics.get(key) || { count: 0, totalTime: 0, lastUpdated: Date.now() };
    
    metric.count++;
    if (tokens !== undefined) {
      metric.totalTime = (metric.totalTime || 0) + tokens; // Reusing totalTime for token count
    }
    metric.lastUpdated = Date.now();
    
    this.metrics.set(key, metric);
    
    logger.metric(`${key}.count`, metric.count);
    if (tokens !== undefined) {
      logger.metric(`${key}.tokens`, tokens);
    }
  }

  // Get all metrics
  getMetrics(): Record<string, any> {
    const result: Record<string, any> = {
      uptime: Math.floor((Date.now() - this.startTime) / 1000),
      requests: {},
      models: {},
      memory: {
        heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
        heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        rss: Math.round(process.memoryUsage().rss / 1024 / 1024)
      }
    };

    for (const [key, metric] of this.metrics.entries()) {
      if (key.startsWith('request.')) {
        const endpoint = key.replace('request.', '');
        result.requests[endpoint] = {
          count: metric.count,
          avgDuration: metric.totalTime && metric.count > 0 
            ? Math.round((metric.totalTime / metric.count) * 100) / 100 
            : undefined,
          errors: metric.errors || 0,
          errorRate: metric.count > 0 
            ? Math.round(((metric.errors || 0) / metric.count) * 10000) / 100 
            : 0
        };
      } else if (key.startsWith('model.')) {
        const modelName = key.replace('model.', '');
        result.models[modelName] = {
          count: metric.count,
          totalTokens: metric.totalTime || 0
        };
      }
    }

    return result;
  }

  // Reset metrics
  reset(): void {
    this.metrics.clear();
    this.startTime = Date.now();
  }
}

export const metrics = new MetricsCollector();
