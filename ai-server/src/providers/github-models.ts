/**
 * @file GitHub Models Provider
 * @description This module re-exports the base GitHub Models provider from the vendored
 * package and initiates an asynchronous pre-loading of the model catalog at startup.
 * This provider offers free-tier access to a variety of models including GPT-4.1, Llama 4,
 * DeepSeek, and Mistral.
 */

import { githubModels as baseProvider } from '../../vendor/ai-sdk-provider-github-models/dist/index.js';

// Pre-load the model catalog at startup to improve the performance of the first request.
// This is an asynchronous, fire-and-forget operation.
baseProvider.refreshModels().catch(err => {
  console.error('⚠️  Failed to pre-load GitHub Models catalog:', err.message);
});

/**
 * @const {object} githubModels
 * @description The singleton instance of the GitHub Models provider.
 */
export const githubModels = baseProvider;