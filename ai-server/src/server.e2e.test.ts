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

  describe('Chat endpoint validation', () => {
    test('POST /chat requires provider', async () => {
      const response = await fetch(`${BASE_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: [{ role: 'user', content: 'test' }]
        })
      });

      expect(response.status).toBe(400);
      const data = await response.json() as any;
      expect(data.error).toContain('provider');
    });

    test('POST /chat requires messages', async () => {
      const response = await fetch(`${BASE_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider: 'gemini-code'
        })
      });

      expect(response.status).toBe(400);
      const data = await response.json() as any;
      expect(data.error).toContain('messages');
    });

    test('POST /chat rejects unknown provider', async () => {
      const response = await fetch(`${BASE_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider: 'unknown-provider',
          messages: [{ role: 'user', content: 'test' }]
        })
      });

      expect(response.status).toBe(400);
      const data = await response.json() as any;
      expect(data.error).toContain('Unknown provider');
    });

    test('POST /chat accepts valid request', async () => {
      const response = await fetch(`${BASE_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider: 'gemini-code-cli',
          messages: [{ role: 'user', content: 'test' }]
        })
      });

      expect(response.status).toBe(200);
      const data = await response.json() as any;
      expect(data.text).toBeDefined();
      expect(data.provider).toBe('gemini-code-cli');
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
      const response = await fetch(`${BASE_URL}/chat`, {
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
      const response = await fetch(`${BASE_URL}/chat`, {
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
      const response = await fetch(`${BASE_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider: 'gemini-code',
          messages: [{ role: 'user', content: 'Say "test"' }]
        })
      });

      const data = await response.json() as any;
      expect(data.text).toBeDefined();
      expect(data.provider).toBe('gemini-code');
    });

    test.skip('Chat response includes usage', async () => {
      const response = await fetch(`${BASE_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider: 'claude-code-cli',
          messages: [{ role: 'user', content: 'test' }]
        })
      });

      const data = await response.json() as any;
      expect(data.usage).toBeDefined();
      expect(data.usage.promptTokens).toBeNumber();
      expect(data.usage.completionTokens).toBeNumber();
      expect(data.usage.totalTokens).toBeNumber();
    });
  });

  describe('Provider-specific behavior', () => {
    test.skip('Gemini Code CLI works', async () => {
      const response = await fetch(`${BASE_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider: 'gemini-code-cli',
          messages: [{ role: 'user', content: 'Say "test"' }],
          model: 'gemini-2.5-pro'
        })
      });

      expect(response.status).toBe(200);
      const data = await response.json() as any;
      expect(data.provider).toBe('gemini-code-cli');
    });

    test.skip('Claude Code CLI works', async () => {
      const response = await fetch(`${BASE_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider: 'claude-code-cli',
          messages: [{ role: 'user', content: 'Say "test"' }],
          model: 'sonnet'
        })
      });

      expect(response.status).toBe(200);
      const data = await response.json() as any;
      expect(data.provider).toBe('claude-code-cli');
    });

    test.skip('Codex requires authentication', async () => {
      const response = await fetch(`${BASE_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider: 'codex',
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
      const response = await fetch(`${BASE_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider: 'gemini-code',
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
