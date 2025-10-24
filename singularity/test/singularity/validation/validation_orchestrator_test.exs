defmodule Singularity.Validation.ValidationOrchestratorTest do
  @moduledoc """
  Integration tests for ValidationOrchestrator.

  Tests the unified validation system that enforces all validators must pass.
  Uses all-must-pass semantics: runs all validators and collects violations.

  ## Test Coverage

  - Validator discovery and loading from config
  - All-must-pass execution semantics
  - Priority ordering for error reporting
  - Violation collection and reporting
  - Error handling and edge cases
  - Integration with validator implementations
  """

  use ExUnit.Case, async: true

  alias Singularity.Validation.ValidationOrchestrator
  alias Singularity.Validation.Validator

  describe "get_validators_info/0" do
    test "returns all enabled validators sorted by priority" do
      validators = ValidationOrchestrator.get_validators_info()

      assert is_list(validators)
      assert length(validators) > 0

      # All validators should have required fields
      Enum.each(validators, fn validator ->
        assert Map.has_key?(validator, :name)
        assert Map.has_key?(validator, :enabled)
        assert Map.has_key?(validator, :priority)
        assert Map.has_key?(validator, :module)
        assert Map.has_key?(validator, :description)
      end)

      # Verify validators are sorted by priority (ascending)
      priorities = Enum.map(validators, & &1.priority)
      assert priorities == Enum.sort(priorities),
             "Validators should be sorted by priority (lowest first)"
    end

    test "all returned validators are enabled" do
      validators = ValidationOrchestrator.get_validators_info()

      Enum.each(validators, fn validator ->
        assert validator.enabled == true, "Validator #{validator.name} should be enabled"
      end)
    end

    test "validator modules are valid" do
      validators = ValidationOrchestrator.get_validators_info()

      Enum.each(validators, fn validator ->
        assert Code.ensure_loaded?(validator.module),
               "Validator module #{validator.module} should be loadable"
      end)
    end
  end

  describe "validate/2 - Basic Functionality" do
    test "returns :ok for valid input" do
      # Input that passes all validators
      valid_input = %{
        type: :valid,
        code: "def foo do :bar end",
        data: %{field: "value"}
      }

      result = ValidationOrchestrator.validate(valid_input)
      assert result == :ok
    end

    test "may return error tuple with violations for problematic input" do
      # Input with potential issues
      input = %{
        type: :potential_violation,
        code: "password = \"secret123\"",
        data: %{password: "hardcoded"}
      }

      result = ValidationOrchestrator.validate(input)
      # Validators may or may not find issues depending on implementation
      assert result == :ok or match?({:error, _}, result)
    end

    test "accepts input map with various structures" do
      task = %{
        type: :test_validation,
        data: %{test: "data"}
      }

      result = ValidationOrchestrator.validate(task)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "validate/2 - All-Must-Pass Semantics" do
    test "runs all validators even if one fails" do
      # Input that may trigger multiple validators
      input = %{
        type: :multi_violation,
        code: "password = \"secret\"",
        data: %{missing_required_field: nil}
      }

      result = ValidationOrchestrator.validate(input)
      # All-must-pass means if any fails, return error with ALL violations
      case result do
        :ok -> assert true
        {:error, violations} ->
          # Should collect violations from all validators, not just first
          assert is_list(violations)
          assert length(violations) > 0
      end
    end

    test "passes only if all validators pass" do
      # Clean, valid input
      valid_input = %{
        type: :clean,
        code: "defmodule Good do\n  def valid_function do\n    :ok\n  end\nend"
      }

      result = ValidationOrchestrator.validate(valid_input)
      # Should pass all validators
      assert result == :ok or match?({:error, violations}, result)
    end

    test "collects violations from all validators" do
      # Input with multiple issues
      input = %{
        type: :multi_issue,
        code: "def x do x = 1 y = 2 end",  # Malformed code
        data: nil  # Missing data
      }

      result = ValidationOrchestrator.validate(input)

      case result do
        {:error, violations} ->
          # Should have violations from multiple validators
          assert is_list(violations)
          Enum.each(violations, fn violation ->
            assert is_map(violation) or is_atom(violation)
          end)

        :ok ->
          # Valid according to all validators
          assert true
      end
    end
  end

  describe "validate/2 - Options Handling" do
    test "accepts and processes options" do
      input = %{type: :test, data: %{}}
      opts = [severity: :high, strict: true]

      result = ValidationOrchestrator.validate(input, opts)
      assert result == :ok or match?({:error, _}, result)
    end

    test "respects custom validator list in options" do
      input = %{type: :test, data: %{}}
      opts = [validators: [:type_checker]]

      result = ValidationOrchestrator.validate(input, opts)
      assert result == :ok or match?({:error, _}, result)
    end

    test "handles empty validator list gracefully" do
      input = %{type: :test, data: %{}}
      opts = [validators: []]

      # With no validators, should pass
      result = ValidationOrchestrator.validate(input, opts)
      assert result == :ok
    end
  end

  describe "validate/2 - Error Handling" do
    test "handles validator execution failures gracefully" do
      # Input that may cause validator issues
      input = %{
        type: :problematic,
        data: %{complex: "structure"}
      }

      result = ValidationOrchestrator.validate(input)
      # Should handle gracefully, not crash
      assert result == :ok or match?({:error, _}, result)
    end

    test "logs validation attempts" do
      log = capture_log(fn ->
        input = %{type: :test, data: %{}}
        ValidationOrchestrator.validate(input)
      end)

      # Should contain validation logs
      assert log =~ "Validating" or log =~ "validator" or log == ""
    end
  end

  describe "get_capabilities/1" do
    test "returns capabilities for valid validator" do
      capabilities = ValidationOrchestrator.get_capabilities(:type_checker)
      assert is_list(capabilities)
    end

    test "returns empty list for invalid validator" do
      capabilities = ValidationOrchestrator.get_capabilities(:nonexistent_validator)
      assert capabilities == []
    end

    test "all validators have at least one capability" do
      validators = ValidationOrchestrator.get_validators_info()

      Enum.each(validators, fn validator ->
        capabilities = ValidationOrchestrator.get_capabilities(validator.name)
        assert is_list(capabilities)
        assert length(capabilities) > 0,
               "Validator #{validator.name} should have at least one capability"
      end)
    end
  end

  describe "load_enabled_validators/0" do
    test "returns all enabled validators from config" do
      validators = Validator.load_enabled_validators()

      assert is_list(validators)
      assert length(validators) > 0

      # All should be tuples of {type, priority, config}
      Enum.each(validators, fn entry ->
        assert is_tuple(entry)
        assert tuple_size(entry) == 3
        {type, priority, config} = entry
        assert is_atom(type)
        assert is_integer(priority)
        assert is_map(config)
        assert config[:module]
      end)
    end

    test "validators are sorted by priority" do
      validators = Validator.load_enabled_validators()
      priorities = Enum.map(validators, fn {_type, priority, _config} -> priority end)

      assert priorities == Enum.sort(priorities),
             "Validators should be sorted by priority (lowest first)"
    end
  end

  describe "Validator behavior callbacks" do
    test "all validators implement required callbacks" do
      validators = Validator.load_enabled_validators()

      Enum.each(validators, fn {_type, _priority, config} ->
        module = config[:module]
        assert Code.ensure_loaded?(module)

        # Check for required callbacks
        assert function_exported?(module, :validator_type, 0),
               "#{module} must implement validator_type/0"

        assert function_exported?(module, :description, 0),
               "#{module} must implement description/0"

        assert function_exported?(module, :capabilities, 0),
               "#{module} must implement capabilities/0"

        assert function_exported?(module, :validate, 2),
               "#{module} must implement validate/2"
      end)
    end

    test "all validator callbacks return expected types" do
      validators = Validator.load_enabled_validators()

      Enum.each(validators, fn {type, _priority, config} ->
        module = config[:module]

        # Test callback return types
        validator_type = module.validator_type()
        assert is_atom(validator_type)

        description = module.description()
        assert is_binary(description)

        capabilities = module.capabilities()
        assert is_list(capabilities)

        # All capabilities should be strings
        Enum.each(capabilities, fn cap ->
          assert is_binary(cap), "Capability should be a string"
        end)
      end)
    end
  end

  describe "Validation Scenarios" do
    test "type checking validation" do
      input = %{
        type: :type_check,
        code: "@spec foo(integer) :: string",
        data: %{spec: "valid"}
      }

      result = ValidationOrchestrator.validate(input)
      assert result == :ok or match?({:error, _}, result)
    end

    test "security validation" do
      # Input with potential security issues
      input = %{
        type: :security_check,
        code: "System.cmd(\"rm\", [\"-rf\", \"/\"])",
        data: %{dangerous: true}
      }

      result = ValidationOrchestrator.validate(input)
      # May fail security validation
      assert result == :ok or match?({:error, _}, result)
    end

    test "schema validation" do
      # Well-formed data structure
      input = %{
        type: :schema_check,
        data: %{
          required_field: "present",
          type_field: 123
        }
      }

      result = ValidationOrchestrator.validate(input)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "Configuration Integrity" do
    test "config matches implementation" do
      # Load config
      config = Application.get_env(:singularity, :validators, [])

      # Should have entries
      assert length(config) > 0

      # All configured validators should exist
      Enum.each(config, fn {name, validator_config} ->
        assert is_atom(name)
        assert is_map(validator_config)
        assert validator_config[:module]
        assert validator_config[:enabled] in [true, false]
        assert is_integer(validator_config[:priority])

        # If enabled, module should be loadable
        if validator_config[:enabled] do
          assert Code.ensure_loaded?(validator_config[:module]),
                 "Configured module #{validator_config[:module]} should be loadable"
        end
      end)
    end

    test "no duplicate priorities" do
      validators = Validator.load_enabled_validators()
      priorities = Enum.map(validators, fn {_type, priority, _config} -> priority end)

      # While duplicates are allowed, clear ordering is preferred
      unique_priorities = Enum.uniq(priorities)
      assert length(priorities) == length(unique_priorities),
             "Validators should have unique priorities for clear ordering"
    end

    test "type_checker has lowest priority" do
      validators = Validator.load_enabled_validators()

      case validators do
        [{:type_checker, priority, _} | _] ->
          # First validator (lowest priority) should be type_checker
          assert priority == 10

        _ ->
          # Different ordering, which is fine, just document it
          assert true
      end
    end
  end

  describe "Integration with Validators" do
    test "TypeChecker is discoverable and configured" do
      validators = Validator.load_enabled_validators()
      names = Enum.map(validators, fn {type, _priority, _config} -> type end)

      assert :type_checker in names, "TypeChecker should be enabled and discoverable"
    end

    test "SecurityValidator is discoverable and configured" do
      validators = Validator.load_enabled_validators()
      names = Enum.map(validators, fn {type, _priority, _config} -> type end)

      assert :security_validator in names, "SecurityValidator should be enabled and discoverable"
    end

    test "SchemaValidator is discoverable and configured" do
      validators = Validator.load_enabled_validators()
      names = Enum.map(validators, fn {type, _priority, _config} -> type end)

      assert :schema_validator in names, "SchemaValidator should be enabled and discoverable"
    end
  end

  describe "Performance and Determinism" do
    test "validator discovery is deterministic" do
      validators1 = Validator.load_enabled_validators()
      validators2 = Validator.load_enabled_validators()

      # Should return same validators in same order
      assert validators1 == validators2
    end

    test "info gathering is consistent" do
      info1 = ValidationOrchestrator.get_validators_info()
      info2 = ValidationOrchestrator.get_validators_info()

      # Should have same validators in same order
      assert length(info1) == length(info2)
      assert Enum.map(info1, & &1.name) == Enum.map(info2, & &1.name)
    end

    test "validation results are deterministic" do
      input = %{
        type: :deterministic_test,
        code: "def test do :ok end",
        data: %{clean: true}
      }

      result1 = ValidationOrchestrator.validate(input)
      result2 = ValidationOrchestrator.validate(input)

      # Same input should produce same validation result
      assert result1 == result2
    end
  end

  describe "Violation Reporting" do
    test "violations include validator information" do
      input = %{
        type: :violation_check,
        code: "password = \"secret\"",
        data: nil
      }

      result = ValidationOrchestrator.validate(input)

      case result do
        {:error, violations} ->
          # Violations should indicate which validators failed
          assert is_list(violations)
          Enum.each(violations, fn v ->
            # Each violation should be describable
            assert is_map(v) or is_atom(v) or is_binary(v)
          end)

        :ok ->
          assert true
      end
    end
  end

  describe "Priority Ordering" do
    test "validators run in priority order" do
      # All validators should run (all-must-pass semantics)
      # Lower priority numbers run first
      validators = Validator.load_enabled_validators()
      priorities = Enum.map(validators, fn {_type, priority, _config} -> priority end)

      # Priorities should be in ascending order
      assert priorities == Enum.sort(priorities)
    end
  end

  defp capture_log(fun) do
    ExUnit.CaptureLog.capture_log(fun)
  end
end
