/**
 * NATS Handler Integration Tests
 *
 * Tests the TypeScript side of the LLM provider flow:
 * - NATS request handling
 * - Provider routing
 * - Response formatting
 * - Error handling
 */

import { describe, test, expect, beforeAll, afterAll, mock } from 'bun:test';
import { connect, NatsConnection } from 'nats';
import { generateText } from 'ai';
import { NATSHandler } from '../nats-handler';

// Mock AI SDK for testing
mock.module('ai', () => ({
  generateText: async ({ model, messages, maxTokens }: any) => ({
    text: `Mock response for ${model}: ${messages[0].content}`,
    usage: {
      promptTokens: 10,
      completionTokens: 20,
      totalTokens: 30
    },
    finishReason: 'stop'
  }),
  streamText: async ({ model, messages }: any) => ({
    textStream: async function* () {
      yield `Mock stream for ${model}`;
    }
  })
}));

interface LLMRequest {
  model: string;
  provider: string;
  messages: Array<{ role: string; content: string }>;
  max_tokens?: number;
  temperature?: number;
  stream?: boolean;
  correlation_id?: string;
}

interface LLMResponse {
  text: string;
  model: string;
  tokens_used?: number;
  cost_cents?: number;
  timestamp: string;
  correlation_id?: string;
}

interface LLMError {
  error: string;
  error_code: string;
  correlation_id?: string;
  timestamp: string;
}

let handler: NATSHandler;

beforeAll(async () => {
  handler = new NATSHandler();
  await handler.connect();
});

afterAll(async () => {
  await handler?.close();
});

describe('NATS Handler - LLM Request Processing', () => {
  let nc: NatsConnection;
  const NATS_URL = process.env.NATS_URL || 'nats://localhost:4222';

  beforeAll(async () => {
    try {
      nc = await connect({ servers: NATS_URL });
      console.log('✅ Connected to NATS for testing');
    } catch (error) {
      console.error('❌ Failed to connect to NATS. Ensure nats-server is running:', error);
      throw error;
    }
  });

  afterAll(async () => {
    await nc?.close();
  });

  test('handles ai.llm.request and publishes to ai.llm.response', async () => {
    const correlationId = `test-${Date.now()}`;

    const request: LLMRequest = {
      model: 'gemini-2.5-flash',
      provider: 'gemini-code',
      messages: [{ role: 'user', content: 'Hello, test!' }],
      max_tokens: 50,
      temperature: 0.7,
      correlation_id: correlationId
    };

    // Subscribe to response before publishing request
    const responseSub = nc.subscribe('ai.llm.response');
    const responsePromise = new Promise<LLMResponse>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timeout waiting for response')), 10000);

      (async () => {
        for await (const msg of responseSub) {
          const response = JSON.parse(msg.data.toString()) as LLMResponse;
          if (response.correlation_id === correlationId) {
            clearTimeout(timeout);
            resolve(response);
            break;
          }
        }
      })();
    });

    // Publish request
    nc.publish('ai.llm.request', JSON.stringify(request));

    // Wait for response
    const response = await responsePromise;

    // Validate response
    expect(response).toBeDefined();
    expect(response.correlation_id).toBe(correlationId);
    expect(response.model).toBe('gemini-2.5-flash');
    expect(response.text).toBeDefined();
    expect(response.timestamp).toBeDefined();

    // Cleanup
    responseSub.unsubscribe();
  }, 15000);

  test('handles missing provider gracefully', async () => {
    const correlationId = `test-error-${Date.now()}`;

    const request = {
      model: 'nonexistent-model',
      provider: 'fake-provider',
      messages: [{ role: 'user', content: 'test' }],
      correlation_id: correlationId
    };

    // Subscribe to error responses
    const errorSub = nc.subscribe('ai.llm.error');
    const errorPromise = new Promise<LLMError>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timeout waiting for error')), 10000);

      (async () => {
        for await (const msg of errorSub) {
          const error = JSON.parse(msg.data.toString()) as LLMError;
          if (error.correlation_id === correlationId) {
            clearTimeout(timeout);
            resolve(error);
            break;
          }
        }
      })();
    });

    // Publish invalid request
    nc.publish('ai.llm.request', JSON.stringify(request));

    // Wait for error response
    const error = await errorPromise;

    // Validate error
    expect(error).toBeDefined();
    expect(error.correlation_id).toBe(correlationId);
    expect(error.error).toBeDefined();
    expect(error.error_code).toBeDefined();
    expect(error.timestamp).toBeDefined();

    // Cleanup
    errorSub.unsubscribe();
  }, 15000);

  test('validates request format', async () => {
    const correlationId = `test-validation-${Date.now()}`;

    const invalidRequest = {
      // Missing required fields
      correlation_id: correlationId
    };

    const errorSub = nc.subscribe('ai.llm.error');
    const errorPromise = new Promise<LLMError>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timeout waiting for validation error')), 10000);

      (async () => {
        for await (const msg of errorSub) {
          const error = JSON.parse(msg.data.toString()) as LLMError;
          if (error.correlation_id === correlationId) {
            clearTimeout(timeout);
            resolve(error);
            break;
          }
        }
      })();
    });

    nc.publish('ai.llm.request', JSON.stringify(invalidRequest));

    const error = await errorPromise;

    expect(error.error).toContain('validation' || 'required' || 'missing');
    expect(error.error_code).toBe('VALIDATION_ERROR');

    errorSub.unsubscribe();
  }, 15000);

  test('handles multiple concurrent requests', async () => {
    const requests: LLMRequest[] = [];
    const numRequests = 5;

    for (let i = 0; i < numRequests; i++) {
      requests.push({
        model: 'gemini-2.5-flash',
        provider: 'gemini-code',
        messages: [{ role: 'user', content: `Test ${i}` }],
        max_tokens: 20,
        correlation_id: `concurrent-${i}-${Date.now()}`
      });
    }

    // Subscribe to responses
    const responseSub = nc.subscribe('ai.llm.response');
    const responses = new Set<string>();

    const allResponsesPromise = new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timeout waiting for all responses')), 30000);

      (async () => {
        for await (const msg of responseSub) {
          const response = JSON.parse(msg.data.toString()) as LLMResponse;
          if (response.correlation_id?.startsWith('concurrent-')) {
            responses.add(response.correlation_id);

            if (responses.size === numRequests) {
              clearTimeout(timeout);
              resolve();
              break;
            }
          }
        }
      })();
    });

    // Publish all requests
    requests.forEach(req => {
      nc.publish('ai.llm.request', JSON.stringify(req));
    });

    // Wait for all responses
    await allResponsesPromise;

    expect(responses.size).toBe(numRequests);

    responseSub.unsubscribe();
  }, 35000);

  test('includes usage metadata in response', async () => {
    const correlationId = `test-metadata-${Date.now()}`;

    const request: LLMRequest = {
      model: 'claude-sonnet-4.5',
      provider: 'claude-code',
      messages: [{ role: 'user', content: 'Count to 5' }],
      max_tokens: 30,
      correlation_id: correlationId
    };

    const responseSub = nc.subscribe('ai.llm.response');
    const responsePromise = new Promise<LLMResponse>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timeout')), 15000);

      (async () => {
        for await (const msg of responseSub) {
          const response = JSON.parse(msg.data.toString()) as LLMResponse;
          if (response.correlation_id === correlationId) {
            clearTimeout(timeout);
            resolve(response);
            break;
          }
        }
      })();
    });

    nc.publish('ai.llm.request', JSON.stringify(request));

    const response = await responsePromise;

    // Should include usage metadata
    expect(response.tokens_used).toBeDefined();
    expect(response.tokens_used).toBeGreaterThan(0);
    // Cost may be optional for free tier
    expect(response.timestamp).toBeDefined();

    responseSub.unsubscribe();
  }, 20000);
});

describe('NATS Handler - Provider Routing', () => {
  let nc: NatsConnection;

  beforeAll(async () => {
    nc = await connect({ servers: process.env.NATS_URL || 'nats://localhost:4222' });
  });

  afterAll(async () => {
    await nc?.close();
  });

  test('routes gemini-code requests correctly', async () => {
    const correlationId = `gemini-route-${Date.now()}`;

    const request: LLMRequest = {
      model: 'gemini-2.5-flash',
      provider: 'gemini-code',
      messages: [{ role: 'user', content: 'test gemini routing' }],
      max_tokens: 20,
      correlation_id: correlationId
    };

    const responseSub = nc.subscribe('ai.llm.response');
    const responsePromise = new Promise<LLMResponse>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timeout')), 10000);

      (async () => {
        for await (const msg of responseSub) {
          const response = JSON.parse(msg.data.toString()) as LLMResponse;
          if (response.correlation_id === correlationId) {
            clearTimeout(timeout);
            resolve(response);
            break;
          }
        }
      })();
    });

    nc.publish('ai.llm.request', JSON.stringify(request));
    const response = await responsePromise;

    expect(response.model).toContain('gemini');

    responseSub.unsubscribe();
  }, 15000);

  test('routes claude-code requests correctly', async () => {
    const correlationId = `claude-route-${Date.now()}`;

    const request: LLMRequest = {
      model: 'claude-sonnet-4.5',
      provider: 'claude-code',
      messages: [{ role: 'user', content: 'test claude routing' }],
      max_tokens: 20,
      correlation_id: correlationId
    };

    const responseSub = nc.subscribe('ai.llm.response');
    const responsePromise = new Promise<LLMResponse>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timeout')), 15000);

      (async () => {
        for await (const msg of responseSub) {
          const response = JSON.parse(msg.data.toString()) as LLMResponse;
          if (response.correlation_id === correlationId) {
            clearTimeout(timeout);
            resolve(response);
            break;
          }
        }
      })();
    });

    nc.publish('ai.llm.request', JSON.stringify(request));
    const response = await responsePromise;

    expect(response.model).toContain('claude');

    responseSub.unsubscribe();
  }, 20000);
});
