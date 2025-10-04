import { getCopilotAccessToken } from '../github-copilot-oauth';
import { randomUUID } from 'crypto';

interface CopilotParams {
  model: string;
  messages: Array<{ role: string; content: string }>;
}

export async function copilotChatCompletion(params: CopilotParams) {
  const token = await getCopilotAccessToken();

  if (!token) {
    throw new Error('GitHub Copilot not authenticated. Please authenticate first.');
  }

  // Make raw fetch request to Copilot API
  const response = await fetch('https://api.githubcopilot.com/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
      'editor-version': 'vscode/1.99.3',
      'editor-plugin-version': 'copilot-chat/0.26.7',
      'user-agent': 'GitHubCopilotChat/0.26.7',
      'copilot-integration-id': 'vscode-chat',
      'openai-intent': 'conversation-panel',
      'x-github-api-version': '2025-04-01',
      'x-request-id': randomUUID(),
    },
    body: JSON.stringify({
      model: params.model,
      messages: params.messages,
      stream: false,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Copilot API error: ${response.status} ${response.statusText} - ${errorText}`);
  }

  const data: any = await response.json();

  return {
    text: data.choices?.[0]?.message?.content || '',
    usage: data.usage,
  };
}
