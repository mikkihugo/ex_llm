import { createOpenAI } from 'ai';

export function createCopilotClient() {
  const apiKey = process.env.COPILOT_API_TOKEN ?? process.env.COPILOT_TOKEN;
  if (!apiKey) {
    throw new Error('COPILOT_API_TOKEN is not set.');
  }
  const baseURL = process.env.COPILOT_API_BASE_URL ?? 'https://api.githubcopilot.com';

  return createOpenAI({
    baseURL,
    apiKey,
    headers: {
      'User-Agent': process.env.COPILOT_USER_AGENT ?? 'singularity-ai-server/1.0',
    },
  });
}

export async function copilotChatCompletion({
  model,
  messages,
  temperature,
  maxTokens,
}: {
  model: string;
  messages: { role: 'system' | 'user' | 'assistant'; content: string }[];
  temperature?: number;
  maxTokens?: number;
}) {
  const client = createCopilotClient();
  return client.chat.completions.create({
    model,
    messages,
    temperature,
    max_tokens: maxTokens,
  });
}
