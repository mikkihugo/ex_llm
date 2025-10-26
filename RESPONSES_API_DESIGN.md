# OpenAI Responses API Integration Design

**Version**: 1.0
**Date**: 2025-10-25
**Status**: Design Proposal

## Executive Summary

This design document outlines the integration of OpenAI's Responses API (`/v1/responses`) into ex_llm, including native support for MCP (Model Context Protocol), server-side state management, and built-in tools. The integration will be **additive** (not replacing Chat Completions) to maintain backward compatibility and cross-provider support.

## Table of Contents

1. [Background](#background)
2. [Goals & Non-Goals](#goals--non-goals)
3. [Architecture Overview](#architecture-overview)
4. [API Design](#api-design)
5. [MCP Integration](#mcp-integration)
6. [State Management](#state-management)
7. [Built-in Tools](#built-in-tools)
8. [Implementation Plan](#implementation-plan)
9. [Testing Strategy](#testing-strategy)
10. [Migration Guide](#migration-guide)

---

## Background

### What is the Responses API?

OpenAI's Responses API (launched March 2025) is a unified interface that combines capabilities from Chat Completions and Assistants APIs with key enhancements:

- **Server-side state management**: Conversations tracked by OpenAI
- **Native MCP support**: Direct integration with Model Context Protocol servers
- **Built-in tools**: Web search, image generation, code interpreter
- **Preserved reasoning state**: Step-by-step thought processes survive across turns
- **No additional cost**: MCP tool calls billed only for output tokens

### Why Add Support?

1. **MCP Integration** - Access unlimited external tools via MCP protocol
2. **Future-Proof** - New OpenAI features will likely land here first
3. **Better UX** - Server-side state eliminates need to track conversation history
4. **Advanced Features** - Code interpreter, web search, image gen built-in
5. **Codex Models** - codex-mini-latest uses `/v1/responses` endpoint

### Current State in ex_llm

- ✅ Uses `/v1/chat/completions` (Chat Completions API)
- ✅ Supports 14+ providers via OpenAI-compatible interface
- ❌ No MCP support
- ❌ No server-side state management
- ❌ No Responses API support

---

## Goals & Non-Goals

### Goals

1. ✅ Add Responses API support as **opt-in** feature
2. ✅ Implement full MCP (Model Context Protocol) integration
3. ✅ Support server-side conversation state management
4. ✅ Expose built-in tools (web search, image gen, code interpreter)
5. ✅ Maintain backward compatibility (Chat Completions still default)
6. ✅ Preserve cross-provider compatibility
7. ✅ Provide clear migration path for users

### Non-Goals

1. ❌ Replace Chat Completions API (it's industry standard)
2. ❌ Force migration (both APIs supported)
3. ❌ Add Responses API support to non-OpenAI providers
4. ❌ Implement custom MCP server (use existing protocol)

---

## Architecture Overview

### Dual-API Architecture

```
ExLLM.Providers.OpenAI (existing)
├── Chat Completions API (/v1/chat/completions)  [DEFAULT]
│   └── Industry standard, stateless, cross-provider compatible
│
└── Responses API (/v1/responses)  [OPT-IN]
    ├── MCP server integration
    ├── Server-side state management
    ├── Built-in tools (web search, image gen, code interpreter)
    └── Preserved reasoning state
```

### Module Structure

```
lib/ex_llm/providers/openai/
├── openai.ex                    # Main provider (Chat Completions - existing)
├── responses.ex                 # NEW: Responses API implementation
├── responses/
│   ├── build_request.ex        # NEW: Request builder for Responses API
│   ├── parse_response.ex       # NEW: Response parser
│   ├── state_manager.ex        # NEW: Conversation state tracking
│   ├── mcp_client.ex           # NEW: MCP protocol client
│   └── tools.ex                # NEW: Built-in tools interface
└── build_request.ex             # Existing Chat Completions builder
```

### Configuration

```yaml
# config/models/openai.yml
provider: openai
api_version: responses  # NEW: Default API version

models:
  gpt-5-codex:
    context_window: 272000
    max_output_tokens: 128000
    supported_endpoints:
      - /v1/chat/completions  # Legacy/cross-provider
      - /v1/responses         # NEW: Responses API
    default_endpoint: /v1/responses  # NEW
    capabilities:
      - chat
      - streaming
      - mcp              # NEW
      - web_search       # NEW
      - image_generation # NEW
      - code_interpreter # NEW
```

---

## API Design

### 1. High-Level API (Public Interface)

#### Basic Usage (Backward Compatible)

```elixir
# Default: Chat Completions API (unchanged)
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "Hello!"}
])

# Opt-in: Responses API (simple input)
{:ok, response} = ExLLM.chat(:openai,
  "Hello!",  # String input instead of messages array
  api_version: :responses
)

# Responses API (messages-style input)
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "Hello!"}
], api_version: :responses)
```

#### MCP Integration

```elixir
# Define MCP server
mcp_config = %{
  url: "https://my-mcp-server.com",
  tools: ["search_database", "fetch_weather"]
}

{:ok, response} = ExLLM.chat(:openai, messages,
  api_version: :responses,
  mcp_servers: [mcp_config]
)
```

#### Custom Functions (Function Calling)

```elixir
# Define custom functions
tools = [
  %{
    type: "function",
    function: %{
      name: "get_weather",
      description: "Get weather for a location",
      parameters: %{
        type: "object",
        properties: %{
          location: %{type: "string", description: "City name"}
        },
        required: ["location"]
      }
    }
  }
]

# Model will call function if needed
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "What's the weather in Tokyo?"}
],
  api_version: :responses,
  tools: tools,
  tool_choice: "auto"
)

# Check for function call
if response.metadata.tool_calls do
  # Execute function and send result back
  # (See Built-in Tools section for complete example)
end
```

#### Built-in Tools

```elixir
# Web search
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "What's the latest news on AI?"}
],
  api_version: :responses,
  tools: [:web_search]
)

# Image generation
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "Generate an image of a sunset"}
],
  api_version: :responses,
  tools: [:image_generation]
)

# Code interpreter
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "Plot y = x^2 for x from -10 to 10"}
],
  api_version: :responses,
  tools: [:code_interpreter]
)
```

#### Server-Side State Management

```elixir
# Start conversation (server creates conversation_id)
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "My name is Alice"}
],
  api_version: :responses,
  stateful: true  # Enable server-side state
)

conversation_id = response.conversation_id

# Continue conversation (server maintains history)
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "What's my name?"}
],
  api_version: :responses,
  conversation_id: conversation_id
)
# Response: "Your name is Alice"
```

### 2. Low-Level API (Provider-Specific)

#### Direct Responses API Call

```elixir
alias ExLLM.Providers.OpenAI.Responses

# Basic call
{:ok, response} = Responses.chat(messages, model: "gpt-5-codex")

# With MCP servers
{:ok, response} = Responses.chat(messages,
  model: "gpt-5-codex",
  mcp_servers: [
    %{
      url: "https://mcp.example.com",
      auth: %{type: :bearer, token: "..."},
      tools: ["search", "calculate"]
    }
  ]
)

# With built-in tools
{:ok, response} = Responses.chat(messages,
  model: "gpt-5-codex",
  tools: [
    %{type: :web_search},
    %{type: :code_interpreter}
  ]
)

# Stateful conversation
{:ok, response} = Responses.chat(messages,
  model: "gpt-5-codex",
  conversation_id: "conv_abc123",
  stateful: true
)
```

### 3. Streaming API

```elixir
# Stream with Responses API
{:ok, stream} = ExLLM.stream(:openai, messages,
  fn chunk -> IO.write(chunk.content) end,
  api_version: :responses,
  mcp_servers: [mcp_config]
)
```

---

## MCP Integration

### Model Context Protocol (MCP) Overview

MCP is an open protocol that standardizes how applications provide context to LLMs. It allows models to:

- Access remote tools and data sources
- Execute functions server-side (no client round-trips)
- Use unlimited external tools
- Pay only for output tokens (no additional MCP fees)

### MCP Configuration

```elixir
defmodule ExLLM.MCP.ServerConfig do
  @type t :: %__MODULE__{
    url: String.t(),
    auth: auth_config(),
    tools: [String.t()],
    timeout: integer(),
    retry_policy: retry_config()
  }

  @type auth_config :: %{
    type: :bearer | :basic | :api_key,
    token: String.t() | nil,
    username: String.t() | nil,
    password: String.t() | nil
  }

  @type retry_config :: %{
    max_retries: integer(),
    backoff: :exponential | :linear,
    base_delay: integer()
  }
end
```

### MCP Client Implementation

```elixir
defmodule ExLLM.Providers.OpenAI.Responses.MCPClient do
  @moduledoc """
  Client for Model Context Protocol (MCP) server integration.

  Handles:
  - MCP server authentication
  - Tool discovery and registration
  - Request/response formatting
  - Error handling and retries
  """

  alias ExLLM.MCP.ServerConfig

  @doc """
  Discover available tools from MCP server.

  ## Examples

      iex> discover_tools(%ServerConfig{url: "https://mcp.example.com"})
      {:ok, [
        %{name: "search_database", description: "Search internal database"},
        %{name: "fetch_weather", description: "Get weather data"}
      ]}
  """
  @spec discover_tools(ServerConfig.t()) :: {:ok, [map()]} | {:error, term()}
  def discover_tools(config) do
    # Implementation: HTTP GET to {url}/tools
  end

  @doc """
  Format MCP server configuration for Responses API request.
  """
  @spec format_for_request([ServerConfig.t()]) :: map()
  def format_for_request(mcp_servers) do
    %{
      mcp_servers: Enum.map(mcp_servers, fn server ->
        %{
          url: server.url,
          auth: format_auth(server.auth),
          tools: server.tools
        }
      end)
    }
  end

  defp format_auth(%{type: :bearer, token: token}) do
    %{type: "bearer", token: token}
  end

  defp format_auth(%{type: :api_key, token: token}) do
    %{type: "api_key", api_key: token}
  end
end
```

### MCP Request Format

```elixir
# Request body sent to OpenAI Responses API
%{
  model: "gpt-5-codex",
  messages: [...],
  mcp_servers: [
    %{
      url: "https://mcp.example.com",
      auth: %{type: "bearer", token: "..."},
      tools: ["search", "calculate"]
    }
  ]
}
```

### MCP Tool Execution Flow

```
1. User sends request with MCP server config
     ↓
2. OpenAI Responses API calls MCP server to discover tools
     ↓
3. Model decides which MCP tool to call
     ↓
4. OpenAI executes tool on MCP server (server-side)
     ↓
5. Tool response fed back to model
     ↓
6. Model generates final response
     ↓
7. Response returned to user (billed only for output tokens)
```

---

## State Management

### Server-Side State (Stateful Conversations)

```elixir
defmodule ExLLM.Providers.OpenAI.Responses.StateManager do
  @moduledoc """
  Manages server-side conversation state for Responses API.

  OpenAI tracks conversation history on their servers, eliminating
  the need to send full message history with each request.
  """

  @doc """
  Start a stateful conversation.

  Returns conversation_id to use for subsequent requests.
  """
  @spec start_conversation(messages :: [map()], opts :: keyword()) ::
    {:ok, %{conversation_id: String.t(), response: map()}} | {:error, term()}
  def start_conversation(messages, opts) do
    # Implementation: POST to /v1/responses with stateful: true
  end

  @doc """
  Continue existing conversation.

  Only sends new messages; OpenAI maintains full history.
  """
  @spec continue_conversation(
    conversation_id :: String.t(),
    new_messages :: [map()],
    opts :: keyword()
  ) :: {:ok, map()} | {:error, term()}
  def continue_conversation(conversation_id, new_messages, opts) do
    # Implementation: POST to /v1/responses with conversation_id
  end

  @doc """
  Retrieve conversation history from server.
  """
  @spec get_history(conversation_id :: String.t()) ::
    {:ok, [map()]} | {:error, term()}
  def get_history(conversation_id) do
    # Implementation: GET /v1/conversations/:id
  end

  @doc """
  Delete conversation from server.
  """
  @spec delete_conversation(conversation_id :: String.t()) :: :ok | {:error, term()}
  def delete_conversation(conversation_id) do
    # Implementation: DELETE /v1/conversations/:id
  end
end
```

### Stateful vs Stateless Mode

| Mode | Message History | Use Case |
|------|----------------|----------|
| **Stateless** (default) | Client sends full history | Single requests, cross-provider compatibility |
| **Stateful** | Server maintains history | Multi-turn conversations, reduced token usage |

### Example: Stateful Conversation

```elixir
# Turn 1: Start conversation
{:ok, resp1} = ExLLM.chat(:openai, [
  %{role: "user", content: "I'm planning a trip to Japan"}
], api_version: :responses, stateful: true)

conv_id = resp1.conversation_id

# Turn 2: Continue (server remembers context)
{:ok, resp2} = ExLLM.chat(:openai, [
  %{role: "user", content: "What's the best time to visit?"}
], api_version: :responses, conversation_id: conv_id)

# Turn 3: Still in context
{:ok, resp3} = ExLLM.chat(:openai, [
  %{role: "user", content: "Any visa requirements?"}
], api_version: :responses, conversation_id: conv_id)

# Retrieve full history
{:ok, history} = ExLLM.Providers.OpenAI.Responses.StateManager.get_history(conv_id)
```

---

## Built-in Tools

### Tool Types in Responses API

The Responses API supports **three types of tools**:

1. **Built-in Tools** - OpenAI-provided (web search, image gen, code interpreter)
2. **Custom Functions** - Your application functions (function calling / tool use)
3. **MCP Tools** - External MCP server tools

### Built-in Tools

| Tool | Description | Models | Cost |
|------|-------------|--------|------|
| **web_search** | Real-time web search | gpt-4o, gpt-5, codex models | Output tokens only |
| **image_generation** | Generate images (DALL-E) | gpt-4o | Output tokens + image gen |
| **code_interpreter** | Execute Python code | All GPT models | Output tokens only |

### Custom Functions (Function Calling / Tool Use)

The Responses API supports **custom function calling** identical to Chat Completions API. Define your application functions via JSON Schema and let the model decide when to call them.

#### Function Definition Format

```elixir
# Define a custom function
function_def = %{
  type: "function",
  function: %{
    name: "get_weather",
    description: "Get the current weather for a location",
    parameters: %{
      type: "object",
      properties: %{
        location: %{
          type: "string",
          description: "The city and state, e.g. San Francisco, CA"
        },
        unit: %{
          type: "string",
          enum: ["celsius", "fahrenheit"],
          description: "Temperature unit"
        }
      },
      required: ["location"]
    }
  }
}
```

#### Using Custom Functions

```elixir
# 1. Define your functions
tools = [
  %{
    type: "function",
    function: %{
      name: "search_database",
      description: "Search the product database",
      parameters: %{
        type: "object",
        properties: %{
          query: %{type: "string", description: "Search query"},
          limit: %{type: "integer", description: "Max results", default: 10}
        },
        required: ["query"]
      }
    }
  },
  %{
    type: "function",
    function: %{
      name: "get_order_status",
      description: "Get order status by order ID",
      parameters: %{
        type: "object",
        properties: %{
          order_id: %{type: "string", description: "Order ID"}
        },
        required: ["order_id"]
      }
    }
  }
]

# 2. Send request with tools
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "What's the status of order #12345?"}
],
  api_version: :responses,
  tools: tools,
  tool_choice: "auto"  # Let model decide
)

# 3. Check if model wants to call a function
if response.metadata.tool_calls do
  for tool_call <- response.metadata.tool_calls do
    # Execute your function
    result = case tool_call.function.name do
      "get_order_status" ->
        args = Jason.decode!(tool_call.function.arguments)
        MyApp.get_order_status(args["order_id"])

      "search_database" ->
        args = Jason.decode!(tool_call.function.arguments)
        MyApp.search_database(args["query"], args["limit"])
    end

    # 4. Send function result back to model
    {:ok, final_response} = ExLLM.chat(:openai, [
      %{role: "user", content: "What's the status of order #12345?"},
      %{role: "assistant", content: nil, tool_calls: [tool_call]},
      %{role: "tool", content: Jason.encode!(result), tool_call_id: tool_call.id}
    ],
      api_version: :responses,
      tools: tools
    )

    # Final response incorporates function result
    IO.puts(final_response.content)
  end
end
```

#### Tool Choice Options

```elixir
# Auto (default): Model decides whether to call functions
tool_choice: "auto"

# None: Force model to respond directly (no function calls)
tool_choice: "none"

# Specific function: Force model to call specific function
tool_choice: %{type: "function", function: %{name: "get_weather"}}

# Required: Force model to call any available function
tool_choice: "required"
```

#### Advanced: Parallel Function Calling

```elixir
# Model can call multiple functions in one response
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "Get weather for SF and NY, and check order #12345"}
],
  api_version: :responses,
  tools: [weather_tool, order_tool],
  parallel_tool_calls: true  # Enable parallel calls
)

# Response may contain multiple tool_calls
response.metadata.tool_calls
# => [
#   %{id: "call_1", function: %{name: "get_weather", arguments: ~s({"location":"SF"})}},
#   %{id: "call_2", function: %{name: "get_weather", arguments: ~s({"location":"NY"})}},
#   %{id: "call_3", function: %{name: "get_order_status", arguments: ~s({"order_id":"12345"})}}
# ]
```

#### Combining Built-in + Custom Functions

```elixir
# Use BOTH built-in tools AND custom functions
{:ok, response} = ExLLM.chat(:openai, messages,
  api_version: :responses,
  tools: [
    # Built-in tools (atoms)
    :web_search,
    :code_interpreter,
    # Custom functions (maps)
    %{
      type: "function",
      function: %{
        name: "query_database",
        description: "Query internal database",
        parameters: %{...}
      }
    }
  ]
)
```

### Tool Configuration

```elixir
defmodule ExLLM.Providers.OpenAI.Responses.Tools do
  @moduledoc """
  Built-in tools for Responses API.
  """

  @type tool_type :: :web_search | :image_generation | :code_interpreter

  @doc """
  Format tool configuration for API request.
  """
  @spec format_tools([tool_type()]) :: [map()]
  def format_tools(tool_types) do
    Enum.map(tool_types, &format_tool/1)
  end

  defp format_tool(:web_search) do
    %{type: "web_search"}
  end

  defp format_tool(:image_generation) do
    %{
      type: "image_generation",
      config: %{
        model: "dall-e-3",
        size: "1024x1024",
        quality: "standard"
      }
    }
  end

  defp format_tool(:code_interpreter) do
    %{
      type: "code_interpreter",
      config: %{
        timeout: 30_000  # 30 seconds
      }
    }
  end
end
```

### Tool Usage Examples

#### Web Search

```elixir
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "What are the latest developments in quantum computing?"}
],
  api_version: :responses,
  tools: [:web_search]
)

# Response includes citations and sources
IO.inspect(response.sources)
# => [
#   %{title: "Quantum Breakthrough 2025", url: "https://..."},
#   %{title: "IBM Quantum Update", url: "https://..."}
# ]
```

#### Image Generation

```elixir
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: "Create an image of a futuristic city"}
],
  api_version: :responses,
  tools: [:image_generation]
)

# Response includes generated image
IO.inspect(response.images)
# => [
#   %{url: "https://oaidalleapiprodscus.blob.core.windows.net/...", revised_prompt: "..."}
# ]
```

#### Code Interpreter

```elixir
{:ok, response} = ExLLM.chat(:openai, [
  %{role: "user", content: """
  Plot the function y = sin(x) + cos(x) for x from 0 to 2π.
  Show both the plot and the code used.
  """}
],
  api_version: :responses,
  tools: [:code_interpreter]
)

# Response includes code execution results
IO.inspect(response.code_outputs)
# => [
#   %{
#     code: "import matplotlib.pyplot as plt\nimport numpy as np\n...",
#     output: "...",
#     image: "data:image/png;base64,..."
#   }
# ]
```

---

## Implementation Plan

### Phase 1: Core Infrastructure (Week 1)

**Goal**: Basic Responses API support without MCP/tools

- [ ] Create `ExLLM.Providers.OpenAI.Responses` module
- [ ] Implement request builder (`responses/build_request.ex`)
- [ ] Implement response parser (`responses/parse_response.ex`)
- [ ] Add endpoint configuration to `openai.yml`
- [ ] Update `ExLLM.chat/3` to support `api_version: :responses`
- [ ] Add basic tests

**Deliverable**: Basic Responses API calls working

### Phase 2: State Management (Week 2)

**Goal**: Server-side conversation state

- [ ] Create `StateManager` module
- [ ] Implement conversation lifecycle (start/continue/delete)
- [ ] Add conversation_id tracking in responses
- [ ] Update API to support `conversation_id` parameter
- [ ] Add state management tests
- [ ] Document stateful vs stateless modes

**Deliverable**: Multi-turn stateful conversations working

### Phase 3: MCP Integration (Week 3)

**Goal**: Full Model Context Protocol support

- [ ] Create `MCPClient` module
- [ ] Implement tool discovery from MCP servers
- [ ] Add MCP server configuration format
- [ ] Implement authentication (bearer, API key, basic)
- [ ] Add retry logic and error handling
- [ ] Add `mcp_servers` parameter to API
- [ ] Add MCP integration tests
- [ ] Document MCP setup and usage

**Deliverable**: MCP server integration working

### Phase 4: Built-in Tools (Week 4)

**Goal**: Web search, image gen, code interpreter

- [ ] Create `Tools` module
- [ ] Implement web_search tool
- [ ] Implement image_generation tool
- [ ] Implement code_interpreter tool
- [ ] Add `tools` parameter to API
- [ ] Parse and expose tool outputs in responses
- [ ] Add tool integration tests
- [ ] Document built-in tools usage

**Deliverable**: All built-in tools working

### Phase 5: Streaming Support (Week 5)

**Goal**: Streaming with Responses API

- [ ] Implement streaming for Responses API
- [ ] Support streaming with MCP tools
- [ ] Support streaming with built-in tools
- [ ] Handle stateful conversation streaming
- [ ] Add streaming tests
- [ ] Document streaming behavior

**Deliverable**: Full streaming support

### Phase 6: Documentation & Examples (Week 6)

**Goal**: Production-ready documentation

- [ ] Update `README.md` with Responses API examples
- [ ] Create `RESPONSES_API_GUIDE.md`
- [ ] Create `MCP_INTEGRATION_GUIDE.md`
- [ ] Add example scripts for common use cases
- [ ] Update API documentation
- [ ] Create migration guide from Chat Completions
- [ ] Add troubleshooting guide

**Deliverable**: Complete documentation

### Phase 7: Testing & Optimization (Week 7)

**Goal**: Production hardening

- [ ] Add comprehensive integration tests
- [ ] Add performance benchmarks
- [ ] Optimize request/response parsing
- [ ] Add caching for MCP tool discovery
- [ ] Add circuit breaker for MCP servers
- [ ] Test error scenarios
- [ ] Load testing

**Deliverable**: Production-ready implementation

---

## Testing Strategy

### Unit Tests

```elixir
# test/ex_llm/providers/openai/responses/build_request_test.exs
defmodule ExLLM.Providers.OpenAI.Responses.BuildRequestTest do
  use ExUnit.Case

  alias ExLLM.Providers.OpenAI.Responses.BuildRequest

  test "builds basic request" do
    request = BuildRequest.build(messages, model: "gpt-5-codex")

    assert request.url == "https://api.openai.com/v1/responses"
    assert request.body.model == "gpt-5-codex"
    assert request.body.messages == messages
  end

  test "includes MCP servers" do
    mcp_config = [%{url: "https://mcp.example.com", tools: ["search"]}]
    request = BuildRequest.build(messages, mcp_servers: mcp_config)

    assert length(request.body.mcp_servers) == 1
    assert hd(request.body.mcp_servers).url == "https://mcp.example.com"
  end

  test "includes built-in tools" do
    request = BuildRequest.build(messages, tools: [:web_search, :code_interpreter])

    assert length(request.body.tools) == 2
    assert Enum.any?(request.body.tools, &(&1.type == "web_search"))
  end
end
```

### Integration Tests

```elixir
# test/ex_llm/providers/openai/responses_integration_test.exs
defmodule ExLLM.Providers.OpenAI.ResponsesIntegrationTest do
  use ExUnit.Case

  @moduletag :integration
  @moduletag :requires_api_key

  test "basic chat with Responses API" do
    {:ok, response} = ExLLM.chat(:openai, [
      %{role: "user", content: "Say hello"}
    ], api_version: :responses, model: "gpt-5-codex")

    assert response.content
    assert response.model == "gpt-5-codex"
    assert response.usage.total_tokens > 0
  end

  test "stateful conversation" do
    # Start conversation
    {:ok, resp1} = ExLLM.chat(:openai, [
      %{role: "user", content: "My favorite color is blue"}
    ], api_version: :responses, stateful: true)

    conv_id = resp1.conversation_id

    # Continue conversation
    {:ok, resp2} = ExLLM.chat(:openai, [
      %{role: "user", content: "What's my favorite color?"}
    ], api_version: :responses, conversation_id: conv_id)

    assert resp2.content =~ ~r/blue/i
  end

  @tag :mcp
  test "MCP server integration" do
    mcp_config = %{
      url: System.get_env("TEST_MCP_SERVER_URL"),
      tools: ["test_tool"]
    }

    {:ok, response} = ExLLM.chat(:openai, [
      %{role: "user", content: "Use the test tool"}
    ], api_version: :responses, mcp_servers: [mcp_config])

    assert response.content
  end

  @tag :web_search
  test "web search tool" do
    {:ok, response} = ExLLM.chat(:openai, [
      %{role: "user", content: "What's the weather in San Francisco?"}
    ], api_version: :responses, tools: [:web_search])

    assert response.content
    assert response.sources  # Should include web sources
  end
end
```

### Test Coverage Goals

- Unit tests: 90%+ coverage
- Integration tests: All major features
- MCP integration: Mock MCP server for testing
- Error scenarios: Network failures, timeouts, auth errors
- Performance: Response time benchmarks

---

## Migration Guide

### For Existing ex_llm Users

#### Option 1: Keep Using Chat Completions (No Changes)

```elixir
# This continues to work exactly as before
{:ok, response} = ExLLM.chat(:openai, messages)
# Uses /v1/chat/completions
```

#### Option 2: Migrate to Responses API (Opt-In)

```elixir
# Add api_version parameter
{:ok, response} = ExLLM.chat(:openai, messages, api_version: :responses)
# Uses /v1/responses
```

#### Option 3: Use MCP Features (New Capability)

```elixir
# Define MCP server
mcp_config = %{
  url: "https://your-mcp-server.com",
  auth: %{type: :bearer, token: System.get_env("MCP_TOKEN")},
  tools: ["search_docs", "query_database"]
}

# Use with Responses API
{:ok, response} = ExLLM.chat(:openai, messages,
  api_version: :responses,
  mcp_servers: [mcp_config]
)
```

### When to Migrate?

**Stay with Chat Completions if**:
- ✅ Using multiple providers (Groq, Mistral, etc.)
- ✅ Stateless single-turn requests
- ✅ No need for MCP/built-in tools
- ✅ Existing code works fine

**Migrate to Responses API if**:
- ✅ Need MCP server integration
- ✅ Want server-side state management
- ✅ Need built-in tools (web search, code interpreter, image gen)
- ✅ Using reasoning models (want preserved state)
- ✅ Want access to latest OpenAI features

### Breaking Changes

**None!** Responses API is purely additive:
- Existing code continues to work unchanged
- Chat Completions API remains the default
- Both APIs supported indefinitely

---

## Configuration Reference

### Environment Variables

```bash
# OpenAI API Key (required for both APIs)
export OPENAI_API_KEY="sk-..."

# Default API version (optional)
export OPENAI_API_VERSION="responses"  # or "chat_completions"

# MCP Server Configuration (optional)
export MCP_SERVER_URL="https://mcp.example.com"
export MCP_SERVER_TOKEN="..."
```

### Application Config

```elixir
# config/config.exs
config :ex_llm, :openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  api_version: :responses,  # :responses or :chat_completions (default)
  default_model: "gpt-5-codex",
  base_url: "https://api.openai.com",
  mcp_servers: [
    %{
      url: System.get_env("MCP_SERVER_URL"),
      auth: %{type: :bearer, token: System.get_env("MCP_SERVER_TOKEN")},
      tools: ["search", "analyze"]
    }
  ]
```

---

## Error Handling

### Responses API Specific Errors

```elixir
# MCP server unreachable
{:error, {:mcp_server_error, %{server: "https://...", reason: :timeout}}}

# Conversation not found
{:error, {:conversation_not_found, "conv_abc123"}}

# Tool execution failed
{:error, {:tool_error, %{tool: :code_interpreter, reason: "Syntax error"}}}

# Unsupported model for Responses API
{:error, {:unsupported_api_version, %{model: "gpt-3.5-turbo", api_version: :responses}}}
```

### Error Handling Best Practices

```elixir
case ExLLM.chat(:openai, messages, api_version: :responses, mcp_servers: [mcp]) do
  {:ok, response} ->
    # Success

  {:error, {:mcp_server_error, %{reason: :timeout}}} ->
    # Retry with exponential backoff

  {:error, {:conversation_not_found, conv_id}} ->
    # Start new conversation

  {:error, error} ->
    # Generic error handling
end
```

---

## Performance Considerations

### Token Usage

**Chat Completions**:
- Each request includes full conversation history
- Token usage: `input_tokens = history + new_message`

**Responses API (Stateful)**:
- Server maintains history
- Token usage: `input_tokens = new_message only`
- **Savings**: 50-90% reduction for multi-turn conversations

### Latency

**Chat Completions**:
- Client → OpenAI → Response
- Round-trip: ~500-2000ms

**Responses API with MCP**:
- Client → OpenAI → MCP Server → OpenAI → Response
- Round-trip: ~1000-3000ms (server-side tool execution adds latency)
- **Trade-off**: Slightly higher latency but no client round-trips

### Caching Strategy

```elixir
# Cache MCP tool discovery results
defmodule ExLLM.MCP.ToolCache do
  use GenServer

  # Cache tool definitions for 1 hour
  def get_tools(mcp_url) do
    GenServer.call(__MODULE__, {:get_tools, mcp_url})
  end

  # Invalidate cache when needed
  def invalidate(mcp_url) do
    GenServer.cast(__MODULE__, {:invalidate, mcp_url})
  end
end
```

---

## Security Considerations

### MCP Server Authentication

```elixir
# Always use HTTPS for MCP servers
mcp_config = %{
  url: "https://mcp.example.com",  # ✅ HTTPS
  # url: "http://mcp.example.com",  # ❌ HTTP not allowed
  auth: %{
    type: :bearer,
    token: System.get_env("MCP_TOKEN")  # Don't hardcode tokens
  }
}
```

### Conversation ID Security

```elixir
# Conversation IDs are sensitive - treat like session tokens
# - Don't log conversation IDs
# - Use secure storage (encrypted database)
# - Implement access control (user can only access their conversations)
# - Delete conversations when no longer needed
```

### Rate Limiting

```elixir
# Both APIs share OpenAI rate limits
# Monitor usage across both endpoints
defmodule ExLLM.RateLimiter do
  def check_rate_limit(provider) do
    # Implement rate limit checking
  end
end
```

---

## Monitoring & Observability

### Telemetry Events

```elixir
# Add telemetry for Responses API
:telemetry.execute(
  [:ex_llm, :openai, :responses, :request],
  %{duration: duration, tokens: tokens},
  %{model: model, has_mcp: has_mcp?, has_tools: has_tools?}
)

:telemetry.execute(
  [:ex_llm, :openai, :responses, :mcp_call],
  %{duration: duration},
  %{server_url: url, tool: tool}
)
```

### Metrics to Track

- Request duration (p50, p95, p99)
- Token usage (input, output, total)
- MCP server latency
- Tool execution success rate
- Conversation length (stateful mode)
- Error rates by type

---

## Future Enhancements

### Phase 8+: Advanced Features

- [ ] **Multi-MCP Orchestration**: Coordinate multiple MCP servers
- [ ] **Custom Tool Definitions**: Define app-specific tools
- [ ] **Conversation Branching**: Fork conversations at specific points
- [ ] **Response Caching**: Cache responses for identical requests
- [ ] **Batch Responses API**: Process multiple requests in parallel
- [ ] **Conversation Templates**: Reusable conversation starters
- [ ] **MCP Server Pool**: Load balance across multiple MCP instances

---

## FAQ

### Q: Will Chat Completions API be removed?

**A**: No. OpenAI committed to supporting Chat Completions indefinitely. It's an industry standard used by many providers.

### Q: What's the performance impact of MCP?

**A**: MCP adds ~500-1500ms latency for tool execution, but eliminates client round-trips. Net result is usually faster than client-side tool calling.

### Q: Can I use Responses API with Groq/Mistral/etc?

**A**: No. Responses API is OpenAI-specific. Other providers use Chat Completions.

### Q: What happens to my conversation data in stateful mode?

**A**: OpenAI stores it on their servers. You can retrieve or delete it via API. Check OpenAI's data retention policy.

### Q: How much does MCP cost?

**A**: No additional cost. You pay only for output tokens generated by the model.

### Q: Can I use my own MCP server?

**A**: Yes! Any MCP-compatible server works. You provide the URL and auth.

---

## References

- [OpenAI Responses API Documentation](https://platform.openai.com/docs/guides/responses)
- [Model Context Protocol (MCP) Specification](https://spec.modelcontextprotocol.io/)
- [OpenAI Responses API Migration Guide](https://platform.openai.com/docs/guides/migrate-to-responses)
- [MCP Integration Examples](https://cookbook.openai.com/examples/mcp/mcp_tool_guide)

---

## Appendix: Complete Example

```elixir
defmodule MyApp.AIAssistant do
  @moduledoc """
  Example: AI assistant with MCP server integration using Responses API.
  """

  alias ExLLM.MCP.ServerConfig

  def ask_with_database_access(question) do
    # Configure internal database MCP server
    mcp_config = %ServerConfig{
      url: "https://internal-mcp.myapp.com",
      auth: %{type: :bearer, token: get_mcp_token()},
      tools: ["search_users", "search_orders", "search_products"]
    }

    # Ask question with database access
    {:ok, response} = ExLLM.chat(:openai, [
      %{role: "system", content: """
      You are a helpful assistant with access to our internal database.
      Use the MCP tools to search for information as needed.
      """},
      %{role: "user", content: question}
    ],
      api_version: :responses,
      model: "gpt-5-codex",
      mcp_servers: [mcp_config],
      tools: [:web_search]  # Also enable web search
    )

    response.content
  end

  def start_conversation do
    # Start stateful conversation
    {:ok, response} = ExLLM.chat(:openai, [
      %{role: "user", content: "Hello! I need help with my order."}
    ],
      api_version: :responses,
      model: "gpt-5-codex",
      stateful: true
    )

    {:ok, response.conversation_id, response.content}
  end

  def continue_conversation(conv_id, message) do
    {:ok, response} = ExLLM.chat(:openai, [
      %{role: "user", content: message}
    ],
      api_version: :responses,
      conversation_id: conv_id
    )

    {:ok, response.content}
  end

  defp get_mcp_token do
    System.get_env("INTERNAL_MCP_TOKEN")
  end
end
```

---

**End of Design Document**
