# AI SDK Testing Setup

## Overview

Comprehensive testing infrastructure for the refactored AI server using AI SDK's built-in testing utilities.

## Test Files Created

1. **`src/streaming.test.ts`** - AI SDK streaming tests
   - Uses `MockLanguageModelV2` for provider mocking
   - Uses `simulateReadableStream` for chunk simulation
   - Tests OpenAI SSE format conversion
   - 8 test cases covering core functionality

2. **`src/server.test.ts`** (existing) - Unit tests for utilities
   - 693 lines of comprehensive tests
   - Covers parsePort, token estimation, usage normalization, etc.

## AI SDK Testing Utilities

### MockLanguageModelV2

Mocks any language model provider (Gemini, Claude, Copilot, etc.):

```typescript
import { MockLanguageModelV2, simulateReadableStream } from 'ai/test';

const mockModel = new MockLanguageModelV2({
  provider: 'gemini-code',
  modelId: 'gemini-2.5-flash',
  doStream: async () => ({
    stream: simulateReadableStream({
      chunks: [
        { type: 'text-delta', delta: 'Hello ', id: '1' },
        { type: 'text-delta', delta: 'world', id: '2' },
        { type: 'finish', finishReason: 'stop', totalUsage: { promptTokens: 10, completionTokens: 5, totalTokens: 15 } },
      ],
    }),
    rawCall: { rawPrompt: null, rawSettings: {} },
  }),
});
```

### simulateReadableStream

Creates realistic streaming with delays:

```typescript
simulateReadableStream({
  chunks: [...],
  chunkDelayInMs: 10,        // Delay between chunks
  initialDelayInMs: 0,       // Initial delay before first chunk
})
```

### Key Chunk Types

**text-delta** (text streaming):
```typescript
{ type: 'text-delta', delta: 'text', id: 'unique-id' }
```

**finish** (stream end):
```typescript
{
  type: 'finish',
  finishReason: 'stop' | 'length' | 'content-filter' | 'tool-calls',
  totalUsage: { promptTokens: 10, completionTokens: 5, totalTokens: 15 }
}
```

**tool-call** (function calling):
```typescript
{
  type: 'tool-call',
  toolCallType: 'function',
  toolCallId: 'call_123',
  toolName: 'get_weather',
  args: { location: 'SF' }
}
```

## Running Tests

```bash
# All tests
bun test

# Specific test file
bun test src/streaming.test.ts

# Watch mode
bun test --watch

# Coverage
bun test --coverage
```

## Test Coverage

### Streaming Tests (`streaming.test.ts`)

1. ✅ Basic text streaming
2. ✅ Streaming with delays
3. ✅ Token usage reporting
4. ✅ Different finish reasons (stop, length, content-filter)
5. ✅ doStreamCalls tracking for debugging
6. ✅ Multiple provider simulation (Gemini, Claude, Copilot)
7. ✅ OpenAI SSE format conversion
8. ✅ Required OpenAI fields validation

### Utility Tests (`server.test.ts`)

- Port parsing
- Token estimation
- Usage normalization
- Message format conversion
- OAuth utilities (PKCE, JWT)
- JSON enforcement
- Model catalog merging

## Testing Best Practices

### 1. Use AI SDK Mocks

❌ **Don't** create manual mocks:
```typescript
const fakeStream = new ReadableStream({
  async start(controller) {
    controller.enqueue('Hello');
    // ... manual SSE formatting
  }
});
```

✅ **Do** use AI SDK utilities:
```typescript
const mockModel = new MockLanguageModelV2({
  doStream: async () => ({
    stream: simulateReadableStream({
      chunks: [
        { type: 'text-delta', delta: 'Hello', id: '1' },
        { type: 'finish', finishReason: 'stop', totalUsage: {...} },
      ],
    }),
    rawCall: { rawPrompt: null, rawSettings: {} },
  }),
});
```

### 2. Test All Providers Uniformly

```typescript
const providers = [
  { name: 'gemini-code', modelId: 'gemini-2.5-flash' },
  { name: 'claude-code', modelId: 'sonnet' },
  { name: 'github-copilot', modelId: 'gpt-4o' },
];

for (const { name, modelId } of providers) {
  const mock = new MockLanguageModelV2({
    provider: name,
    modelId,
    doStream: async () => ({...}),
  });

  // Same test for all providers
  const result = await streamText({ model: mock, messages: [...] });
  expect(result.text).toBe('Expected response');
}
```

### 3. Verify OpenAI Compatibility

```typescript
async function convertToOpenAISSE(result) {
  const events = [];

  // Role chunk
  events.push({
    id: 'chatcmpl-test',
    object: 'chat.completion.chunk',
    choices: [{ delta: { role: 'assistant' }, finish_reason: null }],
  });

  // Text chunks
  for await (const chunk of result.textStream) {
    events.push({
      id: 'chatcmpl-test',
      object: 'chat.completion.chunk',
      choices: [{ delta: { content: chunk }, finish_reason: null }],
    });
  }

  // Usage chunk
  const usage = await result.usage;
  events.push({
    id: 'chatcmpl-test',
    object: 'chat.completion.chunk',
    choices: [{ delta: {}, finish_reason: 'stop' }],
    usage: {
      prompt_tokens: usage.promptTokens,
      completion_tokens: usage.completionTokens,
      total_tokens: usage.totalTokens,
    },
  });

  return events;
}
```

### 4. Track Debug Information

```typescript
const mockModel = new MockLanguageModelV2({...});

await streamText({ model: mockModel, messages: [...] }).text;

// Verify calls
expect(mockModel.doStreamCalls).toHaveLength(1);
expect(mockModel.doStreamCalls[0].prompt[0].content[0].text).toBe('expected prompt');
```

## Dependencies

```json
{
  "dependencies": {
    "ai": "^5.0.60"
  },
  "devDependencies": {
    "msw": "^2.11.3",
    "bun-types": "latest"
  }
}
```

**Note:** `msw` is required by AI SDK's test utilities for HTTP mocking.

## Common Pitfalls

### ❌ Wrong chunk format
```typescript
{ type: 'text-delta', textDelta: 'Hello' }  // WRONG - should be 'delta'
{ type: 'text-delta', delta: 'Hello' }      // Missing 'id'
```

### ✅ Correct chunk format
```typescript
{ type: 'text-delta', delta: 'Hello', id: '1' }
```

### ❌ Wrong finish format
```typescript
{ type: 'finish', finishReason: 'stop', usage: {...} }  // WRONG - should be 'totalUsage'
```

### ✅ Correct finish format
```typescript
{
  type: 'finish',
  finishReason: 'stop',
  totalUsage: { promptTokens: 10, completionTokens: 5, totalTokens: 15 }
}
```

## Next Steps

1. ✅ Add tests for tool calling
2. ✅ Add tests for error handling
3. ✅ Add tests for retry logic (`maxRetries`)
4. ✅ Add E2E tests with real providers (optional, use sparingly)
5. ✅ Add performance benchmarks

## References

- [AI SDK Testing Docs](https://sdk.vercel.ai/docs/ai-sdk-core/testing)
- [AI SDK Error Handling](https://ai-sdk.dev/docs/ai-sdk-core/error-handling)
- [AI SDK Tools](https://ai-sdk.dev/docs/ai-sdk-core/tools-and-tool-calling)
- [MockLanguageModelV2 API](https://github.com/vercel/ai/tree/main/packages/ai/src/test)
