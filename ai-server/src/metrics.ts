/**
 * @file Basic Metrics Collection
 * @description This module provides a simple in-memory metrics collector for tracking
 * key performance indicators (KPIs) of the AI server, such as request counts,
 * latencies, errors, and model usage.
 */

import { logger } from './logger.js';

/**
 * @interface MetricData
 * @description Represents the data collected for a single metric.
 */
interface MetricData {
  count: number;
  totalTime?: number;
  errors?: number;
  lastUpdated: number;
}

/**
 * @class MetricsCollector
 * @description A singleton class for collecting and reporting application metrics.
 */
class MetricsCollector {
  private metrics: Map<string, MetricData> = new Map();
  private startTime: number = Date.now();

  /**
   * Records a request and its associated metadata.
   * @param {string} endpoint The API endpoint that was called.
   * @param {number} [duration] The duration of the request in milliseconds.
   * @param {boolean} [error] Whether the request resulted in an error.
   */
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

    // Also log to the metrics stream for real-time monitoring
    logger.metric(`${key}.count`, metric.count);
    if (duration !== undefined) {
      logger.metric(`${key}.duration_ms`, duration);
    }
    if (error) {
      logger.metric(`${key}.errors`, metric.errors || 0);
    }
  }

  /**
   * Records the usage of a specific AI model.
   * @param {string} provider The provider of the model.
   * @param {string} model The name of the model.
   * @param {number} [tokens] The number of tokens used in the request.
   */
  recordModelUsage(provider: string, model: string, tokens?: number): void {
    const key = `model.${provider}.${model}`;
    const metric = this.metrics.get(key) || { count: 0, totalTime: 0, lastUpdated: Date.now() };
    
    metric.count++;
    // TODO: The `totalTime` property is being reused to store token count.
    // This is not ideal and should be refactored to use a more appropriate data structure.
    if (tokens !== undefined) {
      metric.totalTime = (metric.totalTime || 0) + tokens;
    }
    metric.lastUpdated = Date.now();
    
    this.metrics.set(key, metric);
    
    logger.metric(`${key}.count`, metric.count);
    if (tokens !== undefined) {
      logger.metric(`${key}.tokens`, tokens);
    }
  }

  /**
   * Retrieves a summary of all collected metrics.
   * @returns {Record<string, any>} An object containing the metrics summary.
   */
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

  /**
   * Resets all collected metrics.
   */
  reset(): void {
    this.metrics.clear();
    this.startTime = Date.now();
  }
}

/**
 * @const {MetricsCollector} metrics
 * @description A singleton instance of the MetricsCollector.
 */
export const metrics = new MetricsCollector();
