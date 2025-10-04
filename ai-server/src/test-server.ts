/**
 * Test server instance for E2E tests
 * This is a minimal mock server that implements the same endpoints as server.ts
 */

import { createServer, Server } from 'http';
import type { IncomingMessage, ServerResponse } from 'http';
import { AddressInfo } from 'net';

let testServer: Server | null = null;
let testPort: number = 0;

const BASE_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function sendJson(res: ServerResponse, status: number, data: unknown, extraHeaders: Record<string, string> = {}) {
  const payload = JSON.stringify(data);
  res.writeHead(status, {
    ...BASE_HEADERS,
    'Content-Type': 'application/json',
    ...extraHeaders,
  });
  res.end(payload);
}

function sendNoContent(res: ServerResponse, status: number) {
  res.writeHead(status, {
    ...BASE_HEADERS,
  });
  res.end();
}

async function readJsonBody(req: IncomingMessage): Promise<any> {
  try {
    const chunks: Buffer[] = [];
    for await (const chunk of req) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    const text = Buffer.concat(chunks).toString('utf-8');
    if (!text) return {};
    return JSON.parse(text);
  } catch (error) {
    throw new Error('Invalid JSON');
  }
}

async function handleRequest(req: IncomingMessage, res: ServerResponse) {
  const url = new URL(req.url ?? '/', 'http://localhost');

  try {
    if (req.method === 'OPTIONS') {
      sendNoContent(res, 204);
      return;
    }

    if (url.pathname === '/health') {
      sendJson(res, 200, {
        status: 'ok',
        providers: ['gemini-code-cli', 'claude-code-cli'],
        system_time: new Date().toISOString(),
      });
      return;
    }

    if (url.pathname === '/v1/chat/completions') {
      if (req.method !== 'POST') {
        sendJson(res, 405, { error: 'Method not allowed' });
        return;
      }

      let body: any;
      try {
        body = await readJsonBody(req);
      } catch (error: any) {
        sendJson(res, 400, { error: error?.message || 'Invalid JSON' });
        return;
      }

      if (!body || typeof body !== 'object') {
        sendJson(res, 400, { error: 'Invalid request payload' });
        return;
      }

      if (!Array.isArray(body.messages) || body.messages.length === 0) {
        sendJson(res, 400, { error: 'messages array is required' });
        return;
      }

      if (typeof body.model !== 'string' || body.model.length === 0) {
        sendJson(res, 400, { error: 'model is required' });
        return;
      }

      const responseFormat = body.response_format;
      const formatType = typeof responseFormat === 'string' ? responseFormat : responseFormat?.type;
      if (formatType && formatType !== 'json_object' && formatType !== 'text') {
        sendJson(res, 400, { error: `Unsupported response_format type: ${formatType}` });
        return;
      }

      const validModels = new Set([
        'gemini-2.5-flash',
        'gemini-2.5-pro',
        'claude-3.5-sonnet',
        'gpt-5-codex',
        'cursor-gpt-4.1',
        'copilot-claude-sonnet-4.5',
        'copilot-gpt-5',
      ]);

      if (!validModels.has(body.model)) {
        sendJson(res, 400, { error: `Unknown model: ${body.model}` });
        return;
      }

      const messageContent = formatType === 'json_object'
        ? JSON.stringify({ mock: true, model: body.model })
        : 'Mock response from test server';

      const mockResponse = {
        id: 'chatcmpl-test',
        object: 'chat.completion',
        created: Math.floor(Date.now() / 1000),
        model: body.model,
        choices: [
          {
            index: 0,
            message: {
              role: 'assistant',
              content: messageContent,
            },
            finish_reason: 'stop',
            logprobs: null,
          },
        ],
        usage: {
          prompt_tokens: 10,
          completion_tokens: 20,
          total_tokens: 30,
        },
        system_fingerprint: 'test-server',
      };

      if (body.stream === true) {
        res.writeHead(200, {
          ...BASE_HEADERS,
          'Content-Type': 'text/event-stream; charset=utf-8',
          'Cache-Control': 'no-cache, no-transform',
          Connection: 'keep-alive',
        });

        const created = mockResponse.created;
        const id = mockResponse.id;

        const send = (payload: unknown) => {
          res.write(`data: ${JSON.stringify(payload)}\n\n`);
        };

        send({
          id,
          object: 'chat.completion.chunk',
          created,
          model: body.model,
          choices: [
            {
              index: 0,
              delta: { role: 'assistant' },
              finish_reason: null,
              logprobs: null,
            },
          ],
        });

        send({
          id,
          object: 'chat.completion.chunk',
          created,
          model: body.model,
          choices: [
            {
              index: 0,
              delta: { content: messageContent },
              finish_reason: null,
              logprobs: null,
            },
          ],
        });

        send({
          id,
          object: 'chat.completion.chunk',
          created,
          model: body.model,
          choices: [
            {
              index: 0,
              delta: {},
              finish_reason: 'stop',
              logprobs: null,
            },
          ],
          usage: mockResponse.usage,
        });

        res.write('data: [DONE]\n\n');
        res.end();
        return;
      }

      sendJson(res, 200, mockResponse);
      return;
    }

    if (url.pathname === '/codex/auth/start') {
      sendJson(res, 200, {
        url: 'https://auth.openai.com/oauth/authorize?state=test&code_challenge=test',
        message: 'Test OAuth URL',
      });
      return;
    }

    if (url.pathname === '/codex/auth/complete') {
      const code = url.searchParams.get('code');
      if (!code) {
        sendJson(res, 400, { error: 'Missing authorization code' });
        return;
      }

      sendJson(res, 200, { success: true, message: 'OAuth complete' });
      return;
    }

    sendJson(res, 404, { error: 'Not found' });
  } catch (error: any) {
    sendJson(res, 500, { error: error?.message || 'Internal error' });
  }
}

export async function startTestServer(port: number = 0): Promise<number> {
  if (testServer) {
    throw new Error('Test server already running');
  }

  const maxAttempts = port === 0 ? 10 : 1;

  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const listenPort = port === 0 ? 40000 + Math.floor(Math.random() * 10000) : port;
    const server = createServer((req, res) => {
      void handleRequest(req, res);
    });

    try {
      await new Promise<void>((resolve, reject) => {
        server.once('error', reject);
        server.listen(listenPort, '127.0.0.1', () => {
          server.off('error', reject);
          resolve();
        });
      });

      const address = server.address() as AddressInfo;
      testServer = server;
      testPort = address.port;
      return testPort;
    } catch (error: any) {
      server.close();
      if (error?.code === 'EADDRINUSE' && port === 0 && attempt < maxAttempts - 1) {
        continue;
      }
      throw error;
    }
  }

  throw new Error('Failed to start test server');
}

export function getTestServerUrl(): string {
  if (!testServer) {
    throw new Error('Test server not running');
  }
  return `http://127.0.0.1:${testPort}`;
}

export function stopTestServer(): void {
  if (testServer) {
    testServer.close();
    testServer = null;
    testPort = 0;
  }
}
