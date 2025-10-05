# Interface Architecture

## Overview

Singularity separates tool definitions from the way they are exposed:

- Tools: `lib/singularity/tools/` – what the system can do.
- Interfaces: `lib/singularity/interfaces/` – how clients call those tools.

This keeps tool code reusable and makes it easy to add new interfaces.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    External Clients                         │
│  - Distributed Services (NATS)                              │
│  - Web Clients (HTTP)                                       │
└────────────┬───────────────────────┬────────────────────────┘
             │                       │
             │ NATS                  │ HTTP
             ▼                       ▼
┌────────────────────────────────────────────────────────────┐
│              Interfaces (lib/singularity/interfaces/)      │
│  ┌─────────────┐    ┌─────────────┐                       │
│  │ NATS        │    │ HTTP        │                       │
│  │ Interface   │    │ Interface   │                       │
│  └──────┬──────┘    └──────┬──────┘                       │
│         │                  │                                │
│         └──────────────────┴───────────────────────────┐    │
│                                                        │    │
│                  Protocol.execute_tool()               │    │
└──────────────────────────┬──────────────────────────────┘    │
                           │                                   │
                           ▼                                   │
┌────────────────────────────────────────────────────────────┐
│                Tools (lib/singularity/tools/)              │
└────────────────────────────────────────────────────────────┘
```

## Core Principles

- Interface‑agnostic tools: same function runs under HTTP or NATS.
- Interfaces translate protocol details into a common ToolCall + context.
- A small protocol defines the contract (`Singularity.Interfaces.Protocol`).

## Interface Implementations

### NATS (`lib/singularity/interfaces/nats.ex`)
Purpose: integrate with distributed services using NATS (request/reply or pub/sub).

### HTTP (`lib/singularity_web/router.ex`)
Purpose: simple HTTP endpoints for tool execution, health and metrics, and a provider chat proxy.

## What We Avoid

- Duplicate tool implementations per interface.
- Interface‑specific branching inside tools.
- Multiple REST services doing the same thing. The included HTTP router is sufficient for local and service-to-service calls; NATS can be enabled where needed.

## Adding a New Interface

1) Define a struct for your interface state.
2) Implement `Singularity.Interfaces.Protocol` for that struct.
3) Map incoming requests to `ToolCall` and call `Runner.execute/3`.

All existing tools become available automatically.
### Tools (WHAT)
- **Location**: `lib/singularity/tools/`
- **Purpose**: Core capabilities (quality checks, shell commands, LLM calls, etc.)
- **Interface-agnostic**: Don't know how they're being called

### Interfaces (HOW)
- **Location**: `lib/singularity/interfaces/`
- **Purpose**: Expose tools via different protocols
- **Implementations**:
  - **MCP**: For AI assistants (Claude Desktop, Cursor)
  - **NATS**: For distributed systems
  - **HTTP**: For web/mobile apps (internal use)
- **No external REST API**: External clients use MCP or NATS

### Protocol (CONTRACT)
- **Location**: `lib/singularity/interfaces/protocol.ex`
- **Purpose**: Defines what all interfaces must implement
- **Functions**: `execute_tool/2`, `metadata/1`, `supports_streaming?/1`

**Result**: One set of tools, multiple ways to call them! 🎯
