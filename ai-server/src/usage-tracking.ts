/**
 * @file Usage Tracking System
 * @description This module provides a system for tracking AI provider usage, costs,
 * performance, and other patterns. It includes interfaces for usage events and stats,
 * and implementations for both a PostgreSQL-backed tracker and an in-memory tracker
 * for testing and development.
 */

import type { ModelInfo } from './model-registry';

/**
 * @interface UsageEvent
 * @description Defines the structure for a single usage event to be recorded.
 */
export interface UsageEvent {
  requestId: string;
  sessionId?: string;
  userId?: string;
  provider: string;
  modelId: string;
  modelVersion?: string;
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
  durationMs: number;
  timeToFirstToken?: number;
  tokensPerSecond?: number;
  costTier: 'free' | 'limited' | 'pay-per-use';
  estimatedCost?: number;
  complexity: 'simple' | 'medium' | 'complex';
  hadTools: boolean;
  hadVision: boolean;
  hadReasoning: boolean;
  success: boolean;
  errorType?: string;
  errorMessage?: string;
  startedAt: Date;
  completedAt: Date;
}

/**
 * @interface UsageStats
 * @description Defines the structure for aggregated usage statistics over a time period.
 */
export interface UsageStats {
  provider: string;
  modelId: string;
  totalRequests: number;
  successfulRequests: number;
  failedRequests: number;
  successRate: number;
  totalTokens: number;
  avgTokensPerRequest: number;
  avgDurationMs: number;
  p50DurationMs: number;
  p95DurationMs: number;
  p99DurationMs: number;
  totalCost: number;
  avgCostPerRequest: number;
  periodStart: Date;
  periodEnd: Date;
}

/**
 * @interface UsageTracker
 * @description Defines the interface for a usage tracking system.
 */
export interface UsageTracker {
  recordUsage(event: UsageEvent): Promise<void>;
  getStats(provider: string, modelId: string, startDate: Date, endDate: Date): Promise<UsageStats>;
  getTopModels(limit: number, startDate: Date, endDate: Date): Promise<UsageStats[]>;
  getCostBreakdown(startDate: Date, endDate: Date): Promise<{
    byProvider: Record<string, number>;
    byModel: Record<string, number>;
    byTier: Record<string, number>;
    total: number;
  }>;
  getPerformanceTrends(provider: string, modelId: string, days: number): Promise<{
    date: string;
    avgDurationMs: number;
    avgTokensPerSecond: number;
    requestCount: number;
  }[]>;
}

/**
 * @class PostgresUsageTracker
 * @implements {UsageTracker}
 * @description An implementation of the UsageTracker interface that uses PostgreSQL for storage.
 * @todo Implement the PostgreSQL queries for all methods.
 */
export class PostgresUsageTracker implements UsageTracker {
  constructor(private connectionString: string) {}

  async recordUsage(event: UsageEvent): Promise<void> {
    // TODO: Implement PostgreSQL INSERT statement.
    console.log('[UsageTracker] Recording usage (PostgreSQL):', {
      provider: event.provider,
      model: event.modelId,
      tokens: event.totalTokens,
    });
  }

  async getStats(provider: string, modelId: string, startDate: Date, endDate: Date): Promise<UsageStats> {
    // TODO: Implement PostgreSQL aggregation query.
    console.log('[UsageTracker] Getting stats (PostgreSQL):', { provider, modelId, startDate, endDate });
    return {
      provider, modelId, totalRequests: 0, successfulRequests: 0, failedRequests: 0,
      successRate: 0, totalTokens: 0, avgTokensPerRequest: 0, avgDurationMs: 0,
      p50DurationMs: 0, p95DurationMs: 0, p99DurationMs: 0, totalCost: 0,
      avgCostPerRequest: 0, periodStart: startDate, periodEnd: endDate,
    };
  }

  async getTopModels(limit: number, startDate: Date, endDate: Date): Promise<UsageStats[]> {
    // TODO: Implement PostgreSQL query to get top models.
    console.log('[UsageTracker] Getting top models (PostgreSQL):', { limit, startDate, endDate });
    return [];
  }

  async getCostBreakdown(startDate: Date, endDate: Date) {
    // TODO: Implement PostgreSQL query for cost breakdown.
    console.log('[UsageTracker] Getting cost breakdown (PostgreSQL):', { startDate, endDate });
    return { byProvider: {}, byModel: {}, byTier: { free: 0, limited: 0, 'pay-per-use': 0 }, total: 0 };
  }

  async getPerformanceTrends(provider: string, modelId: string, days: number) {
    // TODO: Implement PostgreSQL query for performance trends.
    console.log('[UsageTracker] Getting performance trends (PostgreSQL):', { provider, modelId, days });
    return [];
  }
}

/**
 * @class InMemoryUsageTracker
 * @implements {UsageTracker}
 * @description An in-memory implementation of the UsageTracker, useful for testing and development.
 */
export class InMemoryUsageTracker implements UsageTracker {
  private events: UsageEvent[] = [];

  async recordUsage(event: UsageEvent): Promise<void> {
    this.events.push(event);
  }

  async getStats(provider: string, modelId: string, startDate: Date, endDate: Date): Promise<UsageStats> {
    const filtered = this.events.filter(e => e.provider === provider && e.modelId === modelId && e.startedAt >= startDate && e.startedAt < endDate);
    const successful = filtered.filter(e => e.success);
    const totalTokens = filtered.reduce((sum, e) => sum + e.totalTokens, 0);
    const totalCost = filtered.reduce((sum, e) => sum + (e.estimatedCost ?? 0), 0);
    const durations = filtered.map(e => e.durationMs).sort((a, b) => a - b);
    return {
      provider, modelId, totalRequests: filtered.length, successfulRequests: successful.length,
      failedRequests: filtered.length - successful.length,
      successRate: filtered.length > 0 ? successful.length / filtered.length : 0,
      totalTokens, avgTokensPerRequest: filtered.length > 0 ? totalTokens / filtered.length : 0,
      avgDurationMs: filtered.length > 0 ? durations.reduce((a, b) => a + b, 0) / filtered.length : 0,
      p50DurationMs: durations[Math.floor(durations.length * 0.5)] ?? 0,
      p95DurationMs: durations[Math.floor(durations.length * 0.95)] ?? 0,
      p99DurationMs: durations[Math.floor(durations.length * 0.99)] ?? 0,
      totalCost, avgCostPerRequest: filtered.length > 0 ? totalCost / filtered.length : 0,
      periodStart: startDate, periodEnd: endDate,
    };
  }

  async getTopModels(limit: number, startDate: Date, endDate: Date): Promise<UsageStats[]> {
    const byModel = new Map<string, UsageEvent[]>();
    for (const event of this.events) {
      if (event.startedAt >= startDate && event.startedAt < endDate) {
        const key = `${event.provider}:${event.modelId}`;
        if (!byModel.has(key)) byModel.set(key, []);
        byModel.get(key)!.push(event);
      }
    }
    const stats = await Promise.all(Array.from(byModel.entries()).map(async ([key, events]) => {
      const [provider, modelId] = key.split(':');
      return this.getStats(provider, modelId, startDate, endDate);
    }));
    return stats.sort((a, b) => b.totalRequests - a.totalRequests).slice(0, limit);
  }

  async getCostBreakdown(startDate: Date, endDate: Date) {
    const filtered = this.events.filter(e => e.startedAt >= startDate && e.startedAt < endDate);
    const byProvider: Record<string, number> = {};
    const byModel: Record<string, number> = {};
    const byTier: Record<string, number> = { free: 0, limited: 0, 'pay-per-use': 0 };
    for (const event of filtered) {
      const cost = event.estimatedCost ?? 0;
      byProvider[event.provider] = (byProvider[event.provider] ?? 0) + cost;
      byModel[event.modelId] = (byModel[event.modelId] ?? 0) + cost;
      byTier[event.costTier] = (byTier[event.costTier] ?? 0) + cost;
    }
    return { byProvider, byModel, byTier, total: Object.values(byProvider).reduce((s, c) => s + c, 0) };
  }

  async getPerformanceTrends(provider: string, modelId: string, days: number) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    const filtered = this.events.filter(e => e.provider === provider && e.modelId === modelId && e.startedAt >= startDate);
    const byDay = new Map<string, UsageEvent[]>();
    for (const event of filtered) {
      const day = event.startedAt.toISOString().split('T')[0];
      if (!byDay.has(day)) byDay.set(day, []);
      byDay.get(day)!.push(event);
    }
    return Array.from(byDay.entries()).map(([date, events]) => ({
      date,
      avgDurationMs: events.reduce((s, e) => s + e.durationMs, 0) / events.length,
      avgTokensPerSecond: events.filter(e => e.tokensPerSecond).reduce((s, e) => s + (e.tokensPerSecond ?? 0), 0) / events.length,
      requestCount: events.length,
    })).sort((a, b) => a.date.localeCompare(b.date));
  }
}

let globalTracker: UsageTracker | null = null;

/**
 * Initializes the global usage tracker with either a PostgreSQL or in-memory implementation.
 * @param {string} [connectionString] The PostgreSQL connection string. If not provided, an in-memory tracker is used.
 * @returns {UsageTracker} The initialized usage tracker instance.
 */
export function initializeUsageTracker(connectionString?: string): UsageTracker {
  globalTracker = connectionString ? new PostgresUsageTracker(connectionString) : new InMemoryUsageTracker();
  return globalTracker;
}

/**
 * Retrieves the global usage tracker instance, initializing it if necessary.
 * @returns {UsageTracker} The global usage tracker instance.
 */
export function getUsageTracker(): UsageTracker {
  if (!globalTracker) {
    globalTracker = new InMemoryUsageTracker();
  }
  return globalTracker;
}

/**
 * A helper function to track a model usage event.
 * @param {ModelInfo} modelInfo The information about the model used.
 * @param {object} options The details of the usage event.
 */
export async function trackModelUsage(
  modelInfo: ModelInfo,
  options: {
    requestId: string;
    sessionId?: string;
    userId?: string;
    promptTokens: number;
    completionTokens: number;
    durationMs: number;
    timeToFirstToken?: number;
    complexity?: 'simple' | 'medium' | 'complex';
    hadTools?: boolean;
    hadVision?: boolean;
    hadReasoning?: boolean;
    success: boolean;
    error?: Error;
  }
): Promise<void> {
  const tracker = getUsageTracker();
  const now = new Date();
  const startedAt = new Date(now.getTime() - options.durationMs);

  await tracker.recordUsage({
    ...options,
    provider: modelInfo.provider,
    modelId: modelInfo.id,
    // @ts-ignore
    modelVersion: modelInfo.version,
    totalTokens: options.promptTokens + options.completionTokens,
    tokensPerSecond: options.timeToFirstToken ? options.completionTokens / (options.durationMs / 1000) : undefined,
    costTier: modelInfo.cost,
    estimatedCost: calculateCost(modelInfo, options.promptTokens, options.completionTokens),
    hadTools: options.hadTools ?? false,
    hadVision: options.hadVision ?? false,
    hadReasoning: options.hadReasoning ?? false,
    errorType: options.error?.name,
    errorMessage: options.error?.message,
    startedAt,
    completedAt: now,
  });
}

/**
 * Calculates the estimated cost of a request based on token usage.
 * @private
 * @param {ModelInfo} model The model used for the request.
 * @param {number} promptTokens The number of tokens in the prompt.
 * @param {number} completionTokens The number of tokens in the completion.
 * @returns {number | undefined} The estimated cost, or undefined if pricing data is unavailable.
 */
function calculateCost(
  model: ModelInfo,
  promptTokens: number,
  completionTokens: number
): number | undefined {
  if (model.cost === 'free') {
    return 0;
  }
  // TODO: Add pricing data to ModelInfo to enable cost calculation.
  return undefined;
}