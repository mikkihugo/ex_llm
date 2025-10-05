# Interface Architecture

## Overview

Singularity follows a **Tools vs Interfaces** architecture:

- **Tools** (`lib/singularity/tools/`) - **WHAT** capabilities exist
- **Interfaces** (`lib/singularity/interfaces/`) - **HOW** those tools are exposed

This separation allows the same tools to be used via different interfaces without duplication.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    External Clients                         │
│  - Claude Desktop (MCP)                                     │
│  - Cursor IDE (MCP)                                         │
│  - Distributed Services (NATS)                              │
│  - Web Clients (HTTP)                                       │
└────────────┬───────────────┬──────────────┬─────────────────┘
             │               │              │
             │ MCP           │ NATS         │ HTTP
             ▼               ▼              ▼
┌────────────────────────────────────────────────────────────┐
│              Interfaces (lib/singularity/interfaces/)      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │ MCP         │  │ NATS        │  │ HTTP        │       │
│  │ Interface   │  │ Interface   │  │ Interface   │       │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘       │
│         │                │                │               │
│         └────────────────┴────────────────┘               │
│                          │                                │
│                  Protocol.execute_tool()                  │
└──────────────────────────┬────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────┐
│                Tools (lib/singularity/tools/)              │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Tools.Runner - Executes tool calls                  │  │
│  │ Tools.Registry - Stores available tools per provider│  │
│  └──────────────────────────┬──────────────────────────┘  │
│                             │                              │
│  ┌──────────────┬──────────┴──────────┬─────────────┐    │
│  │              │                     │             │    │
│  ▼              ▼                     ▼             ▼    │
│  Quality      Shell                 LLM        Web Search │
│  Tools        Tools                 Tools      Tools      │
└────────────────────────────────────────────────────────────┘
```

## Core Principles

### 1. Tools are Interface-Agnostic

Tools don't know or care how they're being called:

```elixir
# Same tool definition works for ALL interfaces
defmodule Singularity.Tools.Quality do
  def quality_check_tool do
    Tool.new!(%{
      name: "quality_check",
      description: "Run quality checks on code",
      parameters: [%{name: "file_path", type: :string}],
      function: &__MODULE__.check_quality/2
    })
  end

  def check_quality(%{"file_path" => path}, _context) do
    # Tool implementation - same for all interfaces!
    {:ok, "Quality: 95%"}
  end
end
```

### 2. Interfaces Handle Protocol Translation

Each interface translates between its protocol and the tool system:

```elixir
# MCP Interface - Returns MCP format
Singularity.Interfaces.Protocol.execute_tool(mcp_interface, tool_call)
#=> {:ok, %{content: [...], isError: false}}

# NATS Interface - Returns NATS format
Singularity.Interfaces.Protocol.execute_tool(nats_interface, tool_call)
#=> {:ok, %{result: ..., status: "success", correlation_id: "..."}}

# HTTP Interface - Returns HTTP format
Singularity.Interfaces.Protocol.execute_tool(http_interface, tool_call)
#=> {:ok, %{data: ..., status: 200, request_id: "..."}}
```

### 3. Protocol Defines the Contract

The `Singularity.Interfaces.Protocol` defines what all interfaces must implement:

```elixir
defprotocol Singularity.Interfaces.Protocol do
  @spec execute_tool(t(), ToolCall.t()) :: {:ok, term()} | {:error, term()}
  def execute_tool(interface, tool_call)

  @spec metadata(t()) :: map()
  def metadata(interface)

  @spec supports_streaming?(t()) :: boolean()
  def supports_streaming?(interface)
end
```

## Interface Implementations

### MCP Interface (`interfaces/mcp.ex`)

**Purpose**: Expose tools to AI assistants via Model Context Protocol

**Clients**:
- Claude Desktop
- Cursor IDE
- Continue.dev
- Any MCP-compatible client

**Format**:
```elixir
%Singularity.Interfaces.MCP{
  session_id: "sess_abc123",
  client_info: %{name: "Claude Desktop", version: "1.0"},
  capabilities: [:tools, :resources, :prompts]
}
```


### NATS Interface (`interfaces/nats.ex`)

**Purpose**: Expose tools to distributed services via NATS messaging

**Use Cases**:
- Microservice coordination
- Distributed agent orchestration
- Event-driven tool execution
- Async workflows

**Format**:
```elixir
%Singularity.Interfaces.NATS{
  reply_to: "responses.abc123",
  subject: "tools.execute",
  correlation_id: "req_xyz"
}
```




## Why This Architecture?

### ✅ Benefits

1. **Single Source of Truth**
   - Tools defined once, used everywhere
   - No duplication between interfaces

2. **Easy to Add Interfaces**
   - Add new interface = implement protocol
   - No changes to existing tools

3. **Consistent Tool Behavior**
   - Same tool produces same result regardless of interface
   - Only format differs

4. **Type Safety**
   - Protocol enforces interface contract
   - Compile-time guarantees

5. **Testable**
   - Test tools independently of interfaces
   - Test interfaces independently of tools

6. **Flexible**
   - Different interfaces can have different capabilities
   - Easy to add interface-specific features

### 🚫 What We DON'T Do

❌ **No Duplicate Tool Implementations**
```elixir
# WRONG - Don't do this!
defmodule Singularity.MCP.QualityTools do
  def quality_check(...) # MCP version
end

defmodule Singularity.NATS.QualityTools do
  def quality_check(...) # NATS version - duplicate!
end
```

❌ **No Interface-Specific Tool Logic**
```elixir
# WRONG - Tools shouldn't know about interfaces
def quality_check(args, context) do
  case context.interface do
    :mcp -> # MCP-specific logic
    :nats -> # NATS-specific logic
  end
end
```

❌ **No External REST API Service**
```elixir
# We DON'T need a separate API service!
# HTTP interface is for internal use only
# External clients use:
#   - MCP protocol for AI assistants
#   - NATS for distributed systems
```

## Usage Examples

### Example 1: MCP Client Calls Quality Check

```elixir
# 1. Claude Desktop sends MCP request
# 2. MCP server creates interface
interface = %Singularity.Interfaces.MCP{
  session_id: "sess_123",
  client_info: %{name: "Claude Desktop"}
}

# 3. Create tool call
tool_call = %Singularity.Tools.ToolCall{
  name: "quality_check",
  arguments: %{"file_path" => "lib/my_module.ex"}
}

# 4. Execute via protocol
{:ok, result} = Singularity.Interfaces.Protocol.execute_tool(interface, tool_call)

# 5. Result formatted for MCP
result
#=> %{
#     content: [%{type: "text", text: "Quality: 95%"}],
#     isError: false
#   }
```

### Example 2: NATS Service Calls Same Tool

```elixir
# 1. NATS message arrives on "tools.execute"
# 2. NATS handler creates interface
interface = %Singularity.Interfaces.NATS{
  reply_to: "responses.123",
  correlation_id: "req_xyz"
}

# 3. Same tool call!
tool_call = %Singularity.Tools.ToolCall{
  name: "quality_check",
  arguments: %{"file_path" => "lib/my_module.ex"}
}

# 4. Execute via same protocol!
{:ok, result} = Singularity.Interfaces.Protocol.execute_tool(interface, tool_call)

# 5. Result formatted for NATS
result
#=> %{
#     result: "Quality: 95%",
#     status: "success",
#     correlation_id: "req_xyz",
#     timestamp: "2025-10-05T..."
#   }
```

**Same tool, same logic, different format!** ✨

## Adding a New Interface

To add a new interface (e.g., WebSocket):

### 1. Create the struct
```elixir
defmodule Singularity.Interfaces.WebSocket do
  @enforce_keys [:connection_id]
  defstruct [:connection_id, :user_id, provider: :websocket]
end
```

### 2. Implement the protocol
```elixir
defimpl Singularity.Interfaces.Protocol, for: Singularity.Interfaces.WebSocket do
  def execute_tool(interface, tool_call) do
    context = %{
      interface: :websocket,
      connection_id: interface.connection_id
    }

    case Runner.execute(interface.provider, tool_call, context) do
      {:ok, result} -> {:ok, format_for_websocket(result)}
      {:error, reason} -> {:error, format_error_for_websocket(reason)}
    end
  end

  def metadata(_), do: %{name: "WebSocket", protocol: "WSS"}
  def supports_streaming?(_), do: true
end
```

### 3. Use it!
```elixir
interface = %Singularity.Interfaces.WebSocket{connection_id: "ws_123"}
{:ok, result} = Singularity.Interfaces.Protocol.execute_tool(interface, tool_call)
```

That's it! All existing tools work immediately with the new interface.

## Summary

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
