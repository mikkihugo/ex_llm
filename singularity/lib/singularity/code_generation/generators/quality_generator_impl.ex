defmodule Singularity.CodeGeneration.Generators.QualityGenerator do
  @moduledoc """
  Quality Code Generator - Generates high-quality, production-ready code.

  Wraps QualityCodeGenerator into unified GeneratorType behavior.
  """

  @behaviour Singularity.CodeGeneration.Orchestrator.GeneratorType
  require Logger
  alias Singularity.CodeGeneration.Implementations.QualityCodeGenerator

  @impl true
  def generator_type, do: :quality

  @impl true
  def description, do: "Generate high-quality, production-ready code"

  @impl true
  def capabilities do
    ["production_code", "tested_code", "documented_code"]
  end

  @impl true
  def generate(spec, _opts \\ []) when is_map(spec) do
    try do
      # QualityCodeGenerator.generate expects keyword list with task, language, quality options
      merged_opts =
        _opts ++
          [
            task: Map.get(spec, "task") || Map.get(spec, :task, ""),
            language: Map.get(spec, "language") || Map.get(spec, :language, "elixir"),
            quality: Map.get(spec, "quality") || Map.get(spec, :quality, :production)
          ]

      QualityCodeGenerator.generate(merged_opts)
    rescue
      e ->
        Logger.error("Quality code generation failed", error: inspect(e))
        {:error, :generation_failed}
    end
  end

  @impl true
  def learn_from_generation(result) do
    case result do
      %{success: true} ->
        Logger.info("Quality generation was successful")
        :ok

      _ ->
        :ok
    end
  end
end
