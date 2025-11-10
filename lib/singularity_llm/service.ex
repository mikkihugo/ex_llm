defmodule SingularityLLM.Service do
  @moduledoc """
  Pure functional LLM service library.

  Provides direct HTTP calls to LLM providers without OTP infrastructure.
  """

  require Logger

  @capability_aliases %{
    "code" => "code",
    "codegen" => "code", 
    "coding" => "code",
    "reasoning" => "reasoning",
    "analysis" => "reasoning",
    "architect" => "reasoning",
    "architecture" => "reasoning",
    "creativity" => "creativity",
    "creative" => "creativity",
    "design" => "creativity",
    "speed" => "speed",
    "fast" => "speed",
    "cost" => "cost",
    "cheap" => "cost"
  }

  @capability_values ["code", "reasoning", "creativity", "speed", "cost"]

  @type model :: String.t()
  @type message :: %{role: String.t(), content: String.t()}
  @type llm_request :: %{
          required(:messages) => [message()],
          optional(:model) => model(),
          optional(:provider) => String.t(),
          optional(:complexity) => String.t(),
          optional(:task_type) => String.t(),
          optional(:capabilities) => [String.t()],
          optional(:max_tokens) => non_neg_integer(),
          optional(:temperature) => float(),
          optional(:stream) => boolean()
        }
  @type llm_response :: %{
          text: String.t(),
          model: model(),
          tokens_used: non_neg_integer(),
          cost_cents: non_neg_integer()
        }

  @doc """
  Call LLM with model name or complexity level.
  """
  @spec call(model() | atom(), [message()], keyword()) :: {:ok, llm_response()} | {:error, term()}
  def call(model_or_complexity, messages, opts \\ [])

  def call(model, messages, opts) when is_binary(model) do
    request = build_request(messages, Keyword.put(opts, :model, model))
    dispatch_request(request, opts)
  end

  def call(complexity, messages, opts) when complexity in [:simple, :medium, :complex] do
    opts = Keyword.put_new(opts, :complexity, complexity)
    request = build_request(messages, opts)
    dispatch_request(request, opts)
  end

  def call(model, messages, opts) when is_atom(model) do
    model
    |> Atom.to_string()
    |> call(messages, opts)
  end

  @doc """
  Call LLM with a simple prompt string.
  """
  @spec call_with_prompt(model() | atom(), String.t(), keyword()) :: {:ok, llm_response()} | {:error, term()}
  def call_with_prompt(model_or_complexity, prompt, opts \\ []) do
    messages = [%{role: "user", content: prompt}]
    call(model_or_complexity, messages, opts)
  end

  @doc """
  Call LLM with system prompt and user message.
  """
  @spec call_with_system(model() | atom(), String.t(), String.t(), keyword()) :: {:ok, llm_response()} | {:error, term()}
  def call_with_system(model_or_complexity, system_prompt, user_message, opts \\ []) do
    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_message}
    ]
    call(model_or_complexity, messages, opts)
  end

  # Private functions

  defp build_request(messages, opts) do
    %{
      messages: messages,
      model: Keyword.get(opts, :model),
      provider: Keyword.get(opts, :provider),
      complexity: Keyword.get(opts, :complexity),
      task_type: Keyword.get(opts, :task_type),
      capabilities: Keyword.get(opts, :capabilities),
      max_tokens: Keyword.get(opts, :max_tokens, 4096),
      temperature: Keyword.get(opts, :temperature, 0.7),
      stream: Keyword.get(opts, :stream, false)
    }
  end

  defp dispatch_request(request, opts) do
    provider = determine_provider(request, opts)
    model = determine_model(request, provider)

    case provider do
      "openai" -> call_openai_api(model, request, opts)
      "anthropic" -> call_anthropic_api(model, request, opts)
      "google" -> call_google_api(model, request, opts)
      "github" -> call_github_api(model, request, opts)
      "ollama" -> call_ollama_api(model, request, opts)
      _ -> {:error, {:unsupported_provider, provider}}
    end
  end

  defp determine_provider(request, opts) do
    cond do
      provider = Keyword.get(opts, :provider) -> provider
      provider = Map.get(request, :provider) -> provider
      model = Map.get(request, :model) ->
        cond do
          String.contains?(model, "gpt") -> "openai"
          String.contains?(model, "claude") -> "anthropic"
          String.contains?(model, "gemini") -> "google"
          String.contains?(model, "copilot") -> "github"
          true -> "openai" # default
        end
      true -> "openai" # default
    end
  end

  defp determine_model(request, provider) do
    case Map.get(request, :model) do
      nil ->
        case {provider, Map.get(request, :complexity)} do
          {"openai", :simple} -> "gpt-3.5-turbo"
          {"openai", :medium} -> "gpt-4"
          {"openai", :complex} -> "gpt-4-turbo"
          {"anthropic", :simple} -> "claude-3-haiku-20240307"
          {"anthropic", :medium} -> "claude-3-sonnet-20240229"
          {"anthropic", :complex} -> "claude-3-opus-20240229"
          {"google", :simple} -> "gemini-1.5-flash"
          {"google", :medium} -> "gemini-1.5-pro"
          {"google", :complex} -> "gemini-1.5-pro"
          _ -> "gpt-3.5-turbo"
        end
      model -> model
    end
  end

  # Provider API implementations

  defp call_openai_api(model, request, opts) do
    api_key = System.get_env("OPENAI_API_KEY")
    if !api_key do
      {:error, :missing_openai_api_key}
    else
      url = "https://api.openai.com/v1/chat/completions"

      body = %{
        model: model,
        messages: Map.get(request, :messages),
        max_tokens: Map.get(request, :max_tokens),
        temperature: Map.get(request, :temperature),
        stream: Map.get(request, :stream, false)
      }

      headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"}
      ]

      case Req.post(url, json: body, headers: headers) do
        {:ok, %{status: 200, body: response_body}} ->
          parse_openai_response(response_body, model)
        {:ok, %{status: status, body: error_body}} ->
          {:error, {:openai_api_error, status, error_body}}
        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end
  end

  defp call_anthropic_api(model, request, opts) do
    api_key = System.get_env("ANTHROPIC_API_KEY")
    if !api_key do
      {:error, :missing_anthropic_api_key}
    else
      url = "https://api.anthropic.com/v1/messages"

      body = %{
        model: model,
        messages: Map.get(request, :messages),
        max_tokens: Map.get(request, :max_tokens),
        temperature: Map.get(request, :temperature),
        system: get_system_message(Map.get(request, :messages))
      }

      headers = [
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"},
        {"Content-Type", "application/json"}
      ]

      case Req.post(url, json: body, headers: headers) do
        {:ok, %{status: 200, body: response_body}} ->
          parse_anthropic_response(response_body, model)
        {:ok, %{status: status, body: error_body}} ->
          {:error, {:anthropic_api_error, status, error_body}}
        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end
  end

  # Simplified implementations for other providers
  defp call_google_api(model, request, opts), do: {:error, :not_implemented}
  defp call_github_api(model, request, opts), do: {:error, :not_implemented}
  defp call_ollama_api(model, request, opts), do: {:error, :not_implemented}

  # Response parsers

  defp parse_openai_response(response_body, model) do
    case response_body do
      %{"choices" => [%{"message" => %{"content" => content}} | _], "usage" => %{"total_tokens" => tokens}} ->
        {:ok, %{
          text: content,
          model: model,
          tokens_used: tokens,
          cost_cents: calculate_cost(model, tokens)
        }}
      _ ->
        {:error, :invalid_openai_response}
    end
  end

  defp parse_anthropic_response(response_body, model) do
    case response_body do
      %{"content" => [%{"text" => text}], "usage" => %{"input_tokens" => input_tokens, "output_tokens" => output_tokens}} ->
        total_tokens = input_tokens + output_tokens
        {:ok, %{
          text: text,
          model: model,
          tokens_used: total_tokens,
          cost_cents: calculate_cost(model, total_tokens)
        }}
      _ ->
        {:error, :invalid_anthropic_response}
    end
  end

  # Helper functions

  defp get_system_message(messages) do
    case Enum.find(messages, &(&1.role == "system")) do
      %{content: content} -> content
      nil -> nil
    end
  end

  defp calculate_cost(model, tokens) do
    case model do
      "gpt-3.5-turbo" -> trunc(tokens * 0.002)
      "gpt-4" -> trunc(tokens * 0.03)
      "gpt-4-turbo" -> trunc(tokens * 0.01)
      "claude-3-haiku-20240307" -> trunc(tokens * 0.00025)
      "claude-3-sonnet-20240229" -> trunc(tokens * 0.0015)
      "claude-3-opus-20240229" -> trunc(tokens * 0.015)
      _ -> 0
    end
  end
end