defmodule Singularity.CodeGeneration.GeneratorType do
  @moduledoc """
  Generator Type Behavior - Contract for all code generation strategies.

  Consolidates scattered code generators (RAGCodeGenerator, QualityCodeGenerator,
  PseudocodeGenerator, etc.) into a unified, config-driven system.

  ## Anti-Patterns

  - ❌ **DO NOT** call generators directly
  - ✅ **DO** use `GenerationOrchestrator.generate/2`
  """

  @callback generator_type() :: atom()
  @callback description() :: String.t()
  @callback capabilities() :: [String.t()]
  @callback generate(spec :: map(), opts :: Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  @callback learn_from_generation(result :: map()) :: :ok | {:error, term()}

  require Logger

  def load_enabled_generators do
    :singularity
    |> Application.get_env(:generator_types, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.to_list()
  end

  def enabled?(generator_type) when is_atom(generator_type) do
    generators = load_enabled_generators()
    Enum.any?(generators, fn {type, _config} -> type == generator_type end)
  end

  def get_generator_module(generator_type) when is_atom(generator_type) do
    case Application.get_env(:singularity, :generator_types, %{})[generator_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :generator_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  def get_description(generator_type) when is_atom(generator_type) do
    case get_generator_module(generator_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          module.description()
        else
          "Unknown generator"
        end

      {:error, _} ->
        "Unknown generator"
    end
  end
end
