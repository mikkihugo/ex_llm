/**
 * AI SDK Provider for GitHub Models
 *
 * Free tier access to GPT-4.1, Llama 4, DeepSeek, Mistral, and more.
 * Uses OpenAI-compatible API at https://models.github.ai
 *
 * Usage:
 * ```ts
 * import { githubModels } from 'ai-sdk-provider-github-models';
 * import { generateText } from 'ai';
 *
 * const result = await generateText({
 *   model: githubModels.languageModel('openai/gpt-4o'),
 *   prompt: 'Explain quantum computing',
 * });
 * ```
 */

import { createGitHubModelsProvider, type GitHubModelsProvider, type GitHubModelsConfig } from './github-models-provider';

export type { GitHubModelsProvider, GitHubModelsConfig };

/**
 * Default GitHub Models provider instance
 *
 * Requires GitHub token (auto-detected from gh CLI or environment).
 *
 * Authentication:
 * - Set GITHUB_TOKEN or GH_TOKEN environment variable
 * - Or pass token via config: createGitHubModelsProvider({ token: 'ghp_...' })
 * - Or pass token function: createGitHubModelsProvider({ token: getGitHubToken })
 */
export const githubModels = createGitHubModelsProvider();

/**
 * Create GitHub Models provider with custom config
 */
export { createGitHubModelsProvider };
