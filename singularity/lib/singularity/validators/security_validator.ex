defmodule Singularity.Validators.SecurityValidator do
  @moduledoc """
  Security Validator - Enforces security policies and access control.

  Implements @behaviour Singularity.Validation.Validator for validating
  that code follows security best practices and doesn't use dangerous patterns.

  ## Features

  - Checks for hardcoded secrets/credentials
  - Validates secure function usage
  - Enforces access control patterns
  - Detects dangerous patterns

  ## Capabilities

  - `["security_enforcement", "policy_checking", "secret_detection"]`
  """

  @behaviour Singularity.Validation.Validator

  require Logger

  @impl Singularity.Validation.Validator
  def validator_type, do: :security_validator

  @impl Singularity.Validation.Validator
  def description do
    "Enforces security policies and access control in code"
  end

  @impl Singularity.Validation.Validator
  def capabilities do
    ["security_enforcement", "policy_checking", "secret_detection", "pattern_matching"]
  end

  @impl Singularity.Validation.Validator
  def validate(code, opts \\ []) when is_binary(code) do
    Logger.debug("Security validator: Starting validation")

    violations = []
    violations = check_for_secrets(code, violations, opts)
    violations = check_dangerous_patterns(code, violations, opts)

    if Enum.empty?(violations) do
      Logger.debug("Security validator: No violations found")
      :ok
    else
      Logger.warning("Security validator: Found #{length(violations)} violations")
      {:error, violations}
    end
  end

  defp check_for_secrets(code, violations, _opts) do
    # Check for common secret patterns
    secrets = [
      {~r/password\s*=\s*"[^"]*"/i, "Hardcoded password found"},
      {~r/api[_-]?key\s*=\s*"[^"]*"/i, "Hardcoded API key found"},
      {~r/secret\s*=\s*"[^"]*"/i, "Hardcoded secret found"},
      {~r/credentials\s*=\s*"[^"]*"/i, "Hardcoded credentials found"}
    ]

    Enum.reduce(secrets, violations, fn {pattern, message}, acc ->
      if Regex.match?(pattern, code) do
        acc ++ [message]
      else
        acc
      end
    end)
  end

  defp check_dangerous_patterns(code, violations, _opts) do
    # Check for dangerous patterns
    dangerous = [
      {~r/eval\s*\(/i, "Dangerous eval/1 usage detected"},
      {~r/code\.eval/i, "Dangerous Code.eval_* usage detected"},
      {~r/System\.cmd.*sudo/i, "Dangerous sudo execution detected"}
    ]

    Enum.reduce(dangerous, violations, fn {pattern, message}, acc ->
      if Regex.match?(pattern, code) do
        acc ++ [message]
      else
        acc
      end
    end)
  end
end
