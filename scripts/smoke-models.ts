#!/usr/bin/env bun

type SmokeStatus = 'passed' | 'failed' | 'skipped';

type SmokeResult = {
  name: string;
  status: SmokeStatus;
  message: string;
};

async function runGitHubModelsSmoke(): Promise<SmokeResult> {
  const token = process.env.GITHUB_MODELS_TOKEN ?? process.env.GITHUB_TOKEN;
  if (!token) {
    return {
      name: 'GitHub Models chat completion',
      status: 'skipped',
      message: 'GITHUB_MODELS_TOKEN not set – skipping.',
    };
  }

  const baseUrl = process.env.GITHUB_MODELS_BASE_URL ?? 'https://models.inference.ai.azure.com';
  const model = process.env.GITHUB_MODELS_SMOKE_MODEL ?? 'gpt-4o-mini';

  try {
    const response = await fetch(`${baseUrl}/v1/chat/completions`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        max_tokens: 32,
        messages: [
          { role: 'system', content: 'You are a health check. Respond briefly.' },
          { role: 'user', content: 'Status?' },
        ],
      }),
    });

    if (!response.ok) {
      const bodyText = await response.text();
      return {
        name: 'GitHub Models chat completion',
        status: 'failed',
        message: `HTTP ${response.status} ${response.statusText}: ${bodyText}`,
      };
    }

    const payload = await response.json();
    const text = payload?.choices?.[0]?.message?.content;
    if (typeof text !== 'string') {
      return {
        name: 'GitHub Models chat completion',
        status: 'failed',
        message: 'Response missing assistant content.',
      };
    }

    return {
      name: 'GitHub Models chat completion',
      status: 'passed',
      message: text.trim(),
    };
  } catch (error) {
    return {
      name: 'GitHub Models chat completion',
      status: 'failed',
      message: (error as Error).message,
    };
  }
}

async function runVercelGatewaySmoke(): Promise<SmokeResult> {
  const apiKey = process.env.VERCEL_AI_GATEWAY_KEY;
  if (!apiKey) {
    return {
      name: 'Vercel AI Gateway chat completion',
      status: 'skipped',
      message: 'VERCEL_AI_GATEWAY_KEY not set – skipping.',
    };
  }

  const baseUrl = process.env.VERCEL_AI_GATEWAY_URL ?? 'https://gateway.ai.vercel.com/api/v1';
  const model = process.env.VERCEL_AI_GATEWAY_MODEL ?? 'openai/gpt-5-mini';

  try {
    const response = await fetch(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        max_tokens: 32,
        messages: [
          { role: 'system', content: 'You are a health check. Respond briefly.' },
          { role: 'user', content: 'Status?' },
        ],
      }),
    });

    if (!response.ok) {
      const bodyText = await response.text();
      return {
        name: 'Vercel AI Gateway chat completion',
        status: 'failed',
        message: `HTTP ${response.status} ${response.statusText}: ${bodyText}`,
      };
    }

    const payload = await response.json();
    const text = payload?.choices?.[0]?.message?.content;
    if (typeof text !== 'string') {
      return {
        name: 'Vercel AI Gateway chat completion',
        status: 'failed',
        message: 'Response missing assistant content.',
      };
    }

    return {
      name: 'Vercel AI Gateway chat completion',
      status: 'passed',
      message: text.trim(),
    };
  } catch (error) {
    return {
      name: 'Vercel AI Gateway chat completion',
      status: 'failed',
      message: (error as Error).message,
    };
  }
}

async function main() {
  const results = await Promise.all([
    runGitHubModelsSmoke(),
    runVercelGatewaySmoke(),
  ]);

  let failed = false;

  for (const result of results) {
    const prefix = result.status === 'passed' ? '✅' : result.status === 'skipped' ? '⚪️' : '❌';
    console.log(`${prefix} ${result.name}: ${result.message}`);
    if (result.status === 'failed') {
      failed = true;
    }
  }

  if (failed) {
    process.exitCode = 1;
  }
}

await main();
