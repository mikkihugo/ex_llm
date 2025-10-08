defmodule Singularity.LLM.Service do
  @moduledoc """
  LLM Service - Communicates with AI server via NATS.

  This is the ONLY way to call LLM providers in the Elixir app.
  All LLM calls go through NATS to the AI server (TypeScript).
  """

  require Logger
  alias Singularity.NatsClient
  alias Singularity.PromptEngine

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
  Call an LLM via NATS.

  ## Examples

      # With specific model
      iex> Singularity.LLM.Service.call("claude-sonnet-4.5", [%{role: "user", content: "Hello"}])
      {:ok, %{text: "Hello! How can I help you?", model: "claude-sonnet-4.5"}}
      
      # With model and optional provider
      iex> Singularity.LLM.Service.call("claude-sonnet-4.5", [%{role: "user", content: "Hello"}], provider: "claude")
      {:ok, %{text: "Hello! How can I help you?", model: "claude-sonnet-4.5"}}
      
      # Request by complexity level (model is chosen by AI server)
      iex> Singularity.LLM.Service.call(:simple, [%{role: "user", content: "Hello"}])
      {:ok, %{text: "Hello! How can I help you?", model: _selected_model}}
      
      # Request by complexity with task metadata
      iex> Singularity.LLM.Service.call(:complex, [%{role: "user", content: "Analyze this..."}], task_type: :architect)
      {:ok, %{text: "Analysis...", model: _strategic_model}}

  Supported options:

    * `:provider` - Preferred provider hint (e.g. `"claude"`, `:gemini`)
    * `:complexity` - Override inferred complexity (`:simple`, `:medium`, `:complex`)
    * `:task_type` - Task persona hint (`:architect`, `:coder`, `:qa`, etc.)
    * `:capabilities` - List of capability hints (`[:code, :reasoning, :creativity]`)
    * `:max_tokens`, `:temperature`, `:stream`, `:timeout` - Standard request controls
  """
  @spec call(model(), [message()], keyword()) :: {:ok, llm_response()} | {:error, term()}
  @spec call(atom(), [message()], keyword()) :: {:ok, llm_response()} | {:error, term()}
  def call(model_or_complexity, messages, opts \\ [])

  def call(model, messages, opts) when is_binary(model) do
    request =
      messages
      |> build_request(opts, %{model: model})

    dispatch_request(request, opts)
  end

  def call(complexity, messages, opts) when complexity in [:simple, :medium, :complex] do
    opts = Keyword.put_new(opts, :complexity, complexity)

    request =
      messages
      |> build_request(opts)

    dispatch_request(request, opts)
  end

  def call(model, messages, opts) when is_atom(model) do
    model
    |> Atom.to_string()
    |> call(messages, opts)
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
  @spec call_with_prompt(model() | atom(), String.t(), keyword()) ::
          {:ok, llm_response()} | {:error, term()}
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
  @spec call_with_system(model() | atom(), String.t(), String.t(), keyword()) ::
          {:ok, llm_response()} | {:error, term()}
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
      "opus-4.1",
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

  defp build_request(messages, opts, overrides \\ %{}) do
    max_tokens = Keyword.get(opts, :max_tokens, 4000)
    temperature = Keyword.get(opts, :temperature, 0.7)
    stream = Keyword.get(opts, :stream, false)

    model =
      overrides[:model] ||
        opts
        |> Keyword.get(:model)
        |> normalize_string_option()

    provider =
      overrides[:provider] ||
        opts
        |> Keyword.get(:provider)
        |> normalize_provider()

    complexity =
      overrides[:complexity] ||
        opts
        |> Keyword.get(:complexity)
        |> normalize_complexity()

    task_type =
      overrides[:task_type] ||
        opts
        |> Keyword.get(:task_type)
        |> normalize_task_type_option()

    capabilities =
      overrides[:capabilities] ||
        opts
        |> Keyword.get(:capabilities)
        |> normalize_capabilities()

    %{
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature,
      stream: stream
    }
    |> maybe_put(:model, model)
    |> maybe_put(:provider, provider)
    |> maybe_put(:complexity, complexity)
    |> maybe_put(:task_type, task_type)
    |> maybe_put_capabilities(capabilities)
  end

  defp dispatch_request(request, opts) do
    subject = "ai.llm.request"
    timeout = Keyword.get(opts, :timeout, 30_000)
    requested_model = Map.get(request, :model, "auto")

    Logger.debug("Calling LLM via NATS",
      model: requested_model,
      provider: Map.get(request, :provider),
      complexity: Map.get(request, :complexity),
      task_type: Map.get(request, :task_type),
      subject: subject
    )

    case NatsClient.request(subject, Jason.encode!(request), timeout: timeout) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} ->
            Logger.debug("LLM response received",
              provider: Map.get(request, :provider),
              requested_model: requested_model,
              selected_model: Map.get(data, "model"),
              complexity: Map.get(request, :complexity)
            )

            {:ok, data}

          {:error, reason} ->
            Logger.error("Failed to decode LLM response", reason: reason)
            {:error, {:json_decode_error, reason}}
        end

      {:error, reason} ->
        Logger.error("NATS request failed",
          model: requested_model,
          complexity: Map.get(request, :complexity),
          reason: reason
        )

        {:error, {:nats_error, reason}}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_capabilities(map, []), do: map
  defp maybe_put_capabilities(map, caps), do: Map.put(map, :capabilities, caps)

  defp normalize_provider(value) do
    value
    |> normalize_string_option()
    |> case do
      nil -> nil
      string -> String.downcase(string)
    end
  end

  defp normalize_task_type_option(value) do
    value
    |> normalize_string_option()
    |> case do
      nil ->
        nil

      string ->
        string
        |> String.downcase()
        |> String.replace(~r/\s+/, "_")
    end
  end

  defp normalize_complexity(nil), do: :medium

  defp normalize_complexity(complexity) when is_atom(complexity) do
    case complexity do
      :simple -> :simple
      :medium -> :medium
      :complex -> :complex
      _ -> :medium
    end
  end

  defp normalize_complexity(complexity) when is_binary(complexity) do
    case String.downcase(complexity) do
      "simple" -> :simple
      "medium" -> :medium
      "complex" -> :complex
      _ -> :medium
    end
  end

  defp normalize_complexity(_), do: :medium

  defp normalize_capabilities(nil), do: []

  defp normalize_capabilities(capabilities) when is_list(capabilities) do
    capabilities
    |> Enum.map(&normalize_capability/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_capabilities(capabilities) when is_binary(capabilities) do
    capabilities
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> normalize_capabilities()
  end

  defp normalize_capabilities(capabilities) when is_atom(capabilities) do
    [normalize_capability(capabilities)]
  end

  defp normalize_capabilities(_), do: []

  defp normalize_capability(capability) when is_atom(capability) do
    case capability do
      :code -> :code
      :reasoning -> :reasoning
      :creativity -> :creativity
      :analysis -> :analysis
      :synthesis -> :synthesis
      :planning -> :planning
      :problem_solving -> :problem_solving
      :communication -> :communication
      :learning -> :learning
      _ -> nil
    end
  end

  defp normalize_capability(capability) when is_binary(capability) do
    case String.downcase(String.trim(capability)) do
      "code" -> :code
      "reasoning" -> :reasoning
      "creativity" -> :creativity
      "analysis" -> :analysis
      "synthesis" -> :synthesis
      "planning" -> :planning
      "problem_solving" -> :problem_solving
      "problem-solving" -> :problem_solving
      "communication" -> :communication
      "learning" -> :learning
      _ -> nil
    end
  end

  defp normalize_capability(_), do: nil

  defp normalize_string_option(nil), do: nil

  defp normalize_string_option(option) when is_binary(option) do
    if String.trim(option) == "", do: nil, else: String.trim(option)
  end

  defp normalize_string_option(option) when is_atom(option) do
    Atom.to_string(option)
  end

  defp normalize_string_option(_), do: nil

  @doc """
  Call LLM with prompt optimization using the prompt engine.
  
  Uses contextual complexity-based model selection (recommended approach).

  ## Examples

      # With prompt optimization (auto-detects complexity and capabilities)
      iex> Singularity.LLM.Service.call_optimized("Create a REST API endpoint", "elixir")
      {:ok, %{text: "...", model: "claude-sonnet-4.5", optimized: true}}
      
      # With specific complexity for coding
      iex> Singularity.LLM.Service.call_optimized({:complex, :coding}, "Create a microservice", "elixir")
      {:ok, %{text: "...", model: "gpt-5-codex", optimized: true}}
      
      # With specific complexity for architecture
      iex> Singularity.LLM.Service.call_optimized({:complex, :architecture}, "Design system architecture", "elixir")
      {:ok, %{text: "...", model: "o3", optimized: true}}
      
      # With capabilities
      iex> Singularity.LLM.Service.call_optimized({:medium, [:reasoning, :creativity]}, "Design a solution", "elixir")
      {:ok, %{text: "...", model: "claude-sonnet-4.5", optimized: true}}
  """
  @spec call_optimized(atom() | tuple() | String.t(), String.t(), String.t(), keyword()) ::
          {:ok, llm_response()} | {:error, term()}
  def call_optimized(complexity_or_prompt, prompt_or_language, language_or_opts \\ "elixir", opts \\ []) do
    case {complexity_or_prompt, prompt_or_language, language_or_opts} do
      {{complexity, context}, prompt, language} when complexity in [:simple, :medium, :complex] ->
        # call_optimized({complexity, context}, prompt, language, opts)
        do_call_optimized_contextual(complexity, context, prompt, language, opts)
      
      {complexity, prompt, language} when complexity in [:simple, :medium, :complex] ->
        # call_optimized(complexity, prompt, language, opts) - auto-detect context
        context = detect_context_from_prompt(prompt)
        do_call_optimized_contextual(complexity, context, prompt, language, opts)
      
      {prompt, language, opts} when is_binary(prompt) and is_binary(language) and is_list(opts) ->
        # call_optimized(prompt, language, opts) - auto-detect both complexity and context
        complexity = detect_complexity_from_prompt(prompt)
        context = detect_context_from_prompt(prompt)
        do_call_optimized_contextual(complexity, context, prompt, language, opts)
      
      _ ->
        {:error, :invalid_arguments}
    end
  end

  defp detect_complexity_from_prompt(prompt) when is_binary(prompt) do
    length = String.length(prompt)

    cond do
      length > 500 -> :complex
      length > 200 -> :medium
      true -> :simple
    end
  end

  defp detect_complexity_from_prompt(_), do: :medium

  defp detect_context_from_prompt(prompt) when is_binary(prompt) do
    down = String.downcase(prompt)

    cond do
      String.contains?(down, ["architecture", "diagram", "design"]) -> :architecture
      String.contains?(down, ["test", "spec", "unit"]) -> :testing
      String.contains?(down, ["api", "controller", "service"]) -> :coding
      true -> :general
    end
  end

  defp detect_context_from_prompt(_), do: :general

  defp do_call_optimized_contextual(complexity, context, prompt, language, opts) do
    opts = Keyword.put_new(opts, :context, context)
    do_call_optimized(complexity, prompt, language, opts)
  end

  defp do_call_optimized(complexity, prompt, language, opts) do
    # Try to optimize the prompt using prompt engine
    case PromptEngine.optimize_prompt(prompt, 
      context: prompt,
      language: language
    ) do
      {:ok, %{optimized_prompt: optimized_prompt, optimization_score: score}} ->
        Logger.info("Using optimized prompt", 
          complexity: complexity,
          original_length: String.length(prompt),
          optimized_length: String.length(optimized_prompt),
          optimization_score: score
        )
        
        # Call LLM with optimized prompt using complexity-based selection
        case call(complexity, [%{role: "user", content: optimized_prompt}], opts) do
          {:ok, response} ->
            # Add optimization metadata to response
            {:ok, Map.put(response, :optimized, true)}
          
          error ->
            error
        end
      
      {:error, reason} ->
        Logger.debug("Prompt optimization failed, using original", reason: reason)
        
        # Fall back to original prompt with complexity-based selection
        case call(complexity, [%{role: "user", content: prompt}], opts) do
          {:ok, response} ->
            {:ok, Map.put(response, :optimized, false)}
          
          error ->
            error
        end
    end
  end
end
