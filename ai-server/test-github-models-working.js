#!/usr/bin/env bun

/**
 * GitHub Models Provider - Working Test
 * Demonstrates that the enhanced loading and text generation is now working
 */

import { githubModels } from './src/providers/github-models.ts';

async function testGitHubModelsWorking() {
  console.log('🎉 Testing GitHub Models Provider (Working Version)\n');

  try {
    // Wait for loading
    console.log('⏳ Waiting for models to load...');
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Get models
    const metadata = await githubModels.getModelMetadata();
    console.log(`✅ Successfully loaded ${metadata.length} models`);

    // Test text generation with proper format
    console.log('\n🤖 Testing text generation...');
    const model = githubModels.languageModel('openai/gpt-4o-mini');

    const result = await model.doGenerate({
      inputFormat: 'prompt',
      mode: { type: 'regular' },
      prompt: [{ role: 'user', content: 'Say hello and confirm you are working!' }],
    });

    console.log('✅ Text generation successful!');
    console.log(`Response: ${result.text}`);
    console.log('\n🎊 GitHub Models provider is fully working!');

  } catch (error) {
    console.log(`❌ Test failed: ${error.message}`);
  }
}

// Run the test
testGitHubModelsWorking();