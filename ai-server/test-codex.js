#!/usr/bin/env bun

/**
 * Codex Provider Test
 * Tests the OpenAI Codex provider functionality (Codex SDK only)
 */

import { codex } from './src/providers/codex.ts';

async function testCodexProvider() {
  console.log('🧪 Testing Codex Provider (Codex SDK only)...\n');

  try {
    // Step 1: Test model metadata
    console.log('📦 Step 1: Testing model metadata...');
    const metadata = codex.getModelMetadata();
    console.log(`✅ Found ${metadata.length} Codex models:`);
    metadata.forEach(model => {
      console.log(`  - ${model.id}: ${model.displayName}`);
    });

    if (metadata.length === 0) {
      console.log('❌ No models found');
      return;
    }

    // Step 2: Test text generation with Codex agent
    console.log('\n📝 Step 2: Testing text generation...');
    const codexAgentModel = metadata.find(m => m.id === 'codex-agent');
    if (!codexAgentModel) {
      console.log('❌ Codex agent model not found');
      return;
    }

    console.log(`Using model: ${codexAgentModel.id} (${codexAgentModel.displayName})`);

    const model = codex.languageModel(codexAgentModel.id);
    const result = await model.doGenerate({
      inputFormat: 'prompt',
      mode: { type: 'regular' },
      prompt: [{ role: 'user', content: 'Hello! Can you help me write a simple function to calculate fibonacci numbers in JavaScript?' }],
    });

    console.log('✅ Text generation successful!');
    console.log(`Response: ${result.text?.substring(0, 200)}...`);

    // Step 3: Test multiple models
    console.log('\n🔄 Step 3: Testing multiple models...');
    const modelsToTest = metadata; // Test all available models (only Codex agents now)
    for (const modelInfo of modelsToTest) {
      try {
        console.log(`Testing ${modelInfo.id}...`);
        const quickModel = codex.languageModel(modelInfo.id);
        const quickResult = await quickModel.doGenerate({
          inputFormat: 'prompt',
          mode: { type: 'regular' },
          prompt: [{ role: 'user', content: 'Write a one-line comment explaining what you are.' }],
        });
        console.log(`✅ ${modelInfo.id}: ${quickResult.text?.trim()}`);
      } catch (error) {
        console.log(`❌ ${modelInfo.id}: ${error.message}`);
      }
    }

    console.log('\n🎉 Codex provider test completed successfully!');

  } catch (error) {
    console.log(`❌ Test failed: ${error.message}`);
    console.log('Full error:', error);
  }
}

// Run the test
testCodexProvider();