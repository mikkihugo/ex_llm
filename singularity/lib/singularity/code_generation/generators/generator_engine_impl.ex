defmodule Singularity.CodeGeneration.Generators.GeneratorEngineImpl do
  @moduledoc """
  Generator Engine Implementation - Wraps GeneratorEngine into unified GeneratorType behavior.

  Provides Rust NIF-backed code generation with intelligent naming and structure suggestions.

  ## Features

  - ✅ Fast Rust NIF-backed code generation
  - ✅ Intelligent naming suggestions
  - ✅ Language-specific code generation
  - ✅ Pseudocode generation for planning
  - ✅ Microservice and monorepo structure suggestions
  - ✅ Naming compliance validation
  - ✅ Local processing (no external API calls)

  ## Example

      iex> GenerationOrchestrator.generate(
      ...>   %{spec: "Create a user service"},
      ...>   generators: [:generator_engine]
      ...> )
      {:ok, %{generator_engine: {:ok, "code here" }}}
  """

  @behaviour Singularity.CodeGeneration.GeneratorType
  require Logger
  alias Singularity.Engines.GeneratorEngine

  @impl true
  def generator_type, do: :generator_engine

  @impl true
  def description do
    "Generate code using Rust NIF-backed engine with intelligent naming"
  end

  @impl true
  def capabilities do
    [
      "clean_code_generation",
      "pseudocode_generation",
      "intelligent_naming",
      "microservice_structures",
      "monorepo_structures",
      "naming_validation",
      "language_specific_generation"
    ]
  end

  @impl true
  def generate(spec, opts \\ []) when is_map(spec) do
    try do
      # Unpack spec fields for GeneratorEngine.code_generate/5
      task = spec[:spec] || spec[:task] || ""
      language = spec[:language] || opts[:language] || "elixir"
      repos = opts[:repos] || []
      quality = opts[:quality] || :standard
      include_tests = opts[:include_tests] || true

      Logger.debug("GeneratorEngineImpl: generating with GeneratorEngine",
        task: task,
        language: language
      )

      GeneratorEngine.code_generate(task, language, repos, quality, include_tests)
    rescue
      e ->
        Logger.error("GeneratorEngine code generation failed", error: inspect(e))
        {:error, :generation_failed}
    end
  end

  @impl true
  def learn_from_generation(result) do
    case result do
      {:ok, code} when is_binary(code) ->
        Logger.info("GeneratorEngine generation was successful")
        :ok

      {:error, reason} ->
        Logger.warn("GeneratorEngine generation failed", reason: inspect(reason))
        :ok

      _ ->
        :ok
    end
  end
end
