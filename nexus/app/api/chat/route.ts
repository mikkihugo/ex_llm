import { streamText, generateText } from 'ai';
import { createGeminiProvider } from '@/src/providers/gemini-code';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from '@/src/providers/codex';

const providers = {
  'gemini-code': createGeminiProvider({ authType: 'oauth-personal' }),
  'claude-code': claudeCode,
  'openai-codex': codex,
};

export async function POST(req: Request) {
  try {
    const { messages, provider = 'claude-code', model } = await req.json();

    if (!messages || !Array.isArray(messages)) {
      return new Response(
        JSON.stringify({ error: 'Invalid messages format' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const selectedProvider = providers[provider as keyof typeof providers];
    if (!selectedProvider) {
      return new Response(
        JSON.stringify({ error: `Provider ${provider} not found` }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Get the language model
    let languageModel;
    if (typeof selectedProvider === 'object' && 'languageModel' in selectedProvider) {
      languageModel = selectedProvider.languageModel(model || 'default');
    } else {
      return new Response(
        JSON.stringify({ error: 'Provider does not support languageModel' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const result = streamText({
      model: languageModel,
      messages: messages.map((msg: any) => ({
        role: msg.role,
        content: msg.content,
      })),
      temperature: 0.7,
    });

    return result.toTextStreamResponse();
  } catch (error) {
    console.error('Chat API error:', error);
    return new Response(
      JSON.stringify({
        error: 'Failed to process chat request',
        details: error instanceof Error ? error.message : 'Unknown error',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}
