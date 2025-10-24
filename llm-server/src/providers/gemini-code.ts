/**
 * @file Google Gemini Provider
 * @description Using third-party ai-sdk-provider-gemini-cli package for Gemini Code Assist
 */

// @ts-ignore - Third-party package has type issues but works at runtime
import { createGeminiProvider as baseCreateGeminiProvider } from 'ai-sdk-provider-gemini-cli';

// Define proper auth types to match third-party library expectations
interface GeminiApiKeyAuth {
  authType: 'api-key';
  apiKey: string;
}

interface VertexAIAuth {
  authType: 'vertex-ai';
  vertexAI: {
    projectId: string;
    location: string;
    apiKey?: string;
  };
}

interface OAuthAuth {
  authType: 'oauth';
  oauth: {
    clientId: string;
    clientSecret: string;
    redirectUri?: string;
  };
}

interface OAuthPersonalAuth {
  authType: 'oauth-personal';
  oauth?: {
    clientId: string;
    clientSecret: string;
    redirectUri?: string;
  };
}

interface GoogleAuthLibraryAuth {
  authType: 'google-auth-library';
  googleAuth: {
    keyFilename?: string;
    credentials?: any;
  };
}

interface BaseProviderOptions {
  proxy?: string;
}

type GeminiProviderOptions =
  | (GeminiApiKeyAuth & BaseProviderOptions)
  | (VertexAIAuth & BaseProviderOptions)
  | (OAuthAuth & BaseProviderOptions)
  | (OAuthPersonalAuth & BaseProviderOptions)
  | (GoogleAuthLibraryAuth & BaseProviderOptions);

interface BaseGeminiProvider {
  (modelId: string): any;
  languageModel?: (modelId: string) => any;
}

export type { GeminiProviderOptions };

/**
 * @const {Array<object>} GEMINI_CODE_MODELS
 * @description A static list of available Gemini models and their metadata.
 */
export const GEMINI_CODE_MODELS = [
  {
    id: 'gemini-2.5-flash',
    displayName: 'Gemini Code 2.5 Flash',
    description: 'Fast, efficient model (FREE via Gemini Code Assist)',
    contextWindow: 1048576,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: false, tools: true },
    cost: 'free' as const,
  },
  {
    id: 'gemini-2.5-pro',
    displayName: 'Gemini Code 2.5 Pro',
    description: 'Most capable Gemini model (FREE via Gemini Code Assist)',
    contextWindow: 1048576,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: false, tools: true },
    cost: 'free' as const,
  },
] as const;

/**
 * @interface GeminiProvider
 * @extends BaseGeminiProvider
 * @description Extends the base Gemini provider to include a `listModels` method.
 */
export interface GeminiProvider extends BaseGeminiProvider {
  listModels(): typeof GEMINI_CODE_MODELS;
}

/**
 * Creates a Gemini provider instance, extended with a `listModels` method.
 *
 * Authentication Status:
 * - API Key Authentication: ✅ Working (current method)
 * - OAuth Flow: Deferred (planned for future implementation)
 *
 * OAuth Implementation Notes:
 * - Will require similar flow to GitHub Copilot (auth code → access token)
 * - Needs to integrate with Google Cloud OAuth 2.0 consent screen
 * - Should handle token refresh for long-running processes
 * - User will authenticate once, tokens stored securely
 *
 * Current workaround: Uses GOOGLE_CLOUD_PROJECT env var or default project ID
 *
 * @param {GeminiProviderOptions} [options] Configuration options for the Gemini provider.
 * @returns {GeminiProvider} A configured Gemini provider instance.
 */
export function createGeminiProvider(options?: any): GeminiProvider {
  // Current: API key authentication (set via GOOGLE_API_KEY env var)
  // Planned: OAuth flow for user-specific authentication (planned for v2.0)

  // Set a default Google Cloud Project ID if not provided in the environment.
  if (!process.env.GOOGLE_CLOUD_PROJECT) {
    process.env.GOOGLE_CLOUD_PROJECT = 'gemini-code-473918';
  }

  const baseProvider = baseCreateGeminiProvider(options);

  // Extend the base provider with the listModels method.
  return Object.assign(baseProvider, {
    listModels: () => GEMINI_CODE_MODELS,
  }) as GeminiProvider;
}

/**
 * @const {object} geminiCode
 * @description The singleton instance of the Gemini provider with default configuration.
 * NOTE: Currently using third-party gemini-cli package, not official AI SDK
 */
export const geminiCode = createGeminiProvider();