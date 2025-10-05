/**
 * Example Usage of AI Addon Template System
 *
 * Demonstrates how to use the addon registry and individual addons.
 */

import { addonRegistry, setupCommonAddons } from './addon-registry';
import { githubModelsAddon } from './github-models-addon';

async function main() {
  console.log('🚀 AI Addon Template System Demo\n');

  // Setup common addons (GitHub Models)
  console.log('📦 Setting up addons...');
  await setupCommonAddons();

  // List all registered addons
  console.log('\n📋 Registered Addons:');
  const addons = addonRegistry.listAddons();
  addons.forEach(addon => {
    console.log(`  • ${addon.name} (${addon.provider}) - ${addon.models.length} models`);
  });

  // Validate authentication
  console.log('\n🔐 Validating authentication...');
  const authResults = await addonRegistry.validateAllAuth();
  authResults.forEach((isValid, provider) => {
    const status = isValid ? '✅' : '❌';
    console.log(`  ${status} ${provider}`);
  });

  // Test GitHub Models directly
  console.log('\n🧪 Testing GitHub Models...');
  try {
    const testMessages = [
      { role: 'user', content: 'Hello! Can you tell me about AI addon templates?' }
    ];

    const response = await githubModelsAddon.chat(testMessages, {
      model: 'gpt-4o-mini',
      temperature: 0.7
    });

    console.log('✅ GitHub Models Response:');
    console.log(`   Model: ${response.model}`);
    console.log(`   Tokens: ${response.usage.totalTokens}`);
    console.log(`   Response: ${response.text.substring(0, 100)}...`);

  } catch (error) {
    console.log('❌ GitHub Models test failed:', error.message);
  }

  // Test GitHub Copilot API
  console.log('\n🧪 Testing GitHub Copilot API...');
  try {
    const { copilotAPIAddon } = await import('./copilot-addon');

    const copilotResponse = await copilotAPIAddon.chat([
      { role: 'user', content: 'What are the benefits of AI addon templates?' }
    ], {
      model: 'copilot-gpt-4.1'
    });

    console.log('✅ Copilot API Response:');
    console.log(`   Model: ${copilotResponse.model}`);
    console.log(`   Tokens: ${copilotResponse.usage.totalTokens}`);
    console.log(`   Response: ${copilotResponse.text.substring(0, 100)}...`);

  } catch (error) {
    console.log('❌ Copilot API test failed:', error.message);
  }

  // Test via registry
  console.log('\n🎯 Testing via addon registry...');
  try {
    const response = await addonRegistry.chat('github-models', [
      { role: 'user', content: 'What is the benefit of AI addon templates?' }
    ], { model: 'gpt-4o-mini' });

    console.log('✅ Registry Response:');
    console.log(`   Response: ${response.text.substring(0, 100)}...`);

  } catch (error) {
    console.log('❌ Registry test failed:', error.message);
  }

  // Show registry statistics
  console.log('\n📊 Registry Statistics:');
  const stats = addonRegistry.getStats();
  console.log(`   Total Addons: ${stats.totalAddons}`);
  console.log(`   Providers: ${stats.providers.join(', ')}`);
  console.log('   Models per Provider:');
  Object.entries(stats.models).forEach(([provider, models]) => {
    console.log(`     ${provider}: ${models.join(', ')}`);
  });

  console.log('\n🎉 Demo complete!');
}

// Run the demo
if (import.meta.main) {
  main().catch(console.error);
}

export { main as runAddonDemo };