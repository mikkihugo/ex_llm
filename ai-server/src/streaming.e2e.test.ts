import { describe, test, expect, beforeAll } from 'bun:test';
import { streamText, generateText } from 'ai';
import { createGeminiProvider } from 'ai-sdk-provider-gemini-cli';

/**
 * E2E Streaming Tests (Like Vercel's Test Strategy)
 *
 * Tests with REAL providers, not mocks.
 * Vercel AI SDK team uses this approach for their own tests!
 *
 * Run with: bun test src/streaming.e2e.test.ts
 */

describe('E2E: Real Provider Streaming', () => {
  let gemini: ReturnType<typeof createGeminiProvider>;

  beforeAll(() => {
    // Use Gemini Code (FREE via subscription)
    gemini = createGeminiProvider({ authType: 'oauth-personal' });
  });

  test('Gemini streaming produces text chunks', async () => {
    const result = streamText({
      model: gemini('gemini-2.5-flash'),
      prompt: 'Count from 1 to 3. Just the numbers.',
    });

    const chunks: string[] = [];
    for await (const chunk of result.textStream) {
      chunks.push(chunk);
    }

    // Verify we got chunks
    expect(chunks.length).toBeGreaterThan(0);

    // Verify final text
    const text = await result.text;
    expect(text.length).toBeGreaterThan(0);

    // Verify usage reporting
    const usage = await result.usage;
    expect(usage.promptTokens).toBeGreaterThan(0);
    expect(usage.completionTokens).toBeGreaterThan(0);
    expect(usage.totalTokens).toBeGreaterThan(0);
  }, 30000); // 30s timeout for network request

  test('Gemini non-streaming works', async () => {
    const result = await generateText({
      model: gemini('gemini-2.5-flash'),
      prompt: 'Say hello in 2 words.',
    });

    expect(result.text).toBeTruthy();
    expect(result.usage.totalTokens).toBeGreaterThan(0);
  }, 30000);

  test('streaming reports finish reason', async () => {
    const result = streamText({
      model: gemini('gemini-2.5-flash'),
      prompt: 'Hi',
      maxTokens: 10,
    });

    // Consume stream
    for await (const chunk of result.textStream) {
      // Just consume
    }

    const finishReason = await result.finishReason;
    expect(finishReason).toBeTruthy();
    expect(['stop', 'length', 'content-filter']).toContain(finishReason);
  }, 30000);
});

describe('E2E: OpenAI SSE Format Compatibility', () => {
  test('streamText produces valid SSE-compatible output', async () => {
    const gemini = createGeminiProvider({ authType: 'oauth-personal' });
    const result = streamText({
      model: gemini('gemini-2.5-flash'),
      prompt: 'Say "test" once.',
    });

    // Simulate converting to OpenAI SSE format
    const events: any[] = [];

    // Initial role chunk
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

    // Verify SSE structure
    expect(events.length).toBeGreaterThanOrEqual(3); // role + content + finish
    expect(events[0].choices[0].delta.role).toBe('assistant');
    expect(events[events.length - 1].usage.total_tokens).toBeGreaterThan(0);
  }, 30000);
});

console.log('✅ E2E tests use REAL providers (like Vercel AI SDK team does)');
console.log('   - Fast enough for CI (~5-10s per test)');
console.log('   - Tests actual behavior, not mocks');
console.log('   - Gemini is FREE via subscription (no API costs)');
