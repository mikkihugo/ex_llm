import { createLanguageModel } from "ai";

export const openaiLanguageModel = createLanguageModel({
  doGenerate: async (options) => {
    const { openai, messages } = await import("./sdk.ts");
    const model = options.model ?? "gpt-4o-mini";
    const prompt = messages ?? [];

    const client = openai({ apiKey: process.env.OPENAI_API_KEY ?? "" });

    const result = await client.chat.completions.create({
      model,
      messages: prompt as any,
    });

    const text = result.choices[0]?.message?.content ?? "";

    return {
      type: "text-generation",
      text,
      usage: {
        inputTokens: result.usage?.prompt_tokens ?? 0,
        outputTokens: result.usage?.completion_tokens ?? 0,
      },
    };
  },
});
