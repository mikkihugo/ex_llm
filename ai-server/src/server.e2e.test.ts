import { describe, test, expect, beforeAll, afterAll } from 'bun:test';
import { startTestServer, stopTestServer, getTestServerUrl } from './test-server';

// E2E tests for HTTP endpoints
describe('Server E2E Tests', () => {
  let BASE_URL: string;

  beforeAll(async () => {
    await startTestServer(0); // Use random available port
    BASE_URL = getTestServerUrl();
    console.log(`Test server started on ${BASE_URL}`);
  });

  afterAll(() => {
    stopTestServer();
  });

  describe('Health endpoint', () => {
    test('GET /health returns 200', async () => {
      const response = await fetch(`${BASE_URL}/health`);
      expect(response.status).toBe(200);
    });

    test('health response includes providers', async () => {
      const response = await fetch(`${BASE_URL}/health`);
      const data = await response.json() as any;
      expect(data.providers).toBeArray();
      expect(data.providers.length).toBeGreaterThan(0);
    });

    test('health response includes system_time', async () => {
      const response = await fetch(`${BASE_URL}/health`);
      const data = await response.json() as any;
      expect(data.system_time).toBeString();
      expect(data.status).toBe('ok');
    });
  });

  describe('CORS headers', () => {
    test('OPTIONS request returns CORS headers', async () => {
      const response = await fetch(`${BASE_URL}/health`, {
        method: 'OPTIONS'
      });

      expect(response.headers.get('Access-Control-Allow-Origin')).toBeTruthy();
      expect(response.headers.get('Access-Control-Allow-Methods')).toContain('GET');
      expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
    });

    test('CORS allows configured origins', async () => {
      const response = await fetch(`${BASE_URL}/health`, {
        headers: { 'Origin': 'http://localhost:3000' }
      });

      const allowedOrigin = response.headers.get('Access-Control-Allow-Origin');
      expect(allowedOrigin).toBeTruthy();
    });
  });

  describe('OpenAI chat completions endpoint', () => {
    const endpoint = () => `${BASE_URL}/v1/chat/completions`;

    test('requires model field', async () => {
      const response = await fetch(endpoint(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: [{ role: 'user', content: 'hello' }],
        }),
      });

      expect(response.status).toBe(400);
      const data = await response.json() as any;
      expect(data.error).toContain('model');
    });

    test('requires messages array', async () => {
      const response = await fetch(endpoint(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: 'gemini-2.5-flash' }),
      });

      expect(response.status).toBe(400);
      const data = await response.json() as any;
      expect(data.error).toContain('messages');
    });

    test('rejects unknown models', async () => {
      const response = await fetch(endpoint(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'unknown-model',
          messages: [{ role: 'user', content: 'hi' }],
        }),
      });

      expect(response.status).toBe(400);
      const data = await response.json() as any;
      expect(data.error).toContain('Unknown model');
    });

    test('returns OpenAI-compatible payload for valid request', async () => {
      const response = await fetch(endpoint(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'gemini-2.5-flash',
          messages: [{ role: 'user', content: 'hello there' }],
        }),
      });

      expect(response.status).toBe(200);
      const data = await response.json() as any;
      expect(data.object).toBe('chat.completion');
      expect(data.choices).toBeArray();
      expect(data.choices[0].message.role).toBe('assistant');
      expect(data.choices[0].message.content).toBeString();
      expect(data.usage.total_tokens).toBeNumber();
    });

    test('supports json_object response_format', async () => {
      const response = await fetch(endpoint(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'gemini-2.5-flash',
          messages: [{ role: 'user', content: 'return json' }],
          response_format: { type: 'json_object' },
        }),
      });

      expect(response.status).toBe(200);
      const data = await response.json() as any;
      const content = data.choices[0].message.content;
      expect(() => JSON.parse(content)).not.toThrow();
      expect(JSON.parse(content)).toBeObject();
    });

    test('streams SSE when stream flag is set', async () => {
      const response = await fetch(endpoint(), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'gemini-2.5-flash',
          messages: [{ role: 'user', content: 'stream?' }],
          stream: true,
        }),
      });

      expect(response.status).toBe(200);
      expect(response.headers.get('content-type')).toContain('text/event-stream');
      const bodyText = await response.text();
      expect(bodyText).toContain('Mock response from test server');
      expect(bodyText).toContain('[DONE]');
    });
  });

  describe('OAuth endpoints', () => {
    test('GET /codex/auth/start returns authorization URL', async () => {
      const response = await fetch(`${BASE_URL}/codex/auth/start`);
      expect(response.status).toBe(200);

      const data = await response.json() as any;
      expect(data.url).toBeDefined();
      expect(typeof data.url).toBe('string');
    });

    test('GET /codex/auth/complete requires code', async () => {
      const response = await fetch(`${BASE_URL}/codex/auth/complete`);
      expect(response.status).toBe(400);

      const data = await response.json() as any;
      expect(data.error).toBeDefined();
    });

    test.skip('OAuth flow maintains state', async () => {
      // Start OAuth flow
      const startResponse = await fetch(`${BASE_URL}/codex/auth/start`);
      const startData = await startResponse.json() as any;
      const authUrl = new URL(startData.url);
      const state = authUrl.searchParams.get('state');

      expect(state).toBeTruthy();
      // In real test, would verify state is validated on callback
    });
  });

  describe('Error handling', () => {
    test('Invalid JSON returns 400', async () => {
      const response = await fetch(`${BASE_URL}/v1/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{invalid json}'
      });

      expect(response.status).toBe(400);
    });

    test('404 for unknown routes', async () => {
      const response = await fetch(`${BASE_URL}/unknown-route`);
      expect(response.status).toBe(404);
    });

    test('Error responses include error field', async () => {
      const response = await fetch(`${BASE_URL}/v1/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      });

      const data = await response.json() as any;
      expect(data.error).toBeString();
    });

    test.skip('Stack traces only in development', async () => {
      // Would need to test with different NODE_ENV values
      // In production: no stack trace
      // In development: includes stack trace
    });
  });

  describe('Response formats', () => {
    test.skip('Chat response includes text', async () => {
      const response = await fetch(`${BASE_URL}/v1/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'gemini-2.5-flash',
          messages: [{ role: 'user', content: 'Say "test"' }]
        })
      });

      const data = await response.json() as any;
      expect(data.object).toBe('chat.completion');
      expect(data.choices[0].message.role).toBe('assistant');
    });

    test.skip('Chat response includes usage', async () => {
      const response = await fetch(`${BASE_URL}/v1/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-3.5-sonnet',
          messages: [{ role: 'user', content: 'test' }]
        })
      });

      const data = await response.json() as any;
      expect(data.usage).toBeDefined();
      expect(data.usage.prompt_tokens).toBeNumber();
      expect(data.usage.completion_tokens).toBeNumber();
      expect(data.usage.total_tokens).toBeNumber();
    });
  });

  describe('Provider-specific behavior', () => {
    test.skip('Gemini Code CLI works', async () => {
      const response = await fetch(`${BASE_URL}/v1/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'gemini-2.5-pro',
          messages: [{ role: 'user', content: 'Say "test"' }]
        })
      });

      expect(response.status).toBe(200);
      const data = await response.json() as any;
      expect(data.object).toBe('chat.completion');
    });

    test.skip('Claude Code CLI works', async () => {
      const response = await fetch(`${BASE_URL}/v1/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-3.5-sonnet',
          messages: [{ role: 'user', content: 'Say "test"' }]
        })
      });

      expect(response.status).toBe(200);
      const data = await response.json() as any;
      expect(data.model).toBe('claude-3.5-sonnet');
    });

    test.skip('Codex requires authentication', async () => {
      const response = await fetch(`${BASE_URL}/v1/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'gpt-5-codex',
          messages: [{ role: 'user', content: 'test' }]
        })
      });

      // Should fail if not authenticated
      if (response.status !== 200) {
        const data = await response.json() as any;
        expect(data.error).toContain('not authenticated');
      }
    });
  });

  describe('Security', () => {
    test.skip('Validates OAuth params to prevent XSS', async () => {
      const maliciousState = '<script>alert("xss")</script>';
      const response = await fetch(`${BASE_URL}/codex/auth/complete?code=test&state=${encodeURIComponent(maliciousState)}`);

      // Should reject or sanitize malicious input
      expect(response.status).not.toBe(200);
    });

    test.skip('HTML responses are escaped', async () => {
      // Test that OAuth callback pages escape user input
      const response = await fetch(`${BASE_URL}/codex/auth/complete?error=<script>xss</script>`);
      const html = await response.text();

      // Should contain escaped version, not raw script tags
      expect(html).not.toContain('<script>');
      expect(html).toContain('&lt;script&gt;');
    });

    test.skip('Rejects oversized payloads', async () => {
      const hugeMessage = 'a'.repeat(10_000_000); // 10MB
      const response = await fetch(`${BASE_URL}/v1/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'gemini-2.5-flash',
          messages: [{ role: 'user', content: hugeMessage }]
        })
      });

      // Should reject or handle gracefully
      expect([400, 413, 500]).toContain(response.status);
    });
  });

  describe('Performance', () => {
    test.skip('Health check responds quickly', async () => {
      const start = Date.now();
      const response = await fetch(`${BASE_URL}/health`);
      const duration = Date.now() - start;

      expect(response.status).toBe(200);
      expect(duration).toBeLessThan(100); // Should respond in < 100ms
    });

    test.skip('Handles concurrent requests', async () => {
      const requests = Array.from({ length: 10 }, () =>
        fetch(`${BASE_URL}/health`)
      );

      const responses = await Promise.all(requests);

      responses.forEach(response => {
        expect(response.status).toBe(200);
      });
    });
  });
});

// Integration test helpers
describe('Test Helpers', () => {
  describe('Mock provider', () => {
    function createMockProvider(name: string, responseText: string) {
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

    test('creates mock provider', () => {
      const mock = createMockProvider('test-provider', 'mock response');
      expect(mock.name).toBe('test-provider');
      expect(mock.handler).toBeFunction();
    });

    test('mock provider returns expected format', async () => {
      const mock = createMockProvider('test', 'response');
      const result = await mock.handler();

      expect(result.text).toBe('response');
      expect(result.provider).toBe('test');
      expect(result.usage).toBeDefined();
    });
  });

  describe('Request builder', () => {
    function buildChatRequest(overrides: any = {}) {
      return {
        provider: 'gemini-code',
        messages: [{ role: 'user', content: 'test' }],
        ...overrides
      };
    }

    test('builds basic request', () => {
      const req = buildChatRequest();
      expect(req.provider).toBe('gemini-code');
      expect(req.messages).toHaveLength(1);
    });

    test('applies overrides', () => {
      const req = buildChatRequest({ provider: 'claude-code-cli', model: 'sonnet' });
      expect(req.provider).toBe('claude-code-cli');
      expect(req.model).toBe('sonnet');
    });
  });
});
