defmodule Singularity.LLM.Service do
  @moduledoc """
  LLM Service - Communicates with AI server via NATS.
  
  This is the ONLY way to call LLM providers in the Elixir app.
  All LLM calls go through NATS to the AI server (TypeScript).
  """

  require Logger
  alias Singularity.NatsClient

  @type model :: String.t()
  @type message :: %{role: String.t(), content: String.t()}
  @type llm_request :: %{
    model: model(),
    messages: [message()],
    max_tokens: non_neg_integer(),
    temperature: float(),
    stream: boolean()
  }
  @type llm_response :: %{
    text: String.t(),
    model: model(),
    tokens_used: non_neg_integer(),
    cost_cents: non_neg_integer()
  }

  @doc """
  Call an LLM via NATS.
  
  ## Examples
  
      # With specific model
      iex> Singularity.LLM.Service.call("claude-sonnet-4.5", [%{role: "user", content: "Hello"}])
      {:ok, %{text: "Hello! How can I help you?", model: "claude-sonnet-4.5"}}
      
      # With model and optional provider
      iex> Singularity.LLM.Service.call("claude-sonnet-4.5", [%{role: "user", content: "Hello"}], provider: "claude")
      {:ok, %{text: "Hello! How can I help you?", model: "claude-sonnet-4.5"}}
      
      # Request by complexity level
      iex> Singularity.LLM.Service.call(:simple, [%{role: "user", content: "Hello"}])
      {:ok, %{text: "Hello! How can I help you?", model: "gemini-1.5-flash"}}
      
      # Request by complexity with provider preference
      iex> Singularity.LLM.Service.call(:complex, [%{role: "user", content: "Analyze this..."}], provider: "claude")
      {:ok, %{text: "Analysis...", model: "claude-3-5-sonnet-20241022"}}
  """
  @spec call(model(), [message()], keyword()) :: {:ok, llm_response()} | {:error, term()}
  @spec call(atom(), [message()], keyword()) :: {:ok, llm_response()} | {:error, term()}
  def call(model_or_complexity, messages, opts \\ [])

  def call(model, messages, opts) when is_binary(model) do
    max_tokens = Keyword.get(opts, :max_tokens, 4000)
    temperature = Keyword.get(opts, :temperature, 0.7)
    stream = Keyword.get(opts, :stream, false)
    provider = Keyword.get(opts, :provider)
    
    request = %{
      model: model,
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature,
      stream: stream
    }
    
    # Add provider if specified
    request = if provider, do: Map.put(request, :provider, provider), else: request
    
    # Single NATS subject for all LLM requests
    subject = "ai.llm.request"
    timeout = Keyword.get(opts, :timeout, 30000)
    
    Logger.debug("Calling LLM via NATS", model: model, provider: provider, subject: subject)
    
    case NatsClient.request(subject, Jason.encode!(request), timeout: timeout) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} ->
            Logger.debug("LLM response received", provider: provider, model: model)
            {:ok, data}
          {:error, reason} ->
            Logger.error("Failed to decode LLM response", reason: reason)
            {:error, {:json_decode_error, reason}}
        end
      {:error, reason} ->
        Logger.error("NATS request failed", model: model, reason: reason)
        {:error, {:nats_error, reason}}
    end
  end

  def call(complexity, messages, opts) when complexity in [:simple, :medium, :complex] do
    provider = Keyword.get(opts, :provider)
    model = select_model_for_complexity(complexity, provider)
    call(model, messages, opts)
  end

  @doc """
  Call LLM with a simple prompt string.
  
  ## Examples
  
      # With specific model
      iex> Singularity.LLM.Service.call_with_prompt("claude-sonnet-4.5", "Hello world")
      {:ok, %{text: "Hello! How can I help you?", model: "claude-sonnet-4.5"}}
      
      # With complexity level
      iex> Singularity.LLM.Service.call_with_prompt(:simple, "Hello world")
      {:ok, %{text: "Hello! How can I help you?", model: "gemini-1.5-flash"}}
  """
  @spec call_with_prompt(model() | atom(), String.t(), keyword()) :: {:ok, llm_response()} | {:error, term()}
  def call_with_prompt(model_or_complexity, prompt, opts \\ []) do
    messages = [%{role: "user", content: prompt}]
    call(model_or_complexity, messages, opts)
  end

  @doc """
  Call LLM with system prompt and user message.
  
  ## Examples
  
      # With specific model
      iex> Singularity.LLM.Service.call_with_system("claude-sonnet-4.5", "You are a helpful assistant", "Hello")
      {:ok, %{text: "Hello! How can I help you?", model: "claude-sonnet-4.5"}}
      
      # With complexity level
      iex> Singularity.LLM.Service.call_with_system(:complex, "You are a helpful assistant", "Hello")
      {:ok, %{text: "Hello! How can I help you?", model: "claude-3-5-sonnet-20241022"}}
  """
  @spec call_with_system(model() | atom(), String.t(), String.t(), keyword()) :: {:ok, llm_response()} | {:error, term()}
  def call_with_system(model_or_complexity, system_prompt, user_message, opts \\ []) do
    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_message}
    ]
    call(model_or_complexity, messages, opts)
  end

  @doc """
  Get available models.
  """
  @spec get_available_models() :: [model()]
  def get_available_models do
    [
      # Claude models
      "claude-sonnet-4.5",
      "claude-3-5-haiku-20241022", 
      "claude-3-5-sonnet-20241022",
      # Gemini models
      "gemini-1.5-flash",
      "gemini-2.5-pro",
      # Codex models
      "gpt-5-codex",
      "o3-mini-codex",
      # Cursor models
      "cursor-auto",
      # Copilot models
      "github-copilot"
    ]
  end

  @doc false
  defp select_model_for_complexity(complexity, provider) do
    case {complexity, provider} do
      {:simple, "claude"} -> "claude-3-5-haiku-20241022"
      {:simple, "gemini"} -> "gemini-1.5-flash"
      {:simple, "codex"} -> "gpt-5-codex"
      {:simple, _} -> "gemini-1.5-flash"  # Default cheapest
      
      {:medium, "claude"} -> "claude-3-5-haiku-20241022"
      {:medium, "gemini"} -> "gemini-2.5-pro"
      {:medium, "codex"} -> "gpt-5-codex"
      {:medium, _} -> "claude-3-5-haiku-20241022"  # Default balanced
      
      {:complex, "claude"} -> "claude-3-5-sonnet-20241022"
      {:complex, "gemini"} -> "gemini-2.5-pro"
      {:complex, "codex"} -> "gpt-5-codex"
      {:complex, _} -> "claude-3-5-sonnet-20241022"  # Default best
    end
  end


end