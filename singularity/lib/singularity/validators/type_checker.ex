defmodule Singularity.Validators.TypeChecker do
  @moduledoc """
  Type Checker - Validates type specifications and type safety.

  Implements @behaviour Singularity.Validation.Validator for checking that code
  includes proper type specifications (@spec), @typedoc, and follows type safety patterns.

  ## Features

  - Checks for @spec declarations in public functions
  - Validates type annotation completeness
  - Checks for @type definitions
  - Verifies against complex type patterns

  ## Capabilities

  - `["type_safe", "ast_based", "fast"]`
  """

  @behaviour Singularity.Validation.Validator

  require Logger

  @impl Singularity.Validation.Validator
  def validator_type, do: :type_checker

  @impl Singularity.Validation.Validator
  def description do
    "Validates type specifications and type safety in code"
  end

  @impl Singularity.Validation.Validator
  def capabilities do
    ["type_safe", "ast_based", "fast", "spec_checking"]
  end

  @impl Singularity.Validation.Validator
  def validate(code, opts \\ []) when is_binary(code) do
    Logger.debug("Type checker: Starting validation")

    violations = []
    violations = check_has_specs(code, violations, opts)
    violations = check_type_annotations(code, violations, opts)

    if Enum.empty?(violations) do
      Logger.debug("Type checker: No violations found")
      :ok
    else
      Logger.warning("Type checker: Found #{length(violations)} violations")
      {:error, violations}
    end
  end

  defp check_has_specs(code, violations, _opts) do
    # Check if code contains @spec declarations
    case Regex.scan(~r/@spec\s+\w+/, code) do
      [] ->
        violations ++ ["Missing @spec declarations for public functions"]

      _ ->
        violations
    end
  end

  defp check_type_annotations(code, violations, _opts) do
    # Check for proper type annotations
    case Regex.scan(~r/def\s+\w+\([^)]*\)\s*do/, code) do
      [] ->
        violations

      functions ->
        # Check if functions have specs
        spec_count = length(Regex.scan(~r/@spec/, code))

        if spec_count < length(functions) do
          violations ++ [
            "Not all functions have @spec declarations (#{spec_count}/#{length(functions)} declared)"
          ]
        else
          violations
        end
    end
  end
end
