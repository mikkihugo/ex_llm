import('./src/providers/github-models.ts').then(async (m) => {
  console.log('Available models in GITHUB_MODELS_FALLBACK:', m.GITHUB_MODELS_FALLBACK.map(m => m.id));
  try {
    const baseProvider = await import('./vendor/ai-sdk-provider-github-models/dist/index.js');
    console.log('Base provider keys:', Object.keys(baseProvider));
    if (baseProvider.githubModels && typeof baseProvider.githubModels === 'object') {
      console.log('Base provider has languageModels:', !!baseProvider.githubModels.languageModels);
    }
  } catch (e) {
    console.error('Error accessing base provider:', e.message);
  }
}).catch(e => console.error('Error:', e.message));
