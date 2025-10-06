# Using Cursor Agent as a FREE Tool-Enabled LLM

## The Opportunity

**Cursor `auto` model is unlimited with Cursor Pro/Business subscription ($20/mo).**

This creates a unique opportunity for MCP-enabled LLMs:
- 🔧 **MCP servers**: The ONLY subscription provider with MCP support
- 🔒 **Safe**: Built-in read-only mode
- 🤖 **Smart**: Auto-selects best model (GPT-4.1, Sonnet 4, etc.)
- 💰 **Unlimited**: No per-token costs within subscription

**Note**: Gemini is TRULY free ($0 cost) but doesn't support MCP servers.

## Comparison: Cost & Capabilities

| Provider | Cost | Tools | Context | Notes |
|----------|------|-------|---------|-------|
| **Gemini Code** | 🆓 **$0 FREE** | AI SDK tools (Elixir) | **1M** | Just need Google account! |
| **Cursor auto** | $20/mo | MCP servers | 128K | Unknown model, read-only mode |
| **Codex** | $20-30/mo | AI SDK tools (Elixir) | 200K | GPT-5, no MCP (yet) |
| Claude Code | $20-30/mo | AI SDK tools (Elixir) | 200K | Sonnet/Opus, no MCP |

**Key Insight**: Gemini is the ONLY truly free option ($0 cost). All others require paid subscriptions.

## Use Cases for Cursor as FREE MCP Provider

### 1. Chat Assistant with File Access

```typescript
import { cursor } from 'ai-sdk-provider-cursor';
import { generateText } from 'ai';

const result = await generateText({
  model: cursor('auto', {
    approvalPolicy: 'read-only',
    mcpServers: {
      'filesystem': {
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-filesystem', process.cwd()],
      },
    },
  }),
  prompt: 'What files are in this project? Summarize the main functionality.',
});
```

**Result**: FREE chat LLM that can read your codebase via MCP filesystem server.

### 2. Git Analysis Assistant

```typescript
const result = await generateText({
  model: cursor('auto', {
    approvalPolicy: 'read-only',
    mcpServers: {
      'git': {
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-git'],
      },
    },
  }),
  prompt: 'Analyze the last 10 commits and identify the main changes.',
});
```

**Result**: FREE git analysis without paying per token.

### 3. Multi-Tool Research Assistant

```typescript
const result = await generateText({
  model: cursor('auto', {
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
      'github': {
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-github'],
        env: { GITHUB_TOKEN: process.env.GITHUB_TOKEN },
      },
    },
  }),
  prompt: 'Research this codebase: files, git history, and related GitHub issues.',
});
```

**Result**: FREE multi-source research assistant.

### 4. Development Agent (Read-Only)

```typescript
const result = await generateText({
  model: cursor('auto', {
    approvalPolicy: 'read-only',
    workingDirectory: '/path/to/project',
    mcpServers: {
      'filesystem': {
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-filesystem', '/path/to/project'],
      },
    },
  }),
  prompt: 'Find all TODO comments in the codebase and categorize them by urgency.',
});
```

**Result**: FREE code analysis agent (read-only for safety).

## Architecture: How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                     Your Elixir Application                  │
│  (Singularity AI Server)                                    │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ├─ Sends request with MCP config
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│              AI SDK Provider (TypeScript/Bun)                │
│  ai-sdk-provider-cursor                                     │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ├─ Executes cursor-agent CLI
                  │  with --mcp-config flag
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    Cursor Agent CLI                          │
│  - Loads MCP servers                                        │
│  - Executes MCP tools internally                            │
│  - Returns results                                          │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ├─ MCP Server 1 (filesystem)
                  ├─ MCP Server 2 (git)
                  └─ MCP Server 3 (github)
```

**Key Points:**
1. **MCP tools execute inside Cursor Agent** (not in Elixir)
2. **Results returned as text** (not tool_calls)
3. **No token counting** (FREE with subscription)
4. **Unknown model** (Cursor chooses best)

## Limitations

### What You CAN'T Do

❌ **Custom AI SDK tools** - Cursor ignores AI SDK `tools` parameter
```typescript
// ❌ This won't work
const result = await generateText({
  model: cursor('auto'),
  tools: {
    myCustomTool: { /* ... */ }
  },
});
```

❌ **Streaming** - Cursor Agent CLI doesn't support streaming
```typescript
// ❌ This falls back to single chunk
const { textStream } = await streamText({
  model: cursor('auto'),
  prompt: 'Long response...',
});
```

❌ **Exact token counts** - Cursor doesn't provide token usage
```typescript
// ⚠️ Token counts are estimates only
const result = await generateText({
  model: cursor('auto'),
  prompt: 'Test',
});
console.log(result.usage); // Estimated, not exact
```

### What You CAN Do

✅ **MCP servers** - Full MCP support
✅ **Read-only mode** - Safe file operations
✅ **Multi-turn conversations** - Standard AI SDK messages
✅ **Long context** - 128K context window
✅ **FREE usage** - No per-token costs on `auto` model

## When to Use Each Provider (All "Free" via Subscriptions)

### Use Cursor when:
- ✅ You need MCP servers (filesystem, git, github, etc.)
- ✅ You need read-only safety (prevents accidental writes)
- ✅ You're okay with unknown model (Cursor chooses)
- ✅ You don't need streaming
- ✅ You don't need exact token counts

### Use Gemini when:
- 🆓 **You want $0 cost** (just need Google account)
- ✅ You need **1M context** (8x larger than Cursor)
- ✅ You need AI SDK custom tools (Elixir executes)
- ✅ You need streaming support
- ✅ You want a known model (Gemini 2.5 Flash/Pro)
- ✅ You need exact token counts
- ❌ You don't need MCP servers

### Use BOTH:
```typescript
// Cursor for MCP-based research
const research = await generateText({
  model: cursor('auto', {
    mcpServers: { /* filesystem, git, github */ },
  }),
  prompt: 'Research this codebase',
});

// Gemini for long-context analysis with custom tools
const analysis = await generateText({
  model: gemini('gemini-2.5-pro'),
  prompt: `Analyze this research:\n\n${research.text}`,
  tools: { /* custom Elixir tools */ },
});
```

## Cost Analysis

**Cursor Pro/Business: $20/month**
- Unlimited `auto` model usage
- Limited explicit model usage (GPT-4.1, Sonnet 4)
- MCP server support
- **Break-even**: ~10K-50K tokens/day (compared to paid APIs)

**Example savings:**
- OpenAI GPT-4: $10/M input tokens
- 50K tokens/day × 30 days = 1.5M tokens/month
- Cost with API: $15/month
- Cost with Cursor: $20/month (but UNLIMITED on `auto`)

**Verdict**: If you use 100K+ tokens/day, Cursor is significantly cheaper.

## Best Practices

### 1. Always Use `auto` for FREE Usage
```typescript
// ✅ FREE
model: cursor('auto')

// ❌ Paid (uses quota)
model: cursor('gpt-4.1')
model: cursor('sonnet-4')
```

### 2. Enable Read-Only Mode by Default
```typescript
model: cursor('auto', {
  approvalPolicy: 'read-only', // Safe by default
})
```

### 3. Configure MCP Servers Per Task
```typescript
// Research task: filesystem + git
const researchConfig = {
  mcpServers: {
    'filesystem': { /* ... */ },
    'git': { /* ... */ },
  },
};

// Analysis task: filesystem only
const analysisConfig = {
  mcpServers: {
    'filesystem': { /* ... */ },
  },
};
```

### 4. Handle Errors Gracefully
```typescript
try {
  const result = await generateText({
    model: cursor('auto', { /* ... */ }),
    prompt: 'Task',
  });
} catch (error) {
  if (error.message.includes('cursor-agent failed')) {
    console.error('Cursor Agent error:', error);
    // Fallback to Gemini (also free)
    return await generateText({
      model: gemini('gemini-2.5-flash'),
      prompt: 'Task',
    });
  }
}
```

## Summary

**Cursor Agent `auto` is a FREE tool-enabled LLM** that fills a unique niche:

| Need | Solution | Cost |
|------|----------|------|
| **$0 cost** | ✅ **Gemini Code** | **FREE** (Google account) |
| **MCP servers** | ✅ Cursor auto | $20/mo subscription |
| **AI SDK tools** | ✅ Gemini/Codex/Claude | $0 or $20-30/mo |
| **Large context (1M)** | ✅ Gemini Code | $0 |
| **Streaming** | ✅ Gemini/Codex/Claude | $0 or $20-30/mo |

**Recommendations**:
- **Want $0 cost?** → Use Gemini (1M context, AI SDK tools, streaming)
- **Need MCP servers?** → Use Cursor ($20/mo, read-only mode)
- **Need both?** → Use Gemini for most tasks, Cursor when you need MCP
