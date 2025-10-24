defmodule Singularity.CodeGeneration.Orchestrator.GenerationOrchestrator do
  @moduledoc """
  Generation Orchestrator - Config-driven code generation orchestration.

  Unifies scattered code generators (RAGCodeGenerator, QualityCodeGenerator,
  PseudocodeGenerator, etc.) into a single, config-driven system.

  ## Quick Start

  ```elixir
  # Generate with all enabled generators
  {:ok, results} = GenerationOrchestrator.generate(%{
    spec: "Create a GenServer for user management",
    language: "elixir"
  })

  # Generate with specific generator
  {:ok, results} = GenerationOrchestrator.generate(spec,
    generator_types: [:quality]
  )
  ```

  ## Public API

  - `generate(spec, opts)` - Generate code with all/specified generators
  - `learn_from_generation(generator_type, result)` - Learn from generation results

  ## Key Features

  - **Config-driven discovery** - Generators auto-registered from config
  - **Parallel execution** - All generators run concurrently
  - **Multiple strategies** - RAG, quality, pseudocode, etc.
  - **Learning capability** - Optional feedback from generation results

  ## Error Handling

  Returns `{:ok, %{generator_type => result}}` or `{:error, reason}`.

  ---

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.CodeGeneration.GenerationOrchestrator",
    "purpose": "Config-driven orchestration of all code generators (RAG, quality, pseudocode)",
    "role": "orchestrator",
    "layer": "domain_services",
    "alternatives": {
      "GeneratorType": "Internal behavior contract - use GenerationOrchestrator as public API",
      "Individual generators": "Specific generator implementations - managed by GenerationOrchestrator",
      "Direct LLM calls": "Manual generation - use GenerationOrchestrator for unified generation"
    },
    "disambiguation": {
      "vs_generator_type": "GenerationOrchestrator orchestrates; GeneratorType defines behavior contract",
      "vs_individual_generators": "GenerationOrchestrator manages all generators; individual generators implement specific strategies",
      "vs_manual_llm": "GenerationOrchestrator provides config-driven parallel generation vs single LLM call"
    }
  }
  ```

  ### Anti-Patterns

  ### ❌ DO NOT call individual generators directly
  **Why:** GenerationOrchestrator provides unified generation with parallel execution.
  **Use instead:**
  ```elixir
  # ❌ WRONG
  QualityGenerator.generate(spec)

  # ✅ CORRECT
  GenerationOrchestrator.generate(spec, generator_types: [:quality])
  ```

  ### ❌ DO NOT create new generation orchestrators
  **Why:** GenerationOrchestrator already exists!
  **Use instead:** Add generator to config:
  ```elixir
  config :singularity, :generator_types,
    my_generator: %{
      module: Singularity.CodeGeneration.Generators.MyGenerator,
      enabled: true
    }
  ```

  ### ❌ DO NOT hardcode generator selection
  **Why:** Config-driven discovery enables better generator evolution.
  **Use instead:** Let GenerationOrchestrator load from config.

  ### Search Keywords

  generation orchestrator, code generation, rag generator, quality generator, pseudocode,
  config driven generation, parallel generation, code synthesis, template generation,
  llm code generation, ai code generation
  """

  require Logger
  alias Singularity.CodeGeneration.Orchestrator.GeneratorType

  @doc """
  Generate code using all enabled generators or specified ones.

  ## Options

  - `:generator_types` - List of generator types to use (default: all enabled)
  - `:strategy` - How to combine results (default: :first_success)

  ## Returns

  `{:ok, %{generator_type => result}}` or `{:error, reason}`
  """
  def generate(spec, opts \\ []) when is_map(spec) do
    try do
      enabled_generators = GeneratorType.load_enabled_generators()

      generator_types = Keyword.get(opts, :generator_types, nil)

      generators_to_use =
        if generator_types do
          Enum.filter(enabled_generators, fn {type, _} -> type in generator_types end)
        else
          enabled_generators
        end

      # Run all generators in parallel
      results =
        generators_to_use
        |> Enum.map(fn {gen_type, gen_config} ->
          Task.async(fn -> run_generator(gen_type, gen_config, spec, opts) end)
        end)
        |> Enum.map(&Task.await/1)
        |> Enum.into(%{})

      Logger.info("Code generation complete",
        generators_used: Enum.map(results, fn {type, result} -> {type, success?(result)} end)
      )

      {:ok, results}
    rescue
      e ->
        Logger.error("Code generation failed", error: inspect(e))
        {:error, :generation_failed}
    end
  end

  @doc """
  Learn from generation results.
  """
  def learn_from_generation(generator_type, generation_result) when is_atom(generator_type) do
    case GeneratorType.get_generator_module(generator_type) do
      {:ok, module} ->
        Logger.info("Learning from generation for #{generator_type}")
        module.learn_from_generation(generation_result)

      {:error, reason} ->
        Logger.error("Cannot learn from generation for #{generator_type}",
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Private helpers

  defp run_generator(gen_type, gen_config, spec, opts) do
    try do
      module = gen_config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Running #{gen_type} generator")
        result = module.generate(spec, opts)
        {gen_type, result}
      else
        Logger.warn("Generator module not found for #{gen_type}")
        {gen_type, {:error, :module_not_found}}
      end
    rescue
      e ->
        Logger.error("Generator failed for #{gen_type}",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        {gen_type, {:error, :generation_failed}}
    end
  end

  defp success?({:ok, _}), do: true
  defp success?({:error, _}), do: false
  defp success?(_), do: false
end
