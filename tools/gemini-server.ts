#!/usr/bin/env bun

/**
 * Gemini AI HTTP Server
 *
 * Simple HTTP server wrapping the Gemini CLI AI SDK
 * No API keys needed with OAuth - auto-authenticates
 *
 * Usage:
 *   bun run tools/gemini-server.ts
 *
 * Environment:
 *   PORT - Server port (default: 3001)
 */

import { generateText } from 'ai';
import { createGeminiProvider } from 'ai-sdk-provider-gemini-cli';

interface Message {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface ChatRequest {
  model?: string;
  messages: Message[];
  temperature?: number;
  maxTokens?: number;
}

const PORT = parseInt(process.env.PORT || '3001');

// Create Gemini provider once
const gemini = createGeminiProvider({
  authType: 'oauth-personal',
});

const server = Bun.serve({
  port: PORT,
  async fetch(req) {
    // CORS headers
    const headers = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Content-Type': 'application/json',
    };

    if (req.method === 'OPTIONS') {
      return new Response(null, { headers });
    }

    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers,
      });
    }

    if (req.url.endsWith('/health')) {
      return new Response(JSON.stringify({ status: 'ok' }), { headers });
    }

    if (!req.url.endsWith('/chat')) {
      return new Response(JSON.stringify({ error: 'Not found' }), {
        status: 404,
        headers,
      });
    }

    try {
      const body: ChatRequest = await req.json();

      if (!body.messages || body.messages.length === 0) {
        return new Response(
          JSON.stringify({ error: 'Missing or empty messages array' }),
          { status: 400, headers }
        );
      }

      const modelName =
        body.model === 'gemini-2.5-flash' ? 'gemini-2.5-flash' : 'gemini-2.5-pro';

      const result = await generateText({
        model: gemini(modelName),
        messages: body.messages,
        temperature: body.temperature ?? 0.7,
        maxTokens: body.maxTokens,
        maxRetries: 2,
      });

      return new Response(
        JSON.stringify({
          text: result.text,
          finishReason: result.finishReason,
          usage: result.usage,
          model: modelName,
        }),
        { headers }
      );
    } catch (error: any) {
      console.error('Error processing request:', error);
      return new Response(
        JSON.stringify({
          error: error.message || String(error),
          stack: error.stack,
        }),
        { status: 500, headers }
      );
    }
  },
});

console.log(`Gemini AI HTTP server listening on http://localhost:${PORT}`);
