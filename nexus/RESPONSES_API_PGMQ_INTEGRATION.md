# Responses API + pgmq Integration for Nexus

**Guide for integrating OpenAI Responses API with Nexus's pgmq-based architecture**

## Overview

Nexus currently routes LLM requests through pgmq (PostgreSQL message queue), designed around the Chat Completions API. This guide shows how to add **Responses API support** while maintaining the existing queue-based architecture.

## Why pgmq + Responses API?

### Benefits

1. **Async Processing** - Queue LLM requests, process when ready
2. **Rate Limiting** - Control request throughput via queue
3. **Retry Logic** - Built-in retry for failed requests
4. **State Persistence** - PostgreSQL stores request/response state
5. **Multi-Consumer** - Multiple Nexus instances can consume from queue
6. **Conversation Continuity** - Responses API's stateful mode perfect for queued workflows

### Use Cases

- **Background Tasks**: Queue long-running LLM operations
- **Batch Processing**: Process multiple requests in order
- **Multi-Turn Conversations**: Maintain conversation state across queue messages
- **Load Balancing**: Distribute LLM requests across multiple workers

---

## Architecture

### Current Architecture (Chat Completions)

```
Singularity Agent
    ↓ publishes to pgmq
llm_requests queue
    ↓ consumed by
Nexus.QueueConsumer
    ↓ calls Chat Completions API
OpenAI /v1/chat/completions
    ↓ results
llm_results queue
    ↓ consumed by
Singularity Agent
```

### New Architecture (Dual API Support)

```
Singularity Agent
    ↓ publishes to pgmq
llm_requests queue
    ↓ consumed by
Nexus.QueueConsumer
    ↓ routes based on api_version
    ├─ Chat Completions API (/v1/chat/completions)
    └─ Responses API (/v1/responses)
        ├─ Stateful conversations (previous_response_id)
        ├─ MCP server integration
        └─ Built-in tools
    ↓ results
llm_results queue
    ↓ consumed by
Singularity Agent
```

---

## Message Format

### Request Message (llm_requests queue)

```json
{
  "request_id": "req_uuid",
  "agent_id": "self-improving-agent",
  "api_version": "responses",  // NEW: "chat_completions" (default) or "responses"
  "complexity": "complex",
  "task_type": "architect",

  // Chat Completions format (existing)
  "messages": [
    {"role": "user", "content": "Design a new feature"}
  ],

  // OR Responses API format (new)
  "input": "Design a new feature",  // Simple string
  // OR
  "input": [
    {
      "role": "user",
      "content": [
        {"type": "input_text", "text": "Analyze this"},
        {"type": "input_file", "file_id": "file-123"}
      ]
    }
  ],

  // Responses API specific (new)
  "previous_response_id": "resp_abc123",  // Continue conversation
  "store": true,  // Enable conversation storage
  "mcp_servers": [
    {
      "server_label": "internal-db",
      "server_url": "https://mcp.myapp.com",
      "allowed_tools": ["search_users", "query_orders"]
    }
  ],

  // Common parameters
  "max_tokens": 4000,
  "temperature": 0.7,
  "tools": [
    "web_search",  // Built-in tool
    {  // Custom function
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get weather for location",
        "parameters": {...}
      }
    }
  ],
  "timestamp": "2025-10-25T22:00:00Z"
}
```

### Response Message (llm_results queue)

```json
{
  "request_id": "req_uuid",
  "agent_id": "self-improving-agent",
  "api_version": "responses",
  "response": "Here's the architectural design...",
  "model": "gpt-5-codex",
  "usage": {
    "prompt_tokens": 150,
    "completion_tokens": 800,
    "total_tokens": 950
  },
  "cost": 0.0285,

  // Responses API specific
  "response_id": "resp_xyz789",  // Use for previous_response_id in next request
  "conversation_stored": true,
  "tool_calls": [
    {
      "id": "call_123",
      "type": "function",
      "function": {
        "name": "search_database",
        "arguments": "{\"query\":\"users\"}"
      }
    }
  ],
  "sources": [  // From web_search tool
    {"title": "Example", "url": "https://example.com"}
  ],

  "timestamp": "2025-10-25T22:00:05Z"
}
```

---

## Implementation

### 1. Update LLMRouter

```elixir
# nexus/lib/nexus/llm_router.ex
defmodule Nexus.LLMRouter do
  @moduledoc """
  Routes LLM requests to appropriate API (Chat Completions or Responses).
  """

  def route(request) do
    api_version = Map.get(request, "api_version", "chat_completions")

    case api_version do
      "chat_completions" -> route_chat_completions(request)
      "responses" -> route_responses_api(request)
      _ -> {:error, {:unsupported_api_version, api_version}}
    end
  end

  defp route_chat_completions(request) do
    # Existing implementation
    model = select_model(request["complexity"], request["task_type"])

    ExLLM.chat(:openai, request["messages"],
      model: model,
      temperature: request["temperature"] || 0.7,
      max_tokens: request["max_tokens"] || 4000
    )
  end

  defp route_responses_api(request) do
    model = select_model(request["complexity"], request["task_type"])

    # Convert to Responses API format
    options = [
      api_version: :responses,
      model: model,
      temperature: request["temperature"] || 0.7,
      max_tokens: request["max_tokens"] || 4000
    ]

    # Add Responses API specific options
    options = maybe_add_previous_response(options, request)
    options = maybe_add_mcp_servers(options, request)
    options = maybe_add_tools(options, request)
    options = maybe_add_store(options, request)

    # Input can be string or messages array
    input = get_input(request)

    ExLLM.chat(:openai, input, options)
  end

  defp get_input(request) do
    cond do
      Map.has_key?(request, "input") ->
        request["input"]

      Map.has_key?(request, "messages") ->
        request["messages"]

      true ->
        {:error, :missing_input}
    end
  end

  defp maybe_add_previous_response(options, request) do
    case request["previous_response_id"] do
      nil -> options
      resp_id -> Keyword.put(options, :previous_response_id, resp_id)
    end
  end

  defp maybe_add_mcp_servers(options, request) do
    case request["mcp_servers"] do
      nil -> options
      [] -> options
      servers -> Keyword.put(options, :mcp_servers, parse_mcp_servers(servers))
    end
  end

  defp maybe_add_tools(options, request) do
    case request["tools"] do
      nil -> options
      [] -> options
      tools -> Keyword.put(options, :tools, parse_tools(tools))
    end
  end

  defp maybe_add_store(options, request) do
    case request["store"] do
      nil -> options
      store -> Keyword.put(options, :store, store)
    end
  end

  defp parse_mcp_servers(servers) do
    Enum.map(servers, fn server ->
      %{
        server_label: server["server_label"],
        server_url: server["server_url"],
        allowed_tools: server["allowed_tools"] || [],
        require_approval: server["require_approval"] || "never"
      }
    end)
  end

  defp parse_tools(tools) do
    Enum.map(tools, fn
      tool when is_binary(tool) ->
        # Built-in tool (e.g., "web_search")
        String.to_atom(tool)

      tool when is_map(tool) ->
        # Custom function or MCP tool
        tool
    end)
  end
end
```

### 2. Update QueueConsumer

```elixir
# nexus/lib/nexus/queue_consumer.ex
defmodule Nexus.QueueConsumer do
  use GenServer
  require Logger

  def handle_info(:poll, state) do
    case Pgmq.read(state.db_url, "llm_requests", state.batch_size) do
      {:ok, messages} when length(messages) > 0 ->
        Enum.each(messages, &process_message(&1, state))

      {:ok, []} ->
        # No messages
        :ok

      {:error, reason} ->
        Logger.error("Failed to read from queue: #{inspect(reason)}")
    end

    schedule_poll(state.poll_interval)
    {:noreply, state}
  end

  defp process_message(msg, state) do
    request = Jason.decode!(msg.message)

    Logger.info("Processing LLM request",
      request_id: request["request_id"],
      api_version: request["api_version"] || "chat_completions",
      agent_id: request["agent_id"]
    )

    case Nexus.LLMRouter.route(request) do
      {:ok, response} ->
        result = build_result(request, response)
        publish_result(result, state)
        archive_message(msg, state)

      {:error, reason} ->
        Logger.error("LLM request failed",
          request_id: request["request_id"],
          reason: inspect(reason)
        )
        # Re-queue or handle error
    end
  end

  defp build_result(request, response) do
    %{
      request_id: request["request_id"],
      agent_id: request["agent_id"],
      api_version: request["api_version"] || "chat_completions",
      response: response.content,
      model: response.model,
      usage: response.usage,
      cost: response.cost,
      # Responses API specific
      response_id: response.metadata[:response_id],
      conversation_stored: response.metadata[:conversation_stored],
      tool_calls: response.metadata[:tool_calls],
      sources: response.metadata[:sources],
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp publish_result(result, state) do
    {:ok, _} = Pgmq.send(state.db_url, "llm_results", Jason.encode!(result))
    Logger.info("Published result", request_id: result.request_id)
  end

  defp archive_message(msg, state) do
    Pgmq.archive(state.db_url, "llm_requests", msg.msg_id)
  end
end
```

---

## Conversation State Management

### Multi-Turn Conversations via Queue

```elixir
# Turn 1: Start conversation
request_1 = %{
  request_id: Nexus.ID.generate(),
  agent_id: "chat-agent",
  api_version: "responses",
  input: "My name is Alice",
  store: true,  # Enable state storage
  task_type: :chat
}

Pgmq.send(db_url, "llm_requests", Jason.encode!(request_1))

# Receive response
{:ok, [result_1]} = Pgmq.read(db_url, "llm_results", 1)
response_1 = Jason.decode!(result_1.message)
# => %{"response_id" => "resp_abc123", "conversation_stored" => true}

# Turn 2: Continue conversation
request_2 = %{
  request_id: Nexus.ID.generate(),
  agent_id: "chat-agent",
  api_version: "responses",
  input: "What's my name?",
  previous_response_id: response_1["response_id"],  # Link to turn 1
  task_type: :chat
}

Pgmq.send(db_url, "llm_requests", Jason.encode!(request_2))

# Receive response
{:ok, [result_2]} = Pgmq.read(db_url, "llm_results", 1)
response_2 = Jason.decode!(result_2.message)
# => %{"response" => "Your name is Alice"}
```

### Storing Conversation State in PostgreSQL

```elixir
# Store response_id → request_id mapping for conversation tracking
defmodule Nexus.ConversationStore do
  use Ecto.Schema
  import Ecto.Changeset
  alias Nexus.Repo

  schema "conversations" do
    field :response_id, :string
    field :agent_id, :string
    field :request_ids, {:array, :string}  # All request IDs in conversation
    field :last_updated, :utc_datetime

    timestamps()
  end

  def track_response(response_id, agent_id, request_id) do
    case Repo.get_by(__MODULE__, response_id: response_id) do
      nil ->
        %__MODULE__{}
        |> changeset(%{
          response_id: response_id,
          agent_id: agent_id,
          request_ids: [request_id],
          last_updated: DateTime.utc_now()
        })
        |> Repo.insert()

      existing ->
        existing
        |> changeset(%{
          request_ids: existing.request_ids ++ [request_id],
          last_updated: DateTime.utc_now()
        })
        |> Repo.update()
    end
  end

  def get_conversation_history(response_id) do
    Repo.get_by(__MODULE__, response_id: response_id)
  end
end
```

---

## MCP Integration via pgmq

### Example: Internal Database MCP Server

```elixir
# Queue request with MCP server
request = %{
  request_id: Nexus.ID.generate(),
  agent_id: "support-agent",
  api_version: "responses",
  input: "Search for user alice@example.com",
  mcp_servers: [
    %{
      server_label: "internal-db",
      server_url: "https://mcp.internal.myapp.com",
      allowed_tools: ["search_users", "search_orders"],
      require_approval: "never"
    }
  ],
  task_type: :search
}

Pgmq.send(db_url, "llm_requests", Jason.encode!(request))

# Response includes MCP tool execution results
{:ok, [result]} = Pgmq.read(db_url, "llm_results", 1)
response = Jason.decode!(result.message)

# Response contains data from MCP server
# => %{
#   "response" => "Found user: Alice (alice@example.com), Order count: 5",
#   "tool_calls" => [
#     %{"function" => %{"name" => "search_users", "arguments" => ...}}
#   ]
# }
```

---

## Testing

### Test Queue Integration

```elixir
# test/nexus/responses_api_integration_test.exs
defmodule Nexus.ResponsesAPIIntegrationTest do
  use ExUnit.Case

  @db_url System.get_env("SHARED_QUEUE_DB_URL")

  setup do
    # Clear queues
    Pgmq.purge(@db_url, "llm_requests")
    Pgmq.purge(@db_url, "llm_results")
    :ok
  end

  test "basic Responses API request via queue" do
    request = %{
      request_id: Nexus.ID.generate(),
      agent_id: "test-agent",
      api_version: "responses",
      input: "Say hello",
      task_type: :chat
    }

    # Publish request
    {:ok, _} = Pgmq.send(@db_url, "llm_requests", Jason.encode!(request))

    # Wait for processing (consumer should be running)
    Process.sleep(2000)

    # Read result
    {:ok, [result]} = Pgmq.read(@db_url, "llm_results", 1)
    response = Jason.decode!(result.message)

    assert response["request_id"] == request.request_id
    assert response["api_version"] == "responses"
    assert response["response"]
    assert response["response_id"]  # Should have response_id for state
  end

  test "multi-turn conversation via queue" do
    # Turn 1
    req1 = %{
      request_id: Nexus.ID.generate(),
      agent_id: "test-agent",
      api_version: "responses",
      input: "My favorite color is blue",
      store: true
    }

    {:ok, _} = Pgmq.send(@db_url, "llm_requests", Jason.encode!(req1))
    Process.sleep(2000)

    {:ok, [res1]} = Pgmq.read(@db_url, "llm_results", 1)
    response1 = Jason.decode!(res1.message)

    # Turn 2: Reference previous response
    req2 = %{
      request_id: Nexus.ID.generate(),
      agent_id: "test-agent",
      api_version: "responses",
      input: "What's my favorite color?",
      previous_response_id: response1["response_id"]
    }

    {:ok, _} = Pgmq.send(@db_url, "llm_requests", Jason.encode!(req2))
    Process.sleep(2000)

    {:ok, [res2]} = Pgmq.read(@db_url, "llm_results", 1)
    response2 = Jason.decode!(res2.message)

    assert response2["response"] =~ ~r/blue/i
  end
end
```

---

## Performance Considerations

### Queue vs Direct API

| Aspect | Direct API Call | pgmq Queue |
|--------|----------------|------------|
| Latency | Lower (~500-2000ms) | Higher (+queue delay) |
| Reliability | Retry in code | Built-in retry |
| Throughput | Limited by client | Controlled by consumer |
| State | Managed in memory | Persisted in PostgreSQL |
| Scaling | Vertical (bigger instance) | Horizontal (more consumers) |

### When to Use pgmq

✅ **Use pgmq when**:
- Background/async processing acceptable
- Need reliable delivery (retries)
- Want to control rate limiting
- Multiple consumers needed
- State persistence important
- Long-running operations

❌ **Use direct API when**:
- Real-time response needed
- Simple request/response
- No retry logic needed
- Single consumer sufficient

---

## Migration Path

### Phase 1: Add Responses API Support (No Breaking Changes)

```elixir
# Existing requests continue to work
request = %{
  request_id: "...",
  messages: [...],  # Chat Completions format
  # No api_version specified → defaults to "chat_completions"
}
```

### Phase 2: Opt-In to Responses API

```elixir
# New requests can use Responses API
request = %{
  request_id: "...",
  api_version: "responses",  # Opt-in
  input: "...",
  store: true
}
```

### Phase 3: Enable Advanced Features

```elixir
# Use MCP, tools, stateful conversations
request = %{
  api_version: "responses",
  input: "...",
  previous_response_id: "...",
  mcp_servers: [...],
  tools: [...]
}
```

---

## Configuration

```elixir
# config/config.exs
config :nexus,
  # Queue settings
  poll_interval_ms: 1000,
  batch_size: 10,

  # API settings
  default_api_version: "responses",  # "chat_completions" or "responses"
  enable_conversation_storage: true,

  # Responses API specific
  default_store: true,
  conversation_ttl: 3600  # 1 hour
```

---

## Summary

**✅ Yes, Responses API works great with pgmq!**

**Benefits**:
1. Async LLM requests with queue-based architecture
2. Server-side conversation state (no client tracking)
3. MCP tools execute server-side (no client round-trips)
4. Built-in retry and reliability via pgmq
5. Multi-consumer scaling
6. PostgreSQL state persistence

**Integration**:
- Add `api_version` field to queue messages
- Route based on API version in `LLMRouter`
- Track `response_id` for conversation continuity
- Store conversation state in PostgreSQL

**No Breaking Changes**: Existing Chat Completions requests continue to work!
