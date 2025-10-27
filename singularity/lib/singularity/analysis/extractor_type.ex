defmodule Singularity.Analysis.ExtractorType do
  @moduledoc """
  Extractor Type Behavior - Contract for all data extraction operations.

  Consolidates scattered extractors across different domains
  into a unified, config-driven extraction system.

  Extractors: CodePattern, AST, AIMetadata, etc.
  """

  @callback extractor_type() :: atom()
  @callback description() :: String.t()
  @callback capabilities() :: [String.t()]
  @callback extract(input :: term(), _opts :: Keyword.t()) :: {:ok, map()} | {:error, term()}
  @callback learn_from_extraction(result :: map()) :: :ok | {:error, term()}

  require Logger

  def load_enabled_extractors do
    :singularity
    |> Application.get_env(:extractor_types, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.to_list()
  end

  def enabled?(extractor_type) when is_atom(extractor_type) do
    extractors = load_enabled_extractors()
    Enum.any?(extractors, fn {type, _config} -> type == extractor_type end)
  end

  def get_extractor_module(extractor_type) when is_atom(extractor_type) do
    case Application.get_env(:singularity, :extractor_types, %{})[extractor_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :extractor_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  def get_description(extractor_type) when is_atom(extractor_type) do
    case get_extractor_module(extractor_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          module.description()
        else
          "Unknown extractor"
        end

      {:error, _} ->
        "Unknown extractor"
    end
  end
end
