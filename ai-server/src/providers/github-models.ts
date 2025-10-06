/**
 * GitHub Models Provider
 *
 * Free tier access to GPT-4.1, Llama 4, DeepSeek, Mistral, and more.
 * Uses full AI SDK provider with dynamic model listing.
 */

import { githubModels as baseProvider } from '../../vendor/ai-sdk-provider-github-models/dist/index.js';

// Pre-load models at startup (async, fire-and-forget)
baseProvider.refreshModels().catch(err => {
  console.error('⚠️  Failed to load GitHub Models catalog:', err.message);
});

export const githubModels = baseProvider;