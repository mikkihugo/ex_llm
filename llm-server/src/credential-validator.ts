/**
 * @file Credential Validation
 * @description Validates that required API keys are set and accessible.
 *
 * Runs at startup to identify missing credentials early,
 * before users experience errors. Enables graceful degradation.
 */

import type { ProviderKey, CredentialStatus } from './types';
import { logger } from './logger';

/**
 * Provider credential requirements
 *
 * Maps each provider to the environment variables it requires.
 */
const PROVIDER_CREDENTIALS: Record<ProviderKey, string[]> = {
  claude: ['ANTHROPIC_API_KEY'],
  gemini: ['GOOGLE_API_KEY', 'GOOGLE_PROJECT_ID'], // Can also use ADC
  codex: ['OPENAI_API_KEY'],
  copilot: ['GITHUB_TOKEN'],
  github: ['GITHUB_TOKEN'],
  jules: ['GOOGLE_API_KEY'],
  cursor: ['CURSOR_API_KEY'],
  openrouter: ['OPENROUTER_API_KEY']
};

/**
 * Check if a provider has all required credentials
 *
 * @param provider - Provider name
 * @returns true if all required environment variables are set
 *
 * @example
 * ```typescript
 * if (isProviderAvailable('claude')) {
 *   // Can use Claude
 * } else {
 *   // Claude API key not set
 * }
 * ```
 */
export function isProviderAvailable(provider: ProviderKey): boolean {
  const requiredKeys = PROVIDER_CREDENTIALS[provider] || [];

  for (const key of requiredKeys) {
    const value = process.env[key];

    // Empty strings are treated as missing
    if (!value || value.trim() === '') {
      logger.debug(`Missing credential for ${provider}: ${key}`);
      return false;
    }
  }

  return true;
}

/**
 * Get list of missing credentials for a provider
 *
 * @param provider - Provider name
 * @returns Array of missing environment variable names
 *
 * @example
 * ```typescript
 * const missing = getMissingCredentials('claude');
 * if (missing.length > 0) {
 *   console.log('Missing:', missing);  // Missing: ['ANTHROPIC_API_KEY']
 * }
 * ```
 */
export function getMissingCredentials(provider: ProviderKey): string[] {
  const requiredKeys = PROVIDER_CREDENTIALS[provider] || [];
  const missing: string[] = [];

  for (const key of requiredKeys) {
    const value = process.env[key];
    if (!value || value.trim() === '') {
      missing.push(key);
    }
  }

  return missing;
}

/**
 * Check all providers and return status
 *
 * Validates credentials for all supported providers.
 * Used at startup to identify which providers are available.
 *
 * @returns Array of CredentialStatus for each provider
 *
 * @example
 * ```typescript
 * const status = validateAllProviders();
 * const available = status.filter(s => s.available);
 * console.log(`${available.length} providers available`);
 * ```
 */
export function validateAllProviders(): CredentialStatus[] {
  const providers: ProviderKey[] = [
    'claude',
    'gemini',
    'codex',
    'copilot',
    'github',
    'jules',
    'cursor',
    'openrouter'
  ];

  return providers.map((provider) => ({
    provider,
    available: isProviderAvailable(provider),
    error: getStatusMessage(provider),
    last_checked: new Date().toISOString()
  }));
}

/**
 * Get human-readable status message for a provider
 *
 * @param provider - Provider name
 * @returns Status message or undefined if available
 */
export function getStatusMessage(provider: ProviderKey): string | undefined {
  const missing = getMissingCredentials(provider);

  if (missing.length === 0) {
    return undefined; // Provider is available
  }

  return `Missing: ${missing.join(', ')}`;
}

/**
 * Assert that at least one provider is available
 *
 * Throws an error if no providers can be used.
 * Called during startup to prevent broken deployments.
 *
 * @throws Error if no providers are available
 *
 * @example
 * ```typescript
 * try {
 *   assertAtLeastOneProvider();
 * } catch (error) {
 *   console.error('No AI providers configured:', error.message);
 *   process.exit(1);
 * }
 * ```
 */
export function assertAtLeastOneProvider(): void {
  const status = validateAllProviders();
  const available = status.filter((s) => s.available);

  if (available.length === 0) {
    const missing = status.map((s) => `${s.provider}: ${s.error}`).join('\n  ');
    throw new Error(`No AI providers configured. Missing credentials:\n  ${missing}`);
  }

  const availableNames = available.map((s) => s.provider).join(', ');
  logger.info('Providers available at startup', {
    count: available.length,
    providers: availableNames
  });
}

/**
 * Check if a fallback provider chain has at least one available
 *
 * Useful for validating fallback sequences.
 *
 * @param providers - Sequence of provider names to check
 * @returns First available provider name, or null if none available
 *
 * @example
 * ```typescript
 * const fallback = findAvailableProvider(['claude', 'gemini', 'openrouter']);
 * if (!fallback) {
 *   throw new Error('No fallback providers available');
 * }
 * ```
 */
export function findAvailableProvider(providers: ProviderKey[]): ProviderKey | null {
  for (const provider of providers) {
    if (isProviderAvailable(provider)) {
      return provider;
    }
  }
  return null;
}

/**
 * Log credential status at startup
 *
 * Prints human-readable credential status for debugging.
 * Shows which providers are available and which are not.
 *
 * @example
 * ```typescript
 * logCredentialStatus();
 * // Output:
 * // ✅ claude (ANTHROPIC_API_KEY)
 * // ✅ gemini (GOOGLE_API_KEY)
 * // ❌ codex (OPENAI_API_KEY)
 * ```
 */
export function logCredentialStatus(): void {
  const status = validateAllProviders();

  logger.info('=== Credential Status ===');

  for (const s of status) {
    if (s.available) {
      logger.info(`✅ ${s.provider} is available`);
    } else {
      logger.warn(`❌ ${s.provider} is NOT available: ${s.error}`);
    }
  }

  const available = status.filter((s) => s.available).length;
  logger.info(`Total: ${available}/${status.length} providers available`);
}

/**
 * Validate and sanitize an API key
 *
 * Checks that key is a non-empty string.
 * Does NOT validate with provider (just format check).
 *
 * @param key - API key to validate
 * @param keyName - Name of key for error messages
 * @returns Validated key
 * @throws Error if key is invalid
 *
 * @example
 * ```typescript
 * const key = process.env.ANTHROPIC_API_KEY;
 * const valid = validateAPIKey(key, 'ANTHROPIC_API_KEY');
 * // If key is null/empty, throws error
 * ```
 */
export function validateAPIKey(key: string | undefined, keyName: string): string {
  if (!key || typeof key !== 'string' || key.trim() === '') {
    throw new Error(`Invalid ${keyName}: must be non-empty string`);
  }

  // Check for common mistakes
  if (key.includes(' ')) {
    logger.warn(`${keyName} contains whitespace - trimming`, { keyLength: key.length });
  }

  return key.trim();
}
