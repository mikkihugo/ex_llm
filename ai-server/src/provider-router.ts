/**
 * Provider Priority Routing with Rate Limit Tiers
 *
 * Routes requests to the best available provider based on:
 * - Subscription limits (unlimited > high > limited)
 * - Current usage/rate limits
 * - Model capabilities (tools, reasoning, vision)
 * - Cost tier (free > limited > pay-per-use)
 */

export interface ProviderTier {
  priority: number;           // Lower = higher priority (1 is best)
  quota: 'unlimited' | number; // Infinity or requests per period
  cost: 'free' | 'limited' | 'pay-per-use';
  subscription?: string;
  rateLimitPeriod?: 'hour' | 'day' | 'week' | 'month';
  contextWindow?: number;     // Max context window
  capabilities?: {
    tools?: boolean;
    reasoning?: boolean;
    vision?: boolean;
  };
}

export interface ProviderConfig {
  [provider: string]: ProviderTier;
}

/**
 * Provider Priority Configuration
 * Based on your subscriptions: ChatGPT Pro, Claude Max, Corporate Gemini, Copilot Enterprise
 */
export const PROVIDER_TIERS: ProviderConfig = {
  // ========================================
  // TIER 1: UNLIMITED - Use as Default
  // ========================================

  'openai-codex': {
    priority: 1,
    quota: 'unlimited',
    cost: 'free',
    subscription: 'ChatGPT 5 Pro ($200/month)',
    contextWindow: 200000,
    capabilities: { tools: true, reasoning: true, vision: false },
  },

  'claude-code': {
    priority: 1,
    quota: 'unlimited',
    cost: 'free',
    subscription: 'Claude Max ($100-200/month)',
    contextWindow: 200000,
    capabilities: { tools: true, reasoning: true, vision: true },
  },

  'gemini-code': {
    priority: 1,
    quota: 'unlimited',
    cost: 'free',
    subscription: 'Gemini Code Assist (Professional)',
    contextWindow: 1048576, // 1M tokens
    capabilities: { tools: true, reasoning: false, vision: false },
  },

  // ========================================
  // TIER 2: HIGH LIMITS - Use Freely
  // ========================================

  'github-copilot-free': {
    priority: 2,
    quota: 'unlimited',
    cost: 'free',
    subscription: 'GitHub Copilot Enterprise (free tier)',
    contextWindow: 128000,
    capabilities: { tools: true, reasoning: true, vision: false },
    // Models: gpt-4.1, gpt-5-mini, grok-code-fast-1
  },

  // ========================================
  // TIER 3: LIMITED CONTEXT - Use for Experiments
  // ========================================

  'github-models': {
    priority: 3,
    quota: 500,
    rateLimitPeriod: 'day',
    cost: 'free',
    subscription: undefined,
    contextWindow: 12000, // 8K in + 4K out (SMALL!)
    capabilities: { tools: true, reasoning: false, vision: true },
    // 27/49 models support tools - good for A/B testing!
  },

  // ========================================
  // TIER 4: QUOTA LIMITED - Edge Cases Only
  // ========================================

  'github-copilot-premium': {
    priority: 4,
    quota: 1000,
    rateLimitPeriod: 'month',
    cost: 'free', // Treat as free within quota to use all 1000/month
    subscription: 'GitHub Copilot Enterprise (premium quota)',
    contextWindow: 200000,
    capabilities: { tools: true, reasoning: true, vision: true },
    // Models: Claude Sonnet 4, Claude Opus 4, Gemini 2.5, o3, gpt-5-codex
    // 1000 free requests/month, then $0.04/request - so use freely within quota!
  },
};

/**
 * Get provider tier by name
 */
export function getProviderTier(provider: string): ProviderTier | undefined {
  return PROVIDER_TIERS[provider];
}

/**
 * Get all providers sorted by priority
 */
export function getProvidersByPriority(): string[] {
  return Object.entries(PROVIDER_TIERS)
    .sort(([, a], [, b]) => a.priority - b.priority)
    .map(([name]) => name);
}

/**
 * Select best provider for a request based on requirements
 */
export interface SelectionCriteria {
  requireTools?: boolean;
  requireReasoning?: boolean;
  requireVision?: boolean;
  contextSize?: number;
  allowPremium?: boolean; // Allow Tier 4 (quota-limited)?
}

export function selectProvider(criteria: SelectionCriteria = {}): string | null {
  const providers = getProvidersByPriority();

  for (const provider of providers) {
    const tier = PROVIDER_TIERS[provider];

    // Skip Tier 4 unless explicitly allowed
    if (tier.priority >= 4 && !criteria.allowPremium) {
      continue;
    }

    // Check capabilities
    if (criteria.requireTools && !tier.capabilities?.tools) {
      continue;
    }

    if (criteria.requireReasoning && !tier.capabilities?.reasoning) {
      continue;
    }

    if (criteria.requireVision && !tier.capabilities?.vision) {
      continue;
    }

    // Check context window
    if (criteria.contextSize && tier.contextWindow && criteria.contextSize > tier.contextWindow) {
      continue;
    }

    // Found a match!
    return provider;
  }

  return null;
}

/**
 * Get recommended provider for A/B testing
 * Use GitHub Models (Tier 3) for experimentation with diverse models
 */
export function getABTestingProvider(): string {
  return 'github-models';
}

/**
 * Usage tracking (in-memory for now)
 */
interface UsageTracker {
  [provider: string]: {
    count: number;
    resetAt: number;
  };
}

const usage: UsageTracker = {};

/**
 * Check if provider has remaining quota
 */
export function hasQuota(provider: string): boolean {
  const tier = PROVIDER_TIERS[provider];
  if (!tier) return false;

  // Unlimited quota
  if (tier.quota === 'unlimited') return true;

  // Check usage
  const now = Date.now();
  const usage_record = usage[provider];

  if (!usage_record) {
    return true; // No usage yet
  }

  // Reset if period expired
  if (usage_record.resetAt < now) {
    usage[provider] = { count: 0, resetAt: getResetTime(tier) };
    return true;
  }

  // Check against quota
  return usage_record.count < tier.quota;
}

/**
 * Record usage for a provider
 */
export function recordUsage(provider: string): void {
  const tier = PROVIDER_TIERS[provider];
  if (!tier || tier.quota === 'unlimited') return;

  const now = Date.now();

  if (!usage[provider] || usage[provider].resetAt < now) {
    usage[provider] = {
      count: 1,
      resetAt: getResetTime(tier),
    };
  } else {
    usage[provider].count++;
  }
}

/**
 * Get reset timestamp based on rate limit period
 */
function getResetTime(tier: ProviderTier): number {
  const now = Date.now();

  switch (tier.rateLimitPeriod) {
    case 'hour':
      return now + (60 * 60 * 1000);
    case 'day':
      return now + (24 * 60 * 60 * 1000);
    case 'week':
      return now + (7 * 24 * 60 * 60 * 1000);
    case 'month':
      return now + (30 * 24 * 60 * 60 * 1000);
    default:
      return now + (24 * 60 * 60 * 1000); // Default to 1 day
  }
}

/**
 * Get usage statistics for all providers
 */
export function getUsageStats(): { [provider: string]: { used: number; quota: number | 'unlimited'; remaining: number | 'unlimited' } } {
  const stats: any = {};

  for (const [provider, tier] of Object.entries(PROVIDER_TIERS)) {
    const usage_record = usage[provider];

    if (tier.quota === 'unlimited') {
      stats[provider] = {
        used: usage_record?.count || 0,
        quota: 'unlimited',
        remaining: 'unlimited',
      };
    } else {
      const used = usage_record?.count || 0;
      stats[provider] = {
        used,
        quota: tier.quota,
        remaining: Math.max(0, tier.quota - used),
      };
    }
  }

  return stats;
}
