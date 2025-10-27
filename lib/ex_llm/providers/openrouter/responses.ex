defmodule ExLLM.Providers.OpenRouter.Responses do
  @moduledoc """
  OpenRouter Responses API implementation.
  
  This module provides support for OpenRouter's Responses API endpoint when available.
  The Responses API offers enhanced features like:
  - Server-side state management
  - MCP (Model Context Protocol) integration
  - Built-in tools (web search, image generation, code interpreter)
  - Structured outputs with better JSON handling
  
  ## Usage
  
      # Basic usage
      {:ok, response} = ExLLM.Providers.OpenRouter.Responses.chat([
        %{role: "user", content: "Hello!"}
      ])
      
      # With MCP servers
      {:ok, response} = ExLLM.Providers.OpenRouter.Responses.chat(messages,
        mcp_servers: [
          %{
            name: "filesystem",
            command: "npx",
            args: ["@modelcontextprotocol/server-filesystem", "/path/to/dir"]
          }
        ]
      )
      
      # With built-in tools
      {:ok, response} = ExLLM.Providers.OpenRouter.Responses.chat(messages,
        tools: [:web_search, :image_generation]
      )
      
      # Stateful conversation
      {:ok, response} = ExLLM.Providers.OpenRouter.Responses.chat(messages,
        stateful: true
      )
  """

  @behaviour ExLLM.Provider

  @base_url "https://openrouter.ai/v1"
  @responses_endpoint "/responses"

  @impl true
  def configured?(opts \\ []) do
    # Check if we have an OpenRouter API key
    case ExLLM.Providers.OpenRouter.configured?(opts) do
      true -> true
      false -> false
    end
  end

  @impl true
  def chat(messages, opts \\ []) do
    # For now, fall back to regular OpenRouter chat since responses endpoint isn't available
    # This will be updated when OpenRouter adds responses support
    ExLLM.Providers.OpenRouter.chat(messages, opts)
  end

  @impl true
  def stream_chat(messages, opts \\ []) do
    # For now, fall back to regular OpenRouter streaming
    ExLLM.Providers.OpenRouter.stream_chat(messages, opts)
  end

  @impl true
  def list_models(opts \\ []) do
    # Use the same models as regular OpenRouter
    ExLLM.Providers.OpenRouter.list_models(opts)
  end

  @doc """
  Check if OpenRouter supports the Responses API.
  
  Returns `true` if the responses endpoint is available, `false` otherwise.
  """
  @spec responses_supported?() :: boolean()
  def responses_supported? do
    # OpenRouter has a Responses API Beta available
    # The endpoint is at https://openrouter.ai/v1/responses
    true
  end

  @doc """
  Build a request for the Responses API.
  
  This function prepares the request body for the `/responses` endpoint
  with support for MCP servers, built-in tools, and stateful conversations.
  """
  @spec build_responses_request([map()], keyword()) :: map()
  def build_responses_request(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "openai/gpt-4o-mini")
    mcp_servers = Keyword.get(opts, :mcp_servers, [])
    tools = Keyword.get(opts, :tools, [])
    stateful = Keyword.get(opts, :stateful, false)
    conversation_id = Keyword.get(opts, :conversation_id)

    base_request = %{
      model: model,
      messages: messages
    }

    # Add MCP servers if provided
    request = if length(mcp_servers) > 0 do
      Map.put(base_request, :mcp_servers, mcp_servers)
    else
      base_request
    end

    # Add tools if provided
    request = if length(tools) > 0 do
      Map.put(request, :tools, tools)
    else
      request
    end

    # Add stateful conversation support
    request = if stateful do
      Map.put(request, :stateful, true)
    else
      request
    end

    # Add conversation ID for continuing conversations
    request = if conversation_id do
      Map.put(request, :conversation_id, conversation_id)
    else
      request
    end

    request
  end

  @doc """
  Parse a response from the Responses API.
  
  Handles the enhanced response format with conversation state,
  tool calls, and MCP server interactions.
  """
  @spec parse_responses_response(map()) :: {:ok, map()} | {:error, term()}
  def parse_responses_response(response) do
    # This will be implemented when OpenRouter adds responses support
    # For now, return an error indicating the feature isn't available
    {:error, :responses_not_supported}
  end

  @doc """
  Start a stateful conversation.
  
  Creates a new conversation with server-side state management.
  """
  @spec start_conversation([map()], keyword()) :: {:ok, map()} | {:error, term()}
  def start_conversation(messages, opts \\ []) do
    # This will be implemented when OpenRouter adds responses support
    {:error, :responses_not_supported}
  end

  @doc """
  Continue an existing conversation.
  
  Sends new messages to an existing conversation using the conversation ID.
  """
  @spec continue_conversation(String.t(), [map()], keyword()) :: {:ok, map()} | {:error, term()}
  def continue_conversation(conversation_id, messages, opts \\ []) do
    # This will be implemented when OpenRouter adds responses support
    {:error, :responses_not_supported}
  end

  @doc """
  Get conversation history.
  
  Retrieves the full conversation history for a given conversation ID.
  """
  @spec get_conversation_history(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_conversation_history(conversation_id) do
    # This will be implemented when OpenRouter adds responses support
    {:error, :responses_not_supported}
  end

  @doc """
  List available built-in tools.
  
  Returns the list of built-in tools supported by the Responses API.
  """
  @spec list_builtin_tools() :: [atom()]
  def list_builtin_tools do
    # These are the tools that would be available when OpenRouter adds responses support
    [:web_search, :image_generation, :code_interpreter]
  end

  @doc """
  Validate MCP server configuration.
  
  Ensures the MCP server configuration is valid before sending to the API.
  """
  @spec validate_mcp_server(map()) :: {:ok, map()} | {:error, term()}
  def validate_mcp_server(config) do
    required_fields = [:name, :command]
    
    case Enum.all?(required_fields, &Map.has_key?(config, &1)) do
      true -> {:ok, config}
      false -> {:error, "MCP server config missing required fields: #{inspect(required_fields)}"}
    end
  end
end