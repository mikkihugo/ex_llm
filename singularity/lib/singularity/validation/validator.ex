defmodule Singularity.Validation.Validator do
  @moduledoc """
  Validator Behavior - Contract for all validation strategies.

  Defines the unified interface for validators (type checking, schema validation, security checks, etc.)
  enabling config-driven orchestration of validation rules.

  Consolidates scattered validators (CodeValidator, TemplateValidator, SecurityPolicy, MetadataValidator, etc.)
  into a unified system with consistent configuration and execution patterns.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Validation.Validator",
    "purpose": "Behavior contract for config-driven validator orchestration",
    "type": "behavior/protocol",
    "layer": "validation",
    "status": "production"
  }
  ```

  ## Configuration Example

  ```elixir
  # singularity/config/config.exs
  config :singularity, :validators,
    type_checker: %{
      module: Singularity.Validators.TypeChecker,
      enabled: true,
      priority: 10,
      description: "Validates type specifications and type safety"
    },
    schema_validator: %{
      module: Singularity.Validators.SchemaValidator,
      enabled: true,
      priority: 20,
      description: "Validates against schema templates"
    },
    security_validator: %{
      module: Singularity.Validators.SecurityValidator,
      enabled: true,
      priority: 15,
      description: "Enforces security policies and access control"
    }
  ```

  ## How Validators Work

  1. **Orchestrator loads validators from config** (sorted by priority, ascending)
  2. **Try each validator in sequence**:
     - If `:ok` → Continue to next (all must pass)
     - If `{:error, violations}` → Return error (fail fast)
  3. **Collect all violations** across validators
  4. **Return final result** with all violations combined

  ## Usage

  ```elixir
  case ValidationOrchestrator.validate(code, type: :code) do
    :ok ->
      IO.puts("Code passed all validations")

    {:error, violations} ->
      IO.inspect(violations, label: "Violations")
  end
  ```
  """

  require Logger

  @doc """
  Returns the atom identifier for this validator.

  Examples: `:type_checker`, `:schema_validator`, `:security_validator`
  """
  @callback validator_type() :: atom()

  @doc """
  Returns human-readable description of what this validator does.
  """
  @callback description() :: String.t()

  @doc """
  Returns list of capabilities this validator provides.

  Examples: `["type_safe", "fast"]` or `["security", "policy_enforcement"]`
  """
  @callback capabilities() :: [String.t()]

  @doc """
  Attempt to validate input against rules.

  Returns one of:
  - `:ok` - Validation passed
  - `{:error, violations}` - Validation failed with list of violations (strings)

  The validator should return `:ok` only if ALL checks pass.
  Violations should be human-readable strings describing what failed.
  """
  @callback validate(input :: term(), opts :: Keyword.t()) :: :ok | {:error, [String.t()]}

  # Config loading helpers

  @doc """
  Load all enabled validators from config, sorted by priority (ascending).

  Returns: `[{validator_type, priority, config_map}, ...]` in priority order
  """
  def load_enabled_validators do
    :singularity
    |> Application.get_env(:validators, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.map(fn {type, config} -> {type, config[:priority] || 100, config} end)
    |> Enum.sort_by(fn {_type, priority, _config} -> priority end)
  end

  @doc """
  Check if a specific validator type is enabled.
  """
  def enabled?(validator_type) when is_atom(validator_type) do
    validators = load_enabled_validators()
    Enum.any?(validators, fn {type, _priority, _config} -> type == validator_type end)
  end

  @doc """
  Get the module implementing a specific validator type.
  """
  def get_validator_module(validator_type) when is_atom(validator_type) do
    case Application.get_env(:singularity, :validators, %{})[validator_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :validator_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  @doc """
  Get priority for a specific validator type (lower numbers validate first).

  Defaults to 100 if not specified, ensuring priority-ordered validation.
  """
  def get_priority(validator_type) when is_atom(validator_type) do
    case Application.get_env(:singularity, :validators, %{})[validator_type] do
      %{priority: priority} -> priority
      _ -> 100
    end
  end

  @doc """
  Get description for a specific validator type.
  """
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
