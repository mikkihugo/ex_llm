# Responses API Implementation Guide

Practical implementation guide with code examples, test plans, and development workflow for adding Responses API support to ex_llm.

## Quick Start Implementation

### Step 1: Create Module Structure

```bash
# Create directory structure
mkdir -p lib/ex_llm/providers/openai/responses
mkdir -p test/ex_llm/providers/openai/responses
```

### Step 2: Basic Responses Module

```elixir
# lib/ex_llm/providers/openai/responses.ex
defmodule ExLLM.Providers.OpenAI.Responses do
  @moduledoc """
  OpenAI Responses API client (/v1/responses).

  Provides:
  - Server-side conversation state management
  - MCP (Model Context Protocol) integration
  - Built-in tools (web search, image gen, code interpreter)
  - Preserved reasoning state across turns

  ## Examples

      # Basic usage
      {:ok, response} = Responses.chat([
        %{role: "user", content: "Hello!"}
      ], model: "gpt-5-codex")

      # With MCP servers
      {:ok, response} = Responses.chat(messages,
        model: "gpt-5-codex",
        mcp_servers: [mcp_config]
      )

      # Stateful conversation
      {:ok, response} = Responses.chat(messages,
        stateful: true,
        conversation_id: "conv_abc123"
      )
  """

  @behaviour ExLLM.Provider

  alias ExLLM.Providers.OpenAI.Responses.{
    BuildRequest,
    ParseResponse,
    StateManager,
    MCPClient,
    Tools
  }

  alias ExLLM.Providers.Shared.{ConfigHelper, ErrorHandler, HTTP.Core}
  alias ExLLM.Types

  @base_url "https://api.openai.com/v1"
  @default_model "gpt-5-codex"

  @doc """
  Send chat request using Responses API.

  ## Options

    * `:model` - Model to use (default: "gpt-5-codex")
    * `:stateful` - Enable server-side state management (default: false)
    * `:conversation_id` - Continue existing conversation
    * `:mcp_servers` - List of MCP server configurations
    * `:tools` - List of built-in tools to enable (:web_search, :image_generation, :code_interpreter)
    * `:temperature` - Sampling temperature (0.0-2.0)
    * `:max_tokens` - Maximum tokens in response

  ## Returns

    * `{:ok, response}` - Success with LLMResponse
    * `{:error, reason}` - Error
  """
  @impl ExLLM.Provider
  def chat(messages, options \\ []) do
    with :ok <- validate_messages(messages),
         {:ok, config} <- get_config(options),
         {:ok, request} <- BuildRequest.build(messages, config, options),
         {:ok, http_response} <- execute_request(request, config),
         {:ok, response} <- ParseResponse.parse(http_response, options) do
      {:ok, response}
    end
  end

  @impl ExLLM.Provider
  def stream_chat(messages, options \\ []) do
    with :ok <- validate_messages(messages),
         {:ok, config} <- get_config(options),
         {:ok, request} <- BuildRequest.build_stream(messages, config, options),
         {:ok, stream} <- execute_stream_request(request, config) do
      {:ok, stream}
    end
  end

  @impl ExLLM.Provider
  def embeddings(_inputs, _options), do: {:error, :not_supported}

  @impl ExLLM.Provider
  def list_models(options \\ []) do
    # Delegate to existing OpenAI.list_models
    ExLLM.Providers.OpenAI.list_models(options)
  end

  @impl ExLLM.Provider
  def default_model, do: @default_model

  # Private functions

  defp validate_messages(messages) do
    ExLLM.Providers.Shared.MessageFormatter.validate_messages(messages)
  end

  defp get_config(options) do
    config_provider = ConfigHelper.get_config_provider(options)
    config = ConfigHelper.get_config(:openai, config_provider)
    api_key = ConfigHelper.get_api_key(config, "OPENAI_API_KEY")

    {:ok, %{
      api_key: api_key,
      base_url: config[:base_url] || @base_url,
      timeout: config[:timeout] || 60_000
    }}
  end

  defp execute_request(request, config) do
    headers = [
      {"authorization", "Bearer #{config.api_key}"},
      {"content-type", "application/json"},
      {"openai-beta", "responses-api=1"}  # Beta header required
    ]

    Core.post(request.url, request.body, headers, timeout: config.timeout)
  end

  defp execute_stream_request(request, config) do
    headers = [
      {"authorization", "Bearer #{config.api_key}"},
      {"content-type", "application/json"},
      {"openai-beta", "responses-api=1"}
    ]

    Core.stream(request.url, request.body, headers, timeout: config.timeout)
  end
end
```

### Step 3: Request Builder

```elixir
# lib/ex_llm/providers/openai/responses/build_request.ex
defmodule ExLLM.Providers.OpenAI.Responses.BuildRequest do
  @moduledoc """
  Builds HTTP requests for Responses API.
  """

  alias ExLLM.Providers.OpenAI.Responses.{MCPClient, Tools}

  @doc """
  Build chat request for Responses API.
  """
  def build(messages, config, options) do
    body = %{
      model: Keyword.get(options, :model, "gpt-5-codex"),
      messages: format_messages(messages)
    }
    |> maybe_add_stateful(options)
    |> maybe_add_conversation_id(options)
    |> maybe_add_mcp_servers(options)
    |> maybe_add_tools(options)
    |> maybe_add_parameters(options)

    {:ok, %{
      url: "#{config.base_url}/responses",
      body: body
    }}
  end

  @doc """
  Build streaming request for Responses API.
  """
  def build_stream(messages, config, options) do
    {:ok, request} = build(messages, config, options)

    body = Map.put(request.body, :stream, true)
    {:ok, %{request | body: body}}
  end

  # Private functions

  defp format_messages(messages) do
    Enum.map(messages, fn
      %{role: role, content: content} = msg ->
        base = %{role: to_string(role), content: content}

        # Add name if present
        if msg[:name] do
          Map.put(base, :name, msg.name)
        else
          base
        end
    end)
  end

  defp maybe_add_stateful(body, options) do
    if Keyword.get(options, :stateful, false) do
      Map.put(body, :stateful, true)
    else
      body
    end
  end

  defp maybe_add_conversation_id(body, options) do
    case Keyword.get(options, :conversation_id) do
      nil -> body
      conv_id -> Map.put(body, :conversation_id, conv_id)
    end
  end

  defp maybe_add_mcp_servers(body, options) do
    case Keyword.get(options, :mcp_servers) do
      nil -> body
      [] -> body
      servers -> Map.put(body, :mcp_servers, MCPClient.format_for_request(servers))
    end
  end

  defp maybe_add_tools(body, options) do
    case Keyword.get(options, :tools) do
      nil -> body
      [] -> body
      tool_types -> Map.put(body, :tools, Tools.format_tools(tool_types))
    end
  end

  defp maybe_add_parameters(body, options) do
    body
    |> maybe_add_param(:temperature, options)
    |> maybe_add_param(:max_tokens, options)
    |> maybe_add_param(:top_p, options)
    |> maybe_add_param(:frequency_penalty, options)
    |> maybe_add_param(:presence_penalty, options)
  end

  defp maybe_add_param(body, key, options) do
    case Keyword.get(options, key) do
      nil -> body
      value -> Map.put(body, key, value)
    end
  end
end
```

### Step 4: Response Parser

```elixir
# lib/ex_llm/providers/openai/responses/parse_response.ex
defmodule ExLLM.Providers.OpenAI.Responses.ParseResponse do
  @moduledoc """
  Parses responses from Responses API.
  """

  alias ExLLM.Types.LLMResponse

  @doc """
  Parse Responses API response into LLMResponse struct.
  """
  def parse({:ok, %{status: 200, body: body}}, _options) do
    response = %LLMResponse{
      content: extract_content(body),
      role: "assistant",
      model: body["model"],
      finish_reason: body["choices"] |> List.first() |> Map.get("finish_reason"),
      usage: parse_usage(body["usage"]),
      cost: calculate_cost(body),
      metadata: parse_metadata(body)
    }

    {:ok, response}
  end

  def parse({:ok, %{status: status, body: body}}, _options) do
    {:error, {:api_error, %{status: status, body: body}}}
  end

  def parse({:error, reason}, _options) do
    {:error, reason}
  end

  # Private functions

  defp extract_content(body) do
    body
    |> Map.get("choices", [])
    |> List.first()
    |> Map.get("message", %{})
    |> Map.get("content", "")
  end

  defp parse_usage(nil), do: nil
  defp parse_usage(usage) do
    %{
      prompt_tokens: usage["prompt_tokens"] || 0,
      completion_tokens: usage["completion_tokens"] || 0,
      total_tokens: usage["total_tokens"] || 0
    }
  end

  defp calculate_cost(body) do
    # Cost calculation based on model pricing
    model = body["model"]
    usage = body["usage"]

    if usage do
      ExLLM.Core.Cost.calculate_cost(
        model,
        usage["prompt_tokens"] || 0,
        usage["completion_tokens"] || 0
      )
    else
      nil
    end
  end

  defp parse_metadata(body) do
    %{
      conversation_id: body["conversation_id"],
      tool_calls: parse_tool_calls(body),
      sources: body["sources"],
      images: body["images"],
      code_outputs: body["code_outputs"]
    }
  end

  defp parse_tool_calls(body) do
    body
    |> Map.get("choices", [])
    |> List.first()
    |> Map.get("message", %{})
    |> Map.get("tool_calls", [])
  end
end
```

### Step 5: MCP Client

```elixir
# lib/ex_llm/providers/openai/responses/mcp_client.ex
defmodule ExLLM.Providers.OpenAI.Responses.MCPClient do
  @moduledoc """
  Client for Model Context Protocol (MCP) server integration.
  """

  alias ExLLM.Providers.Shared.HTTP.Core

  @doc """
  Format MCP server configurations for Responses API request.

  ## Examples

      iex> servers = [
      ...>   %{url: "https://mcp.example.com", tools: ["search"], auth: %{type: :bearer, token: "..."}}
      ...> ]
      iex> format_for_request(servers)
      [%{url: "https://mcp.example.com", tools: ["search"], auth: %{type: "bearer", token: "..."}}]
  """
  def format_for_request(mcp_servers) when is_list(mcp_servers) do
    Enum.map(mcp_servers, &format_server/1)
  end

  defp format_server(server) when is_map(server) do
    %{
      url: server.url || server[:url],
      tools: server.tools || server[:tools] || [],
      auth: format_auth(server.auth || server[:auth])
    }
  end

  defp format_auth(nil), do: nil
  defp format_auth(%{type: :bearer, token: token}) do
    %{type: "bearer", token: token}
  end
  defp format_auth(%{type: :api_key, token: token}) do
    %{type: "api_key", api_key: token}
  end
  defp format_auth(%{type: :basic, username: user, password: pass}) do
    %{type: "basic", username: user, password: pass}
  end

  @doc """
  Discover available tools from MCP server.

  ## Examples

      iex> discover_tools("https://mcp.example.com")
      {:ok, [
        %{name: "search", description: "Search the database"},
        %{name: "calculate", description: "Perform calculations"}
      ]}
  """
  def discover_tools(server_url) when is_binary(server_url) do
    case Core.get("#{server_url}/tools") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body["tools"] || []}

      {:ok, %{status: status, body: body}} ->
        {:error, {:mcp_discovery_failed, %{status: status, body: body}}}

      {:error, reason} ->
        {:error, {:mcp_server_unreachable, reason}}
    end
  end

  @doc """
  Validate MCP server configuration.
  """
  def validate_config(server_config) do
    cond do
      !Map.has_key?(server_config, :url) and !Map.has_key?(server_config, "url") ->
        {:error, :missing_url}

      !String.starts_with?(server_config.url || server_config["url"], "https://") ->
        {:error, :insecure_url}

      true ->
        :ok
    end
  end
end
```

### Step 6: Tools Module

```elixir
# lib/ex_llm/providers/openai/responses/tools.ex
defmodule ExLLM.Providers.OpenAI.Responses.Tools do
  @moduledoc """
  Built-in tools for Responses API.
  """

  @type tool_type :: :web_search | :image_generation | :code_interpreter

  @doc """
  Format tools for API request.

  ## Examples

      iex> format_tools([:web_search, :code_interpreter])
      [
        %{type: "web_search"},
        %{type: "code_interpreter", config: %{timeout: 30000}}
      ]
  """
  @spec format_tools([tool_type()]) :: [map()]
  def format_tools(tool_types) when is_list(tool_types) do
    Enum.map(tool_types, &format_tool/1)
  end

  @spec format_tool(tool_type()) :: map()
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

  @doc """
  Extract tool outputs from response.
  """
  def extract_tool_outputs(response_metadata) do
    %{
      web_search: extract_web_search_results(response_metadata),
      images: extract_images(response_metadata),
      code_outputs: extract_code_outputs(response_metadata)
    }
  end

  defp extract_web_search_results(metadata) do
    metadata[:sources] || []
  end

  defp extract_images(metadata) do
    metadata[:images] || []
  end

  defp extract_code_outputs(metadata) do
    metadata[:code_outputs] || []
  end
end
```

### Step 7: State Manager

```elixir
# lib/ex_llm/providers/openai/responses/state_manager.ex
defmodule ExLLM.Providers.OpenAI.Responses.StateManager do
  @moduledoc """
  Manages server-side conversation state for Responses API.
  """

  alias ExLLM.Providers.Shared.HTTP.Core

  @doc """
  Start a new stateful conversation.

  ## Examples

      iex> start_conversation(messages, api_key: "sk-...")
      {:ok, %{conversation_id: "conv_abc123", response: %LLMResponse{...}}}
  """
  def start_conversation(messages, options) do
    # Conversation is started automatically by Responses API
    # when stateful: true is set in request
    {:ok, %{
      stateful: true,
      messages: messages,
      options: options
    }}
  end

  @doc """
  Continue an existing conversation.

  ## Examples

      iex> continue_conversation("conv_abc123", new_messages, api_key: "sk-...")
      {:ok, %LLMResponse{...}}
  """
  def continue_conversation(conversation_id, new_messages, options) do
    # Add conversation_id to options
    options = Keyword.put(options, :conversation_id, conversation_id)
    {:ok, {new_messages, options}}
  end

  @doc """
  Get conversation history from server.

  ## Examples

      iex> get_history("conv_abc123", api_key: "sk-...")
      {:ok, [
        %{role: "user", content: "Hello"},
        %{role: "assistant", content: "Hi!"}
      ]}
  """
  def get_history(conversation_id, options) do
    config = get_config(options)
    url = "#{config.base_url}/conversations/#{conversation_id}"

    headers = [
      {"authorization", "Bearer #{config.api_key}"},
      {"openai-beta", "responses-api=1"}
    ]

    case Core.get(url, headers) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body["messages"] || []}

      {:ok, %{status: 404}} ->
        {:error, :conversation_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Delete conversation from server.

  ## Examples

      iex> delete_conversation("conv_abc123", api_key: "sk-...")
      :ok
  """
  def delete_conversation(conversation_id, options) do
    config = get_config(options)
    url = "#{config.base_url}/conversations/#{conversation_id}"

    headers = [
      {"authorization", "Bearer #{config.api_key}"},
      {"openai-beta", "responses-api=1"}
    ]

    case Core.delete(url, headers) do
      {:ok, %{status: status}} when status in [200, 204] ->
        :ok

      {:ok, %{status: 404}} ->
        :ok  # Already deleted

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_config(options) do
    %{
      api_key: Keyword.fetch!(options, :api_key),
      base_url: Keyword.get(options, :base_url, "https://api.openai.com/v1")
    }
  end
end
```

## Testing Implementation

### Unit Tests

```elixir
# test/ex_llm/providers/openai/responses/build_request_test.exs
defmodule ExLLM.Providers.OpenAI.Responses.BuildRequestTest do
  use ExUnit.Case, async: true

  alias ExLLM.Providers.OpenAI.Responses.BuildRequest

  @messages [%{role: "user", content: "Hello"}]
  @config %{base_url: "https://api.openai.com/v1", api_key: "sk-test"}

  describe "build/3" do
    test "builds basic request" do
      {:ok, request} = BuildRequest.build(@messages, @config, model: "gpt-5-codex")

      assert request.url == "https://api.openai.com/v1/responses"
      assert request.body.model == "gpt-5-codex"
      assert length(request.body.messages) == 1
      assert hd(request.body.messages).role == "user"
    end

    test "includes stateful flag when requested" do
      {:ok, request} = BuildRequest.build(@messages, @config, stateful: true)

      assert request.body.stateful == true
    end

    test "includes conversation_id when provided" do
      {:ok, request} = BuildRequest.build(@messages, @config, conversation_id: "conv_123")

      assert request.body.conversation_id == "conv_123"
    end

    test "includes MCP servers when provided" do
      mcp_servers = [
        %{url: "https://mcp.example.com", tools: ["search"], auth: %{type: :bearer, token: "abc"}}
      ]

      {:ok, request} = BuildRequest.build(@messages, @config, mcp_servers: mcp_servers)

      assert length(request.body.mcp_servers) == 1
      assert hd(request.body.mcp_servers).url == "https://mcp.example.com"
    end

    test "includes tools when provided" do
      {:ok, request} = BuildRequest.build(@messages, @config, tools: [:web_search, :code_interpreter])

      assert length(request.body.tools) == 2
      assert Enum.any?(request.body.tools, &(&1.type == "web_search"))
      assert Enum.any?(request.body.tools, &(&1.type == "code_interpreter"))
    end

    test "includes optional parameters" do
      {:ok, request} = BuildRequest.build(@messages, @config,
        temperature: 0.8,
        max_tokens: 2000,
        top_p: 0.9
      )

      assert request.body.temperature == 0.8
      assert request.body.max_tokens == 2000
      assert request.body.top_p == 0.9
    end
  end

  describe "build_stream/3" do
    test "builds streaming request" do
      {:ok, request} = BuildRequest.build_stream(@messages, @config, model: "gpt-5-codex")

      assert request.body.stream == true
    end
  end
end
```

```elixir
# test/ex_llm/providers/openai/responses/parse_response_test.exs
defmodule ExLLM.Providers.OpenAI.Responses.ParseResponseTest do
  use ExUnit.Case, async: true

  alias ExLLM.Providers.OpenAI.Responses.ParseResponse
  alias ExLLM.Types.LLMResponse

  describe "parse/2" do
    test "parses successful response" do
      http_response = {:ok, %{
        status: 200,
        body: %{
          "model" => "gpt-5-codex",
          "choices" => [
            %{
              "message" => %{"content" => "Hello!"},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{
            "prompt_tokens" => 10,
            "completion_tokens" => 5,
            "total_tokens" => 15
          },
          "conversation_id" => "conv_abc123"
        }
      }}

      {:ok, response} = ParseResponse.parse(http_response, [])

      assert %LLMResponse{} = response
      assert response.content == "Hello!"
      assert response.model == "gpt-5-codex"
      assert response.usage.total_tokens == 15
      assert response.metadata.conversation_id == "conv_abc123"
    end

    test "parses response with web search sources" do
      http_response = {:ok, %{
        status: 200,
        body: %{
          "model" => "gpt-5-codex",
          "choices" => [%{"message" => %{"content" => "Result"}}],
          "sources" => [
            %{"title" => "Example", "url" => "https://example.com"}
          ]
        }
      }}

      {:ok, response} = ParseResponse.parse(http_response, [])

      assert length(response.metadata.sources) == 1
      assert hd(response.metadata.sources)["title"] == "Example"
    end

    test "handles API errors" do
      http_response = {:ok, %{
        status: 429,
        body: %{"error" => %{"message" => "Rate limit exceeded"}}
      }}

      {:error, {:api_error, error}} = ParseResponse.parse(http_response, [])

      assert error.status == 429
    end
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
  @moduletag timeout: 30_000

  alias ExLLM.Providers.OpenAI.Responses

  setup do
    api_key = System.get_env("OPENAI_API_KEY")

    if is_nil(api_key) do
      {:skip, "OPENAI_API_KEY not set"}
    else
      {:ok, api_key: api_key}
    end
  end

  describe "basic chat" do
    test "sends simple request", %{api_key: api_key} do
      messages = [%{role: "user", content: "Say 'test successful'"}]

      {:ok, response} = Responses.chat(messages,
        model: "gpt-5-codex",
        api_key: api_key,
        max_tokens: 50
      )

      assert response.content
      assert response.model == "gpt-5-codex"
      assert response.usage.total_tokens > 0
    end
  end

  describe "stateful conversations" do
    test "maintains context across turns", %{api_key: api_key} do
      # Turn 1: Set context
      messages1 = [%{role: "user", content: "My favorite number is 42"}]

      {:ok, resp1} = Responses.chat(messages1,
        model: "gpt-5-codex",
        api_key: api_key,
        stateful: true
      )

      conv_id = resp1.metadata.conversation_id
      assert conv_id

      # Turn 2: Test context retention
      messages2 = [%{role: "user", content: "What's my favorite number?"}]

      {:ok, resp2} = Responses.chat(messages2,
        model: "gpt-5-codex",
        api_key: api_key,
        conversation_id: conv_id
      )

      assert resp2.content =~ ~r/42/
    end
  end

  @tag :web_search
  describe "web search tool" do
    test "performs web search", %{api_key: api_key} do
      messages = [%{role: "user", content: "What's the current weather in Tokyo?"}]

      {:ok, response} = Responses.chat(messages,
        model: "gpt-5-codex",
        api_key: api_key,
        tools: [:web_search]
      )

      assert response.content
      assert response.metadata.sources  # Should have web sources
    end
  end

  @tag :code_interpreter
  describe "code interpreter tool" do
    test "executes code", %{api_key: api_key} do
      messages = [%{role: "user", content: "Calculate 12345 * 67890"}]

      {:ok, response} = Responses.chat(messages,
        model: "gpt-5-codex",
        api_key: api_key,
        tools: [:code_interpreter]
      )

      assert response.content
      # Should contain the calculated result
      assert response.content =~ ~r/838102050/
    end
  end
end
```

## Development Workflow

### 1. Setup Development Environment

```bash
# Clone repo
cd packages/ex_llm

# Install dependencies
mix deps.get

# Set API key
export OPENAI_API_KEY="sk-..."

# Run tests
mix test

# Run only Responses API tests
mix test test/ex_llm/providers/openai/responses
```

### 2. Run Integration Tests

```bash
# Run all integration tests
mix test --only integration

# Run specific Responses API integration tests
mix test test/ex_llm/providers/openai/responses_integration_test.exs --only integration

# Run with specific tags
mix test --only web_search
mix test --only code_interpreter
```

### 3. Manual Testing

```bash
# Start IEx
iex -S mix

# Test basic call
iex> alias ExLLM.Providers.OpenAI.Responses
iex> messages = [%{role: "user", content: "Hello!"}]
iex> {:ok, resp} = Responses.chat(messages, model: "gpt-5-codex")
iex> IO.puts(resp.content)

# Test stateful conversation
iex> {:ok, resp1} = Responses.chat([%{role: "user", content: "I like pizza"}], stateful: true)
iex> conv_id = resp1.metadata.conversation_id
iex> {:ok, resp2} = Responses.chat([%{role: "user", content: "What do I like?"}], conversation_id: conv_id)
iex> IO.puts(resp2.content)

# Test with tools
iex> {:ok, resp} = Responses.chat([%{role: "user", content: "Search for Elixir news"}], tools: [:web_search])
iex> IO.inspect(resp.metadata.sources)
```

## Performance Benchmarks

### Benchmark Script

```elixir
# test/bench/responses_api_benchmark.exs
defmodule ResponsesAPIBenchmark do
  alias ExLLM.Providers.OpenAI.Responses

  def run_benchmarks do
    api_key = System.get_env("OPENAI_API_KEY")
    messages = [%{role: "user", content: "Hello"}]

    Benchee.run(%{
      "Chat Completions API" => fn ->
        ExLLM.chat(:openai, messages, api_key: api_key)
      end,
      "Responses API" => fn ->
        Responses.chat(messages, model: "gpt-5-codex", api_key: api_key)
      end,
      "Responses API (stateful)" => fn ->
        Responses.chat(messages, model: "gpt-5-codex", api_key: api_key, stateful: true)
      end
    })
  end
end

ResponsesAPIBenchmark.run_benchmarks()
```

Run benchmarks:

```bash
mix run test/bench/responses_api_benchmark.exs
```

## Debugging Tips

### Enable Debug Logging

```elixir
# config/dev.exs
config :ex_llm,
  log_level: :debug,
  log_requests: true,
  log_responses: true
```

### HTTP Request Inspection

```elixir
# Add to BuildRequest for debugging
require Logger

def build(messages, config, options) do
  request = # ... build request

  Logger.debug("Responses API Request: #{inspect(request, pretty: true)}")

  {:ok, request}
end
```

### Response Inspection

```elixir
# Add to ParseResponse for debugging
def parse({:ok, %{body: body}} = response, options) do
  Logger.debug("Responses API Response: #{inspect(body, pretty: true)}")

  # ... parse response
end
```

---

## Next Steps

1. **Implement Phase 1**: Basic Responses API support
2. **Add Tests**: Unit + integration tests
3. **Manual Testing**: Verify with real API
4. **Documentation**: Update user docs
5. **Phase 2+**: State management, MCP, tools

**Ready to start coding!** Follow the implementation plan in RESPONSES_API_DESIGN.md for full details.
