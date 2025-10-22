# Codex Integration with Builtin Tool Filtering

## Overview

Singularity uses a **custom Codex build** with builtin tool filtering disabled. This ensures ALL tools come from Elixir via MCP, giving tools access to:

- ✅ Knowledge base (RAG)
- ✅ Quality standards
- ✅ Templates
- ✅ Real codebase (not sandbox)
- ✅ Elixir orchestration

## Architecture

```
Elixir (singularity)
   ↓ NATS: "ai.llm.request" (model: "gpt-5-codex")
TypeScript AI Server (nats-handler.ts)
   ↓ Calls Codex provider
AI SDK Provider (vendor/ai-sdk-provider-codex)
   ↓ Uses custom Codex binary
Custom Codex Binary (llm-server/bin/codex)
   ↓ Builtin tools DISABLED
   ↓ Only uses tools from MCP
Elixir MCP Server
   ↓ Provides: shell, read_file, write_file, etc.
   ↓ With: RAG, templates, quality standards
```

## Setup

### 1. Build Custom Codex

```bash
cd llm-server
./scripts/build-codex.sh
```

This will:
- Build Codex from `vendor/codex` (feat/builtin-tool-filtering branch)
- Copy binary to `llm-server/bin/codex`
- Verify the binary is executable

### 2. Configure Codex

The config at `llm-server/config/codex.config.toml` disables all builtin tools:

```toml
[builtin_tools]
include = []  # Empty = disable ALL builtin tools

[mcp_servers.singularity]
url = "http://localhost:4000/mcp"  # Elixir app MCP endpoint
```

### 3. Test Tool Filtering

**Verify builtin tools are disabled:**

```bash
cd llm-server
./bin/codex --list-tools --config config/codex.config.toml
```

Should show:
- ❌ NO `local_shell`
- ❌ NO `read_file`
- ❌ NO `write_file`
- ❌ NO `list_dir`
- ✅ ONLY MCP tools from Elixir

## Development

### Codex Source

- **Location:** `vendor/codex/` (git submodule/vendored)
- **Branch:** `feat/builtin-tool-filtering`
- **Upstream:** https://github.com/mikkihugo/codex (fork)
- **Original:** https://github.com/openai/codex

### Rebuild After Changes

```bash
cd llm-server
./scripts/build-codex.sh
```

### Run Tests

```bash
cd ../vendor/codex/codex-rs
cargo test builtin_tool_filtering
```

## Usage from Elixir

```elixir
# Call Codex via NATS
Singularity.LLM.Service.call("gpt-5-codex", [
  %{role: "user", content: "Write a function to parse JSON"}
], provider: "codex")

# Codex will:
# 1. Receive request via llm-server
# 2. NOT see builtin tools (shell, read_file, etc.)
# 3. ONLY see tools from Elixir MCP server
# 4. Tools have access to RAG, templates, quality standards
```

## Why Custom Build?

**Problem with official Codex:**
- Builtin tools bypass Elixir orchestration
- No access to knowledge base
- No access to quality standards
- No access to templates
- Writes to sandbox, not real codebase

**Solution:**
- Disable ALL builtin tools
- Provide ALL tools via Elixir MCP
- Tools have full access to Singularity infrastructure

## Files

```
llm-server/
├── bin/
│   └── codex                    # Custom Codex binary (gitignored)
├── config/
│   └── codex.config.toml        # Tool filtering config
├── scripts/
│   └── build-codex.sh           # Build script
├── vendor/
│   └── ai-sdk-provider-codex/   # AI SDK wrapper
└── README_CODEX.md              # This file

vendor/codex/                     # Codex source (fork)
├── codex-rs/                     # Rust implementation
└── BUILTIN_TOOL_FILTERING.md    # Implementation docs
```

## Troubleshooting

### Binary not found

```bash
cd llm-server
./scripts/build-codex.sh
```

### Tools still visible

Check config:
```bash
cat config/codex.config.toml
```

Should have `include = []` (empty list).

### Build fails

```bash
cd ../vendor/codex
git status  # Check branch
git checkout feat/builtin-tool-filtering
cd codex-rs
cargo build --release
```

### MCP connection fails

Ensure Elixir app is running:
```bash
cd ../singularity
mix phx.server  # Should start on port 4000
```

## References

- [Codex Fork](https://github.com/mikkihugo/codex/tree/feat/builtin-tool-filtering)
- [Implementation Plan](../vendor/codex/BUILTIN_TOOL_FILTERING.md)
- [MCP Protocol](https://modelcontextprotocol.io)
