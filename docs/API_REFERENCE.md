# SingularityLLM Public API Reference

This document provides a comprehensive overview of SingularityLLM's public API. The library provides three levels of API access:

1. **High-Level API** - Simple functions for common use cases
2. **Builder API** - Fluent interface for constructing requests
3. **Pipeline API** - Low-level access for advanced customization

## High-Level API

### Basic Chat
```elixir
# Simple chat completion with messages
messages = [%{role: "user", content: "Hello, world!"}]
{:ok, response} = SingularityLLM.chat(:openai, messages)

# With options
{:ok, response} = SingularityLLM.chat(:anthropic, messages, %{
  model: "claude-3-opus", 
  temperature: 0.7,
  max_tokens: 500
})

# Using provider/model syntax
{:ok, response} = SingularityLLM.chat("openai/gpt-4", messages)
```

### Streaming
```elixir
# Stream responses with a callback
SingularityLLM.stream(:openai, messages, %{stream: true}, fn chunk ->
  IO.write(chunk.content || "")
end)

# With options
SingularityLLM.stream(:anthropic, messages, %{
  model: "claude-3-5-sonnet-20241022",
  stream: true,
  temperature: 0.8
}, fn chunk ->
  process_chunk(chunk)
end)
```

## Builder API

### Fluent Request Building
```elixir
# Build and execute a request
{:ok, response} = 
  SingularityLLM.build(:openai)
  |> SingularityLLM.with_messages([
    %{role: "system", content: "You are a helpful assistant"},
    %{role: "user", content: "Hello!"}
  ])
  |> SingularityLLM.with_model("gpt-4")
  |> SingularityLLM.with_temperature(0.7)
  |> SingularityLLM.with_max_tokens(1000)
  |> SingularityLLM.execute()

# Streaming with builder
SingularityLLM.build(:anthropic)
|> SingularityLLM.with_messages(messages)
|> SingularityLLM.with_stream(fn chunk ->
  IO.write(chunk.content || "")
end)
|> SingularityLLM.execute_stream()

# With custom plugs
{:ok, response} =
  SingularityLLM.build(:openai)
  |> SingularityLLM.with_messages(messages)
  |> SingularityLLM.prepend_plug(MyApp.Plugs.RateLimiter)
  |> SingularityLLM.append_plug(MyApp.Plugs.Logger)
  |> SingularityLLM.execute()
```

## Pipeline API

### Direct Pipeline Execution
```elixir
# Create a request
request = SingularityLLM.Pipeline.Request.new(:openai, messages, %{
  model: "gpt-4",
  temperature: 0.7
})

# Run with default pipeline
{:ok, response} = SingularityLLM.run(request)

# Run with custom pipeline
custom_pipeline = [
  SingularityLLM.Plugs.ValidateProvider,
  MyApp.Plugs.CustomAuth,
  SingularityLLM.Plugs.FetchConfig,
  SingularityLLM.Plugs.BuildTeslaClient,
  SingularityLLM.Plugs.ExecuteRequest,
  SingularityLLM.Plugs.Providers.OpenAIParseResponse
]

{:ok, response} = SingularityLLM.run(request, custom_pipeline)
```

## Session Management

Sessions provide stateful conversation management with automatic context tracking.

### Creating and Using Sessions
```elixir
# Create a new session
{:ok, session} = SingularityLLM.Session.new(:anthropic, %{
  model: "claude-3-sonnet",
  system: "You are a helpful assistant"
})

# Chat with session (maintains conversation history)
{:ok, session, response} = SingularityLLM.Session.chat(session, "What's the weather?")

# Continue the conversation
{:ok, session, response} = SingularityLLM.Session.chat(session, "What about tomorrow?")

# Get session history
messages = session.messages

# Save/load sessions
{:ok, _} = SingularityLLM.Session.save(session, "/path/to/session.json")
{:ok, session} = SingularityLLM.Session.load("/path/to/session.json")
```

### Session with Streaming
```elixir
# Create streaming session
{:ok, session} = SingularityLLM.Session.new(:openai, %{stream: true})

# Stream with session
{:ok, session} = SingularityLLM.Session.stream(session, "Tell me a story", fn chunk ->
  IO.write(chunk.content || "")
end)
```

## Model Information

### Listing and Querying Models
```elixir
# List available models for a provider
{:ok, models} = SingularityLLM.list_models(:openai)

# Get detailed model information
{:ok, info} = SingularityLLM.get_model_info(:anthropic, "claude-3-opus")

# Check model capabilities
true = SingularityLLM.model_supports?(:openai, "gpt-4-vision", :vision)

# Get default model
model = SingularityLLM.default_model(:openai)
```

## Cost Tracking

### Calculate and Estimate Costs
```elixir
# Calculate actual cost from response
{:ok, cost} = SingularityLLM.calculate_cost(:openai, "gpt-4", 
  %{input_tokens: 100, output_tokens: 200}
)

# Format cost for display
"$0.0045" = SingularityLLM.format_cost(cost)

# Estimate tokens before making request
token_count = SingularityLLM.estimate_tokens("This is my prompt")
```

## Context Management

> 🚧 **Under Development**: Context management APIs are currently being refactored.

### Manual Context Management (Current)
```elixir
# Manual message limiting
max_messages = 20
messages = Enum.take(conversation, -max_messages)

{:ok, response} = SingularityLLM.chat(:openai, messages, model: "gpt-4")
```

### Future APIs (Planned)
The following APIs are under development:
- `SingularityLLM.prepare_messages/3` - Automatic message truncation
- `SingularityLLM.validate_context/3` - Context validation  
- `SingularityLLM.context_window_size/2` - Model context windows

See [FEATURE_STATUS.md](../FEATURE_STATUS.md) for current status.

## Function Calling

### Execute Functions with LLMs
```elixir
# Define available functions
functions = [
  %{
    name: "get_weather",
    description: "Get weather for a location",
    parameters: %{
      type: "object",
      properties: %{
        location: %{type: "string"}
      }
    }
  }
]

# Chat with function calling
{:ok, response} = SingularityLLM.chat(:openai, "What's the weather in NYC?",
  functions: functions
)

# Parse and execute function calls
{:ok, calls} = SingularityLLM.parse_function_calls(response)
{:ok, result} = SingularityLLM.execute_function(List.first(calls), 
  fn "get_weather", %{"location" => loc} ->
    {:ok, "Sunny, 72°F in #{loc}"}
  end
)

# Format result for LLM
formatted = SingularityLLM.format_function_result("get_weather", result)
```

## Embeddings

### Generate Text Embeddings
```elixir
# Single text embedding
{:ok, embedding} = SingularityLLM.embeddings(:openai, "Hello world")

# Multiple texts
{:ok, embeddings} = SingularityLLM.embeddings(:openai, ["Text 1", "Text 2"])

# Calculate similarity
similarity = SingularityLLM.cosine_similarity(embedding1, embedding2)

# List embedding models
{:ok, models} = SingularityLLM.list_embedding_models(:openai)
```

## Vision and Multimodal

### Work with Images
```elixir
# Load and validate image
{:ok, image_data} = SingularityLLM.load_image("/path/to/image.jpg",
  max_size: {1024, 1024},
  format: :jpeg
)

# Create vision message
message = SingularityLLM.vision_message("What's in this image?", 
  ["/path/to/image.jpg"]
)

# Check vision support
true = SingularityLLM.supports_vision?(:openai, "gpt-4-vision")
```

## Provider Information

### Query Provider Capabilities
```elixir
# List all supported providers
providers = SingularityLLM.supported_providers()

# Get provider capabilities
{:ok, caps} = SingularityLLM.get_provider_capabilities(:anthropic)

# Check specific capability
true = SingularityLLM.provider_supports?(:openai, :streaming)

# Check if provider is configured
true = SingularityLLM.configured?(:openai)
```

## Streaming Recovery

### Handle Stream Interruptions
```elixir
# Resume an interrupted stream
{:ok, new_stream_id} = SingularityLLM.resume_stream(old_stream_id,
  fn chunk -> IO.write(chunk.content) end
)

# List recoverable streams
streams = SingularityLLM.list_recoverable_streams()
```

## Response Types

### LLMResponse Structure
```elixir
%SingularityLLM.Types.LLMResponse{
  content: "The response text",
  model: "gpt-4",
  finish_reason: "stop",
  usage: %{
    input_tokens: 10,
    output_tokens: 20,
    total_tokens: 30
  },
  cost: %{
    input_cost: 0.0001,
    output_cost: 0.0002,
    total_cost: 0.0003,
    currency: "USD"
  },
  tools: nil,  # Tool calls if any
  raw_response: %{}  # Raw provider response
}
```

### StreamChunk Structure
```elixir
%SingularityLLM.Types.StreamChunk{
  content: "chunk text",  # Incremental content
  role: "assistant",
  done: false,  # true when streaming completes
  model: "gpt-4",
  usage: %{},  # Token usage (usually in final chunk)
  finish_reason: nil,  # Set in final chunk
  provider: :openai
}
```

## Configuration

SingularityLLM can be configured through environment variables or application config:

```elixir
# config/config.exs
config :singularity_llm,
  # Provider API keys
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  
  # Default models
  default_models: %{
    openai: "gpt-4-turbo-preview",
    anthropic: "claude-3-sonnet"
  },
  
  # Global options
  cache_enabled: true,
  log_level: :info
```

## Error Handling

All API functions return `{:ok, result}` or `{:error, reason}` tuples:

```elixir
case SingularityLLM.chat(:openai, "Hello") do
  {:ok, response} -> 
    IO.puts(response.content)
    
  {:error, {:api_error, status, message}} -> 
    IO.puts("API error #{status}: #{message}")
    
  {:error, {:rate_limit, retry_after}} -> 
    IO.puts("Rate limited, retry after #{retry_after}s")
    
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end
```

## Advanced Usage

### Custom Configuration Provider
```elixir
# Use a custom configuration provider
{:ok, response} = SingularityLLM.chat(:openai, "Hello",
  config_provider: MyApp.ConfigProvider
)
```

### Request Options
```elixir
# All available options for chat requests
{:ok, response} = SingularityLLM.chat(:openai, "Hello",
  # Model selection
  model: "gpt-4",
  
  # Generation parameters
  temperature: 0.7,
  max_tokens: 1000,
  top_p: 0.9,
  frequency_penalty: 0.0,
  presence_penalty: 0.0,
  stop: ["\\n\\n"],
  
  # Function calling
  functions: [...],
  function_call: "auto",
  
  # Response format
  response_format: %{type: "json_object"},
  
  # System message
  system: "You are a helpful assistant",
  
  # Other options
  user: "user-123",
  seed: 42,
  track_cost: true
)
```

## Best Practices

1. **Always handle errors**: LLM APIs can fail for various reasons
2. **Use sessions for conversations**: Maintains context automatically
3. **Monitor costs**: Use cost tracking functions to avoid surprises
4. **Validate context size**: Ensure messages fit within model limits
5. **Configure providers properly**: Set API keys and default models
6. **Use streaming for long responses**: Better user experience
7. **Cache responses when appropriate**: Reduce costs and latency

## Type Specifications

All return types are defined in `SingularityLLM.Types`:

```elixir
# Main response type
%SingularityLLM.Types.LLMResponse{
  content: String.t(),
  model: String.t(), 
  usage: %{input_tokens: integer(), output_tokens: integer()},
  cost: %{input: float(), output: float(), total: float()},
  finish_reason: String.t() | nil,
  function_call: map() | nil,
  tool_calls: [map()] | nil
}

# Streaming chunk type
%SingularityLLM.Types.StreamChunk{
  content: String.t(),
  finish_reason: String.t() | nil,
  chunk_index: integer()
}

# Session type
%SingularityLLM.Types.Session{
  provider: atom(),
  model: String.t(),
  messages: [map()],
  total_tokens: %{input: integer(), output: integer()},
  total_cost: %{input: float(), output: float(), total: float()},
  metadata: map()
}
```