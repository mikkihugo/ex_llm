/**
 * Test server instance for E2E tests
 * This is a minimal mock server that implements the same endpoints as server.ts
 */

let testServer: any = null;
let testPort: number = 0;

export async function startTestServer(port: number = 0): Promise<number> {
  if (testServer) {
    throw new Error('Test server already running');
  }

  testServer = Bun.serve({
    port,
    async fetch(req) {
      const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Content-Type': 'application/json',
      };

      if (req.method === 'OPTIONS') {
        return new Response(null, { headers });
      }

      const url = new URL(req.url);

      // Health endpoint
      if (url.pathname === '/health') {
        return new Response(
          JSON.stringify({
            status: 'ok',
            providers: ['gemini-code-cli', 'claude-code-cli'],
            system_time: new Date().toISOString()
          }),
          { headers }
        );
      }

      // Chat endpoint
      if (url.pathname === '/chat' && req.method === 'POST') {
        try {
          const body = await req.json() as any;

          if (!body.provider) {
            return new Response(
              JSON.stringify({ error: 'Missing provider field' }),
              { status: 400, headers }
            );
          }

          if (!body.messages || body.messages.length === 0) {
            return new Response(
              JSON.stringify({ error: 'Missing or empty messages array' }),
              { status: 400, headers }
            );
          }

          const validProviders = ['gemini-code-cli', 'gemini-code', 'claude-code-cli', 'codex', 'cursor-agent', 'copilot'];
          if (!validProviders.includes(body.provider)) {
            return new Response(
              JSON.stringify({ error: `Unknown provider: ${body.provider}` }),
              { status: 400, headers }
            );
          }

          // Mock response
          const mockResponse = {
            text: 'Mock response from test server',
            finishReason: 'stop',
            usage: {
              promptTokens: 10,
              completionTokens: 20,
              totalTokens: 30
            },
            model: body.model || 'test-model',
            provider: body.provider
          };

          return new Response(JSON.stringify(mockResponse), { headers });
        } catch (error: any) {
          return new Response(
            JSON.stringify({ error: error.message || 'Invalid JSON' }),
            { status: 400, headers }
          );
        }
      }

      // Codex OAuth endpoints
      if (url.pathname === '/codex/auth/start') {
        return new Response(
          JSON.stringify({
            url: 'https://auth.openai.com/oauth/authorize?state=test&code_challenge=test',
            message: 'Test OAuth URL'
          }),
          { headers }
        );
      }

      if (url.pathname === '/codex/auth/complete') {
        const code = url.searchParams.get('code');
        if (!code) {
          return new Response(
            JSON.stringify({ error: 'Missing authorization code' }),
            { status: 400, headers }
          );
        }

        return new Response(
          JSON.stringify({ success: true, message: 'OAuth complete' }),
          { headers }
        );
      }

      // 404 for unknown routes
      return new Response(
        JSON.stringify({ error: 'Not found' }),
        { status: 404, headers }
      );
    },
  });

  testPort = testServer.port;
  return testPort;
}

export function getTestServerUrl(): string {
  if (!testServer) {
    throw new Error('Test server not running');
  }
  return `http://localhost:${testPort}`;
}

export function stopTestServer(): void {
  if (testServer) {
    testServer.stop();
    testServer = null;
    testPort = 0;
  }
}
