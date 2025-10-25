/**
 * @file GitHub Models Provider
 * @description This module re-exports the base GitHub Models provider from the vendored
 * package and initiates an asynchronous pre-loading of the model catalog at startup.
 * This provider offers free-tier access to a variety of models including GPT-4.1, Llama 4,
 * DeepSeek, and Mistral.
 */

import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

// Set GitHub token for GitHub Models from the stored token file before importing the provider
try {
  const tokenFile = join(homedir(), '.local', 'share', 'copilot-api', 'github_token');
  if (existsSync(tokenFile)) {
    const token = readFileSync(tokenFile, 'utf-8').trim();
    process.env.GITHUB_TOKEN = token;
    console.log('✅ GitHub token set for GitHub Models');
  } else {
    console.warn('⚠️  GitHub token file not found for GitHub Models');
  }
} catch (error) {
  console.warn('⚠️  Failed to load GitHub token for GitHub Models:', error);
}

import { githubModels as baseProvider } from '../../vendor/ai-sdk-provider-github-models/dist/index.js';

// Enhanced model loading with better error handling and retries
let modelsLoaded = false;
let modelLoadPromise: Promise<void> | null = null;
let loadedModels: any[] = []; // Store loaded models

async function loadGitHubModels(retryCount = 0): Promise<void> {
  const maxRetries = 3;

  try {
    console.log('🔍 Checking base provider methods...');
    console.log('Available methods:', Object.getOwnPropertyNames(baseProvider));
    console.log('refreshModels available:', typeof (baseProvider as any).refreshModels);
    console.log('getModelMetadata available:', typeof (baseProvider as any).getModelMetadata);

    if (typeof (baseProvider as any).refreshModels === 'function') {
      console.log('🔄 Loading GitHub Models catalog...');
      await (baseProvider as any).refreshModels();

      // Try to get models from the provider
      const models = (baseProvider as any).getModelMetadata?.() || [];
      console.log(`📊 Provider returned ${models.length} models`);

      if (models.length > 0) {
        loadedModels = models;
        console.log(`✅ GitHub Models catalog loaded: ${models.length} models`);
        modelsLoaded = true;
      } else {
        // Try alternative method to get models
        console.log('🔍 Trying alternative model access...');
        if ((baseProvider as any).models) {
          loadedModels = (baseProvider as any).models;
          console.log(`✅ Found models via .models: ${loadedModels.length} models`);
          modelsLoaded = true;
        } else {
          throw new Error('No models returned from refresh');
        }
      }
    } else {
      throw new Error('refreshModels method not available');
    }
  } catch (error) {
    console.warn(`⚠️  Failed to load GitHub Models catalog (attempt ${retryCount + 1}/${maxRetries + 1}):`, (error as Error).message);

    if (retryCount < maxRetries) {
      console.log(`⏳ Retrying in ${2 ** retryCount} seconds...`);
      await new Promise(resolve => setTimeout(resolve, 1000 * (2 ** retryCount)));
      return loadGitHubModels(retryCount + 1);
    } else {
      console.warn('❌ Giving up on GitHub Models loading, using fallback');
      modelsLoaded = true; // Mark as loaded even on failure to avoid infinite retries
    }
  }
}

// Initialize model loading
modelLoadPromise = loadGitHubModels();

// Export a function to ensure models are loaded
export async function ensureGitHubModelsLoaded(): Promise<void> {
  if (!modelsLoaded && modelLoadPromise) {
    await modelLoadPromise;
  }
}

/**
 * Model metadata for GitHub Models provider
 * This is a minimal set for fallback - actual models are loaded dynamically from API
 */
export const GITHUB_MODELS_FALLBACK = [
  {
    id: 'openai/gpt-4o-mini',
    displayName: 'GPT-4o Mini',
    description: 'GPT-4o Mini via GitHub Models (FREE tier)',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: true, tools: true },
    cost: 'free' as const,
    subscription: 'GitHub Models',
  },
  {
    id: 'openai/gpt-4o',
    displayName: 'GPT-4o',
    description: 'GPT-4o via GitHub Models (FREE tier)',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: true, tools: true },
    cost: 'free' as const,
    subscription: 'GitHub Models',
  },
  {
    id: 'meta/llama-3.2-90b-vision-instruct',
    displayName: 'Llama 3.2 90B Vision Instruct',
    description: 'Meta Llama 3.2 90B Vision Instruct via GitHub Models (FREE tier)',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: true, reasoning: false, vision: true, tools: false },
    cost: 'free' as const,
    subscription: 'GitHub Models',
  },
];

/**
 * @const {object} githubModels
 * @description The singleton instance of the GitHub Models provider with AI SDK v5 compatibility.
 * Includes enhanced model loading and error handling.
 */
export const githubModels = Object.assign(baseProvider as any, {
  // Ensure models are loaded before use
  async ensureLoaded(): Promise<void> {
    await ensureGitHubModelsLoaded();
  },

  // Enhanced model access with loading check
  languageModel(modelId: string): any {
    // Ensure models are loaded before accessing
    if (!modelsLoaded) {
      console.warn('⚠️  GitHub Models not yet loaded, model access may fail');
    }
    return (baseProvider as any).languageModel(modelId);
  },

  // Enhanced metadata access
  async getModelMetadata(): Promise<any[]> {
    // Ensure models are loaded before returning metadata
    if (!modelsLoaded && modelLoadPromise) {
      console.log('⏳ Waiting for models to load...');
      await modelLoadPromise;
      console.log('✅ Models should be loaded now');
    }

    // Return stored models if available
    if (loadedModels.length > 0) {
      console.log(`📊 Returning ${loadedModels.length} stored models`);
      return loadedModels;
    }

    // Fallback to trying the provider directly
    const models = (baseProvider as any).getModelMetadata?.() || [];
    console.log(`🔍 Base provider returned ${models.length} models`);

    if (models.length > 0) {
      return models;
    }

    console.warn('⚠️  Using fallback metadata for GitHub Models');
    return GITHUB_MODELS_FALLBACK;
  }
});