defmodule Singularity.LLM.PromptEngineClient do
  @moduledoc """
  Client for communicating with the Rust prompt engine via NATS.
  
  Provides high-level functions for:
  - Generating context-aware prompts
  - Optimizing existing prompts
  - Getting templates
  - Searching templates
  """

  require Logger
  alias Singularity.NatsClient

  @doc """
  Generate a context-aware prompt using the prompt engine.
  
  ## Examples
  
      iex> Singularity.LLM.PromptEngineClient.generate_prompt("Create a REST API endpoint", "elixir")
      {:ok, %{prompt: "...", confidence: 0.9, template_used: "..."}}
  """
  @spec generate_prompt(String.t(), String.t(), keyword()) :: 
    {:ok, map()} | {:error, term()}
  def generate_prompt(context, language, opts \\ []) do
    trigger_type = Keyword.get(opts, :trigger_type)
    trigger_value = Keyword.get(opts, :trigger_value)
    category = Keyword.get(opts, :category)
    template_id = Keyword.get(opts, :template_id)

    request = %{
      context: context,
      language: language,
      trigger_type: trigger_type,
      trigger_value: trigger_value,
      category: category,
      template_id: template_id
    }

    case NatsClient.request("prompt.generate", Jason.encode!(request), timeout: 15000) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, {:json_decode, reason}}
        end
      {:error, reason} -> {:error, {:nats_request, reason}}
    end
  end

  @doc """
  Optimize an existing prompt using DSPy optimization.
  
  ## Examples
  
      iex> Singularity.LLM.PromptEngineClient.optimize_prompt("Analyze this code")
      {:ok, %{optimized_prompt: "...", optimization_score: 0.85, ...}}
  """
  @spec optimize_prompt(String.t(), keyword()) :: 
    {:ok, map()} | {:error, term()}
  def optimize_prompt(prompt, opts \\ []) do
    context = Keyword.get(opts, :context)
    language = Keyword.get(opts, :language)

    request = %{
      prompt: prompt,
      context: context,
      language: language
    }

    case NatsClient.request("prompt.optimize", Jason.encode!(request), timeout: 15000) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, {:json_decode, reason}}
        end
      {:error, reason} -> {:error, {:nats_request, reason}}
    end
  end

  @doc """
  Get a specific template by ID.
  
  ## Examples
  
      iex> Singularity.LLM.PromptEngineClient.get_template("rust-microservice")
      {:ok, %{template: "...", language: "rust", ...}}
  """
  @spec get_template(String.t(), keyword()) :: 
    {:ok, map()} | {:error, term()}
  def get_template(template_id, opts \\ []) do
    context = Keyword.get(opts, :context, %{})

    request = %{
      template_id: template_id,
      context: context
    }

    case NatsClient.request("prompt.template.get", Jason.encode!(request), timeout: 10000) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, {:json_decode, reason}}
        end
      {:error, reason} -> {:error, {:nats_request, reason}}
    end
  end

  @doc """
  List all available templates.
  
  ## Examples
  
      iex> Singularity.LLM.PromptEngineClient.list_templates()
      {:ok, [%{template_id: "rust-microservice", ...}, ...]}
  """
  @spec list_templates() :: {:ok, list(map())} | {:error, term()}
  def list_templates do
    case NatsClient.request("prompt.template.list", "", timeout: 10000) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, {:json_decode, reason}}
        end
      {:error, reason} -> {:error, {:nats_request, reason}}
    end
  end

  @doc """
  Generate a framework-specific prompt.
  
  ## Examples
  
      iex> Singularity.LLM.PromptEngineClient.generate_framework_prompt("Create a controller", "phoenix", "commands")
      {:ok, %{prompt: "...", ...}}
  """
  @spec generate_framework_prompt(String.t(), String.t(), String.t(), String.t()) :: 
    {:ok, map()} | {:error, term()}
  def generate_framework_prompt(context, framework, category, language \\ "elixir") do
    generate_prompt(context, language, 
      trigger_type: "framework",
      trigger_value: framework,
      category: category
    )
  end

  @doc """
  Generate a language-specific prompt.
  
  ## Examples
  
      iex> Singularity.LLM.PromptEngineClient.generate_language_prompt("Create a function", "rust", "examples")
      {:ok, %{prompt: "...", ...}}
  """
  @spec generate_language_prompt(String.t(), String.t(), String.t()) :: 
    {:ok, map()} | {:error, term()}
  def generate_language_prompt(context, language, category \\ "commands") do
    generate_prompt(context, language,
      trigger_type: "language",
      trigger_value: language,
      category: category
    )
  end

  @doc """
  Generate a pattern-specific prompt.
  
  ## Examples
  
      iex> Singularity.LLM.PromptEngineClient.generate_pattern_prompt("Implement microservices", "microservice", "architecture")
      {:ok, %{prompt: "...", ...}}
  """
  @spec generate_pattern_prompt(String.t(), String.t(), String.t(), String.t()) :: 
    {:ok, map()} | {:error, term()}
  def generate_pattern_prompt(context, pattern, category, language \\ "elixir") do
    generate_prompt(context, language,
      trigger_type: "pattern",
      trigger_value: pattern,
      category: category
    )
  end

  @doc """
  Check if the prompt engine service is available.
  """
  @spec health_check() :: :ok | {:error, term()}
  def health_check do
    case list_templates() do
      {:ok, _templates} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
