# Interface Architecture Summary

## Quick Reference

### ✅ What We Have

**2 Interfaces** for accessing the same tools:

1. **MCP** (`interfaces/mcp.ex`)
   - **For**: AI assistants (Claude Desktop, Cursor, Continue.dev)
   - **Protocol**: Model Context Protocol
   - **Format**: `{content: [...], isError: false}`

2. **NATS** (`interfaces/nats.ex`)
   - **For**: Distributed services, microservices
   - **Protocol**: NATS messaging
   - **Format**: `{result: ..., status: "success", correlation_id: "..."}`


### 🚫 What We DON'T Need

❌ **No External REST API Service**
- External clients use MCP or NATS
- HTTP interface is for internal Elixir apps only

❌ **No API Gateway**
- Not needed - interfaces handle routing

❌ **No Duplicate Tool Code**
- Tools defined once in `tools/`
- Interfaces just change the format

## Directory Structure

```
lib/singularity/
├── interfaces/              # HOW tools are exposed
│   ├── protocol.ex         # Protocol definition
│   ├── mcp.ex             # MCP implementation
│   ├── nats.ex            # NATS implementation
│   └── http.ex            # HTTP implementation (internal)
│
└── tools/                  # WHAT capabilities exist
    ├── registry.ex         # Tool storage
    ├── runner.ex           # Tool execution
    ├── quality.ex          # Quality tools
    ├── llm.ex             # LLM tools
    ├── web_search.ex      # Search tools
    └── default.ex         # Shell & file tools
```

## One Tool, Three Formats

```elixir
# Same tool call
tool_call = %ToolCall{
  name: "quality_check",
  arguments: %{"file_path" => "lib/my_module.ex"}
}

# Via MCP (AI assistants)
Protocol.execute_tool(%MCP{session_id: "s1"}, tool_call)
#=> {:ok, %{content: [...], isError: false}}

# Via NATS (distributed)
Protocol.execute_tool(%NATS{reply_to: "r1"}, tool_call)
#=> {:ok, %{result: ..., status: "success"}}

# Via HTTP (internal apps)
## Key Points

1. **Tools are interface-agnostic** - don't know how they're called
2. **Interfaces translate protocols** - same tool, different format
3. **Protocol enforces contract** - all interfaces implement same API
4. **No external API** - MCP for AI, NATS for services
5. **Easy to extend** - add new interface = implement protocol

See [INTERFACE_ARCHITECTURE.md](INTERFACE_ARCHITECTURE.md) for full details.
