/**
 * @file Provider Priority Routing and Rate Limiting
 * @description This module defines the routing logic for selecting the best available AI provider
 * based on a tiered system. It considers provider priority, subscription limits, model
 * capabilities, cost, and rate limit quotas.
 */

/**
 * @interface ProviderTier
 * @description Defines the configuration for a single provider tier.
 */
export interface ProviderTier {
  priority: number;
  quota: 'unlimited' | number;
  cost: 'free' | 'limited' | 'pay-per-use';
  subscription?: string;
  rateLimitPeriod?: 'hour' | 'day' | 'week' | 'month';
  contextWindow?: number;
  capabilities?: {
    tools?: boolean;
    reasoning?: boolean;
    vision?: boolean;
  };
}

/**
 * @interface ProviderConfig
 * @description A map of provider names to their tier configurations.
 */
export interface ProviderConfig {
  [provider: string]: ProviderTier;
}

/**
 * @const {ProviderConfig} PROVIDER_TIERS
 * @description The main configuration object that defines the priority and limits for each provider.
 * This configuration is based on typical subscription plans and capabilities.
 */
export const PROVIDER_TIERS: ProviderConfig = {
  // Tier 1: Unlimited usage, high-performance models. Default choice.
  'openai-codex': {
    priority: 1,
    quota: 'unlimited',
    cost: 'free',
    subscription: 'ChatGPT 5 Pro',
    contextWindow: 200000,
    capabilities: { tools: true, reasoning: true, vision: false },
  },
  'claude-code': {
    priority: 1,
    quota: 'unlimited',
    cost: 'free',
    subscription: 'Claude Max',
    contextWindow: 200000,
    capabilities: { tools: true, reasoning: true, vision: true },
  },
  'gemini-code': {
    priority: 1,
    quota: 'unlimited',
    cost: 'free',
    subscription: 'Gemini Code Assist',
    contextWindow: 1048576,
    capabilities: { tools: true, reasoning: false, vision: false },
  },
  // Tier 2: Unlimited free tiers, great for general use.
  'github-copilot-free': {
    priority: 2,
    quota: 'unlimited',
    cost: 'free',
    subscription: 'GitHub Copilot Enterprise (free tier)',
    contextWindow: 128000,
    capabilities: { tools: true, reasoning: true, vision: false },
  },
  // Tier 3: Limited context or capabilities, best for experimentation.
  'github-models': {
    priority: 3,
    quota: 500,
    rateLimitPeriod: 'day',
    cost: 'free',
    subscription: undefined,
    contextWindow: 12000,
    capabilities: { tools: true, reasoning: false, vision: true },
  },
  // Tier 4: Quota-limited premium models, for specific or high-stakes tasks.
  'github-copilot-premium': {
    priority: 4,
    quota: 1000,
    rateLimitPeriod: 'month',
    cost: 'free', // Free within quota
    subscription: 'GitHub Copilot Enterprise (premium quota)',
    contextWindow: 200000,
    capabilities: { tools: true, reasoning: true, vision: true },
  },
};

/**
 * Retrieves the tier configuration for a specific provider.
 * @param {string} provider The name of the provider.
 * @returns {ProviderTier | undefined} The provider's tier configuration, or undefined if not found.
 */
export function getProviderTier(provider: string): ProviderTier | undefined {
  return PROVIDER_TIERS[provider];
}

/**
 * Gets a list of all providers, sorted by their priority (lowest first).
 * @returns {string[]} A sorted array of provider names.
 */
export function getProvidersByPriority(): string[] {
  return Object.entries(PROVIDER_TIERS)
    .sort(([, a], [, b]) => a.priority - b.priority)
    .map(([name]) => name);
}

/**
 * @interface SelectionCriteria
 * @description Defines the criteria for selecting the best provider for a request.
 */
export interface SelectionCriteria {
  requireTools?: boolean;
  requireReasoning?: boolean;
  requireVision?: boolean;
  contextSize?: number;
  allowPremium?: boolean;
}

/**
 * Selects the best provider based on a set of criteria.
 * @param {SelectionCriteria} [criteria={}] The criteria for selecting a provider.
 * @returns {string | null} The name of the best provider, or null if no suitable provider is found.
 */
export function selectProvider(criteria: SelectionCriteria = {}): string | null {
  const providers = getProvidersByPriority();
  for (const provider of providers) {
    const tier = PROVIDER_TIERS[provider];
    if (tier.priority >= 4 && !criteria.allowPremium) continue;
    if (criteria.requireTools && !tier.capabilities?.tools) continue;
    if (criteria.requireReasoning && !tier.capabilities?.reasoning) continue;
    if (criteria.requireVision && !tier.capabilities?.vision) continue;
    if (criteria.contextSize && tier.contextWindow && criteria.contextSize > tier.contextWindow) continue;
    return provider;
  }
  return null;
}

/**
 * Gets the recommended provider for A/B testing.
 * @returns {string} The name of the recommended provider.
 */
export function getABTestingProvider(): string {
  return 'github-models';
}

/**
 * @interface UsageTracker
 * @description An in-memory store for tracking provider usage against quotas.
 */
interface UsageTracker {
  [provider: string]: {
    count: number;
    resetAt: number;
  };
}

const usage: UsageTracker = {};

/**
 * Checks if a provider has remaining quota for the current period.
 * @param {string} provider The name of the provider.
 * @returns {boolean} True if the provider has quota, false otherwise.
 */
export function hasQuota(provider: string): boolean {
  const tier = PROVIDER_TIERS[provider];
  if (!tier) return false;
  if (tier.quota === 'unlimited') return true;

  const now = Date.now();
  const usageRecord = usage[provider];
  if (!usageRecord || usageRecord.resetAt < now) {
    return true;
  }
  return usageRecord.count < tier.quota;
}

/**
 * Records usage for a specific provider.
 * @param {string} provider The name of the provider to record usage for.
 */
export function recordUsage(provider: string): void {
  const tier = PROVIDER_TIERS[provider];
  if (!tier || tier.quota === 'unlimited') return;

  const now = Date.now();
  if (!usage[provider] || usage[provider].resetAt < now) {
    usage[provider] = { count: 1, resetAt: getResetTime(tier) };
  } else {
    usage[provider].count++;
  }
}

/**
 * Calculates the next reset time for a provider's quota.
 * @private
 * @param {ProviderTier} tier The provider's tier configuration.
 * @returns {number} The timestamp for the next reset.
 */
function getResetTime(tier: ProviderTier): number {
  const now = new Date();
  switch (tier.rateLimitPeriod) {
    case 'hour': return now.setHours(now.getHours() + 1);
    case 'day': return now.setDate(now.getDate() + 1);
    case 'week': return now.setDate(now.getDate() + 7);
    case 'month': return now.setMonth(now.getMonth() + 1);
    default: return now.setDate(now.getDate() + 1);
  }
}

/**
 * Gets the current usage statistics for all providers.
 * @returns {Record<string, { used: number; quota: number | 'unlimited'; remaining: number | 'unlimited' }>} An object containing usage stats.
 */
export function getUsageStats(): { [provider: string]: { used: number; quota: number | 'unlimited'; remaining: number | 'unlimited' } } {
  const stats: any = {};
  for (const [provider, tier] of Object.entries(PROVIDER_TIERS)) {
    const used = usage[provider]?.count || 0;
    const quota = tier.quota;
    stats[provider] = {
      used,
      quota,
      remaining: quota === 'unlimited' ? 'unlimited' : Math.max(0, quota - used),
    };
  }
  return stats;
}
