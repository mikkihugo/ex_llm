// SDK providers for OpenAI and Anthropic using the official clients.
// Bun-compatible, no CLI shelling required.
import { configureOpenAI } from "@ai-sdk/openai";
import { createAnthropic } from "@anthropic-ai/sdk";

export const openaiLanguageModel = configureOpenAI({
  apiKey: process.env.OPENAI_API_KEY ?? "",
});

// Anthropic HTTP SDK
const anthropicClient = createAnthropic({
  apiKey: process.env.ANTHROPIC_API_KEY ?? "",
});

export async function anthropicChat(prompt: string, opts: { model?: string } = {}) {
  const model = opts.model ?? process.env.CLAUDE_DEFAULT_MODEL ?? "sonnet";
  const response = await anthropicClient.messages.create({
    model,
    max_tokens: 1024,
    messages: [
      {
        role: "user",
        content: prompt,
      },
    ],
  });

  const message = response?.content?.[0];
  if (!message || message.type !== "text") {
    throw new Error("No text response from Anthropic");
  }

  return message.text;
}
