defmodule Singularity.Engine.Registry do
  @moduledoc """
  Central registry for engine implementations. Provides discovery helpers so the
  prototype can enumerate engines and their capabilities without hard-coded
  knowledge.
  """

  alias Singularity.Engine
  require Logger

  @default_engines [
    Singularity.ArchitectureEngine,
    Singularity.CodeEngine,
    Singularity.PromptEngine,
    Singularity.QualityEngine,
    Singularity.GeneratorEngine
  ]

  @type engine_summary :: %{
          module: module(),
          id: Engine.id(),
          label: String.t(),
          description: String.t(),
          capabilities: [Engine.capability()],
          health: :ok | {:error, term()}
        }

  @doc """
  Return a list of engine modules registered in the system.

  Additional engines can be appended with the `:engine_modules` config key:

      config :singularity, Singularity.Engine.Registry,
        engine_modules: [My.CustomEngine]
  """
  @spec modules() :: [module()]
  def modules do
    configured =
      Application.get_env(:singularity, __MODULE__, [])
      |> Keyword.get(:engine_modules, [])

    (configured ++ @default_engines)
    |> Enum.uniq()
    |> Enum.filter(&function_exported?(&1, :capabilities, 0))
  end

  @doc """
  Enumerate all engines with metadata and health information.
  """
  @spec all() :: [engine_summary()]
  def all do
    modules()
    |> Enum.map(&summarise/1)
    |> Enum.sort_by(& &1.id)
  end

  @doc """
  Fetch a specific engine by id (atom) or label (string).
  """
  @spec fetch(Engine.id() | String.t()) :: {:ok, engine_summary()} | :error
  def fetch(identifier) when is_atom(identifier) do
    case Enum.find(all(), &(&1.id == identifier)) do
      nil -> :error
      summary -> {:ok, summary}
    end
  end

  def fetch(label) when is_binary(label) do
    case Enum.find(all(), &(String.downcase(&1.label) == String.downcase(label))) do
      nil -> :error
      summary -> {:ok, summary}
    end
  end

  @doc """
  Return flattened capability rows for all engines.
  """
  @spec capabilities_index() :: [map()]
  def capabilities_index do
    all()
    |> Enum.flat_map(fn summary ->
      Enum.map(summary.capabilities, fn capability ->
        Map.merge(capability, %{engine: summary.id, engine_module: summary.module})
      end)
    end)
  end

  defp summarise(module) do
    %{
      module: module,
      id: safe_call(module, :id, [], default_id(module)),
      label: safe_call(module, :label, [], default_label(module)),
      description: safe_call(module, :description, [], ""),
      capabilities: safe_call(module, :capabilities, [], []),
      health: health(module)
    }
  end

  defp health(module) do
    if function_exported?(module, :health, 0) do
      safe_call(module, :health, [], :ok)
    else
      :ok
    end
  end

  defp safe_call(module, fun, args, default) do
    apply(module, fun, args)
  rescue
    error ->
      Logger.warning(fn ->
        "Engine registry call #{inspect(module)}.#{fun}/#{length(args)} failed: " <>
          Exception.message(error)
      end)

      default
  end

  defp default_id(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  rescue
    _ -> module
  end

  defp default_label(module) do
    module
    |> Module.split()
    |> List.last()
  rescue
    _ -> inspect(module)
  end
end
