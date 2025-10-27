defmodule Singularity.Validation.Validator do
  @moduledoc """
  Behaviour for validation modules that enforce quality or safety rules.

  Validators should implement callbacks that describe their purpose,
  declared capabilities, and a `validate/2` function that returns `:ok`
  or `{:error, term()}` when violations are detected.
  """

  @typedoc "Validator modules implement this behaviour."
  @type t :: module()

  @callback validator_type() :: atom()
  @callback description() :: String.t()
  @callback capabilities() :: [String.t()]
  @callback validate(term(), keyword()) :: :ok | {:error, term()}

  @optional_callbacks capabilities: 0
end
