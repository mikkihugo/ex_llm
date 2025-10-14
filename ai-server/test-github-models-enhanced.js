// Set GitHub token before importing provider
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

const tokenFile = join(homedir(), '.local', 'share', 'copilot-api', 'github_token');
if (existsSync(tokenFile)) {
  const token = readFileSync(tokenFile, 'utf-8').trim();
  process.env.GITHUB_TOKEN = token;
  console.log('✅ GitHub token set for GitHub Models');
} else {
  console.warn('⚠️  GitHub token file not found');
}

import { githubModels } from './src/providers/github-models.js';

async function testEnhancedGitHubModels() {
  console.log('🧪 Testing Enhanced GitHub Models Loading...\n');

  try {
    // Test 1: Ensure models are loaded
    console.log('📦 Step 1: Ensuring models are loaded...');
    await githubModels.ensureLoaded();
    console.log('✅ Models loading ensured\n');

    // Test 2: Check model metadata
    console.log('📊 Step 2: Checking model metadata...');
    const models = githubModels.getModelMetadata();
    console.log(`📊 Available GitHub Models: ${models.length}`);

    if (models.length > 0) {
      console.log('🎯 Top models:');
      models.slice(0, 5).forEach((model, index) => {
        console.log(`  ${index + 1}. ${model.id}: ${model.displayName || 'Unknown'}`);
      });
      console.log('✅ Model metadata loaded successfully\n');
    } else {
      console.log('❌ No models available\n');
      return;
    }

    // Test 3: Try model access
    console.log('🔧 Step 3: Testing model access...');
    const testModel = models[0].id;
    console.log(`🧪 Testing model access for: ${testModel}`);

    const model = githubModels.languageModel(testModel);
    if (model) {
      console.log('✅ Model instance created successfully');
      console.log('✅ GitHub Models provider is ready!\n');

      // Summary
      console.log('🎉 ENHANCED GITHUB MODELS STATUS:');
      console.log('✅ Token authentication: Working');
      console.log('✅ Model catalog loading: Working');
      console.log('✅ Model metadata access: Working');
      console.log('✅ Model instance creation: Working');
      console.log('⚠️  Text generation: May need provider fixes');
      console.log(`📊 Total models available: ${models.length}`);

    } else {
      console.log('❌ Model instance creation failed');
    }

  } catch (error) {
    console.log('❌ Error during enhanced testing:', error.message);
    console.log('💡 This may indicate API connectivity or authentication issues');
  }
}

testEnhancedGitHubModels();