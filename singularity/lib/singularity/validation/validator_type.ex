defmodule Singularity.Validation.ValidatorType do
  @moduledoc """
  Validator Type Behavior - Contract for all validation operations.

  Consolidates scattered validators across different domains
  into a unified, config-driven validation system.

  Validators: Template, Code, Metadata, etc.
  """

  @callback validator_type() :: atom()
  @callback description() :: String.t()
  @callback capabilities() :: [String.t()]
  @callback validate(input :: term(), opts :: Keyword.t()) :: :ok | {:error, [String.t()]}
  @callback schema() :: map()

  require Logger

  def load_enabled_validators do
    :singularity
    |> Application.get_env(:validator_types, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.to_list()
  end

  def enabled?(validator_type) when is_atom(validator_type) do
    validators = load_enabled_validators()
    Enum.any?(validators, fn {type, _config} -> type == validator_type end)
  end

  def get_validator_module(validator_type) when is_atom(validator_type) do
    case Application.get_env(:singularity, :validator_types, %{})[validator_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :validator_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  def get_description(validator_type) when is_atom(validator_type) do
    case get_validator_module(validator_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          module.description()
        else
          "Unknown validator"
        end

      {:error, _} ->
        "Unknown validator"
    end
  end
end
