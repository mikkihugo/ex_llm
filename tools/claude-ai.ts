#!/usr/bin/env bun

/**
 * Claude Code AI SDK wrapper for Elixir integration
 *
 * Usage:
 *   bun run tools/claude-ai.ts <messages_json>
 *
 * Uses the Claude Code CLI via ai-sdk-provider-claude-code
 * No API keys needed - uses your Claude Code subscription
 */

import { generateText } from 'ai';
import { claudeCode } from 'ai-sdk-provider-claude-code';

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
        error: 'Missing arguments. Usage: claude-ai <messages_json>'
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

    // Map model names: "sonnet" or "opus" (default to sonnet)
    const modelName = request.model === 'opus' ? 'opus' : 'sonnet';

    const result = await generateText({
      model: claudeCode(modelName),
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
