import { openai } from '@ai-sdk/openai';

// Create a custom GitHub Models provider using OpenAI-compatible API
export const githubModels = (modelName: string) => {
  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;

  if (!token) {
    throw new Error('GitHub token not found. Please set GITHUB_TOKEN or GH_TOKEN environment variable.');
  }

  // GitHub Models uses Azure AI inference endpoint with OpenAI-compatible API
  return openai(modelName, {
    apiKey: token,
    baseURL: 'https://models.inference.ai.azure.com',
    headers: {
      'azureml-model-deployment': modelName,
    },
  });
};