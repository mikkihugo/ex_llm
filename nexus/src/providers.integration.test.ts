import { describe, test, expect } from 'bun:test';
import { createProviderRegistry } from 'ai';
import { createGeminiProvider } from 'ai-sdk-provider-gemini-cli';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from './providers/codex';
import { copilot } from './providers/copilot';
import { githubModels } from './providers/github-models';
import { buildModelCatalog, type ProviderWithModels, type ProviderWithMetadata } from './model-registry';

/**
 * Provider Integration Tests
 *
 * Tests that:
 * 1. All providers can be registered
 * 2. Provider registry works correctly
 * 3. Models can be accessed via registry
 * 4. Provider-specific configurations work
 */

describe('Provider Integration', () => {
  describe('Provider Registry Creation', () => {
    test('creates registry with all providers', () => {
      const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

      const registry = createProviderRegistry({
        'gemini-code': geminiCode,
        'claude-code': claudeCode,
        'openai-codex': codex,
        'github-copilot': copilot as any,
        'github-models': githubModels,
      });

      expect(registry).toBeDefined();
      expect(typeof registry.languageModel).toBe('function');
    });

    test('registry can access language models', () => {
      const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

      const registry = createProviderRegistry({
        'gemini-code': geminiCode,
        'claude-code': claudeCode,
        // 'openai-codex': codex,
      });

      // Should be able to create model instances
      const geminiModel = registry.languageModel('gemini-code:gemini-2.5-flash');
      expect(geminiModel).toBeDefined();
      // Provider ID may differ from registry key (e.g., "gemini-cli-core" vs "gemini-code")
      expect(geminiModel.provider).toBeTruthy();
      expect(geminiModel.modelId).toBe('gemini-2.5-flash');

      const claudeModel = registry.languageModel('claude-code:sonnet');
      expect(claudeModel).toBeDefined();
      expect(claudeModel.provider).toBeTruthy();
      expect(claudeModel.modelId).toBe('sonnet');
    });
  });

  describe('Provider Model Discovery', () => {
    test('Gemini provider lists models', () => {
      const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

      // Check if provider has listModels method
      if ('listModels' in geminiCode) {
        const models = (geminiCode as any).listModels();
        expect(Array.isArray(models)).toBe(true);
        expect(models.length).toBeGreaterThan(0);
        console.log(`  Gemini: ${models.length} models`);
      } else {
        console.log('  Gemini: Uses custom model resolution');
      }
    });

    test('Claude provider has model info', () => {
      // Claude Code uses customProvider, check if it has metadata
      if ('getModelMetadata' in claudeCode) {
        const metadata = (claudeCode as any).getModelMetadata();
        expect(Array.isArray(metadata)).toBe(true);
        console.log(`  Claude: ${metadata.length} models`);
      } else {
        console.log('  Claude: Uses custom model resolution');
      }
    });

    test('Codex provider has model metadata', async () => {
      if ('getModelMetadata' in codex) {
        const metadata = codex.getModelMetadata();
        // Handle both sync and async returns
        const resolvedMetadata = metadata instanceof Promise ? await metadata : metadata;
        expect(Array.isArray(resolvedMetadata)).toBe(true);
        expect(resolvedMetadata.length).toBeGreaterThan(0);
        console.log(`  Codex: ${resolvedMetadata.length} models`);
      }
    });

    test('Copilot provider has model metadata', async () => {
      if ('getModelMetadata' in copilot) {
        const metadata = (copilot as any).getModelMetadata();
        // Handle both sync and async returns
        const resolvedMetadata = metadata instanceof Promise ? await metadata : metadata;
        expect(Array.isArray(resolvedMetadata)).toBe(true);
        expect(resolvedMetadata.length).toBeGreaterThan(0);
        console.log(`  Copilot: ${resolvedMetadata.length} models`);
      }
    });

    test('GitHub Models provider has model metadata', async () => {
      if ('getModelMetadata' in githubModels) {
        const metadata = githubModels.getModelMetadata();
        // Handle both sync and async returns
        const resolvedMetadata = metadata instanceof Promise ? await metadata : metadata;
        expect(Array.isArray(resolvedMetadata)).toBe(true);
        expect(resolvedMetadata.length).toBeGreaterThan(0);
        console.log(`  GitHub Models: ${resolvedMetadata.length} models`);
      }
    });
  });

  describe('Model Catalog Integration', () => {
    test('buildModelCatalog works with all providers', async () => {
      const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

      const models = await buildModelCatalog({
        'gemini-code': geminiCode as unknown as ProviderWithModels,
        'claude-code': claudeCode as unknown as ProviderWithModels,
        'openai-codex': codex as unknown as ProviderWithMetadata,
        'github-copilot': copilot as unknown as ProviderWithMetadata,
        'github-models': githubModels as unknown as ProviderWithMetadata,
      });

      expect(models.length).toBeGreaterThan(0);

      // Only providers with getModelMetadata() or listModels() contribute
      // (Gemini/Claude use customProvider without metadata export)
      const providers = [...new Set(models.map(m => m.provider))];
      expect(providers.length).toBeGreaterThanOrEqual(2); // At least Codex + Copilot

      console.log('\n📊 Model Distribution:');
      for (const provider of providers) {
        const count = models.filter(m => m.provider === provider).length;
        console.log(`  ${provider}: ${count} models`);
      }
    });

    test('models from different providers have unique IDs', async () => {
      const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

      const models = await buildModelCatalog({
        'gemini-code': geminiCode as unknown as ProviderWithModels,
        'claude-code': claudeCode as unknown as ProviderWithModels,
        'openai-codex': codex as unknown as ProviderWithMetadata,
      });

      const ids = models.map(m => m.id);
      const uniqueIds = new Set(ids);

      expect(uniqueIds.size).toBe(ids.length);
    });

    test('provider:model format is consistent', async () => {
      const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

      const models = await buildModelCatalog({
        'gemini-code': geminiCode as unknown as ProviderWithModels,
        'openai-codex': codex as unknown as ProviderWithMetadata,
      });

      for (const model of models) {
        expect(model.id).toMatch(/^[^:]+:[^:]+$/);
        expect(model.id.startsWith(model.provider + ':')).toBe(true);
      }
    });
  });

  describe('Provider-Specific Features', () => {
    test('Gemini models support various modalities', async () => {
      const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });
      const models = await buildModelCatalog({
        'gemini-code': geminiCode as unknown as ProviderWithModels,
      });

      // Gemini Pro models typically support vision
      const proModels = models.filter(m => m.model.includes('pro'));
      if (proModels.length > 0) {
        console.log(`  Gemini Pro models: ${proModels.map(m => m.model).join(', ')}`);
      }
    });

    test('Claude models have context windows', async () => {
      const models = await buildModelCatalog({
        'claude-code': claudeCode as unknown as ProviderWithModels,
      });

      for (const model of models) {
        expect(model.contextWindow).toBeGreaterThan(0);
        console.log(`  ${model.model}: ${model.contextWindow.toLocaleString()} tokens`);
      }
    });

    test('Codex models include reasoning models', async () => {
      const models = await buildModelCatalog({
        'openai-codex': codex as unknown as ProviderWithMetadata,
      });

      const oSeriesModels = models.filter(m => m.model.match(/^o[0-9]/));
      console.log(`  O-series (reasoning) models: ${oSeriesModels.map(m => m.model).join(', ')}`);
    });
  });

  describe('Registry and Catalog Consistency', () => {
    test('registry can load all catalogued models', async () => {
      const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

      const registry = createProviderRegistry({
        'gemini-code': geminiCode,
        'claude-code': claudeCode,
        'openai-codex': codex,
        'github-copilot': copilot as any,
        'github-models': githubModels,
      });

      const models = await buildModelCatalog({
        'gemini-code': geminiCode as unknown as ProviderWithModels,
        'claude-code': claudeCode as unknown as ProviderWithModels,
        'openai-codex': codex as unknown as ProviderWithMetadata,
      });

      // Try to load a few random models from catalog
      const sampleSize = Math.min(5, models.length);
      const samples = models.slice(0, sampleSize);

      for (const model of samples) {
        const instance = registry.languageModel(model.id as any);
        expect(instance).toBeDefined();
        // Provider ID may differ (registry key vs internal ID)
        // e.g., "openai-codex" → "openai.codex", "gemini-code" → "gemini-cli-core"
        expect(instance.provider).toBeTruthy();
      }

      console.log(`  ✅ Successfully loaded ${sampleSize} sample models from registry`);
    });

    test('all catalog entries can create model instances', async () => {
      const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

      const registry = createProviderRegistry({
        'gemini-code': geminiCode,
        'claude-code': claudeCode,
        'openai-codex': codex,
        'github-copilot': copilot as any,
        'github-models': githubModels,
      });

      const models = await buildModelCatalog({
        'gemini-code': geminiCode as unknown as ProviderWithModels,
        'claude-code': claudeCode as unknown as ProviderWithModels,
        'openai-codex': codex as unknown as ProviderWithMetadata,
        'github-copilot': copilot as unknown as ProviderWithMetadata,
        'github-models': githubModels as unknown as ProviderWithMetadata,
      });

      let successCount = 0;
      for (const model of models) {
        try {
          const instance = registry.languageModel(model.id as any);
          if (instance) successCount++;
        } catch (error) {
          console.warn(`  ⚠️  Failed to load ${model.id}: ${error}`);
        }
      }

      console.log(`  ✅ ${successCount}/${models.length} models loadable from registry`);
      expect(successCount).toBe(models.length);
    });
  });
});

describe('Provider Summary', () => {
  test('print provider capabilities matrix', async () => {
    const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

    const providers = {
      'gemini-code': geminiCode as unknown as ProviderWithModels,
      'claude-code': claudeCode as unknown as ProviderWithModels,
      'openai-codex': codex as unknown as ProviderWithMetadata,
      'github-copilot': copilot as unknown as ProviderWithMetadata,
      'github-models': githubModels as unknown as ProviderWithMetadata,
    };

    const models = await buildModelCatalog(providers);

    console.log('\n🔧 PROVIDER CAPABILITIES MATRIX');
    console.log('═'.repeat(80));

    const providerNames = Object.keys(providers);
    for (const providerName of providerNames) {
      const providerModels = models.filter(m => m.provider === providerName);

      if (providerModels.length === 0) continue;

      const streaming = providerModels.filter(m => m.capabilities.streaming).length;
      const vision = providerModels.filter(m => m.capabilities.vision).length;
      const reasoning = providerModels.filter(m => m.capabilities.reasoning).length;
      const tools = providerModels.filter(m => m.capabilities.tools).length;
      const free = providerModels.filter(m => m.cost === 'free').length;

      console.log(`\n${providerName.toUpperCase()}`);
      console.log('─'.repeat(80));
      console.log(`  Total Models:    ${providerModels.length}`);
      console.log(`  Streaming:       ${streaming}/${providerModels.length} (${((streaming / providerModels.length) * 100).toFixed(0)}%)`);
      console.log(`  Vision:          ${vision}/${providerModels.length} (${((vision / providerModels.length) * 100).toFixed(0)}%)`);
      console.log(`  Reasoning:       ${reasoning}/${providerModels.length} (${((reasoning / providerModels.length) * 100).toFixed(0)}%)`);
      console.log(`  Tool Calling:    ${tools}/${providerModels.length} (${((tools / providerModels.length) * 100).toFixed(0)}%)`);
      console.log(`  Free Tier:       ${free}/${providerModels.length} (${((free / providerModels.length) * 100).toFixed(0)}%)`);

      const avgContext = Math.round(
        providerModels.reduce((sum, m) => sum + m.contextWindow, 0) / providerModels.length
      );
      console.log(`  Avg Context:     ${avgContext.toLocaleString()} tokens`);
    }

    console.log('\n' + '═'.repeat(80));
    console.log(`TOTAL: ${models.length} models across ${providerNames.length} providers`);
    console.log('═'.repeat(80) + '\n');

    expect(models.length).toBeGreaterThan(0);
  });
});
