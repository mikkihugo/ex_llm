/**
 * AI Server Integration for Addon Template System
 *
 * Shows how to integrate the addon registry into the main AI server.
 * This replaces individual provider handlers with dynamic addon loading.
 */

import { addonRegistry, setupCommonAddons } from './addon-registry';
import { AIResponse } from './ai-addon-template';

// Initialize addons when server starts
export async function initializeAIAddons(): Promise<void> {
  console.log('🚀 Initializing AI Addon System...');

  // Setup built-in addons
  await setupCommonAddons();

  // Load additional addons from config (if available)
  try {
    await addonRegistry.loadFromConfig();
  } catch (error) {
    console.warn('⚠️  Could not load addon config, using built-in addons only');
  }

  // Validate all addon authentication
  const authResults = await addonRegistry.validateAllAuth();
  const validCount = Array.from(authResults.values()).filter(Boolean).length;
  const totalCount = authResults.size;

  console.log(`✅ Initialized ${validCount}/${totalCount} AI addons`);

  // Log available models
  const addons = addonRegistry.listAddons();
  console.log('\n📋 Available AI Providers:');
  addons.forEach(addon => {
    const authStatus = authResults.get(addon.provider) ? '🟢' : '🔴';
    console.log(`  ${authStatus} ${addon.name} (${addon.provider})`);
    addon.models.forEach(model => {
      console.log(`    └─ ${model.id} (${model.contextWindow} tokens)`);
    });
  });
}

// Unified chat handler using addon registry
export async function handleAddonChat(
  provider: string,
  messages: any[],
  options: any = {}
): Promise<AIResponse> {
  try {
    const response = await addonRegistry.chat(provider, messages, options);
    return response;
  } catch (error) {
    throw new Error(`Addon chat failed for ${provider}: ${error.message}`);
  }
}

// Streaming handler (if addon supports it)
export async function handleAddonStream(
  provider: string,
  messages: any[],
  options: any = {}
): Promise<AsyncIterable<AIResponse>> {
  try {
    return addonRegistry.stream(provider, messages, options);
  } catch (error) {
    throw new Error(`Streaming not supported for ${provider}: ${error.message}`);
  }
}

// Health check for addons
export async function checkAddonHealth(): Promise<any> {
  const authResults = await addonRegistry.validateAllAuth();
  const addons = addonRegistry.listAddons();

  return {
    status: 'healthy',
    addons: addons.map(addon => ({
      name: addon.name,
      provider: addon.provider,
      authenticated: authResults.get(addon.provider) || false,
      models: addon.models.length,
      capabilities: addon.capabilities
    }))
  };
}

// Model catalog from addons
export function getAddonModels(): any[] {
  const addons = addonRegistry.listAddons();
  const models: any[] = [];

  addons.forEach(addon => {
    addon.models.forEach(model => {
      models.push({
        id: model.id,
        object: 'model',
        created: Date.now() / 1000,
        owned_by: addon.provider,
        context_window: model.contextWindow,
        capabilities: addon.capabilities,
        provider: addon.provider,
        upstream_id: model.id,
        description: `${addon.name} - ${model.name}`,
        name: model.name
      });
    });
  });

  return models;
}

// Example server integration
export function integrateWithServer() {
  // This would be called from your main server.ts file

  // Initialize addons on server start
  initializeAIAddons().catch(console.error);

  // Example route handlers
  const addonRoutes = {
    // Chat endpoint
    '/v1/chat/completions': async (request: any) => {
      const { provider, messages, ...options } = request;
      return await handleAddonChat(provider, messages, options);
    },

    // Models endpoint
    '/v1/models': () => ({
      object: 'list',
      data: getAddonModels()
    }),

    // Health endpoint
    '/health': async () => await checkAddonHealth()
  };

  return addonRoutes;
}

// Export everything needed for server integration
export {
  addonRegistry,
  type AIResponse
};