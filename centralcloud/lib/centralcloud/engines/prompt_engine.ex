defmodule Centralcloud.Engines.PromptEngine do
  @moduledoc """
  Prompt Engine - NATS Delegation to Singularity.

  CentralCloud delegates all prompt generation and optimization to Singularity's
  PromptEngine via NATS, which has the compiled Rust NIF with full functionality.

  ## Features

  - Generate AI prompts with context and language awareness
  - Optimize existing prompts with goals and constraints
  - Template management and discovery
  - Fallback to local templates if Singularity unavailable

  ## Architecture

  Request Flow:
  1. CentralCloud receives prompt request
  2. Sends via NATS to Singularity.PromptEngine
  3. Singularity uses Rust NIF or NATS services
  4. Returns result back to CentralCloud

  This enables:
  - Zero duplication of NIF compilation
  - Shared Rust engine across instances
  - Consistent prompt generation behavior
  """

  require Logger
  alias Centralcloud.NatsClient

  @doc """
  Generate AI prompts using Singularity's Prompt Engine via NATS.

  Generates optimized prompts for a given context and language.

  ## Parameters

  - `context` - The task or context for the prompt
  - `language` - Programming language or domain (e.g., "elixir", "general")
  - `opts` - Optional keyword arguments:
    - `:template` - Template name (default: "default")
    - `:optimization_level` - "balanced", "concise", "detailed"
    - `:max_length` - Maximum prompt length

  ## Returns

  - `{:ok, %{"prompt" => prompt_text, ...}}` - Successfully generated
  - `{:error, reason}` - Generation failed
  """
  def generate_prompt(context, language, opts \\ []) do
    request = %{
      "context" => context,
      "language" => language,
      "template" => Keyword.get(opts, :template, "default"),
      "optimization_level" => Keyword.get(opts, :optimization_level, "balanced"),
      "max_length" => Keyword.get(opts, :max_length, nil)
    }

    case NatsClient.request_nats(
      "prompt.generate",
      request,
      timeout: 30_000
    ) do
      {:ok, response} ->
        Logger.debug("Prompt generated via NATS",
          language: language,
          length: byte_size(Map.get(response, "prompt", ""))
        )
        {:ok, response}

      {:error, reason} ->
        Logger.warn("Prompt generation failed via NATS", reason: inspect(reason))
        # Fallback to simple template if NATS unavailable
        {:ok, local_generate_prompt(context, language, opts)}
    end
  end

  @doc """
  Optimize an existing prompt.

  Improves clarity, effectiveness, or target length of a prompt.

  ## Parameters

  - `prompt` - The prompt text to optimize
  - `opts` - Optional keyword arguments:
    - `:goals` - List of optimization goals ("clarity", "conciseness", "effectiveness")
    - `:target_length` - Target length in tokens (approximate)
    - `:language` - Language context for optimization

  ## Returns

  - `{:ok, %{"optimized_prompt" => text, ...}}` - Successfully optimized
  - `{:error, reason}` - Optimization failed
  """
  def optimize_prompt(prompt, opts \\ []) do
    request = %{
      "prompt" => prompt,
      "goals" => Keyword.get(opts, :goals, ["clarity", "effectiveness"]),
      "target_length" => Keyword.get(opts, :target_length, nil),
      "language" => Keyword.get(opts, :language, "general")
    }

    case NatsClient.request_nats(
      "prompt.optimize",
      request,
      timeout: 30_000
    ) do
      {:ok, response} ->
        Logger.debug("Prompt optimized via NATS",
          original_length: String.length(prompt),
          optimized_length: String.length(Map.get(response, "optimized_prompt", ""))
        )
        {:ok, response}

      {:error, reason} ->
        Logger.warn("Prompt optimization failed via NATS", reason: inspect(reason))
        # Fallback to returning original with notes
        {:ok, %{"optimized_prompt" => prompt, "note" => "NATS unavailable, returned original"}}
    end
  end

  @doc """
  Get available prompt templates.

  Returns a list of available templates for prompt generation.
  """
  def list_templates do
    case NatsClient.request_nats(
      "prompt.list_templates",
      %{},
      timeout: 10_000
    ) do
      {:ok, response} ->
        Logger.debug("Retrieved prompt templates from Singularity")
        {:ok, Map.get(response, "templates", [])}

      {:error, _reason} ->
        # Return local defaults
        {:ok, @local_templates}
    end
  end

  # ============================================================================
  # Local Fallback Templates
  # ============================================================================

  @local_templates [
    %{
      id: "general-command",
      category: "commands",
      language: "general",
      skeleton: """
      ## Task
      {{context}}

      ## Expectations
      - Provide clear, idiomatic code
      - Include documentation where helpful
      """
    },
    %{
      id: "architecture",
      category: "architecture",
      language: "general",
      skeleton: """
      You are designing a system for {{context}}.

      Please outline:
      1. Key components
      2. Data flow
      3. Dependencies
      4. Operational considerations
      """
    }
  ]

  @spec local_generate_prompt(String.t(), String.t(), keyword()) :: map()
  defp local_generate_prompt(context, language, opts) do
    template_id = Keyword.get(opts, :template, "general-command")

    template = Enum.find(@local_templates, fn t -> t.id == template_id end)

    if template do
      prompt = String.replace(template.skeleton, "{{context}}", context)
      %{
        "prompt" => prompt,
        "template_used" => template_id,
        "fallback" => true,
        "language" => language
      }
    else
      # Final fallback - very basic
      %{
        "prompt" => "Task: #{context}\n\nPlease provide a solution in #{language}.",
        "template_used" => "minimal-fallback",
        "fallback" => true,
        "language" => language
      }
    end
  end
end
