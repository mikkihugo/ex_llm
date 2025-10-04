/**
 * Mock utilities for testing
 */

export interface MockProvider {
  name: string;
  handler: () => Promise<{
    text: string;
    finishReason: string;
    usage: {
      promptTokens: number;
      completionTokens: number;
      totalTokens: number;
    };
    model: string;
    provider: string;
  }>;
}

export function createMockProvider(name: string, responseText: string): MockProvider {
  return {
    name,
    handler: async () => ({
      text: responseText,
      finishReason: 'stop',
      usage: { promptTokens: 10, completionTokens: 20, totalTokens: 30 },
      model: 'mock-model',
      provider: name
    })
  };
}
