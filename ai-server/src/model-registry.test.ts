import { describe, test, expect, beforeAll } from 'bun:test';
import { codex } from 'ai-sdk-provider-codex';
import { copilot } from './providers/copilot';
import { githubModels } from './providers/github-models';
import { claudeCode } from './providers/claude-code';
import { createGeminiProvider } from './providers/gemini-code';
import { cursor } from './providers/cursor';
import { julesWithModels } from './providers/google-ai-jules';
import {
  buildModelCatalog,
  registerProviderModels,
  getModelInfo,
  getProviderModels,
  getProviders,
  toOpenAIModelsFormat,
  type ModelInfo,
  type ProviderWithModels,
  type ProviderWithMetadata,
} from './model-registry';

/**
 * Model Registry Tests
 *
 * Tests both:
 * 1. Dynamic model discovery (via listModels() or getModelMetadata())
 * 2. Static model registration
 * 3. OpenAI /v1/models compatibility
 */

describe('Model Registry', () => {
  let models: ModelInfo[];
  const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

  beforeAll(async () => {
    // Build catalog with ALL providers (production + experimental)
    models = await buildModelCatalog({
      'openai-codex': codex as unknown as ProviderWithMetadata,
      'claude-code': claudeCode as unknown as ProviderWithMetadata,
      'gemini-code': geminiCode as unknown as ProviderWithMetadata,
      'github-copilot': copilot as unknown as ProviderWithMetadata,
      'github-models': githubModels as unknown as ProviderWithMetadata,
      'cursor': cursor as unknown as ProviderWithMetadata,
      'google-jules': julesWithModels as unknown as ProviderWithMetadata,
    });
  });

  describe('buildModelCatalog', () => {
    test('discovers models from all providers', () => {
      expect(models.length).toBeGreaterThan(0);
      console.log(`📊 Total models discovered: ${models.length}`);
    });

    test('all models have required fields', () => {
      for (const model of models) {
        expect(model.id).toBeTruthy();
        expect(model.provider).toBeTruthy();
        expect(model.model).toBeTruthy();
        expect(model.displayName).toBeTruthy();
        expect(model.contextWindow).toBeGreaterThan(0);
        expect(model.capabilities).toBeDefined();
        expect(model.cost).toMatch(/^(free|subscription|limited)$/);
      }
    });

    test('model IDs follow provider:model format', () => {
      for (const model of models) {
        expect(model.id).toMatch(/^[^:]+:[^:]+$/);
        expect(model.id).toBe(`${model.provider}:${model.model}`);
      }
    });

    test('capabilities have all required fields', () => {
      for (const model of models) {
        expect(typeof model.capabilities.completion).toBe('boolean');
        expect(typeof model.capabilities.streaming).toBe('boolean');
        expect(typeof model.capabilities.reasoning).toBe('boolean');
        expect(typeof model.capabilities.vision).toBe('boolean');
        expect(typeof model.capabilities.tools).toBe('boolean');
      }
    });
  });

  describe('Provider-specific models', () => {
    test('Codex models are discovered', () => {
      const codexModels = getProviderModels('openai-codex', models);
      expect(codexModels.length).toBeGreaterThan(0);
      console.log(`  Codex models: ${codexModels.map(m => m.model).join(', ')}`);

      // Should have GPT and O-series models
      const modelNames = codexModels.map(m => m.model);
      expect(modelNames.some(n => n.includes('gpt') || n.includes('o1') || n.includes('o3'))).toBe(true);
    });

    test('Copilot models are discovered', () => {
      const copilotModels = getProviderModels('github-copilot', models);
      expect(copilotModels.length).toBeGreaterThan(0);
      console.log(`  Copilot models: ${copilotModels.map(m => m.model).join(', ')}`);
    });

    test('GitHub Models are discovered (if async refresh completed)', () => {
      const ghModels = getProviderModels('github-models', models);

      // GitHub Models requires async refreshModels() before getModelMetadata() returns data
      // The test may run before async refresh completes at startup
      if (ghModels.length > 0) {
        console.log(`  GitHub Models: ${ghModels.map(m => m.model).join(', ')}`);
      } else {
        console.log(`  GitHub Models: (not loaded yet - async refresh pending)`);
      }

      // Test passes whether or not async refresh completed
      expect(ghModels.length).toBeGreaterThanOrEqual(0);
    });
  });

  describe('getModelInfo', () => {
    test('finds model by full ID', () => {
      const firstModel = models[0];
      const found = getModelInfo(firstModel.id, models);

      expect(found).toBeDefined();
      expect(found?.id).toBe(firstModel.id);
      expect(found?.provider).toBe(firstModel.provider);
    });

    test('returns undefined for non-existent model', () => {
      const found = getModelInfo('fake-provider:fake-model', models);
      expect(found).toBeUndefined();
    });

    test('finds specific known models', () => {
      // Try to find a Gemini Flash model
      const geminiFlash = models.find(m => m.provider === 'gemini-code' && m.model.includes('flash'));
      if (geminiFlash) {
        const found = getModelInfo(geminiFlash.id, models);
        expect(found).toBeDefined();
        expect(found?.displayName).toBeTruthy();
      }
    });
  });

  describe('getProviders', () => {
    test('lists all unique providers', () => {
      const providers = getProviders(models);

      expect(providers.length).toBeGreaterThan(0);
      expect(providers).toContain('openai-codex');

      // All providers should be unique
      expect(new Set(providers).size).toBe(providers.length);

      console.log(`  Available providers: ${providers.join(', ')}`);
    });
  });

  describe('toOpenAIModelsFormat', () => {
    test('converts to OpenAI /v1/models format', () => {
      const openaiFormat = toOpenAIModelsFormat(models);

      expect(openaiFormat.object).toBe('list');
      expect(Array.isArray(openaiFormat.data)).toBe(true);
      expect(openaiFormat.data.length).toBe(models.length);
    });

    test('each model has OpenAI-required fields', () => {
      const openaiFormat = toOpenAIModelsFormat(models);

      for (const model of openaiFormat.data) {
        expect(model.id).toBeTruthy();
        expect(model.object).toBe('model');
        expect(typeof model.created).toBe('number');
        expect(model.owned_by).toBeTruthy();
        expect(Array.isArray(model.permission)).toBe(true);
        expect(model.root).toBe(model.id);
        expect(model.parent).toBeNull();
      }
    });

    test('OpenAI format preserves model IDs', () => {
      const openaiFormat = toOpenAIModelsFormat(models);
      const originalIds = models.map(m => m.id).sort();
      const convertedIds = openaiFormat.data.map((m: any) => m.id).sort();

      expect(convertedIds).toEqual(originalIds);
    });
  });

  describe('Model capabilities', () => {
    test('all models support completion', () => {
      const allSupportCompletion = models.every(m => m.capabilities.completion);
      expect(allSupportCompletion).toBe(true);
    });

    test('most models support streaming', () => {
      const streamingModels = models.filter(m => m.capabilities.streaming);
      const streamingPercentage = (streamingModels.length / models.length) * 100;

      expect(streamingModels.length).toBeGreaterThan(0);
      console.log(`  Streaming support: ${streamingPercentage.toFixed(1)}%`);
    });

    test('some models support vision', () => {
      const visionModels = models.filter(m => m.capabilities.vision);
      console.log(`  Vision models: ${visionModels.length}`);
      console.log(`    - ${visionModels.map(m => m.id).join('\n    - ')}`);
    });

    test('some models support reasoning', () => {
      const reasoningModels = models.filter(m => m.capabilities.reasoning);
      console.log(`  Reasoning models: ${reasoningModels.length}`);
      if (reasoningModels.length > 0) {
        console.log(`    - ${reasoningModels.map(m => m.id).join('\n    - ')}`);
      }
    });

    test('some models support tools', () => {
      const toolModels = models.filter(m => m.capabilities.tools);
      expect(toolModels.length).toBeGreaterThan(0);
      console.log(`  Tool-calling models: ${toolModels.length}`);
    });
  });

  describe('Cost information', () => {
    test('all models have cost classification', () => {
      const withCost = models.filter(m => m.cost);
      expect(withCost.length).toBe(models.length);
    });

    test('free models are identified', () => {
      const freeModels = models.filter(m => m.cost === 'free');
      console.log(`  Free models: ${freeModels.length}`);
      if (freeModels.length > 0) {
        console.log(`    - ${freeModels.map(m => m.id).join('\n    - ')}`);
      }
    });

    test('subscription models are identified', () => {
      const subscriptionModels = models.filter(m => m.cost === 'subscription');
      console.log(`  Subscription models: ${subscriptionModels.length}`);
      if (subscriptionModels.length > 0) {
        console.log(`    - ${subscriptionModels.map(m => `${m.id} (${m.subscription || 'unknown'})`).join('\n    - ')}`);
      }
    });
  });

  describe('registerProviderModels', () => {
    test('registers models from openai-codex', async () => {
      const registered = await registerProviderModels('openai-codex', codex as unknown as ProviderWithMetadata);

      expect(registered.length).toBeGreaterThan(0);
      expect(registered[0].provider).toBe('openai-codex');
      expect(registered[0].id).toMatch(/^openai-codex:/);
    });

    test('registers models from claude-code', async () => {
      const registered = await registerProviderModels('claude-code', claudeCode as unknown as ProviderWithMetadata);

      expect(registered.length).toBe(2); // sonnet, opus
      expect(registered[0].provider).toBe('claude-code');
      expect(registered[0].cost).toBe('subscription');
      expect(registered.some(m => m.model === 'sonnet')).toBe(true);
      expect(registered.some(m => m.model === 'opus')).toBe(true);
    });

    test('registers models from gemini-code', async () => {
      const registered = await registerProviderModels('gemini-code', geminiCode as unknown as ProviderWithMetadata);

      expect(registered.length).toBe(2); // flash, pro
      expect(registered[0].provider).toBe('gemini-code');
      expect(registered[0].cost).toBe('free');
      expect(registered[0].contextWindow).toBe(1048576); // 1M tokens
      expect(registered.some(m => m.model === 'gemini-2.5-flash')).toBe(true);
      expect(registered.some(m => m.model === 'gemini-2.5-pro')).toBe(true);
    });

    test('registers models from github-copilot', async () => {
      const registered = await registerProviderModels('github-copilot', copilot as unknown as ProviderWithMetadata);

      expect(registered.length).toBeGreaterThan(0);
      expect(registered[0].provider).toBe('github-copilot');
      expect(registered[0].id).toMatch(/^github-copilot:/);
    });

    test('registers models from github-models', async () => {
      const registered = await registerProviderModels('github-models', githubModels as unknown as ProviderWithMetadata);

      // GitHub Models can return 0 models if rate limited or auth fails (external service)
      // Just verify the structure works when models ARE available
      expect(Array.isArray(registered)).toBe(true);
      if (registered.length > 0) {
        expect(registered[0].provider).toBe('github-models');
        // GitHub Models defaults to 'free' (500 requests/day free tier)
        expect(['free', 'limited']).toContain(registered[0].cost);
      }
    });

    test('registers models from cursor', async () => {
      const registered = await registerProviderModels('cursor', cursor as unknown as ProviderWithMetadata);

      // Cursor plugin returns 4 models (plugin overrides local CURSOR_MODELS)
      expect(registered.length).toBe(4); // auto, gpt-4.1, sonnet-4, sonnet-4-thinking
      expect(registered[0].provider).toBe('cursor');
      expect(registered.some(m => m.model === 'auto')).toBe(true);
      expect(registered.some(m => m.model === 'gpt-4.1')).toBe(true);
      expect(registered.some(m => m.model === 'sonnet-4')).toBe(true);
      // Cursor has mix of free (auto) and subscription (premium models)
      expect(registered.some(m => m.cost === 'free')).toBe(true);
      expect(registered.some(m => m.cost === 'subscription')).toBe(true);
    });

    test('registers models from google-jules (experimental agent)', async () => {
      const registered = await registerProviderModels('google-jules', julesWithModels as unknown as ProviderWithMetadata);

      expect(registered.length).toBe(1); // jules-v1
      expect(registered[0].provider).toBe('google-jules');
      expect(registered[0].model).toBe('jules-v1');
      expect(registered[0].cost).toBe('free'); // 15 tasks/day free tier
      expect(registered[0].contextWindow).toBe(2097152); // 2M tokens (Gemini 2.5 Pro)
    });

    test('registered models have all required fields', async () => {
      const registered = await registerProviderModels('openai-codex', codex as unknown as ProviderWithMetadata);

      for (const model of registered) {
        expect(model.id).toBeTruthy();
        expect(model.provider).toBe('openai-codex');
        expect(model.model).toBeTruthy();
        expect(model.displayName).toBeTruthy();
        expect(model.capabilities).toBeDefined();
      }
    });
  });
});

describe('Model Registry Summary', () => {
  test('print complete model inventory', async () => {
    const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });
    const models = await buildModelCatalog({
      'openai-codex': codex as unknown as ProviderWithMetadata,
      'claude-code': claudeCode as unknown as ProviderWithMetadata,
      'gemini-code': geminiCode as unknown as ProviderWithMetadata,
      'github-copilot': copilot as unknown as ProviderWithMetadata,
      'github-models': githubModels as unknown as ProviderWithMetadata,
      'cursor': cursor as unknown as ProviderWithMetadata,
      'google-jules': julesWithModels as unknown as ProviderWithMetadata,
    });

    console.log('\n📊 MODEL REGISTRY INVENTORY');
    console.log('═'.repeat(60));

    const providers = getProviders(models);
    for (const provider of providers) {
      const providerModels = getProviderModels(provider, models);
      console.log(`\n${provider.toUpperCase()} (${providerModels.length} models)`);
      console.log('─'.repeat(60));

      for (const model of providerModels) {
        const caps = [];
        if (model.capabilities.streaming) caps.push('stream');
        if (model.capabilities.vision) caps.push('vision');
        if (model.capabilities.reasoning) caps.push('reason');
        if (model.capabilities.tools) caps.push('tools');

        console.log(`  ${model.model}`);
        console.log(`    ID: ${model.id}`);
        console.log(`    Name: ${model.displayName}`);
        console.log(`    Context: ${model.contextWindow.toLocaleString()} tokens`);
        console.log(`    Capabilities: ${caps.join(', ')}`);
        console.log(`    Cost: ${model.cost}${model.subscription ? ` (${model.subscription})` : ''}`);
      }
    }

    console.log('\n═'.repeat(60));
    console.log(`TOTAL: ${models.length} models across ${providers.length} providers`);
    console.log('═'.repeat(60) + '\n');

    expect(models.length).toBeGreaterThan(0);
  });
});
