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
  alias Nexus.Providers.GeminiCode

  @gemini_code_prefix "gemini-code:"

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

  Returns model identifier for ex_llm by discovering available models dynamically.
  """
  def select_model(complexity, task_type \\ nil)

  def select_model(:simple, _task_type) do
    cond do
      gemini_code_available?() ->
        @gemini_code_prefix <> GeminiCode.default_model()

      true ->
        # Simple tasks: Use fast, cheap models
        # Try to find a fast, cost-effective model
        case find_model_by_criteria(:simple) do
          {:ok, model_id} -> model_id
          # Fallback
          {:error, _} -> "gemini-2.5-flash"
        end
    end
  end

  def select_model(:medium, task_type) do
    case task_type do
      :coder -> select_codex_or_fallback(find_medium_model())
      :planning -> find_medium_model()
      task when task in Singularity.MetaRegistry.TaskTypeRegistry.get_tasks_by_complexity(:medium) ->
        find_medium_model()
      _ -> find_medium_model()
    end
  end

  def select_model(:complex, task_type) do
    case task_type do
      :architect -> select_codex_or_fallback(find_complex_model())
      :code_generation -> select_codex_or_fallback(find_complex_model())
      :refactoring -> select_codex_or_fallback(find_complex_model())
      task when task in Singularity.MetaRegistry.TaskTypeRegistry.get_tasks_by_complexity(:complex) ->
        find_complex_model()
      _ -> find_complex_model()
    end
  end

  # Check if Codex is configured, otherwise fallback
  defp select_codex_or_fallback(fallback_model) do
    if codex_configured?() do
      # Use Codex if OAuth tokens available
      "gpt-5-codex"
    else
      # Fallback to specified model
      fallback_model
    end
  end

  defp codex_configured? do
    Nexus.Providers.Codex.configured?()
  rescue
    # If module not available, fallback
    _ -> false
  end

  # Dynamic model discovery using ex_llm
  # Note: ExLLM.Core.Models.list_all() always returns {:ok, models}, never {:error, _}
  defp find_model_by_criteria(:simple) do
    {:ok, models} = ExLLM.Core.Models.list_all()

    # Find fast, cheap models (Gemini Flash, GPT-4o-mini, GitHub Models, etc.)
    simple_model =
      models
      |> Enum.filter(fn model ->
        model.provider in [:gemini, :openai, :github_models] and
          (String.contains?(model.id, "flash") or
             String.contains?(model.id, "mini") or
             String.contains?(model.id, "github"))
      end)
      |> Enum.sort_by(fn model -> model.pricing[:input] || 0 end)
      |> List.first()

    if simple_model, do: {:ok, simple_model.id}, else: {:error, :no_model_found}
  end

  defp find_medium_model do
    # Note: ExLLM.Core.Models.list_all() always returns {:ok, models}, never {:error, _}
    {:ok, models} = ExLLM.Core.Models.list_all()

    # Find balanced models (Claude Sonnet, GPT-4o, GitHub Models, etc.)
    medium_model =
      models
      |> Enum.filter(fn model ->
        model.provider in [:anthropic, :openai, :github_models] and
          (String.contains?(model.id, "sonnet") or
             (String.contains?(model.id, "gpt-4o") and not String.contains?(model.id, "mini")) or
             String.contains?(model.id, "llama") or
             String.contains?(model.id, "mistral"))
      end)
      |> Enum.sort_by(fn model -> model.pricing[:input] || 0 end)
      |> List.first()

    if medium_model, do: medium_model.id, else: "claude-3-5-sonnet-latest"
  end

  defp find_complex_model do
    # Note: ExLLM.Core.Models.list_all() always returns {:ok, models}, never {:error, _}
    {:ok, models} = ExLLM.Core.Models.list_all()

    # Find powerful models (Claude Opus, GPT-4, GitHub Models, etc.)
    complex_model =
      models
      |> Enum.filter(fn model ->
        model.provider in [:anthropic, :openai, :github_models] and
          (String.contains?(model.id, "opus") or
             (String.contains?(model.id, "gpt-4") and not String.contains?(model.id, "mini")) or
             String.contains?(model.id, "llama-3.3") or
             String.contains?(model.id, "deepseek"))
      end)
      |> Enum.sort_by(fn model -> model.pricing[:input] || 0 end)
      |> List.first()

    if complex_model, do: complex_model.id, else: "claude-3-5-sonnet-latest"
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

    cond do
      is_binary(model) and String.starts_with?(model, @gemini_code_prefix) ->
        gemini_model = String.replace_prefix(model, @gemini_code_prefix, "")

        case GeminiCode.chat(formatted_messages, Keyword.put(opts, :model, gemini_model)) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end

      true ->
        # Call ex_llm with selected model
        ExLLM.chat(formatted_messages, [model: model] ++ opts)
    end
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

  defp gemini_code_available? do
    if Code.ensure_loaded?(GeminiCode) do
      GeminiCode.configured?()
    else
      false
    end
  rescue
    _ -> false
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
