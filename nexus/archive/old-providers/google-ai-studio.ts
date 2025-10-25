import { GoogleGenerativeAI } from '@google/generative-ai';

interface GoogleAIStudioParams {
  model: string;
  messages: Array<{ role: string; content: string }>;
}

export async function googleAIStudioChatCompletion(params: GoogleAIStudioParams) {
  const apiKey = process.env.GOOGLE_AI_STUDIO_API_KEY;

  if (!apiKey) {
    throw new Error('Google AI Studio not configured. Set GOOGLE_AI_STUDIO_API_KEY environment variable.');
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: params.model });

  // Convert messages to Gemini format
  // Gemini expects alternating user/model messages
  const history = [];
  const lastMessage = params.messages[params.messages.length - 1];

  for (let i = 0; i < params.messages.length - 1; i++) {
    const msg = params.messages[i];
    history.push({
      role: msg.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: msg.content }],
    });
  }

  const chat = model.startChat({ history });
  const result = await chat.sendMessage(lastMessage.content);
  const response = result.response;

  return {
    text: response.text(),
    usage: {
      promptTokens: response.usageMetadata?.promptTokenCount || 0,
      completionTokens: response.usageMetadata?.candidatesTokenCount || 0,
      totalTokens: response.usageMetadata?.totalTokenCount || 0,
    },
  };
}
