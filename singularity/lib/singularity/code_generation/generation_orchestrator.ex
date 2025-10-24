defmodule Singularity.CodeGeneration.GenerationOrchestrator do
  @moduledoc """
  Generation Orchestrator - Config-driven code generation orchestration.

  Unifies scattered code generators (RAGCodeGenerator, QualityCodeGenerator,
  PseudocodeGenerator, etc.) into a single, config-driven system.

  ## Usage

  ```elixir
  {:ok, results} = GenerationOrchestrator.generate(spec)
  # => %{
  #   rag: {:ok, \"...generated code...\"},
  #   quality: {:ok, \"...generated code...\"},
  #   pseudocode: {:ok, \"...pseudocode...\"}
  # }
  ```
  """

  require Logger
  alias Singularity.CodeGeneration.GeneratorType

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
