# ai-sdk-provider-codex

Vercel AI SDK provider for OpenAI Codex CLI.

## Installation

```bash
npm install ai-sdk-provider-codex
```

## Usage

```typescript
import { generateText } from 'ai';
import { codex } from 'ai-sdk-provider-codex';

const result = await generateText({
  model: codex('gpt-5-codex'),
  prompt: 'Write a function to calculate fibonacci numbers',
});

console.log(result.text);
```

## Configuration

```typescript
import { codex } from 'ai-sdk-provider-codex';

const model = codex('gpt-5-codex', {
  logLevel: 'error',
  approvalPolicy: 'never', // 'always' | 'never' | 'auto'
  mcpServers: {
    // MCP server configuration
  }
});
```

## Features

- ✅ Text generation via Codex CLI
- ✅ MCP tool support (tools are executed by Codex internally)
- ✅ Multiple model support (gpt-5-codex, o3-mini-codex, etc.)
- ⚠️  Streaming support (limited - returns full response as single chunk)

## Tool Support

Codex handles tool execution internally via MCP servers. When tools are called:

1. AI SDK sends request with tools
2. Codex decides to call MCP tool
3. Tool is executed by Codex (not by AI SDK)
4. Result is included in response text

This is different from other AI SDK providers where tools are executed externally.

## License

MIT
