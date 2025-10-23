defmodule Singularity.PromptEngine do
  @moduledoc """
  Prompt Engine - AI-powered prompt generation and optimization.

  Integrates the Rust `prompt_intelligence` NIF when available, falls back to NATS services,
  and finally to lightweight Elixir templates.
  """

  require Logger
  alias Singularity.NatsClient

  @behaviour Singularity.Engine

  @impl Singularity.Engine
  def id, do: :prompt

  @impl Singularity.Engine
  def label, do: "Prompt Engine"

  @impl Singularity.Engine
  def description,
    do: "Prompt generation, optimization, and template management with NIF/NATS fallbacks."

  @impl Singularity.Engine
  def capabilities do
    backend_available = backend_available?()
    cache_available = cache_available?()
    templates_available = local_templates_available?()

    [
      %{
        id: :prompt_generation,
        label: "Prompt Generation",
        description: "Generate prompts using NIF, NATS service, or local templates.",
        available?: backend_available,
        tags: [:prompting, :nif, :nats]
      },
      %{
        id: :prompt_optimization,
        label: "Prompt Optimization",
        description: "Optimize prompts with COPRO-backed heuristics and local fallbacks.",
        available?: backend_available,
        tags: [:prompting, :optimization]
      },
      %{
        id: :template_catalog,
        label: "Template Catalog",
        description: "Expose built-in templates plus remote template discovery via NATS.",
        available?: backend_available || templates_available,
        tags: [:templates]
      },
      %{
        id: :prompt_cache,
        label: "Prompt Cache",
        description: "Access cache lifecycle operations through the NIF interface.",
        available?: cache_available,
        tags: [:cache]
      }
    ]
  end

  @impl Singularity.Engine
  def health, do: health_check()

  defp backend_available? do
    nif_loaded?() or nats_available?()
  end

  defp cache_available? do
    case call_nif(fn -> Native.cache_stats() end) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp local_templates_available?, do: true

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

    with {:nif, {:ok, response}} <- {:nif, call_nif(fn -> Native.generate_prompt(request) end)} do
      {:ok, response}
    else
      {:nif, {:error, _}} ->
        with {:nats, true} <- {:nats, nats_available?()},
             {:ok, response} <- nats_generate_prompt(request) do
          {:ok, response}
        else
          _ -> {:ok, local_generate_prompt(request)}
        end
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

  @spec call_llm(String.t() | atom(), [map()], keyword()) :: {:ok, map()} | {:error, term()}
  def call_llm(model_or_complexity, messages, opts \\ []) do
    # Use centralized LLM service via NATS-based llm-server
    Singularity.LLM.Service.call(model_or_complexity, messages, opts)
  end

  @spec call_llm_with_prompt(String.t() | atom(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def call_llm_with_prompt(model_or_complexity, prompt, opts \\ []) do
    messages = [%{role: "user", content: prompt}]
    call_llm(model_or_complexity, messages, opts)
  end

  @spec call_llm_with_system(String.t() | atom(), String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def call_llm_with_system(model_or_complexity, system_prompt, user_message, opts \\ []) do
    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_message}
    ]
    call_llm(model_or_complexity, messages, opts)
  end

  @spec optimize_prompt(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def optimize_prompt(prompt, opts \\ []) do
    request = %{
      prompt: prompt,
      context: Keyword.get(opts, :context),
      language: Keyword.get(opts, :language)
    }

    with {:nif, {:ok, response}} <- {:nif, call_nif(fn -> Native.optimize_prompt(request) end)} do
      {:ok, response}
    else
      {:nif, {:error, _}} ->
        with {:nats, true} <- {:nats, nats_available?()},
             {:ok, response} <- nats_optimize_prompt(request) do
          {:ok, response}
        else
          _ -> {:ok, local_optimize_prompt(request)}
        end
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
  def cache_get(key) do
    case call_nif(fn -> Native.cache_get(key) end) do
      {:ok, response} -> {:ok, response}
      {:error, _} -> {:error, :cache_disabled}
    end
  end

  @spec cache_put(String.t(), String.t()) :: :ok | {:error, term()}
  def cache_put(key, value) do
    case call_nif(fn -> Native.cache_put(key, value) end) do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  @spec cache_clear() :: :ok | {:error, term()}
  def cache_clear do
    case call_nif(fn -> Native.cache_clear() end) do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  @spec cache_stats() :: prompt_response
  def cache_stats do
    case call_nif(fn -> Native.cache_stats() end) do
      {:ok, stats} -> {:ok, stats}
      {:error, _} -> {:ok, %{total_entries: 0, hits: 0, misses: 0, hit_rate: 0.0}}
    end
  end

  @spec health_check() :: :ok | {:error, term()}
  def health_check do
    cond do
      nif_loaded?() -> :ok
      nats_available?() -> :ok
      true -> {:error, :no_backend_available}
    end
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
    # Use the centralized template service instead of direct NATS calls
    case Singularity.Knowledge.TemplateService.search_patterns(["prompt"]) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  rescue
    _ -> false
  end

  defp nif_loaded? do
    match?({:ok, _}, call_nif(fn -> Native.cache_stats() end))
  end

  # ---------------------------------------------------------------------------
  # NIF helpers
  # ---------------------------------------------------------------------------

  defp call_nif(fun) when is_function(fun, 0) do
    fun.()
    |> normalize_result()
  rescue
    _ -> {:error, :nif_not_loaded}
  catch
    :exit, _ -> {:error, :nif_not_loaded}
  end

  defp normalize_result({:ok, %_struct{} = value}), do: {:ok, Map.from_struct(value)}
  defp normalize_result({:ok, value}), do: {:ok, value}
  defp normalize_result(:ok), do: {:ok, :ok}
  defp normalize_result({:error, reason}), do: {:error, reason}
  defp normalize_result(other), do: {:ok, other}

  defp nats_generate_prompt(request) do
    with {:ok, response} <- NatsClient.request("prompt.generate.request", Jason.encode!(request), timeout: 15_000),
         {:ok, data} <- Jason.decode(response.data) do
      {:ok, data}
    end
  end

  defp nats_optimize_prompt(request) do
    with {:ok, response} <- NatsClient.request("prompt.optimize.request", Jason.encode!(request), timeout: 15_000),
         {:ok, data} <- Jason.decode(response.data) do
      {:ok, data}
    end
  end

  defmodule Native do
    @moduledoc false
    use Rustler,
      otp_app: :singularity,
      crate: :prompt_engine,
      path: "../rust/prompt_engine",
      mode: :release,
      skip_compilation?: true

    # NIF functions - names must match Rust #[rustler::nif] function names
    def nif_generate_prompt(_request), do: :erlang.nif_error(:nif_not_loaded)
    def nif_optimize_prompt(_request), do: :erlang.nif_error(:nif_not_loaded)
    def nif_call_llm(_request), do: :erlang.nif_error(:nif_not_loaded)
    def nif_cache_get(_key), do: :erlang.nif_error(:nif_not_loaded)
    def nif_cache_put(_key, _value), do: :erlang.nif_error(:nif_not_loaded)
    def nif_cache_clear, do: :erlang.nif_error(:nif_not_loaded)
    def nif_cache_stats, do: :erlang.nif_error(:nif_not_loaded)

    # Convenience wrappers without nif_ prefix
    def generate_prompt(request), do: nif_generate_prompt(request)
    def optimize_prompt(request), do: nif_optimize_prompt(request)
    def call_llm(request), do: nif_call_llm(request)
    def cache_get(key), do: nif_cache_get(key)
    def cache_put(key, value), do: nif_cache_put(key, value)
    def cache_clear(), do: nif_cache_clear()
    def cache_stats(), do: nif_cache_stats()
  end

  @doc """
  Loads and optimizes a prompt template using the Rust prompt_engine.
  """
  def load_and_optimize_template(template_name) do
    :prompt_engine.load_and_optimize_template(template_name)
  end

  @doc """
  Generates a prompt from a template and input using the Rust prompt_engine.
  """
  def generate_prompt_from_template(template_name, input) do
    :prompt_engine.generate_prompt_from_template(template_name, input)
  end

  @doc """
  Syncs a template from the global knowledge cache via NATS.
  """
  def sync_template_from_global(template_name) do
    :prompt_engine.sync_template_from_global(template_name)
  end

  @doc """
  Invalidates the local cache for a template.
  """
  def invalidate_template(template_name) do
    :prompt_engine.invalidate_template(template_name)
  end
end
