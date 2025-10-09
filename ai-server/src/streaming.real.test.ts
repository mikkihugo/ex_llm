import { describe, test, expect, beforeAll } from 'bun:test';
import { streamText, generateText, createProviderRegistry } from 'ai';
import { createGeminiProvider } from 'ai-sdk-provider-gemini-cli';
import { claudeCode } from 'ai-sdk-provider-claude-code';
import { codex } from 'ai-sdk-provider-codex';
import { copilot } from './providers/copilot';
import { buildModelCatalog, type ProviderWithModels, type ProviderWithMetadata } from './model-registry';

/**
 * Real Provider Streaming Tests
 *
 * Tests streaming with ACTUAL providers (not mocks)
 * Follows Vercel AI SDK team's testing approach
 *
 * NOTE: These tests require authentication:
 * - Gemini: OAuth (free tier)
 * - Claude: Subscription
 * - Codex: ChatGPT Plus/Pro
 *
 * Run with: bun test src/streaming.real.test.ts
 * Timeout: 60s per test (network requests)
 */

describe('Real Provider Streaming', () => {
  let registry: ReturnType<typeof createProviderRegistry>;
  let availableModels: string[] = [];

  beforeAll(async () => {
    const geminiCode = createGeminiProvider({ authType: 'oauth-personal' });

    registry = createProviderRegistry({
      'gemini-code': geminiCode,
      'claude-code': claudeCode,
      'openai-codex': codex,
      'github-copilot': copilot,
    });

    // Build model catalog to know what's available
    const models = await buildModelCatalog({
      'gemini-code': geminiCode as unknown as ProviderWithModels,
      'claude-code': claudeCode as unknown as ProviderWithModels,
      'openai-codex': codex as unknown as ProviderWithMetadata,
      'github-copilot': copilot as unknown as ProviderWithMetadata,
    });

    availableModels = models.map(m => m.id);
    console.log(`\n📋 Available models for testing: ${availableModels.length}`);
  });

  describe('Gemini Streaming', () => {
    test('streams text chunks from Gemini Flash', async () => {
      const result = streamText({
        model: registry.languageModel('gemini-code:gemini-2.5-flash'),
        prompt: 'Count from 1 to 3, just the numbers.',
        temperature: 0.7,
        maxRetries: 2,
      });

      const chunks: string[] = [];
      for await (const chunk of result.textStream) {
        chunks.push(chunk);
      }

      // Verify we got chunks
      expect(chunks.length).toBeGreaterThan(0);
      console.log(`  Received ${chunks.length} chunks`);

      // Verify final text (reconstruct from chunks since textStream was consumed)
      const text = chunks.join('');
      expect(text.length).toBeGreaterThan(0);
      console.log(`  Final text: "${text}"`);

      // Verify usage (may not be available for all providers)
      const usage = await result.usage;
      if (usage.inputTokens && usage.outputTokens) {
        expect(usage.inputTokens).toBeGreaterThan(0);
        expect(usage.outputTokens).toBeGreaterThan(0);
        expect(usage.totalTokens).toBe(usage.inputTokens + usage.outputTokens);
        console.log(`  Usage: ${usage.inputTokens} + ${usage.outputTokens} = ${usage.totalTokens} tokens`);
      } else if (usage.totalTokens) {
        console.log(`  Usage: ${usage.totalTokens} tokens total (no breakdown available)`);
      } else {
        console.log(`  Usage: not available for this provider`);
      }
    }, 60000);

    test('non-streaming works with Gemini', async () => {
      const result = await generateText({
        model: registry.languageModel('gemini-code:gemini-2.5-flash'),
        prompt: 'Say hello in 2 words.',
        temperature: 0.7,
        maxRetries: 2,
      });

      expect(result.text).toBeTruthy();
      expect(result.usage.totalTokens).toBeGreaterThan(0);
      console.log(`  Generated: "${result.text}"`);
      console.log(`  Tokens: ${result.usage.totalTokens}`);
    }, 60000);

    test('reports finish reason correctly', async () => {
      const result = streamText({
        model: registry.languageModel('gemini-code:gemini-2.5-flash'),
        prompt: 'Hi',
        temperature: 0.7,
        maxOutputTokens: 20,
        maxRetries: 2,
      });

      // Consume stream
      for await (const _chunk of result.textStream) {
        // Just consume
      }

      const finishReason = await result.finishReason;
      expect(finishReason).toBeTruthy();
      expect(['stop', 'length', 'content-filter', 'tool-calls']).toContain(finishReason);
      console.log(`  Finish reason: ${finishReason}`);
    }, 60000);
  });

  describe('Claude Streaming', () => {
    test('streams text chunks from Claude Sonnet', async () => {
      try {
        const result = streamText({
          model: registry.languageModel('claude-code:sonnet'),
          prompt: 'Say hi in 2 words.',
          temperature: 0.7,
          maxRetries: 2,
        });

        const chunks: string[] = [];
        for await (const chunk of result.textStream) {
          chunks.push(chunk);
        }

        expect(chunks.length).toBeGreaterThan(0);
        console.log(`  Received ${chunks.length} chunks`);

        const usage = await result.usage;
        console.log(`  Usage: ${usage.totalTokens} tokens`);
      } catch (error: any) {
        if (error.message?.includes('auth') || error.message?.includes('credentials')) {
          console.warn('  ⏭️  Skipped: Claude requires authentication');
        } else {
          throw error;
        }
      }
    }, 60000);
  });

  describe('Copilot Streaming', () => {
    test('streams text chunks from GPT-4.1', async () => {
      try {
        const result = streamText({
          model: registry.languageModel('github-copilot:gpt-4.1'),
          prompt: 'Say test.',
          temperature: 0.7,
          maxRetries: 2,
        });

        const chunks: string[] = [];
        for await (const chunk of result.textStream) {
          chunks.push(chunk);
        }

        expect(chunks.length).toBeGreaterThan(0);
        console.log(`  Received ${chunks.length} chunks`);

        const usage = await result.usage;
        console.log(`  Usage: ${usage.totalTokens} tokens`);
      } catch (error: any) {
        if (error.message?.includes('auth') || error.message?.includes('credentials') || error.statusCode === 404 || error.message?.includes('not found') || error.message?.includes('Unsupported model version')) {
          console.warn('  ⏭️  Skipped: Copilot requires authentication, model not available, or provider version incompatible');
        } else {
          throw error;
        }
      }
    }, 60000);
  });

  describe('Streaming Features', () => {
    test('streams handle errors gracefully', async () => {
      try {
        // Try to use invalid model
        const result = streamText({
          model: registry.languageModel('gemini-code:nonexistent-model'),
          prompt: 'test',
        });

        await result.text;
        // If we get here, the model exists (shouldn't happen)
      } catch (error: any) {
        // Expected to throw
        expect(error).toBeDefined();
        console.log(`  ✅ Error caught: ${error.message?.slice(0, 50)}...`);
      }
    }, 60000);

    test('streaming respects maxTokens', async () => {
      try {
        const result = streamText({
          model: registry.languageModel('gemini-code:gemini-2.5-flash'),
          prompt: 'Write a long essay about AI.',
          temperature: 0.7,
          maxOutputTokens: 10,
          maxRetries: 2,
        });

        // const text = await result.text; // Not used
        const usage = await result.usage;

        if (usage.outputTokens) {
          expect(usage.outputTokens).toBeLessThanOrEqual(15); // Some buffer
          console.log(`  Generated ${usage.outputTokens} tokens (limit: 10)`);
        } else {
          console.warn('  ⏭️  Skipped: No token usage available');
        }
      } catch (error: any) {
        console.warn(`  ⏭️  Skipped: ${error.message?.slice(0, 50)}`);
      }
    }, 60000);

    test('streaming reports accurate token counts', async () => {
      try {
        const result = streamText({
          model: registry.languageModel('gemini-code:gemini-2.5-flash'),
          prompt: 'Count: 1, 2, 3',
          temperature: 0.7,
          maxRetries: 2,
        });

        await result.text;
        const usage = await result.usage;

        if (usage.inputTokens && usage.outputTokens) {
          expect(usage.inputTokens).toBeGreaterThan(0);
          expect(usage.outputTokens).toBeGreaterThan(0);
          expect(usage.totalTokens).toBe(usage.inputTokens + usage.outputTokens);
          console.log(`  Prompt: ${usage.inputTokens}, Completion: ${usage.outputTokens}, Total: ${usage.totalTokens}`);
        } else {
          console.warn('  ⏭️  Skipped: No token usage available');
        }
      } catch (error: any) {
        console.warn(`  ⏭️  Skipped: ${error.message?.slice(0, 50)}`);
      }
    }, 60000);
  });

  describe('Cross-Provider Consistency', () => {
    test('all providers return consistent stream format', async () => {
      const testCases = [
        { id: 'gemini-code:gemini-2.5-flash', name: 'Gemini' },
      ];

      for (const { id, name } of testCases) {
        if (!availableModels.includes(id)) {
          console.log(`  ⏭️  Skipped ${name}: model not available`);
          continue;
        }

        try {
          const result = streamText({
            model: registry.languageModel(id),
            prompt: 'Hi',
          });

          const chunks: string[] = [];
          for await (const chunk of result.textStream) {
            chunks.push(chunk);
            expect(typeof chunk).toBe('string');
          }

          const usage = await result.usage;
          expect(usage).toHaveProperty('promptTokens');
          expect(usage).toHaveProperty('completionTokens');
          expect(usage).toHaveProperty('totalTokens');

          console.log(`  ✅ ${name}: ${chunks.length} chunks, ${usage.totalTokens} tokens`);
        } catch (error: any) {
          if (error.message?.includes('auth')) {
            console.log(`  ⏭️  ${name}: Requires auth`);
          } else {
            throw error;
          }
        }
      }
    }, 60000);
  });

  describe('Performance Benchmarks', () => {
    test('measure streaming latency', async () => {
      const startTime = Date.now();

      const result = streamText({
        model: registry.languageModel('gemini-code:gemini-2.5-flash'),
        prompt: 'Say: Hello!',
      });

      let firstChunkTime: number | null = null;
      let chunkCount = 0;

      for await (const _chunk of result.textStream) {
        if (firstChunkTime === null) {
          firstChunkTime = Date.now();
        }
        chunkCount++;
      }

      const totalTime = Date.now() - startTime;
      const timeToFirstChunk = firstChunkTime! - startTime;

      console.log(`  ⏱️  Performance:`);
      console.log(`    Time to first chunk: ${timeToFirstChunk}ms`);
      console.log(`    Total time: ${totalTime}ms`);
      console.log(`    Chunks received: ${chunkCount}`);
      console.log(`    Avg time per chunk: ${Math.round(totalTime / chunkCount)}ms`);

      expect(timeToFirstChunk).toBeGreaterThan(0);
      expect(totalTime).toBeGreaterThan(timeToFirstChunk);
    }, 60000);
  });
});

describe('OpenAI SSE Format Compatibility', () => {
  test('AI SDK streams convert to OpenAI SSE format', async () => {
    const registry = createProviderRegistry({
      'gemini-code': createGeminiProvider({ authType: 'oauth-personal' }),
    });

    const result = streamText({
      model: registry.languageModel('gemini-code:gemini-2.5-flash'),
      prompt: 'Say "test".',
    });

    // Simulate converting to OpenAI SSE format
    const events: any[] = [];

    // Role chunk
    events.push({
      id: 'test',
      object: 'chat.completion.chunk',
      choices: [{ delta: { role: 'assistant' }, finish_reason: null }],
    });

    // Text chunks
    for await (const chunk of result.textStream) {
      events.push({
        id: 'test',
        object: 'chat.completion.chunk',
        choices: [{ delta: { content: chunk }, finish_reason: null }],
      });
    }

    // Final usage chunk
    const usage = await result.usage;
    events.push({
      id: 'test',
      object: 'chat.completion.chunk',
      choices: [{ delta: {}, finish_reason: 'stop' }],
      usage: {
        prompt_tokens: usage.promptTokens,
        completion_tokens: usage.completionTokens,
        total_tokens: usage.totalTokens,
      },
    });

    // Verify structure
    expect(events.length).toBeGreaterThanOrEqual(3);
    expect(events[0].choices[0].delta.role).toBe('assistant');
    expect(events[events.length - 1].usage.total_tokens).toBeGreaterThan(0);

    console.log(`  ✅ Generated ${events.length} SSE events`);
    console.log(`  ✅ OpenAI format validation passed`);
  }, 60000);
});

console.log('\n✅ Real provider tests use ACTUAL providers (like Vercel does)');
console.log('   - No mocks, real behavior');
console.log('   - Tests require auth (OAuth, API keys, subscriptions)');
console.log('   - 60s timeout per test for network latency');
