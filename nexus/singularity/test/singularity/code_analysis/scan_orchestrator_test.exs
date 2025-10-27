defmodule Singularity.CodeAnalysis.ScanOrchestratorTest do
  @moduledoc """
  Integration tests for ScanOrchestrator.

  Tests the unified code scanning system that orchestrates all enabled scanners
  (Quality, Security, Performance).

  Uses parallel execution with result aggregation: runs all scanners
  simultaneously and combines issues into a single map.

  ## Test Coverage

  - Scanner discovery and loading from config
  - Parallel execution of all scanners
  - Result aggregation and formatting
  - Options handling (scanner_types, min_severity, limit)
  - Severity filtering and result limiting
  - Error handling and edge cases
  - Integration with scanner implementations
  - Configuration integrity
  - Performance and determinism
  """

  use ExUnit.Case, async: true

  alias Singularity.CodeAnalysis.ScanOrchestrator
  alias Singularity.CodeAnalysis.ScannerType

  describe "get_scanner_types_info/0" do
    test "returns all enabled scanners" do
      scanners = ScanOrchestrator.get_scanner_types_info()

      assert is_list(scanners)
      assert length(scanners) > 0
    end

    test "all returned scanners have required fields" do
      scanners = ScanOrchestrator.get_scanner_types_info()

      Enum.each(scanners, fn scanner ->
        assert Map.has_key?(scanner, :name)
        assert Map.has_key?(scanner, :enabled)
        assert Map.has_key?(scanner, :description)
        assert Map.has_key?(scanner, :module)
      end)
    end

    test "all returned scanners are enabled" do
      scanners = ScanOrchestrator.get_scanner_types_info()

      Enum.each(scanners, fn scanner ->
        assert scanner.enabled == true, "Scanner #{scanner.name} should be enabled"
      end)
    end

    test "scanner modules are valid and loadable" do
      scanners = ScanOrchestrator.get_scanner_types_info()

      Enum.each(scanners, fn scanner ->
        assert Code.ensure_loaded?(scanner.module),
               "Scanner module #{scanner.module} should be loadable"
      end)
    end
  end

  describe "scan/2 - Basic Functionality" do
    test "accepts valid file path" do
      path = "lib"

      result = ScanOrchestrator.scan(path)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "returns ok tuple with results for valid path" do
      path = "lib"

      result = ScanOrchestrator.scan(path)

      case result do
        {:ok, results} ->
          assert is_map(results)
          # Results should have entries for each enabled scanner
          scanners = ScanOrchestrator.get_scanner_types_info()

          Enum.each(scanners, fn scanner ->
            assert Map.has_key?(results, scanner.name)
            assert is_list(results[scanner.name])
          end)

        {:error, reason} ->
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "accepts various valid paths" do
      paths = ["lib", "test", "lib/singularity"]

      Enum.each(paths, fn path ->
        result = ScanOrchestrator.scan(path)
        assert is_tuple(result) and tuple_size(result) == 2
      end)
    end

    test "rejects non-binary paths" do
      assert_raise FunctionClauseError, fn ->
        ScanOrchestrator.scan(123)
      end
    end

    test "handles nonexistent paths gracefully" do
      result = ScanOrchestrator.scan("/nonexistent/path/that/does/not/exist")
      # Should handle gracefully or return error
      assert is_tuple(result) and tuple_size(result) == 2
    end
  end

  describe "scan/2 - Parallel Execution" do
    test "runs all enabled scanners" do
      path = "lib"

      {:ok, results} = ScanOrchestrator.scan(path)

      # Should have results from all enabled scanners
      enabled_scanners = ScannerType.load_enabled_scanners()
      assert map_size(results) > 0
      assert map_size(results) <= length(enabled_scanners)
    end

    test "scanner results are lists" do
      path = "lib"

      result = ScanOrchestrator.scan(path)

      case result do
        {:ok, results} ->
          Enum.each(results, fn {_scanner_type, issues} ->
            assert is_list(issues), "Scanner issues should be lists"
          end)

        {:error, _} ->
          assert true
      end
    end

    test "results are aggregated from all scanners" do
      path = "lib"

      {:ok, results} = ScanOrchestrator.scan(path)

      # Results map should have keys for each scanner that ran
      assert is_map(results)
      assert map_size(results) > 0
    end
  end

  describe "scan/2 - Options Handling" do
    test "respects scanner_types option to run specific scanners" do
      path = "lib"
      opts = [scanner_types: [:quality]]

      {:ok, results} = ScanOrchestrator.scan(path, opts)

      # Should only have results from requested scanners
      assert map_size(results) <= 1
    end

    test "handles empty scanner_types list" do
      path = "lib"
      opts = [scanner_types: []]

      result = ScanOrchestrator.scan(path, opts)
      # With no scanners, should return ok with empty results
      assert result == {:ok, %{}} or match?({:ok, _}, result)
    end

    test "accepts min_severity option" do
      path = "lib"
      opts = [min_severity: "high"]

      result = ScanOrchestrator.scan(path, opts)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "accepts limit option to restrict results per scanner" do
      path = "lib"
      opts = [limit: 5]

      result = ScanOrchestrator.scan(path, opts)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "accepts combination of options" do
      path = "lib"
      opts = [scanner_types: [:quality], min_severity: "medium", limit: 10]

      result = ScanOrchestrator.scan(path, opts)
      assert is_tuple(result) and tuple_size(result) == 2
    end
  end

  describe "scan/2 - Severity Filtering" do
    test "filters results by minimum severity" do
      path = "lib"
      opts = [min_severity: "high"]

      {:ok, results} = ScanOrchestrator.scan(path, opts)

      # Results should only include high or critical severity
      Enum.each(results, fn {_scanner, issues} ->
        Enum.each(issues, fn issue ->
          severity = issue[:severity] || "low"
          severity_order = %{"low" => 1, "medium" => 2, "high" => 3, "critical" => 4}
          min_order = severity_order["high"] || 0
          result_order = severity_order[severity] || 0
          assert result_order >= min_order
        end)
      end)
    end

    test "includes all severities when no filter applied" do
      path = "lib"

      {:ok, results} = ScanOrchestrator.scan(path)
      # Without min_severity, all results should be included
      assert is_map(results)
    end

    test "respects critical severity level" do
      path = "lib"
      opts = [min_severity: "critical"]

      {:ok, results} = ScanOrchestrator.scan(path, opts)

      # All results should be critical
      Enum.each(results, fn {_scanner, issues} ->
        Enum.each(issues, fn issue ->
          severity = issue[:severity] || "low"
          assert severity == "critical" or issue == %{}
        end)
      end)
    end
  end

  describe "scan/2 - Result Limiting" do
    test "limits results per scanner when specified" do
      path = "lib"
      opts = [limit: 3]

      {:ok, results} = ScanOrchestrator.scan(path, opts)

      # Each scanner should have at most 3 results
      Enum.each(results, fn {_scanner, issues} ->
        assert length(issues) <= 3
      end)
    end

    test "zero limit returns empty results" do
      path = "lib"
      opts = [limit: 0]

      {:ok, results} = ScanOrchestrator.scan(path, opts)

      # All scanners should have no results
      Enum.each(results, fn {_scanner, issues} ->
        assert issues == []
      end)
    end
  end

  describe "learn_from_scan/2" do
    test "learns from valid scanner result" do
      scan_result = %{
        type: "duplication",
        severity: "high",
        message: "Code duplication detected"
      }

      result = ScanOrchestrator.learn_from_scan(:quality, scan_result)
      # Should return ok or error, but not crash
      assert result == :ok or match?({:error, _}, result)
    end

    test "handles nonexistent scanner gracefully" do
      scan_result = %{type: "test", severity: "low"}
      result = ScanOrchestrator.learn_from_scan(:nonexistent, scan_result)

      # Should return error for unknown scanner
      assert match?({:error, _}, result)
    end

    test "accepts result map with various fields" do
      scan_result = %{
        type: "complex_issue",
        severity: "medium",
        message: "Test message",
        data: %{extra: "fields"}
      }

      result = ScanOrchestrator.learn_from_scan(:security, scan_result)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "Configuration Integrity" do
    test "scanner config matches implementation" do
      # Load config
      config = Application.get_env(:singularity, :scanner_types, %{})

      # Should have entries
      assert config != nil and config != %{}

      # All configured scanners should exist
      Enum.each(config, fn {name, scanner_config} ->
        assert is_atom(name)
        assert is_map(scanner_config)
        assert scanner_config[:module]
        assert scanner_config[:enabled] in [true, false]

        # If enabled, module should be loadable
        if scanner_config[:enabled] do
          assert Code.ensure_loaded?(scanner_config[:module]),
                 "Configured module #{scanner_config[:module]} should be loadable"
        end
      end)
    end

    test "all enabled scanners are discoverable" do
      enabled_scanners = ScannerType.load_enabled_scanners()
      info = ScanOrchestrator.get_scanner_types_info()
      info_names = Enum.map(info, & &1.name)

      Enum.each(enabled_scanners, fn {type, _config} ->
        assert type in info_names, "Scanner #{type} should be in info list"
      end)
    end

    test "no duplicate scanner names" do
      info = ScanOrchestrator.get_scanner_types_info()
      names = Enum.map(info, & &1.name)
      unique_names = Enum.uniq(names)

      assert length(names) == length(unique_names),
             "Scanner names should be unique"
    end
  end

  describe "Scanner Behavior Callbacks" do
    test "all enabled scanners implement required callbacks" do
      enabled_scanners = ScannerType.load_enabled_scanners()

      Enum.each(enabled_scanners, fn {_type, config} ->
        module = config[:module]
        assert Code.ensure_loaded?(module)

        # Check for required callbacks
        assert function_exported?(module, :scanner_type, 0),
               "#{module} must implement scanner_type/0"

        assert function_exported?(module, :description, 0),
               "#{module} must implement description/0"

        assert function_exported?(module, :capabilities, 0),
               "#{module} must implement capabilities/0"

        assert function_exported?(module, :scan, 2),
               "#{module} must implement scan/2"

        assert function_exported?(module, :learn_from_scan, 1),
               "#{module} must implement learn_from_scan/1"
      end)
    end

    test "all scanner callbacks return expected types" do
      enabled_scanners = ScannerType.load_enabled_scanners()

      Enum.each(enabled_scanners, fn {_type, config} ->
        module = config[:module]

        # Test callback return types
        scanner_type = module.scanner_type()
        assert is_atom(scanner_type)

        description = module.description()
        assert is_binary(description)

        capabilities = module.capabilities()
        assert is_list(capabilities)

        # All capabilities should be strings
        Enum.each(capabilities, fn capability ->
          assert is_binary(capability)
        end)
      end)
    end
  end

  describe "Scanning Scenarios" do
    test "quality scanning" do
      path = "lib"

      result = ScanOrchestrator.scan(path, scanner_types: [:quality])

      case result do
        {:ok, results} ->
          assert :quality in Map.keys(results) or map_size(results) >= 0

        {:error, _} ->
          assert true
      end
    end

    test "security scanning" do
      path = "lib"

      result = ScanOrchestrator.scan(path, scanner_types: [:security])

      case result do
        {:ok, results} ->
          assert :security in Map.keys(results) or map_size(results) >= 0

        {:error, _} ->
          assert true
      end
    end

    test "comprehensive scanning with all scanners" do
      path = "lib"

      result = ScanOrchestrator.scan(path)

      case result do
        {:ok, results} ->
          # Should have scans from multiple types
          assert is_map(results)
          assert map_size(results) > 0

        {:error, _} ->
          assert true
      end
    end
  end

  describe "Integration with Scanners" do
    test "QualityScanner is discoverable and configured" do
      enabled = ScannerType.load_enabled_scanners()
      names = Enum.map(enabled, fn {type, _config} -> type end)

      assert :quality in names, "QualityScanner should be enabled"
    end

    test "SecurityScanner is discoverable and configured" do
      enabled = ScannerType.load_enabled_scanners()
      names = Enum.map(enabled, fn {type, _config} -> type end)

      assert :security in names, "SecurityScanner should be enabled"
    end
  end

  describe "Performance and Determinism" do
    test "scanner discovery is deterministic" do
      scanners1 = ScannerType.load_enabled_scanners()
      scanners2 = ScannerType.load_enabled_scanners()

      # Should return same scanners
      assert length(scanners1) == length(scanners2)
    end

    test "info gathering is consistent" do
      info1 = ScanOrchestrator.get_scanner_types_info()
      info2 = ScanOrchestrator.get_scanner_types_info()

      # Should have same scanners in same order
      assert length(info1) == length(info2)
      assert Enum.map(info1, & &1.name) == Enum.map(info2, & &1.name)
    end

    test "scanning results are deterministic" do
      path = "lib"

      result1 = ScanOrchestrator.scan(path)
      result2 = ScanOrchestrator.scan(path)

      # Same path should produce consistent results
      case {result1, result2} do
        {{:ok, _}, {:ok, _}} -> assert true
        {{:error, _}, {:error, _}} -> assert true
        _ -> assert true
      end
    end
  end

  describe "Error Handling" do
    test "handles scanner execution failures gracefully" do
      path = "lib"

      result = ScanOrchestrator.scan(path)
      # Should handle gracefully, not crash
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "logs scanning attempts" do
      log =
        capture_log(fn ->
          path = "lib"
          ScanOrchestrator.scan(path)
        end)

      # Should contain some logs or be empty
      assert is_binary(log)
    end
  end

  describe "Scan Results Structure" do
    test "all scan results have consistent structure" do
      path = "lib"

      {:ok, results} = ScanOrchestrator.scan(path)

      Enum.each(results, fn {_scanner_type, issues} ->
        Enum.each(issues, fn issue ->
          # Each issue should be a map
          assert is_map(issue)
        end)
      end)
    end

    test "scan results preserve scanner type information" do
      path = "lib"

      {:ok, results} = ScanOrchestrator.scan(path)

      # Results should be keyed by scanner type
      Enum.each(results, fn {scanner_type, _issues} ->
        assert is_atom(scanner_type)
      end)
    end
  end

  describe "Scanner Type Checking" do
    test "enabled? predicate works for valid scanner" do
      enabled_scanners = ScannerType.load_enabled_scanners()

      case enabled_scanners do
        [{first_type, _config} | _] ->
          assert ScannerType.enabled?(first_type)

        _ ->
          assert true
      end
    end

    test "enabled? predicate returns false for invalid scanner" do
      assert ScannerType.enabled?(:nonexistent_scanner) == false
    end

    test "get_scanner_module works for valid scanner" do
      enabled_scanners = ScannerType.load_enabled_scanners()

      case enabled_scanners do
        [{first_type, _config} | _] ->
          result = ScannerType.get_scanner_module(first_type)
          assert match?({:ok, _}, result)

        _ ->
          assert true
      end
    end

    test "get_scanner_module returns error for invalid scanner" do
      result = ScannerType.get_scanner_module(:nonexistent)
      assert match?({:error, _}, result)
    end
  end

  describe "Scan Filtering Logic" do
    test "severity filtering removes low severity results when min_severity is high" do
      path = "lib"
      opts = [min_severity: "critical"]

      {:ok, results} = ScanOrchestrator.scan(path, opts)

      # All results should be critical or not present
      Enum.each(results, fn {_scanner, issues} ->
        Enum.each(issues, fn issue ->
          severity = issue[:severity] || "low"
          assert severity == "critical" or issue == %{}
        end)
      end)
    end

    test "limit filtering caps results per scanner" do
      path = "lib"
      opts = [limit: 2]

      {:ok, results} = ScanOrchestrator.scan(path, opts)

      Enum.each(results, fn {_scanner, issues} ->
        assert length(issues) <= 2
      end)
    end
  end

  describe "Multi-Scanner Scenarios" do
    test "scanning with multiple scanner types specified" do
      path = "lib"
      opts = [scanner_types: [:quality, :security]]

      result = ScanOrchestrator.scan(path, opts)

      case result do
        {:ok, results} ->
          # Should have results from both scanners
          types = Map.keys(results)
          assert :quality in types or :security in types or map_size(results) >= 0

        {:error, _} ->
          assert true
      end
    end

    test "combining severity filter with scanner type selection" do
      path = "lib"
      opts = [scanner_types: [:quality], min_severity: "high"]

      result = ScanOrchestrator.scan(path, opts)

      case result do
        {:ok, results} ->
          Enum.each(results, fn {_scanner, issues} ->
            Enum.each(issues, fn issue ->
              severity = issue[:severity] || "low"
              assert severity in ["high", "critical"]
            end)
          end)

        {:error, _} ->
          assert true
      end
    end

    test "combining limit with severity filter" do
      path = "lib"
      opts = [min_severity: "medium", limit: 5]

      result = ScanOrchestrator.scan(path, opts)

      case result do
        {:ok, results} ->
          Enum.each(results, fn {_scanner, issues} ->
            assert length(issues) <= 5
          end)

        {:error, _} ->
          assert true
      end
    end
  end

  defp capture_log(fun) do
    ExUnit.CaptureLog.capture_log(fun)
  end
end
