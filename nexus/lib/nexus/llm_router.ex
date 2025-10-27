defmodule Nexus.LLMRouter do
  @moduledoc """
  LLM Router - Routes LLM requests to appropriate providers using ex_llm.

  This module handles:
  - Model selection based on task complexity
  - Provider routing via ex_llm
  - Error handling and fallback logic

  ## Configuration

  Set provider API keys via environment variables:
  - `ANTHROPIC_API_KEY` - For Claude models
  - `OPENAI_API_KEY` - For GPT models
  - `GEMINI_API_KEY` - For Gemini models
  - `GROQ_API_KEY` - For Groq models

  ## Usage

      # Route simple task
      {:ok, response} = Nexus.LLMRouter.route(%{
        complexity: :simple,
        messages: [%{role: "user", content: "Hello"}],
        task_type: :classifier
      })

      # Route complex architectural task
      {:ok, response} = Nexus.LLMRouter.route(%{
        complexity: :complex,
        messages: messages,
        task_type: :architect,
        max_tokens: 4000
      })
  """

  require Logger

  @doc """
  Route LLM request to appropriate provider based on complexity and task type.

  ## Parameters
  - `request` - Map with keys:
    - `:complexity` - :simple, :medium, or :complex
    - `:api_version` - Optional "chat_completions" (default) or "responses"
    - `:messages` - List of message maps (Chat Completions format)
    - `:input` - String or list (Responses API format)
    - `:task_type` - Optional atom describing task (e.g., :architect, :coder)
    - `:max_tokens` - Optional max tokens for response
    - `:temperature` - Optional temperature (0.0-2.0)
    - `:stream` - Optional boolean to enable streaming
    - `:previous_response_id` - Optional (Responses API) for conversation continuity
    - `:mcp_servers` - Optional (Responses API) for MCP integration
    - `:tools` - Optional tools (built-in or custom functions)
    - `:store` - Optional (Responses API) enable server-side state

  ## Returns
  - `{:ok, response}` - LLM response with content, usage, and cost
  - `{:error, reason}` - Error details
  """
  def route(request) do
    api_version = Map.get(request, :api_version, "chat_completions")

    case api_version do
      "chat_completions" -> route_chat_completions(request)
      "responses" -> route_responses_api(request)
      _ -> {:error, {:unsupported_api_version, api_version}}
    end
  end

  # Chat Completions API routing (existing behavior)
  defp route_chat_completions(request) do
    complexity = Map.fetch!(request, :complexity)
    messages = Map.fetch!(request, :messages)
    opts = build_options(request)

    Logger.info("Routing LLM request (Chat Completions)",
      complexity: complexity,
      task_type: Map.get(request, :task_type),
      message_count: length(messages)
    )

    model = select_model(complexity, Map.get(request, :task_type))

    case call_provider(model, messages, opts) do
      {:ok, response} ->
        log_success(model, response, api_version: "chat_completions")
        {:ok, response}

      {:error, reason} = error ->
        log_error(model, reason)
        error
    end
  end

  # Responses API routing (new)
  defp route_responses_api(request) do
    complexity = Map.fetch!(request, :complexity)
    input = get_input(request)

    Logger.info("Routing LLM request (Responses API)",
      complexity: complexity,
      task_type: Map.get(request, :task_type),
      has_previous_response: Map.has_key?(request, :previous_response_id),
      has_mcp_servers: Map.has_key?(request, :mcp_servers)
    )

    model = select_model(complexity, Map.get(request, :task_type))
    opts = build_responses_options(request, model)

    case call_responses_api(input, opts) do
      {:ok, response} ->
        log_success(model, response, api_version: "responses")
        {:ok, response}

      {:error, reason} = error ->
        log_error(model, reason)
        error
    end
  end

  defp get_input(request) do
    cond do
      Map.has_key?(request, :input) ->
        request.input

      Map.has_key?(request, :messages) ->
        request.messages

      true ->
        {:error, :missing_input}
    end
  end

  @doc """
  Select appropriate model based on complexity and task type.

  Returns model identifier for ex_llm (e.g., "gpt-4o", "claude-3-5-sonnet-20241022").
  """
  def select_model(complexity, task_type \\ nil)

  def select_model(:simple, _task_type) do
    # Simple tasks: Use fast, cheap models
    # Gemini Flash is free and fast
    "gemini-2.0-flash-exp"
  end

  def select_model(:medium, task_type) do
    case task_type do
      :coder -> select_codex_or_fallback("gpt-4o")  # Codex if available, else GPT-4o
      :planning -> "gpt-4o"  # GPT-4o for planning
      _ -> "claude-3-5-sonnet-20241022"  # Default to Claude Sonnet
    end
  end

  def select_model(:complex, task_type) do
    case task_type do
      :architect -> select_codex_or_fallback("claude-3-5-sonnet-20241022")  # Codex or Claude
      :code_generation -> select_codex_or_fallback("claude-3-5-sonnet-20241022")  # Codex best for code
      :refactoring -> select_codex_or_fallback("claude-3-5-sonnet-20241022")  # Codex for refactors
      _ -> "claude-3-5-sonnet-20241022"  # Default to Claude Sonnet for complex tasks
    end
  end

  # Check if Codex is configured, otherwise fallback
  defp select_codex_or_fallback(fallback_model) do
    if codex_configured?() do
      "gpt-5-codex"  # Use Codex if OAuth tokens available
    else
      fallback_model  # Fallback to specified model
    end
  end

  defp codex_configured? do
    Nexus.Providers.Codex.configured?()
  rescue
    _ -> false  # If module not available, fallback
  end

  # Private functions

  defp build_options(request) do
    []
    |> maybe_add_opt(:max_tokens, Map.get(request, :max_tokens))
    |> maybe_add_opt(:temperature, Map.get(request, :temperature))
    |> maybe_add_opt(:stream, Map.get(request, :stream, false))
  end

  defp maybe_add_opt(opts, _key, nil), do: opts
  defp maybe_add_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp call_provider(model, messages, opts) do
    # Convert messages to ex_llm format
    formatted_messages = format_messages(messages)

    # Call ex_llm with selected model
    ExLLM.chat(formatted_messages, [model: model] ++ opts)
  end

  defp format_messages(messages) do
    Enum.map(messages, fn msg ->
      %{
        role: Map.get(msg, :role) || Map.get(msg, "role"),
        content: Map.get(msg, :content) || Map.get(msg, "content")
      }
    end)
  end

  defp build_responses_options(request, model) do
    [
      api_version: :responses,
      model: model
    ]
    |> maybe_add_opt(:temperature, Map.get(request, :temperature))
    |> maybe_add_opt(:max_tokens, Map.get(request, :max_tokens))
    |> maybe_add_opt(:previous_response_id, Map.get(request, :previous_response_id))
    |> maybe_add_opt(:store, Map.get(request, :store))
    |> maybe_add_mcp_servers(request)
    |> maybe_add_tools(request)
  end

  defp maybe_add_mcp_servers(opts, request) do
    case Map.get(request, :mcp_servers) do
      nil -> opts
      [] -> opts
      servers -> Keyword.put(opts, :mcp_servers, parse_mcp_servers(servers))
    end
  end

  defp parse_mcp_servers(servers) do
    Enum.map(servers, fn server ->
      %{
        server_label: Map.get(server, :server_label) || Map.get(server, "server_label"),
        server_url: Map.get(server, :server_url) || Map.get(server, "server_url"),
        allowed_tools: Map.get(server, :allowed_tools) || Map.get(server, "allowed_tools", [])
      }
    end)
  end

  defp maybe_add_tools(opts, request) do
    case Map.get(request, :tools) do
      nil -> opts
      [] -> opts
      tools -> Keyword.put(opts, :tools, tools)
    end
  end

  defp call_responses_api(input, opts) do
    # Call ex_llm with Responses API version
    ExLLM.chat(:openai, input, opts)
  end

defp log_success(model, response, opts) do
    api_version = Keyword.get(opts, :api_version, "chat_completions")

    Logger.info("LLM request successful",
      model: model,
      api_version: api_version,
      tokens: get_in(response, [:usage, :total_tokens]),
      cost: get_in(response, [:cost]),
      response_id: get_in(response, [:id])
    )
  end

  defp log_error(model, reason) do
    Logger.error("LLM request failed",
      model: model,
      reason: inspect(reason)
    )
  end
end
