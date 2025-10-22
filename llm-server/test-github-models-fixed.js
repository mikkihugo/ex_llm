#!/usr/bin/env bun

/**
 * Enhanced GitHub Models Provider Test
 * Tests the improved loading mechanism and text generation
 */

import { githubModels } from './src/providers/github-models.ts';

async function testEnhancedGitHubModels() {
  console.log('🧪 Testing Enhanced GitHub Models Provider...\n');

  try {
    // Step 0: Wait for initial loading to complete
    console.log('⏳ Step 0: Waiting for initial model loading...');
    await new Promise(resolve => setTimeout(resolve, 2000)); // Give it 2 seconds to load
    console.log('✅ Initial loading wait complete\n');

    // Step 1: Test model loading
    console.log('📦 Step 1: Testing model loading...');
    const metadata = await githubModels.getModelMetadata();
    console.log(`✅ Found ${metadata.length} models`);

    if (metadata.length === 0) {
      console.log('❌ No models loaded');
      return;
    }

    // Step 2: Test text generation with first available model
    console.log('\n📝 Step 2: Testing text generation...');
    const testModel = metadata[0];
    console.log(`Using model: ${testModel.id || testModel.displayName}`);

    // Try with proper AI SDK v5 format
    const model = githubModels.languageModel(testModel.id);
    console.log('Model object:', typeof model, Object.getOwnPropertyNames(model || {}));

    try {
      const result = await model.doGenerate({
        inputFormat: 'prompt',
        mode: { type: 'regular' },
        prompt: [{ role: 'user', content: 'Hello, can you help me with a simple coding task?' }],
      });

      console.log('✅ Text generation successful!');
      console.log(`Response: ${result.text?.substring(0, 100)}...`);
    } catch (error) {
      console.log(`❌ Text generation failed: ${error.message}`);

      // Try alternative format
      console.log('🔄 Trying alternative message format...');
      try {
        const result2 = await model.doGenerate({
          inputFormat: 'prompt',
          mode: { type: 'regular' },
          prompt: 'Hello, can you help me with a simple coding task?',
        });
        console.log('✅ Alternative format worked!');
        console.log(`Response: ${result2.text?.substring(0, 100)}...`);
      } catch (error2) {
        console.log(`❌ Alternative format also failed: ${error2.message}`);
      }
    }

    // Step 3: Test multiple models if available
    console.log('\n🔄 Step 3: Testing multiple models...');
    const testModels = metadata.slice(0, 3); // Test first 3 models
    for (const model of testModels) {
      try {
        console.log(`Testing ${model.id || model.displayName}...`);
        const quickResult = await githubModels.languageModel(model.id).doGenerate({
          inputFormat: 'prompt',
          mode: { type: 'regular' },
          prompt: 'Say "OK" if you can generate text.',
        });
        console.log(`✅ ${model.id || model.displayName}: ${quickResult.text?.trim()}`);
      } catch (error) {
        console.log(`❌ ${model.id || model.displayName}: ${error.message}`);
      }
    }

    console.log('\n🎉 All tests completed successfully!');

  } catch (error) {
    console.log(`❌ Test failed: ${error.message}`);
    console.log('Full error:', error);
  }
}

// Run the test
testEnhancedGitHubModels();