import { createLanguageModel } from "ai";

// TODO: OpenAI tools are stubbed out - implement when needed
export const openaiLanguageModel = createLanguageModel({
  doGenerate: async (options) => {
    // Stub implementation - returns empty response
    console.log("OpenAI tool called (stubbed):", options.model ?? "gpt-4o-mini");
    
    return {
      type: "text-generation",
      text: "OpenAI tool is currently stubbed out - functionality not implemented",
      usage: {
        inputTokens: 0,
        outputTokens: 0,
      },
    };
  },
});
