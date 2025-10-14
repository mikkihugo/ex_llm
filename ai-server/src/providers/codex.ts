/**
 * @file OpenAI Codex Provider
 * @description Direct integration with OpenAI Codex SDK for running Codex agents.
 * This provider offers access to Codex agents that can execute commands and make file changes.
 */

import { Codex } from '@openai/codex-sdk';
import { customProvider } from 'ai';

/**
 * Model metadata for OpenAI Codex provider
 */
export const CODEX_MODELS = [
  {
    id: 'gpt-5',
    displayName: 'GPT-5',
    description: 'GPT-5 via Codex SDK (pure text generation, no tools/commands/editing)',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: false, read: true, webSearch: true },
    cost: 'subscription',
    subscription: 'OpenAI Codex',
  },
  {
    id: 'gpt-5-codex',
    displayName: 'GPT-5 Codex',
    description: 'GPT-5 Codex via Codex SDK with full agent capabilities (commands & file editing)',
    contextWindow: 200000,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: true, read: true, webSearch: true },
    cost: 'subscription',
    subscription: 'OpenAI Codex',
  },
  {
    id: 'codex-agent',
    displayName: 'Codex Agent',
    description: 'OpenAI Codex agent with command execution and file editing capabilities',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: true, read: true, webSearch: true },
    cost: 'subscription',
    subscription: 'OpenAI Codex',
  },
  {
    id: 'codex-agent-safe',
    displayName: 'Codex Agent (Safe Mode)',
    description: 'Codex agent with read-only sandbox mode (can read files, no commands/editing)',
    contextWindow: 128000,
    capabilities: { completion: true, streaming: true, reasoning: true, vision: false, tools: false, read: true, webSearch: true },
    cost: 'subscription',
    subscription: 'OpenAI Codex',
  },
];

/**
 * Create Codex provider using Codex SDK
 */
function createCodexProvider() {
  // Initialize Codex client
  const codexClient = new Codex({
    // Will use environment variables or default configuration
  });

  // Create language models that wrap Codex threads
  const languageModels: Record<string, any> = {};

  for (const model of CODEX_MODELS) {
    languageModels[model.id] = {
      specificationVersion: 'v1',
      provider: 'codex',
      modelId: model.id,

      defaultObjectGenerationMode: 'json',
      supportedUrls: [],
      doGenerate: async (options: any) => {
        try {
          // Start a new thread for each request
          const thread = codexClient.startThread({
            // Use read-only mode for models with read capability, workspace-write for models with tools
            sandboxMode: (model.capabilities as any).read ? 'read-only' : 
                        model.capabilities.tools ? 'workspace-write' : 'read-only',
          });

          // Extract text from prompt
          const promptText = Array.isArray(options.prompt)
            ? options.prompt.map((msg: any) =>
                Array.isArray(msg.content)
                  ? msg.content.map((part: any) => part.text || '').join('')
                  : msg.content
              ).join('\n')
            : options.prompt;

          // Run the thread with the prompt
          const result = await thread.run(promptText);

          return {
            text: result.finalResponse,
            usage: result.usage ? {
              promptTokens: result.usage.input_tokens,
              completionTokens: result.usage.output_tokens,
              totalTokens: result.usage.input_tokens + result.usage.output_tokens,
            } : undefined,
            finishReason: 'stop',
            response: {
              id: `codex_${Date.now()}`,
              timestamp: new Date(),
              modelId: model.id,
            },
          };
        } catch (error) {
          console.error('Codex generation error:', error);
          throw new Error(`Codex API error: ${error instanceof Error ? error.message : String(error)}`);
        }
      },

      doStream: async function* (options: any) {
        try {
          // Start a new thread for each request
          const thread = codexClient.startThread({
            // Use read-only mode for models with read capability, workspace-write for models with tools
            sandboxMode: (model.capabilities as any).read ? 'read-only' : 
                        model.capabilities.tools ? 'workspace-write' : 'read-only',
          });

          // Extract text from prompt
          const promptText = Array.isArray(options.prompt)
            ? options.prompt.map((msg: any) =>
                Array.isArray(msg.content)
                  ? msg.content.map((part: any) => part.text || '').join('')
                  : msg.content
              ).join('\n')
            : options.prompt;

          // Run streamed thread
          const streamedResult = await thread.runStreamed(promptText);

          let accumulatedResponse = '';
          let usage: any = null;

          for await (const event of streamedResult.events) {
            switch (event.type) {
              case 'item.started':
              case 'item.updated':
                if (event.item.type === 'agent_message') {
                  const newText = event.item.text;
                  const delta = newText.slice(accumulatedResponse.length);
                  accumulatedResponse = newText;
                  if (delta) {
                    yield {
                      type: 'text-delta',
                      textDelta: delta,
                    };
                  }
                }
                break;
              case 'turn.completed':
                usage = event.usage;
                break;
              case 'error':
                throw new Error(`Codex streaming error: ${event.message}`);
            }
          }

          yield {
            type: 'finish',
            finishReason: 'stop',
            usage: usage ? {
              promptTokens: usage.input_tokens,
              completionTokens: usage.output_tokens,
              totalTokens: usage.input_tokens + usage.output_tokens,
            } : undefined,
          };
        } catch (error) {
          console.error('Codex streaming error:', error);
          throw new Error(`Codex streaming API error: ${error instanceof Error ? error.message : String(error)}`);
        }
      },
    };
  }  // Create custom provider
  const baseProvider = customProvider({
    languageModels,
  });

  // Add metadata accessor for integration tests
  return Object.assign(baseProvider, {
    getModelMetadata: () => CODEX_MODELS,
  });
}

/**
 * @const {object} codex
 * @description The singleton instance of the Codex provider with AI SDK v5 compatibility.
 */
export const codex = createCodexProvider();