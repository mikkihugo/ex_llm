defmodule CentralCloud.Engines.PromptEngine do
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
  alias CentralCloud.Engines.SharedEngineService

  @doc """
  Generate AI prompts using Singularity's Prompt Engine via NATS.

  Generates optimized prompts for a given context and language.

  ## Parameters

  - `context` - The context or task description
  - `language` - Target programming language
  - `opts` - Optional keyword arguments:
    - `:template` - Template to use (default: "default")
    - `:optimization_level` - Optimization level (default: "balanced")
    - `:max_length` - Maximum prompt length
    - `:timeout` - Request timeout in milliseconds

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

    SharedEngineService.call_prompt_engine("generate", request, opts)
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

    SharedEngineService.call_prompt_engine("optimize", request, opts)
  end

  @doc """
  Get available prompt templates.

  Returns a list of available templates for prompt generation.
  """
  def list_templates do
    SharedEngineService.call_prompt_engine("list_templates", %{}, [])
  end

  # ============================================================================
  # Local Fallback Templates
  # ============================================================================

  # @local_templates [
  #   %{
  #     id: "general-command",
  #     category: "commands",
  #     language: "general",
  #     skeleton: """
  #     ## Task
  #     {{context}}
  #
  #     ## Expectations
  #     - Provide clear, idiomatic code
  #     - Include documentation where helpful
  #     """
  #   },
  #   %{
  #     id: "architecture",
  #     category: "architecture",
  #     language: "general",
  #     skeleton: """
  #     ## Architecture Task
  #     {{context}}
  #
  #     ## Requirements
  #     - Design scalable, maintainable solution
  #     - Consider performance and security
  #     - Document design decisions
  #     """
  #   }
  # ]
end