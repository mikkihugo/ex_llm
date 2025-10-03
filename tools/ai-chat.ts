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

    const token = process.env.VERCEL_AI_GATEWAY_TOKEN;
    if (!token) {
      console.error(JSON.stringify({
        error: 'Missing VERCEL_AI_GATEWAY_TOKEN environment variable'
      }));
      process.exit(1);
    }

    // Parse model string (e.g., "openai/gpt-5-codex" or "gpt-5-codex")
    const modelParts = request.model.split('/');
    const modelName = modelParts.length > 1 ? modelParts[1] : modelParts[0];
    const provider = modelParts.length > 1 ? modelParts[0] : 'openai';

    // Use Vercel AI Gateway URL
    const baseUrl = process.env.VERCEL_AI_GATEWAY_URL || 'https://gateway.vercel.com/v1';
    const url = `${baseUrl}/chat/completions`;

    const payload = {
      model: `${provider}/${modelName}`,
      messages: request.messages,
      temperature: request.temperature ?? 0.7,
      ...(request.maxTokens && { max_tokens: request.maxTokens })
    };

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    };

    // Add team ID header if provided
    const teamId = process.env.VERCEL_TEAM_ID;
    if (teamId) {
      headers['x-vercel-team-id'] = teamId;
    }

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(JSON.stringify({
        error: `API request failed: ${response.status} ${response.statusText}`,
        details: errorText
      }));
      process.exit(1);
    }

    const result: ChatResponse = await response.json();

    // Output JSON result
    console.log(JSON.stringify({
      text: result.choices[0]?.message?.content || '',
      finishReason: result.choices[0]?.finish_reason || 'unknown',
      usage: result.usage,
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
