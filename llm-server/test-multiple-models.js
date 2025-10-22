import { githubModels } from './src/providers/github-models.ts';

async function testMultipleModels() {
  try {
    console.log('Testing multiple GitHub Models...');

    // Refresh models first
    await githubModels.refreshModels();
    console.log('✅ Models refreshed');

    const modelsToTest = [
      'openai/gpt-4o-mini',
      'openai/gpt-4o',
      'meta/llama-3.2-90b-vision-instruct'
    ];

    for (const modelId of modelsToTest) {
      try {
        console.log(`\n🧪 Testing ${modelId}...`);

        const model = githubModels.languageModel(modelId);
        if (!model) {
          console.log(`❌ Model ${modelId} not found`);
          continue;
        }

        const result = await model.doGenerate({
          inputFormat: 'messages',
          mode: { type: 'regular' },
          prompt: [
            { role: 'user', content: `Say hello in one word as ${modelId}.` }
          ]
        });

        console.log(`✅ ${modelId}: ${result.text}`);

      } catch (error) {
        console.log(`❌ ${modelId} failed: ${error.message}`);
      }
    }

    console.log('\n🎉 Multi-model test complete!');

  } catch (error) {
    console.error('❌ Multi-model test failed:', error.message);
  }
}

testMultipleModels();