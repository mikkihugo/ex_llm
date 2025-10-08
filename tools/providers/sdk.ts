// SDK providers for OpenAI and Anthropic using the official clients.
// Bun-compatible, no CLI shelling required.
import { configureOpenAI } from "@ai-sdk/openai";
import { createAnthropic } from "@anthropic-ai/sdk";

// TODO: OpenAI tools are stubbed out - implement when needed
export const openaiLanguageModel = configureOpenAI({
  apiKey: process.env.OPENAI_API_KEY ?? "",
});

// Anthropic HTTP SDK
const anthropicClient = createAnthropic({
  apiKey: process.env.ANTHROPIC_API_KEY ?? "",
});

// TODO: Anthropic chat is stubbed out - implement when needed
export async function anthropicChat(prompt: string, opts: { model?: string } = {}) {
  const model = opts.model ?? process.env.CLAUDE_DEFAULT_MODEL ?? "sonnet";
  
  // Stub implementation - returns empty response
  console.log("Anthropic chat called (stubbed):", model, prompt.substring(0, 50) + "...");
  
  return "Anthropic chat is currently stubbed out - functionality not implemented";
}
