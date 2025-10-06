# AI SDK Provider for Cursor Agent

AI SDK v2 provider for Cursor Agent CLI with read-only tools and MCP server support.

## 🎯 Key Insight: MCP-Enabled LLM

**Cursor is the ONLY subscription provider with MCP server support!**

This makes Cursor unique for $20/mo:
- ✅ **MCP servers**: Filesystem, Git, GitHub, and custom MCP tools
- ✅ **Unlimited**: No per-token costs on `auto` model
- ✅ **Read-only safety**: Built-in read-only mode for safe operations
- ✅ **Unknown model**: Cursor chooses best model (GPT-4.1, Sonnet, etc.) automatically

**Use case**: When you need MCP server capabilities (Gemini is $0 but no MCP support).

## Features

- ✅ **FREE auto model** - Unlimited usage with Cursor subscription
- ✅ **Read-only tools by default** - Safe file operations (read, search, grep, glob)
- ✅ **MCP server support** - Extensible with Model Context Protocol servers
- ✅ **Multiple models** - Auto (FREE) or explicit choice (GPT-4.1, Sonnet 4)
- ✅ **AI SDK v2 compatible** - Works with `generateText`, `streamText`, etc.

## Installation

```bash
cd ai-server/vendor/ai-sdk-provider-cursor
bun install
bun run build
```

## Usage

### Basic Usage (Read-Only)

```typescript
import { cursor } from 'ai-sdk-provider-cursor';
import { generateText } from 'ai';

const result = await generateText({
  model: cursor('auto', { approvalPolicy: 'read-only' }),
  prompt: 'Search for async functions in this codebase',
});

console.log(result.text);
```

### With MCP Servers

```typescript
import { cursor } from 'ai-sdk-provider-cursor';
import { generateText } from 'ai';

const result = await generateText({
  model: cursor('sonnet-4', {
    approvalPolicy: 'read-only',
    mcpServers: {
      'filesystem': {
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-filesystem', process.cwd()],
      },
      'git': {
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-git'],
      },
    },
  }),
  prompt: 'Analyze recent git commits and find code patterns',
});
```

## Available Models

| Model ID | Description | Context Window | Cost |
|----------|-------------|----------------|------|
| `auto` | Auto model selection (default) | 128K | **FREE** ✨ |
| `gpt-4.1` | GPT-4.1 | 128K | Paid (quota) |
| `sonnet-4` | Claude Sonnet 4 | 200K | Paid (quota) |
| `sonnet-4-thinking` | Claude Sonnet 4 with extended thinking | 200K | Paid (quota) |

**💡 Pro Tip**: Always use `auto` for FREE unlimited usage! Explicit models consume your request quota.

## Configuration Options

```typescript
interface CursorModelConfig {
  /** Model to use (default: 'auto') */
  model?: string;

  /** Log level for debugging */
  logLevel?: 'error' | 'warn' | 'info' | 'debug';

  /** Approval policy:
   * - 'read-only': Safe read operations only (default)
   * - 'never': Auto-approve all tools (use with caution!)
   */
  approvalPolicy?: 'read-only' | 'never';

  /** MCP servers to enable (name -> config) */
  mcpServers?: Record<string, MCPServerConfig>;

  /** Working directory for cursor-agent */
  workingDirectory?: string;

  /** Additional CLI flags */
  additionalFlags?: string[];
}
```

## Security: Read-Only by Default

The default `approvalPolicy: 'read-only'` restricts Cursor Agent to safe operations:

**Allowed Tools:**
- `read_file` - Read file contents
- `list_files` - List directory contents
- `search_files` - Search for files
- `grep` - Search file contents
- `glob` - Pattern matching
- MCP tools (if configured)

**Blocked Tools:**
- `write_file` - ❌ No file writing
- `edit_file` - ❌ No file editing
- `shell` - ❌ No shell execution
- `bash` - ❌ No bash commands
- `execute` - ❌ No arbitrary execution

## Prerequisites

1. **Cursor subscription** (Pro or Business)
2. **cursor-agent CLI installed**:
   ```bash
   curl https://cursor.com/install -fsSL | bash
   ```
3. **Authentication**:
   ```bash
   cursor-agent login
   ```

## How It Works

1. Implements AI SDK `LanguageModelV1` interface
2. Executes `cursor-agent` CLI with `--output-format stream-json`
3. Parses JSON stream to extract:
   - Response text
   - Tool calls (if any)
   - Finish reason
4. Estimates token usage (Cursor Agent doesn't provide exact counts)

## MCP Server Examples

### Filesystem Server
```typescript
mcpServers: {
  'filesystem': {
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-filesystem', '/path/to/project'],
  },
}
```

### Git Server
```typescript
mcpServers: {
  'git': {
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-git'],
  },
}
```

### Custom MCP Server
```typescript
mcpServers: {
  'my-server': {
    command: '/path/to/my-mcp-server',
    args: ['--port', '3000'],
    env: { API_KEY: 'secret' },
  },
}
```

## Limitations

### ⚠️ CRITICAL: No Custom AI SDK Tools

**Cursor Agent CLI does NOT support custom tools from AI SDK's `tools` parameter.**

```typescript
// ❌ THIS WILL NOT WORK - Tools will be ignored!
const result = await generateText({
  model: cursor('auto'),
  prompt: 'Calculate 2+2',
  tools: {
    calculate: {
      description: 'Perform calculation',
      parameters: z.object({ expression: z.string() }),
      execute: async ({ expression }) => eval(expression),
    },
  },
});
```

**Solutions:**

**Option 1: Use MCP Servers Instead** ✅
```typescript
const result = await generateText({
  model: cursor('auto', {
    mcpServers: {
      'calculator': {
        command: 'npx',
        args: ['-y', '@your-org/mcp-calculator-server'],
      },
    },
  }),
  prompt: 'Calculate 2+2',
});
```

**Option 2: Use Codex or Claude Code** ✅
```typescript
import { codex } from 'ai-sdk-provider-codex';

const result = await generateText({
  model: codex('gpt-5-codex'),
  prompt: 'Calculate 2+2',
  tools: {
    calculate: { /* custom tool works here */ },
  },
});
```

### Other Limitations

1. **No native streaming** - Falls back to single-chunk response
2. **No exact token counts** - Uses byte-based estimation
3. **CLI-based** - Slower than native API (overhead of process spawning)
4. **Subscription required** - No free tier like Gemini

## Comparison with Other Providers

| Feature | Cursor | Codex | Claude Code |
|---------|--------|-------|-------------|
| **Cost** | Subscription | Subscription | Subscription |
| **Custom AI SDK Tools** | ❌ No | ✅ Yes | ✅ Yes |
| **MCP Support** | ✅ Yes | ✅ Yes | ❌ No |
| **Built-in Tools** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Read-only Mode** | ✅ Yes | ✅ Yes | ❌ No |
| **Streaming** | ❌ No | ✅ Yes | ✅ Yes |

### When to Use Each Provider

**Use Cursor Agent when:**
- 🆓 **You want FREE tool-enabled LLM** (auto model)
- ✅ You need MCP server extensibility
- ✅ You need read-only safety
- ✅ You're okay with unknown model (Cursor chooses best)
- ✅ You don't need AI SDK custom tools (MCP only)

**Use Codex when:**
- ✅ You need custom AI SDK tools (Elixir executes)
- ✅ You need streaming
- ✅ You want GPT-5/GPT-5-Codex specifically
- ❌ You're okay paying per request

**Use Claude Code when:**
- ✅ You need custom AI SDK tools (Elixir executes)
- ✅ You need streaming
- ✅ You prefer Claude models (Sonnet/Opus)
- ❌ You don't need MCP servers

**Use Gemini Code when:**
- 🆓 **You want $0 cost** (just need Google account)
- ✅ You need **1M context** window (8x larger than Cursor)
- ✅ You need custom AI SDK tools (Elixir executes)
- ✅ You need streaming support
- ❌ You don't need MCP servers

## Troubleshooting

### "cursor-agent not found"
```bash
# Install cursor-agent CLI
curl https://cursor.com/install -fsSL | bash

# Verify installation
cursor-agent --version
```

### "Authentication required"
```bash
# Login to Cursor
cursor-agent login
```

### "Permission denied"
- Check that `cursor-agent` is executable
- Verify Cursor subscription is active

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
