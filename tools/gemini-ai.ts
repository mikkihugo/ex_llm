#!/usr/bin/env bun

/**
 * Gemini CLI AI SDK wrapper for Elixir integration
 *
 * Usage:
 *   bun run tools/gemini-ai.ts <messages_json>
 *
 * Uses the Gemini CLI via ai-sdk-provider-gemini-cli
 * No API keys needed with OAuth - auto-authenticates
 *
 * Prerequisites:
 *   npm install -g @google/gemini-cli
 */

import { generateText } from 'ai';
import { createGeminiProvider } from 'ai-sdk-provider-gemini-cli';

interface Message {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface ChatRequest {
  model: string;
  messages: Message[];
  temperature?: number;
  maxTokens?: number;
}

async function main() {
  try {
    const args = process.argv.slice(2);

    if (args.length === 0) {
      console.error(JSON.stringify({
        error: 'Missing arguments. Usage: gemini-ai <messages_json>'
      }));
      process.exit(1);
    }

    const input = args.join(' ');
    const request: ChatRequest = JSON.parse(input);

    if (!request.messages || request.messages.length === 0) {
      console.error(JSON.stringify({
        error: 'Missing or empty messages array'
      }));
      process.exit(1);
    }

    // Create Gemini provider with OAuth (no API key needed)
    const gemini = createGeminiProvider({
      authType: 'oauth-personal',
    });

    // Map model names: gemini-2.5-pro or gemini-2.5-flash (default to pro)
    const modelName = request.model === 'gemini-2.5-flash'
      ? 'gemini-2.5-flash'
      : 'gemini-2.5-pro';

    const result = await generateText({
      model: gemini(modelName),
      messages: request.messages,
      temperature: request.temperature ?? 0.7,
      maxTokens: request.maxTokens,
      maxRetries: 2,
    });

    // Output JSON result
    console.log(JSON.stringify({
      text: result.text,
      finishReason: result.finishReason,
      usage: result.usage,
      model: modelName
    }));

  } catch (error: any) {
    console.error(JSON.stringify({
      error: error.message || String(error),
      stack: error.stack
    }));
    process.exit(1);
  }
}

main();
