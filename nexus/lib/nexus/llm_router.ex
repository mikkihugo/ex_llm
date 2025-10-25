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
    - `:messages` - List of message maps with :role and :content
    - `:task_type` - Optional atom describing task (e.g., :architect, :coder)
    - `:max_tokens` - Optional max tokens for response
    - `:temperature` - Optional temperature (0.0-2.0)
    - `:stream` - Optional boolean to enable streaming

  ## Returns
  - `{:ok, response}` - LLM response with content, usage, and cost
  - `{:error, reason}` - Error details
  """
  def route(request) do
    complexity = Map.fetch!(request, :complexity)
    messages = Map.fetch!(request, :messages)
    opts = build_options(request)

    Logger.info("Routing LLM request",
      complexity: complexity,
      task_type: Map.get(request, :task_type),
      message_count: length(messages)
    )

    model = select_model(complexity, Map.get(request, :task_type))

    case call_provider(model, messages, opts) do
      {:ok, response} ->
        log_success(model, response)
        {:ok, response}

      {:error, reason} = error ->
        log_error(model, reason)
        error
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
      :coder -> "claude-3-5-sonnet-20241022"  # Claude Sonnet is excellent for code
      :planning -> "gpt-4o"  # GPT-4o for planning
      _ -> "claude-3-5-sonnet-20241022"  # Default to Claude Sonnet
    end
  end

  def select_model(:complex, task_type) do
    case task_type do
      :architect -> "claude-3-5-sonnet-20241022"  # Architecture design
      :code_generation -> "claude-3-5-sonnet-20241022"  # Complex code generation
      :refactoring -> "claude-3-5-sonnet-20241022"  # Large refactors
      _ -> "claude-3-5-sonnet-20241022"  # Default to Claude Sonnet for complex tasks
    end
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

  defp log_success(model, response) do
    Logger.info("LLM request successful",
      model: model,
      tokens: get_in(response, [:usage, :total_tokens]),
      cost: get_in(response, [:cost])
    )
  end

  defp log_error(model, reason) do
    Logger.error("LLM request failed",
      model: model,
      reason: inspect(reason)
    )
  end
end
