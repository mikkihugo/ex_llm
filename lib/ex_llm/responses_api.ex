defmodule ExLLM.ResponsesAPI do
  @moduledoc """
  Unified Responses API interface for providers that support it.
  
  The Responses API is a newer interface that provides enhanced features:
  - Server-side state management
  - MCP (Model Context Protocol) integration  
  - Built-in tools (web search, image generation, code interpreter)
  - Better structured outputs and JSON handling
  - Semi-broken JSON repair capabilities
  
  ## Supported Providers
  
  Currently, only OpenAI supports the Responses API. Other providers like OpenRouter
  may add support in the future.
  
  ## Usage
  
      # Basic usage with OpenAI
      {:ok, response} = ExLLM.ResponsesAPI.chat(:openai, [
        %{role: "user", content: "Hello!"}
      ])
      
      # With MCP servers
      {:ok, response} = ExLLM.ResponsesAPI.chat(:openai, messages,
        mcp_servers: [
          %{
            name: "filesystem",
            command: "npx",
            args: ["@modelcontextprotocol/server-filesystem", "/path/to/dir"]
          }
        ]
      )
      
      # With built-in tools
      {:ok, response} = ExLLM.ResponsesAPI.chat(:openai, messages,
        tools: [:web_search, :image_generation]
      )
      
      # Stateful conversation
      {:ok, response} = ExLLM.ResponsesAPI.chat(:openai, messages,
        stateful: true
      )
      
      # Continue existing conversation
      {:ok, response} = ExLLM.ResponsesAPI.chat(:openai, messages,
        conversation_id: "conv_abc123"
      )
  """

  @doc """
  Send a chat request using the Responses API.
  
  ## Parameters
  
  - `provider` - The provider to use (:openai, :openrouter, etc.)
  - `messages` - List of message maps or a single string
  - `opts` - Options including:
    - `:model` - Model to use (defaults to provider default)
    - `:mcp_servers` - List of MCP server configurations
    - `:tools` - List of built-in tools to enable
    - `:stateful` - Enable server-side state management
    - `:conversation_id` - Continue existing conversation
    - `:max_tokens` - Maximum tokens to generate
    - `:temperature` - Sampling temperature
  """
  @spec chat(atom(), [map()] | String.t(), keyword()) :: 
    {:ok, ExLLM.Types.LLMResponse.t()} | {:error, term()}
  def chat(provider, messages, opts \\ []) do
    case get_responses_provider(provider) do
      {:ok, provider_module} ->
        # Convert string to messages if needed
        messages = normalize_messages(messages)
        
        # Call the provider's responses implementation
        provider_module.chat(messages, opts)
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Stream a chat response using the Responses API.
  
  ## Parameters
  
  - `provider` - The provider to use
  - `messages` - List of message maps or a single string
  - `callback` - Function to call for each chunk
  - `opts` - Options (same as chat/3)
  """
  @spec stream_chat(atom(), [map()] | String.t(), function(), keyword()) :: 
    {:ok, term()} | {:error, term()}
  def stream_chat(provider, messages, callback, opts \\ []) do
    case get_responses_provider(provider) do
      {:ok, provider_module} ->
        messages = normalize_messages(messages)
        provider_module.stream_chat(messages, callback, opts)
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if a provider supports the Responses API.
  """
  @spec supported?(atom()) :: boolean()
  def supported?(provider) do
    case get_responses_provider(provider) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  List all providers that support the Responses API.
  """
  @spec supported_providers() :: [atom()]
  def supported_providers do
    # For now, only OpenAI supports responses
    # This will be updated as more providers add support
    [:openai]
  end

  @doc """
  Get the conversation ID from a response.
  
  Returns the conversation ID if the response is from a stateful conversation.
  """
  @spec get_conversation_id(ExLLM.Types.LLMResponse.t()) :: String.t() | nil
  def get_conversation_id(response) do
    case response.metadata do
      %{conversation_id: conversation_id} -> conversation_id
      _ -> nil
    end
  end

  @doc """
  Check if a response contains tool calls.
  """
  @spec has_tool_calls?(ExLLM.Types.LLMResponse.t()) :: boolean()
  def has_tool_calls?(response) do
    case response.metadata do
      %{tool_calls: tool_calls} when is_list(tool_calls) and length(tool_calls) > 0 -> true
      _ -> false
    end
  end

  @doc """
  Check if a response contains MCP server interactions.
  """
  @spec has_mcp_interactions?(ExLLM.Types.LLMResponse.t()) :: boolean()
  def has_mcp_interactions?(response) do
    case response.metadata do
      %{mcp_interactions: interactions} when is_list(interactions) and length(interactions) > 0 -> true
      _ -> false
    end
  end

  @doc """
  List available built-in tools for a provider.
  """
  @spec list_builtin_tools(atom()) :: [atom()] | {:error, term()}
  def list_builtin_tools(provider) do
    case get_responses_provider(provider) do
      {:ok, provider_module} ->
        if function_exported?(provider_module, :list_builtin_tools, 0) do
          provider_module.list_builtin_tools()
        else
          # Default tools that most providers would support
          [:web_search, :image_generation, :code_interpreter]
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp get_responses_provider(provider) do
    case provider do
      :openai ->
        # Check if OpenAI has responses support
        if Code.ensure_loaded?(ExLLM.Providers.OpenAI.Responses) do
          {:ok, ExLLM.Providers.OpenAI.Responses}
        else
          {:error, :responses_not_implemented}
        end
        
      :openrouter ->
        # Check if OpenRouter has responses support
        if Code.ensure_loaded?(ExLLM.Providers.OpenRouter.Responses) do
          {:ok, ExLLM.Providers.OpenRouter.Responses}
        else
          {:error, :responses_not_implemented}
        end
        
      _ ->
        {:error, :provider_not_supported}
    end
  end

  defp normalize_messages(messages) when is_binary(messages) do
    [%{role: "user", content: messages}]
  end

  defp normalize_messages(messages) when is_list(messages) do
    messages
  end
end