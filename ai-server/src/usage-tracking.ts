/**
 * Usage Tracking System
 *
 * Tracks AI provider usage, costs, performance, and patterns.
 * Integrates with PostgreSQL for persistent storage and analytics.
 */

import type { ModelInfo } from './model-registry';

export interface UsageEvent {
  // Request identification
  requestId: string;
  sessionId?: string;
  userId?: string;

  // Model information
  provider: string;
  modelId: string;
  modelVersion?: string;

  // Usage metrics
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;

  // Performance
  durationMs: number;
  timeToFirstToken?: number;
  tokensPerSecond?: number;

  // Cost tracking
  costTier: 'free' | 'limited' | 'pay-per-use';
  estimatedCost?: number;

  // Request metadata
  complexity: 'simple' | 'medium' | 'complex';
  hadTools: boolean;
  hadVision: boolean;
  hadReasoning: boolean;

  // Success/failure
  success: boolean;
  errorType?: string;
  errorMessage?: string;

  // Timestamps
  startedAt: Date;
  completedAt: Date;
}

export interface UsageStats {
  provider: string;
  modelId: string;

  // Aggregated metrics
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

  // Time period
  periodStart: Date;
  periodEnd: Date;
}

export interface UsageTracker {
  /**
   * Record a usage event
   */
  recordUsage(event: UsageEvent): Promise<void>;

  /**
   * Get usage statistics for a time period
   */
  getStats(
    provider: string,
    modelId: string,
    startDate: Date,
    endDate: Date
  ): Promise<UsageStats>;

  /**
   * Get top models by usage
   */
  getTopModels(limit: number, startDate: Date, endDate: Date): Promise<UsageStats[]>;

  /**
   * Get cost breakdown
   */
  getCostBreakdown(startDate: Date, endDate: Date): Promise<{
    byProvider: Record<string, number>;
    byModel: Record<string, number>;
    byTier: Record<string, number>;
    total: number;
  }>;

  /**
   * Get performance trends
   */
  getPerformanceTrends(
    provider: string,
    modelId: string,
    days: number
  ): Promise<{
    date: string;
    avgDurationMs: number;
    avgTokensPerSecond: number;
    requestCount: number;
  }[]>;
}

/**
 * PostgreSQL-backed usage tracker
 */
export class PostgresUsageTracker implements UsageTracker {
  constructor(
    private connectionString: string
  ) {}

  async recordUsage(event: UsageEvent): Promise<void> {
    // TODO: Implement PostgreSQL INSERT
    // For now, log to console
    console.log('[usage-tracker] Recording usage:', {
      provider: event.provider,
      model: event.modelId,
      tokens: event.totalTokens,
      durationMs: event.durationMs,
      success: event.success,
    });

    // Store in db:
    // INSERT INTO ai_usage_events (
    //   request_id, session_id, user_id,
    //   provider, model_id, model_version,
    //   prompt_tokens, completion_tokens, total_tokens,
    //   duration_ms, time_to_first_token, tokens_per_second,
    //   cost_tier, estimated_cost,
    //   complexity, had_tools, had_vision, had_reasoning,
    //   success, error_type, error_message,
    //   started_at, completed_at
    // ) VALUES (...)
  }

  async getStats(
    provider: string,
    modelId: string,
    startDate: Date,
    endDate: Date
  ): Promise<UsageStats> {
    // TODO: Implement PostgreSQL aggregation query
    console.log('[usage-tracker] Getting stats:', { provider, modelId, startDate, endDate });

    // Example query:
    // SELECT
    //   provider,
    //   model_id,
    //   COUNT(*) as total_requests,
    //   COUNT(*) FILTER (WHERE success = true) as successful_requests,
    //   COUNT(*) FILTER (WHERE success = false) as failed_requests,
    //   SUM(total_tokens) as total_tokens,
    //   AVG(total_tokens) as avg_tokens_per_request,
    //   AVG(duration_ms) as avg_duration_ms,
    //   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_ms) as p50_duration_ms,
    //   PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_duration_ms,
    //   PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms) as p99_duration_ms,
    //   SUM(estimated_cost) as total_cost,
    //   AVG(estimated_cost) as avg_cost_per_request
    // FROM ai_usage_events
    // WHERE provider = $1 AND model_id = $2
    //   AND started_at >= $3 AND started_at < $4
    // GROUP BY provider, model_id

    return {
      provider,
      modelId,
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      successRate: 0,
      totalTokens: 0,
      avgTokensPerRequest: 0,
      avgDurationMs: 0,
      p50DurationMs: 0,
      p95DurationMs: 0,
      p99DurationMs: 0,
      totalCost: 0,
      avgCostPerRequest: 0,
      periodStart: startDate,
      periodEnd: endDate,
    };
  }

  async getTopModels(limit: number, startDate: Date, endDate: Date): Promise<UsageStats[]> {
    console.log('[usage-tracker] Getting top models:', { limit, startDate, endDate });

    // SELECT provider, model_id, COUNT(*) as total_requests, ...
    // FROM ai_usage_events
    // WHERE started_at >= $1 AND started_at < $2
    // GROUP BY provider, model_id
    // ORDER BY total_requests DESC
    // LIMIT $3

    return [];
  }

  async getCostBreakdown(startDate: Date, endDate: Date) {
    console.log('[usage-tracker] Getting cost breakdown:', { startDate, endDate });

    // Multi-query aggregation:
    // 1. GROUP BY provider
    // 2. GROUP BY model_id
    // 3. GROUP BY cost_tier

    return {
      byProvider: {},
      byModel: {},
      byTier: { free: 0, limited: 0, 'pay-per-use': 0 },
      total: 0,
    };
  }

  async getPerformanceTrends(provider: string, modelId: string, days: number) {
    console.log('[usage-tracker] Getting performance trends:', { provider, modelId, days });

    // SELECT
    //   DATE_TRUNC('day', started_at) as date,
    //   AVG(duration_ms) as avg_duration_ms,
    //   AVG(tokens_per_second) as avg_tokens_per_second,
    //   COUNT(*) as request_count
    // FROM ai_usage_events
    // WHERE provider = $1 AND model_id = $2
    //   AND started_at >= NOW() - INTERVAL '$3 days'
    // GROUP BY DATE_TRUNC('day', started_at)
    // ORDER BY date ASC

    return [];
  }
}

/**
 * In-memory usage tracker (for testing/development)
 */
export class InMemoryUsageTracker implements UsageTracker {
  private events: UsageEvent[] = [];

  async recordUsage(event: UsageEvent): Promise<void> {
    this.events.push(event);
    console.log('[usage-tracker] [memory] Recorded:', {
      provider: event.provider,
      model: event.modelId,
      tokens: event.totalTokens,
    });
  }

  async getStats(
    provider: string,
    modelId: string,
    startDate: Date,
    endDate: Date
  ): Promise<UsageStats> {
    const filtered = this.events.filter(
      e =>
        e.provider === provider &&
        e.modelId === modelId &&
        e.startedAt >= startDate &&
        e.startedAt < endDate
    );

    const successful = filtered.filter(e => e.success);
    const totalTokens = filtered.reduce((sum, e) => sum + e.totalTokens, 0);
    const totalCost = filtered.reduce((sum, e) => sum + (e.estimatedCost ?? 0), 0);
    const durations = filtered.map(e => e.durationMs).sort((a, b) => a - b);

    return {
      provider,
      modelId,
      totalRequests: filtered.length,
      successfulRequests: successful.length,
      failedRequests: filtered.length - successful.length,
      successRate: filtered.length > 0 ? successful.length / filtered.length : 0,
      totalTokens,
      avgTokensPerRequest: filtered.length > 0 ? totalTokens / filtered.length : 0,
      avgDurationMs: filtered.length > 0 ? durations.reduce((a, b) => a + b, 0) / filtered.length : 0,
      p50DurationMs: durations[Math.floor(durations.length * 0.5)] ?? 0,
      p95DurationMs: durations[Math.floor(durations.length * 0.95)] ?? 0,
      p99DurationMs: durations[Math.floor(durations.length * 0.99)] ?? 0,
      totalCost,
      avgCostPerRequest: filtered.length > 0 ? totalCost / filtered.length : 0,
      periodStart: startDate,
      periodEnd: endDate,
    };
  }

  async getTopModels(limit: number, startDate: Date, endDate: Date): Promise<UsageStats[]> {
    const byModel = new Map<string, UsageEvent[]>();

    for (const event of this.events) {
      if (event.startedAt >= startDate && event.startedAt < endDate) {
        const key = `${event.provider}:${event.modelId}`;
        if (!byModel.has(key)) {
          byModel.set(key, []);
        }
        byModel.get(key)!.push(event);
      }
    }

    const stats = await Promise.all(
      Array.from(byModel.entries()).map(async ([key, events]) => {
        const [provider, modelId] = key.split(':');
        return this.getStats(provider, modelId, startDate, endDate);
      })
    );

    return stats
      .sort((a, b) => b.totalRequests - a.totalRequests)
      .slice(0, limit);
  }

  async getCostBreakdown(startDate: Date, endDate: Date) {
    const filtered = this.events.filter(
      e => e.startedAt >= startDate && e.startedAt < endDate
    );

    const byProvider: Record<string, number> = {};
    const byModel: Record<string, number> = {};
    const byTier: Record<string, number> = { free: 0, limited: 0, 'pay-per-use': 0 };

    for (const event of filtered) {
      const cost = event.estimatedCost ?? 0;

      byProvider[event.provider] = (byProvider[event.provider] ?? 0) + cost;
      byModel[event.modelId] = (byModel[event.modelId] ?? 0) + cost;
      byTier[event.costTier] = (byTier[event.costTier] ?? 0) + cost;
    }

    const total = Object.values(byProvider).reduce((sum, cost) => sum + cost, 0);

    return { byProvider, byModel, byTier, total };
  }

  async getPerformanceTrends(provider: string, modelId: string, days: number) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const filtered = this.events.filter(
      e =>
        e.provider === provider &&
        e.modelId === modelId &&
        e.startedAt >= startDate
    );

    const byDay = new Map<string, UsageEvent[]>();

    for (const event of filtered) {
      const day = event.startedAt.toISOString().split('T')[0];
      if (!byDay.has(day)) {
        byDay.set(day, []);
      }
      byDay.get(day)!.push(event);
    }

    return Array.from(byDay.entries())
      .map(([date, events]) => ({
        date,
        avgDurationMs: events.reduce((sum, e) => sum + e.durationMs, 0) / events.length,
        avgTokensPerSecond: events
          .filter(e => e.tokensPerSecond !== undefined)
          .reduce((sum, e) => sum + (e.tokensPerSecond ?? 0), 0) / events.length,
        requestCount: events.length,
      }))
      .sort((a, b) => a.date.localeCompare(b.date));
  }
}

/**
 * Global usage tracker instance
 */
let globalTracker: UsageTracker | null = null;

export function initializeUsageTracker(connectionString?: string): UsageTracker {
  if (connectionString) {
    globalTracker = new PostgresUsageTracker(connectionString);
  } else {
    globalTracker = new InMemoryUsageTracker();
  }
  return globalTracker;
}

export function getUsageTracker(): UsageTracker {
  if (!globalTracker) {
    globalTracker = new InMemoryUsageTracker();
  }
  return globalTracker;
}

/**
 * Helper to track AI SDK usage
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
    requestId: options.requestId,
    sessionId: options.sessionId,
    userId: options.userId,
    provider: modelInfo.provider,
    modelId: modelInfo.id,
    modelVersion: modelInfo.version,
    promptTokens: options.promptTokens,
    completionTokens: options.completionTokens,
    totalTokens: options.promptTokens + options.completionTokens,
    durationMs: options.durationMs,
    timeToFirstToken: options.timeToFirstToken,
    tokensPerSecond: options.timeToFirstToken
      ? options.completionTokens / (options.durationMs / 1000)
      : undefined,
    costTier: modelInfo.cost,
    estimatedCost: calculateCost(modelInfo, options.promptTokens, options.completionTokens),
    complexity: options.complexity ?? 'medium',
    hadTools: options.hadTools ?? false,
    hadVision: options.hadVision ?? false,
    hadReasoning: options.hadReasoning ?? false,
    success: options.success,
    errorType: options.error?.name,
    errorMessage: options.error?.message,
    startedAt,
    completedAt: now,
  });
}

/**
 * Calculate cost based on token usage
 */
function calculateCost(
  model: ModelInfo,
  promptTokens: number,
  completionTokens: number
): number | undefined {
  if (model.cost === 'free') {
    return 0;
  }

  // TODO: Add pricing data to ModelInfo
  // For now, return undefined for non-free tiers
  return undefined;
}
