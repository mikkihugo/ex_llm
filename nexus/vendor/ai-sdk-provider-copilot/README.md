# AI SDK Provider for GitHub Copilot

AI SDK v2 provider for GitHub Copilot API with full AI SDK tools support.

## What Changed

**Before**: Direct REST API call (no AI SDK tools support)
**After**: Full AI SDK provider (supports tools, streaming, etc.)

## Features

- ✅ **AI SDK tools support** - Tools defined in AI SDK, Elixir executes them
- ✅ **Streaming support** - Real-time streaming responses
- ✅ **Multiple models** - GPT-4.1, Grok Coder 1
- ✅ **Subscription-based** - GitHub Copilot subscription required
- ✅ **AI SDK v2 compatible** - Works with `generateText`, `streamText`, etc.

## Installation

```bash
cd llm-server/vendor/ai-sdk-provider-copilot
bun install
bun run build
```

## Usage

### Basic Usage

```typescript
import { copilot } from 'ai-sdk-provider-copilot';
import { generateText } from 'ai';

const result = await generateText({
  model: copilot('gpt-4.1'),
  prompt: 'Write a function to calculate fibonacci',
});

console.log(result.text);
```

### With AI SDK Tools (Elixir Executes)

```typescript
import { copilot } from 'ai-sdk-provider-copilot';
import { generateText } from 'ai';
import { z } from 'zod';

const result = await generateText({
  model: copilot('gpt-4.1'),
  prompt: 'Calculate fibonacci(10)',
  tools: {
    fibonacci: {
      description: 'Calculate fibonacci number',
      parameters: z.object({
        n: z.number().describe('The fibonacci index'),
      }),
      // Elixir will execute this
    },
  },
});
```

### Streaming

```typescript
import { copilot } from 'ai-sdk-provider-copilot';
import { streamText } from 'ai';

const { textStream } = await streamText({
  model: copilot('gpt-4.1'),
  prompt: 'Write a long story',
});

for await (const chunk of textStream) {
  process.stdout.write(chunk);
}
```

## Available Models

| Model ID | Description | Context Window | Cost |
|----------|-------------|----------------|------|
| `gpt-4.1` | GPT-4.1 | 128K | Subscription |
| `grok-coder-1` | xAI Grok Coder 1 | 128K | Subscription |

## Configuration Options

```typescript
interface CopilotModelConfig {
  /** GitHub token for authentication */
  token?: string;

  /** Log level for debugging */
  logLevel?: 'error' | 'warn' | 'info' | 'debug';
}
```

## Authentication

### Method 1: Environment Variables
```bash
export COPILOT_TOKEN=ghp_...
# or
export GITHUB_TOKEN=ghp_...
```

### Method 2: Direct Token
```typescript
const result = await generateText({
  model: copilot('gpt-4.1', { token: 'ghp_...' }),
  prompt: 'Hello',
});
```

### Method 3: OAuth Function (Recommended)
```typescript
import { getCopilotAccessToken } from './github-copilot-oauth';

const result = await generateText({
  model: copilot('gpt-4.1', {
    token: getCopilotAccessToken  // Function that handles OAuth flow
  }),
  prompt: 'Hello',
});
```

**OAuth Flow Benefits:**
- ✅ Automatic token refresh
- ✅ Token caching with expiration
- ✅ GitHub OAuth → Copilot API token exchange
- ✅ Handles `https://api.github.com/copilot_internal/v2/token` endpoint

## Prerequisites

1. **GitHub Copilot subscription**
2. **GitHub token** with Copilot access

## Comparison with Other Providers

| Provider | AI SDK Tools | MCP | Streaming | Context | Cost |
|----------|--------------|-----|-----------|---------|------|
| **Copilot** | ✅ Yes | ❌ No | ✅ Yes | 128K | Subscription |
| Cursor | ❌ No | ✅ Yes | ❌ No | 128K | Subscription |
| Codex | ✅ Yes | ❌ No | ✅ Yes | 200K | Subscription |
| Gemini | ✅ Yes | ❌ No | ✅ Yes | 1M | $0 FREE |

## How It Works

1. Implements AI SDK `LanguageModelV1` interface
2. Calls `https://api.githubcopilot.com/chat/completions`
3. Converts AI SDK tools to OpenAI function format
4. Returns tool calls for Elixir to execute
5. Supports streaming via SSE (Server-Sent Events)

## Development

```bash
# Install dependencies
bun install

# Build TypeScript
bun run build

# Watch mode
bun run dev
```

## License

MIT
