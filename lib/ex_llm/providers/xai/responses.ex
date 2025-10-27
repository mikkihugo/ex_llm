defmodule ExLLM.Providers.XAI.Responses do
  @moduledoc """
  X.AI Responses API client (/v1/responses).

  Provides access to X.AI's Responses API for server-side state, MCP integration,
  and built-in tools using the Grok models.

  ## Supported Models

  - `grok-2` - Latest Grok model
  - `grok-beta` - Beta Grok model
  - `grok-vision` - Vision-capable Grok model

  ## Usage

      # Simple request
      {:ok, response} = ExLLM.Providers.XAI.Responses.chat([
        %{role: "user", content: "Hello, world!"}
      ])

      # With specific model
      {:ok, response} = ExLLM.Providers.XAI.Responses.chat([
        %{role: "user", content: "Explain quantum computing"}
      ], model: "grok-2")

      # With MCP servers and tools
      {:ok, response} = ExLLM.Providers.XAI.Responses.chat([
        %{role: "user", content: "Analyze this code"}
      ], 
      model: "grok-2",
      mcp_servers: ["codebase"],
      tools: ["code_analysis", "file_search"]
      )

  ## Response Format

  The Responses API returns structured data with:
  - `id` - Response identifier
  - `model` - Model used
  - `choices` - Array of response choices
  - `usage` - Token usage information
  - `created` - Timestamp

  ## Error Handling

  Returns `{:error, reason}` for:
  - Invalid API key (401)
  - Invalid model (400)
  - Rate limiting (429)
  - Server errors (5xx)
  """

  @behaviour ExLLM.Provider

  @base_url "https://api.x.ai/v1"
  @responses_endpoint "/responses"

  @doc """
  Send a chat request to X.AI's Responses API.

  ## Parameters

  - `messages` - List of message maps with `:role` and `:content`
  - `opts` - Keyword list of options:
    - `:model` - Model to use (default: "grok-2")
    - `:mcp_servers` - List of MCP server names
    - `:tools` - List of tool names
    - `:stateful` - Whether to maintain state (default: false)
    - `:conversation_id` - Conversation ID for stateful requests
    - `:max_tokens` - Maximum tokens to generate
    - `:temperature` - Sampling temperature (0.0 to 2.0)
    - `:top_p` - Nucleus sampling parameter (0.0 to 1.0)

  ## Examples

      # Simple request
      {:ok, response} = ExLLM.Providers.XAI.Responses.chat([
        %{role: "user", content: "Hello!"}
      ])

      # With options
      {:ok, response} = ExLLM.Providers.XAI.Responses.chat([
        %{role: "user", content: "Explain AI"}
      ], 
      model: "grok-2",
      max_tokens: 1000,
      temperature: 0.7
      )

  """
  @spec chat([map()], keyword()) :: {:ok, map()} | {:error, term()}
  def chat(messages, opts \\ []) do
    with {:ok, config} <- get_config(opts),
         {:ok, request} <- build_responses_request(messages, opts),
         {:ok, response} <- execute_responses_request(request, config) do
      parse_responses_response(response)
    else
      {:error, :responses_not_available} ->
        # Fall back to regular X.AI chat if responses endpoint isn't available
        ExLLM.Providers.XAI.chat(messages, opts)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Build a request for the X.AI Responses API.

  Converts messages to the Responses API format with `input` field.
  """
  @spec build_responses_request([map()], keyword()) :: {:ok, map()} | {:error, term()}
  def build_responses_request(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "grok-2")
    mcp_servers = Keyword.get(opts, :mcp_servers, [])
    tools = Keyword.get(opts, :tools, [])
    stateful = Keyword.get(opts, :stateful, false)
    conversation_id = Keyword.get(opts, :conversation_id)
    max_tokens = Keyword.get(opts, :max_tokens)
    temperature = Keyword.get(opts, :temperature)
    top_p = Keyword.get(opts, :top_p)

    # Convert messages to input format for X.AI Responses API
    input = case messages do
      [%{role: "user", content: content}] when is_binary(content) ->
        content
      _ ->
        # For complex messages, convert to text format
        messages
        |> Enum.map(fn %{role: role, content: content} ->
          "#{role}: #{content}"
        end)
        |> Enum.join("\n")
    end

    request = %{
      model: model,
      input: input
    }

    # Add optional parameters
    request = if mcp_servers != [], do: Map.put(request, :mcp_servers, mcp_servers), else: request
    request = if tools != [], do: Map.put(request, :tools, tools), else: request
    request = if stateful, do: Map.put(request, :stateful, stateful), else: request
    request = if conversation_id, do: Map.put(request, :conversation_id, conversation_id), else: request
    request = if max_tokens, do: Map.put(request, :max_tokens, max_tokens), else: request
    request = if temperature, do: Map.put(request, :temperature, temperature), else: request
    request = if top_p, do: Map.put(request, :top_p, top_p), else: request

    {:ok, request}
  end

  @doc """
  Execute a request to the X.AI Responses API.
  """
  @spec execute_responses_request(map(), map()) :: {:ok, map()} | {:error, term()}
  def execute_responses_request(request, config) do
    url = "#{@base_url}#{@responses_endpoint}"
    headers = [
      {"authorization", "Bearer #{config.api_key}"},
      {"content-type", "application/json"}
    ]

    case ExLLM.Providers.Shared.HTTP.Core.post(url, request, headers) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Parse the response from X.AI's Responses API.

  Converts the response to a standardized format.
  """
  @spec parse_responses_response(map()) :: {:ok, map()} | {:error, term()}
  def parse_responses_response(response) do
    case response do
      %{"error" => error} ->
        {:error, error}
      %{"choices" => choices} = resp ->
        # Standardize the response format
        standardized = %{
          "id" => resp["id"],
          "model" => resp["model"],
          "choices" => choices,
          "usage" => resp["usage"],
          "created" => resp["created"]
        }
        {:ok, standardized}
      _ ->
        {:ok, response}
    end
  end

  @doc """
  Check if X.AI supports the Responses API.

  Returns true if the Responses API is available.
  """
  @spec responses_supported?() :: boolean()
  def responses_supported? do
    # X.AI supports the Responses API at https://api.x.ai/v1/responses
    true
  end

  # Private functions

  defp get_config(opts) do
    api_key = Keyword.get(opts, :api_key) || 
              Application.get_env(:ex_llm, :xai_api_key) ||
              System.get_env("XAI_API_KEY")

    if api_key do
      {:ok, %{api_key: api_key}}
    else
      {:error, :missing_api_key}
    end
  end
end