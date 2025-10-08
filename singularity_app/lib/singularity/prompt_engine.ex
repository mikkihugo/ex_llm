defmodule Singularity.PromptEngine do
  @moduledoc """
  Prompt Engine - AI-powered prompt generation and optimization.

  Native Rust support has been removed from this snapshot; this module now provides a
  lightweight Elixir implementation with optional NATS fallbacks.
  """

  require Logger
  alias Singularity.NatsClient

  @type prompt_response :: {:ok, map()} | {:error, term()}

  @default_templates [
    %{id: "general-command", category: "commands", language: "elixir", skeleton: """
    ## Task
    {{context}}

    ## Expectations
    - Provide idiomatic {{language}} code
    - Include inline documentation where helpful
    """},
    %{id: "service-blueprint", category: "architecture", language: "general", skeleton: """
    You are designing a service that handles {{context}}.

    Outline:
    1. Responsibilities
    2. API surface
    3. Data flow
    4. Operational considerations
    """}
  ]

  # ---------------------------------------------------------------------------
  # Public API - prompt generation & optimization
  # ---------------------------------------------------------------------------

  @spec generate_prompt(String.t(), String.t(), keyword()) :: prompt_response
  def generate_prompt(context, language, opts \\ []) do
    request = build_request(context, language, opts)

    with {:nats, true} <- {:nats, nats_available?()},
         {:ok, response} <- nats_generate_prompt(request) do
      {:ok, response}
    else
      _ -> {:ok, local_generate_prompt(request)}
    end
  end

  @spec generate_framework_prompt(String.t(), String.t(), String.t(), String.t()) :: prompt_response
  def generate_framework_prompt(context, framework, category, language \\ "elixir") do
    generate_prompt(context, language,
      trigger_type: "framework",
      trigger_value: framework,
      category: category
    )
  end

  @spec generate_language_prompt(String.t(), String.t(), String.t()) :: prompt_response
  def generate_language_prompt(context, language, category \\ "commands") do
    generate_prompt(context, language,
      trigger_type: "language",
      trigger_value: language,
      category: category
    )
  end

  @spec generate_pattern_prompt(String.t(), String.t(), String.t(), String.t()) :: prompt_response
  def generate_pattern_prompt(context, pattern, category, language \\ "elixir") do
    generate_prompt(context, language,
      trigger_type: "pattern",
      trigger_value: pattern,
      category: category
    )
  end

  @spec optimize_prompt(String.t(), keyword()) :: prompt_response
  def optimize_prompt(prompt, opts \\ []) do
    request = %{
      prompt: prompt,
      context: Keyword.get(opts, :context),
      language: Keyword.get(opts, :language)
    }

    with {:nats, true} <- {:nats, nats_available?()},
         {:ok, response} <- nats_optimize_prompt(request) do
      {:ok, response}
    else
      _ -> {:ok, local_optimize_prompt(request)}
    end
  end

  # ---------------------------------------------------------------------------
  # Templates & cache helpers (local placeholders)
  # ---------------------------------------------------------------------------

  @spec get_template(String.t(), keyword()) :: prompt_response
  def get_template(template_id, opts \\ []) do
    context = Keyword.get(opts, :context, %{})

    case Enum.find(@default_templates, &(&1.id == template_id)) do
      nil -> {:error, {:template_not_found, template_id, context}}
      template -> {:ok, template}
    end
  end

  @spec list_templates() :: prompt_response
  def list_templates, do: {:ok, @default_templates}

  @spec cache_get(String.t()) :: prompt_response
  def cache_get(_key), do: {:error, :cache_disabled}

  @spec cache_put(String.t(), String.t()) :: :ok | {:error, term()}
  def cache_put(_key, _value), do: :ok

  @spec cache_clear() :: :ok | {:error, term()}
  def cache_clear, do: :ok

  @spec cache_stats() :: prompt_response
  def cache_stats do
    {:ok, %{total_entries: 0, hits: 0, misses: 0, hit_rate: 0.0}}
  end

  @spec health_check() :: :ok | {:error, term()}
  def health_check do
    if nats_available?(), do: :ok, else: :ok
  end

  # ---------------------------------------------------------------------------
  # Local fallback implementations
  # ---------------------------------------------------------------------------

  defp build_request(context, language, opts) do
    %{
      context: context,
      language: language,
      template_id: Keyword.get(opts, :template_id),
      trigger_type: Keyword.get(opts, :trigger_type),
      trigger_value: Keyword.get(opts, :trigger_value),
      category: Keyword.get(opts, :category, "commands")
    }
  end

  defp local_generate_prompt(%{context: context, language: language} = request) do
    template = resolve_template(request)

    prompt =
      template.skeleton
      |> String.replace("{{context}}", context)
      |> String.replace("{{language}}", language)

    %{
      prompt: prompt,
      confidence: 0.6,
      template_used: template.id,
      optimization_score: nil
    }
  end

  defp local_optimize_prompt(%{prompt: prompt}) do
    %{
      prompt: prompt <> "\n\n# Optimization\n- Clarify intent\n- Ensure best practices",
      confidence: 0.65,
      template_used: nil,
      optimization_score: 0.5
    }
  end

  defp resolve_template(%{template_id: nil} = request) do
    Enum.find(@default_templates, fn template ->
      template.category == request.category and
        (template.language == request.language or template.language == "general")
    end) || hd(@default_templates)
  end

  defp resolve_template(%{template_id: template_id} = request) do
    Enum.find(@default_templates, &(&1.id == template_id)) || resolve_template(%{request | template_id: nil})
  end

  # ---------------------------------------------------------------------------
  # NATS helpers
  # ---------------------------------------------------------------------------

  defp nats_available? do
    case NatsClient.request("prompt.template.list", "", timeout: 5_000) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  rescue
    _ -> false
  end

  defp nats_generate_prompt(request) do
    with {:ok, response} <- NatsClient.request("prompt.generate", Jason.encode!(request), timeout: 15_000),
         {:ok, data} <- Jason.decode(response.data) do
      {:ok, data}
    end
  end

  defp nats_optimize_prompt(request) do
    with {:ok, response} <- NatsClient.request("prompt.optimize", Jason.encode!(request), timeout: 15_000),
         {:ok, data} <- Jason.decode(response.data) do
      {:ok, data}
    end
  end
end
