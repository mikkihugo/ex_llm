#!/usr/bin/env bun

/**
 * Vercel AI Gateway CLI wrapper for Elixir integration
 *
 * Usage:
 *   bun run tools/ai-chat.ts <messages_json>
 *
 * Environment:
 *   VERCEL_AI_GATEWAY_TOKEN - Vercel OAuth token (required)
 *   VERCEL_AI_GATEWAY_URL - Gateway URL (optional, defaults to gateway.vercel.com)
 *   VERCEL_TEAM_ID - Vercel team ID (optional)
 */

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

interface ChatResponse {
  choices: Array<{
    message: {
      content: string;
    };
    finish_reason: string;
  }>;
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}

async function main() {
  try {
    const args = process.argv.slice(2);

    if (args.length === 0) {
      console.error(JSON.stringify({
        error: 'Missing arguments. Usage: ai-chat <messages_json>'
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

    // TODO: AI chat tool is stubbed out - implement when needed
    console.log("AI chat tool called (stubbed):", request.model, request.messages.length, "messages");

    // Stub implementation - returns empty response
    console.log(JSON.stringify({
      text: 'AI chat tool is currently stubbed out - functionality not implemented',
      finishReason: 'stop',
      usage: {
        prompt_tokens: 0,
        completion_tokens: 0,
        total_tokens: 0
      },
      model: request.model
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
