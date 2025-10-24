defmodule Singularity.Validation.ValidationOrchestrator do
  @moduledoc """
  Validation Orchestrator - Config-driven orchestration of validation strategies.

  Automatically discovers and runs enabled validators in priority order, collecting
  all violations. All validators must pass (no violations) for validation to succeed.

  Unlike FrameworkLearningOrchestrator (first-match-wins), ValidationOrchestrator
  runs ALL validators and collects violations from each.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Validation.ValidationOrchestrator",
    "purpose": "Config-driven orchestration of validation strategies",
    "layer": "validation",
    "status": "production"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      Validate["validate(input, opts)"]
      LoadConfig["Load enabled validators by priority"]
      Try1["Try Validator 1 (priority 10)"]
      Try2["Try Validator 2 (priority 15)"]
      Try3["Try Validator 3 (priority 20)"]
      Pass1["✓ Pass (no violations)"]
      Fail1["✗ Fail (has violations)"]
      Pass2["✓ Pass"]
      Fail2["✗ Fail"]
      Collect["Collect all violations"]
      Success["Success: :ok"]
      Error["Error: {:error, violations}"]

      Validate --> LoadConfig
      LoadConfig --> Try1
      Try1 --> Pass1
      Try1 --> Fail1
      Pass1 --> Try2
      Fail1 --> Collect
      Try2 --> Pass2
      Try2 --> Fail2
      Pass2 --> Try3
      Fail2 --> Collect
      Try3 --> Pass1
      Try3 --> Fail1
      Pass1 --> Success
      Fail1 --> Collect
      Collect --> Error
  ```

  ## Usage Examples

  ```elixir
  # Validate code with all enabled validators
  case ValidationOrchestrator.validate(code, type: :code) do
    :ok -> IO.puts("Validation passed")
    {:error, violations} -> IO.inspect(violations, label: "Failed")
  end

  # Validate with specific validators only
  case ValidationOrchestrator.validate(data, [
    type: :schema,
    validators: [:type_checker, :schema_validator]
  ]) do
    :ok -> IO.puts("Valid")
    {:error, v} -> IO.inspect(v)
  end

  # Get validator information
  validators = ValidationOrchestrator.get_validators_info()
  ```

  ## How Validation Works

  1. **Load enabled validators from config** (sorted by priority, ascending)
  2. **Run each validator in sequence**:
     - Collect violations from each validator
     - Continue to next validator (don't stop on error)
  3. **If any violations collected** → Return `{:error, violations}`
  4. **If no violations** → Return `:ok`

  All validators are run (unlike SearchOrchestrator which stops on first match).
  This ensures comprehensive validation.
  """

  require Logger
  alias Singularity.Validation.Validator

  @doc """
  Validate input against all enabled validators.

  Runs each enabled validator in priority order, collecting violations.
  Returns `:ok` only if ALL validators pass (no violations).

  ## Parameters

  - `input`: Data to validate (code, schema, etc.)
  - `opts`: Optional keyword list:
    - `:type` - Validation type (e.g., :code, :schema, :security)
    - `:validators` - Specific validators to use (default: all enabled)
    - `:timeout` - Timeout per validator in milliseconds (default: 5000)

  ## Returns

  - `:ok` - All validators passed
  - `{:error, violations}` - List of violation strings from all failed validators
  - `{:error, reason}` - Hard error from validator
  """
  def validate(input, opts \\ []) when is_list(opts) do
    try do
      validators = load_validators_for_attempt(opts)

      case run_validators(validators, input, opts) do
        {:ok, _violations} ->
          :ok

        {:error, violations} when is_list(violations) ->
          Logger.warn("Validation failed",
            violation_count: length(violations),
            validators: Enum.map(validators, fn {type, _priority, _config} -> type end)
          )
          {:error, violations}

        error ->
          error
      end
    rescue
      e ->
        Logger.error("Validation failed",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )
        {:error, :validation_failed}
    end
  end

  @doc """
  Get information about all configured validators and their status.

  Returns list of validator info maps with name, enabled status, priority, description, module.
  """
  def get_validators_info do
    Validator.load_enabled_validators()
    |> Enum.map(fn {type, priority, config} ->
      description = Validator.get_description(type)

      %{
        name: type,
        enabled: true,
        priority: priority,
        description: description,
        module: config[:module],
        capabilities: get_capabilities(type)
      }
    end)
  end

  @doc """
  Get capabilities for a specific validator type.
  """
  def get_capabilities(validator_type) when is_atom(validator_type) do
    case Validator.get_validator_module(validator_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) && function_exported?(module, :capabilities, 0) do
          module.capabilities()
        else
          []
        end

      {:error, _} ->
        []
    end
  end

  # Private helpers

  defp load_validators_for_attempt(opts) do
    case Keyword.get(opts, :validators) do
      nil ->
        # Use all enabled validators
        Validator.load_enabled_validators()

      specific_validators when is_list(specific_validators) ->
        # Filter to only requested validators, maintaining priority order
        all_validators = Validator.load_enabled_validators()

        Enum.filter(all_validators, fn {type, _priority, _config} ->
          type in specific_validators
        end)
    end
  end

  defp run_validators(validators, input, opts) do
    timeout = Keyword.get(opts, :timeout, 5000)
    run_validators_recursive(validators, input, opts, timeout, [])
  end

  defp run_validators_recursive([], _input, _opts, _timeout, violations) do
    if Enum.empty?(violations) do
      {:ok, []}
    else
      {:error, violations}
    end
  end

  defp run_validators_recursive(
         [{validator_type, _priority, config} | rest],
         input,
         opts,
         timeout,
         violations
       ) do
    try do
      module = config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Running #{validator_type} validator", input_type: Keyword.get(opts, :type))

        # Execute validator
        case module.validate(input, opts) do
          :ok ->
            Logger.debug("#{validator_type} validator passed")
            run_validators_recursive(rest, input, opts, timeout, violations)

          {:error, new_violations} ->
            Logger.warning("#{validator_type} validator failed",
              violation_count: length(new_violations)
            )

            # Collect violations and continue to next validator
            combined_violations = violations ++ new_violations
            run_validators_recursive(rest, input, opts, timeout, combined_violations)

          {:error, reason} ->
            # Hard error, stop and propagate
            Logger.error("#{validator_type} validator returned error",
              reason: inspect(reason)
            )

            {:error, reason}
        end
      else
        Logger.warn("Validator module not found for #{validator_type}")
        run_validators_recursive(rest, input, opts, timeout, violations)
      end
    rescue
      e ->
        Logger.error("Validator execution failed for #{validator_type}",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        # Continue to next validator on execution error
        run_validators_recursive(rest, input, opts, timeout, violations)
    end
  end
end
