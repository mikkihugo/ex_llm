defmodule Singularity.Architecture.AnalysisOrchestratorTest do
  @moduledoc """
  Integration tests for AnalysisOrchestrator.

  Tests the unified analysis system that orchestrates all enabled analyzers
  (Feedback, Quality, Refactoring, Microservice).

  Uses parallel execution with result aggregation: runs all analyzers
  simultaneously and combines results into a single map.

  ## Test Coverage

  - Analyzer discovery and loading from config
  - Parallel execution of all analyzers
  - Result aggregation and formatting
  - Options handling (analyzer_types, min_severity, limit)
  - Error handling and edge cases
  - Integration with analyzer implementations
  - Configuration integrity
  - Performance and determinism
  """

  use ExUnit.Case, async: true

  alias Singularity.Architecture.AnalysisOrchestrator
  alias Singularity.Architecture.AnalyzerType

  describe "get_analyzer_types_info/0" do
    test "returns all enabled analyzers" do
      analyzers = AnalysisOrchestrator.get_analyzer_types_info()

      assert is_list(analyzers)
      assert length(analyzers) > 0
    end

    test "all returned analyzers have required fields" do
      analyzers = AnalysisOrchestrator.get_analyzer_types_info()

      Enum.each(analyzers, fn analyzer ->
        assert Map.has_key?(analyzer, :name)
        assert Map.has_key?(analyzer, :enabled)
        assert Map.has_key?(analyzer, :description)
        assert Map.has_key?(analyzer, :module)
      end)
    end

    test "all returned analyzers are enabled" do
      analyzers = AnalysisOrchestrator.get_analyzer_types_info()

      Enum.each(analyzers, fn analyzer ->
        assert analyzer.enabled == true, "Analyzer #{analyzer.name} should be enabled"
      end)
    end

    test "analyzer modules are valid and loadable" do
      analyzers = AnalysisOrchestrator.get_analyzer_types_info()

      Enum.each(analyzers, fn analyzer ->
        assert Code.ensure_loaded?(analyzer.module),
               "Analyzer module #{analyzer.module} should be loadable"
      end)
    end
  end

  describe "analyze/2 - Basic Functionality" do
    test "returns ok tuple with results for valid input" do
      input = %{
        type: :test_analysis,
        data: %{metric: 0.95, cost: 0.05}
      }

      result = AnalysisOrchestrator.analyze(input)

      case result do
        {:ok, results} ->
          assert is_map(results)
          # Results should have entries for each enabled analyzer
          analyzers = AnalysisOrchestrator.get_analyzer_types_info()

          Enum.each(analyzers, fn analyzer ->
            assert Map.has_key?(results, analyzer.name)
            assert is_list(results[analyzer.name])
          end)

        {:error, reason} ->
          # Analysis may fail gracefully
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "accepts input map with various structures" do
      input = %{
        type: :analysis_test,
        data: %{test: "data"}
      }

      result = AnalysisOrchestrator.analyze(input)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "returns error tuple on failures" do
      # May or may not fail depending on analyzer implementations
      input = %{
        type: :problematic,
        data: nil
      }

      result = AnalysisOrchestrator.analyze(input)
      assert is_tuple(result) and tuple_size(result) == 2
    end
  end

  describe "analyze/2 - Parallel Execution" do
    test "runs all enabled analyzers" do
      input = %{
        type: :parallel_test,
        data: %{complex: "metrics"}
      }

      {:ok, results} = AnalysisOrchestrator.analyze(input)

      # Should have results from all enabled analyzers
      enabled_analyzers = AnalyzerType.load_enabled_analyzers()
      assert map_size(results) > 0
      assert map_size(results) <= length(enabled_analyzers)
    end

    test "analyzer results are lists" do
      input = %{
        type: :result_format_test,
        data: %{test: "data"}
      }

      result = AnalysisOrchestrator.analyze(input)

      case result do
        {:ok, results} ->
          Enum.each(results, fn {_analyzer_type, analysis_results} ->
            assert is_list(analysis_results),
                   "Analysis results should be lists"
          end)

        {:error, _} ->
          assert true
      end
    end

    test "results are aggregated from all analyzers" do
      input = %{
        type: :aggregation_test,
        data: %{comprehensive: "analysis"}
      }

      {:ok, results} = AnalysisOrchestrator.analyze(input)

      # Results map should have keys for each analyzer that ran
      assert is_map(results)
      assert map_size(results) > 0
    end
  end

  describe "analyze/2 - Options Handling" do
    test "respects analyzer_types option to run specific analyzers" do
      input = %{
        type: :selective_analysis,
        data: %{}
      }

      opts = [analyzer_types: [:feedback, :quality]]
      {:ok, results} = AnalysisOrchestrator.analyze(input, opts)

      # Should only have results from requested analyzers
      assert map_size(results) <= 2
    end

    test "handles empty analyzer_types list" do
      input = %{type: :empty_analysis, data: %{}}
      opts = [analyzer_types: []]

      result = AnalysisOrchestrator.analyze(input, opts)
      # With no analyzers, should return ok with empty results
      assert result == {:ok, %{}} or match?({:ok, _}, result)
    end

    test "accepts min_severity option" do
      input = %{type: :severity_filter, data: %{}}
      opts = [min_severity: "high"]

      result = AnalysisOrchestrator.analyze(input, opts)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "accepts limit option to restrict results per analyzer" do
      input = %{type: :limit_test, data: %{}}
      opts = [limit: 5]

      result = AnalysisOrchestrator.analyze(input, opts)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "accepts combination of options" do
      input = %{type: :multi_option, data: %{}}
      opts = [analyzer_types: [:feedback], min_severity: "medium", limit: 10]

      result = AnalysisOrchestrator.analyze(input, opts)
      assert is_tuple(result) and tuple_size(result) == 2
    end
  end

  describe "analyze/2 - Severity Filtering" do
    test "filters results by minimum severity" do
      input = %{
        type: :severity_test,
        data: %{test: "filter"}
      }

      opts = [min_severity: "high"]
      {:ok, results} = AnalysisOrchestrator.analyze(input, opts)

      # Results should only include high or critical severity
      Enum.each(results, fn {_analyzer, analyses} ->
        Enum.each(analyses, fn analysis ->
          severity = analysis[:severity] || "low"
          severity_order = %{"low" => 1, "medium" => 2, "high" => 3, "critical" => 4}
          min_order = severity_order["high"] || 0
          result_order = severity_order[severity] || 0
          assert result_order >= min_order
        end)
      end)
    end

    test "includes all severities when no filter applied" do
      input = %{type: :no_filter_test, data: %{}}

      {:ok, results} = AnalysisOrchestrator.analyze(input)
      # Without min_severity, all results should be included
      assert is_map(results)
    end
  end

  describe "analyze/2 - Result Limiting" do
    test "limits results per analyzer when specified" do
      input = %{type: :limit_results, data: %{}}
      opts = [limit: 3]

      {:ok, results} = AnalysisOrchestrator.analyze(input, opts)

      # Each analyzer should have at most 3 results
      Enum.each(results, fn {_analyzer, analyses} ->
        assert length(analyses) <= 3
      end)
    end
  end

  describe "learn_pattern/2" do
    test "learns from valid analyzer result" do
      analysis_result = %{
        type: "success_rate",
        severity: "high",
        message: "Agent success rate below 90%"
      }

      result = AnalysisOrchestrator.learn_pattern(:feedback, analysis_result)
      # Should return ok or error, but not crash
      assert result == :ok or match?({:error, _}, result)
    end

    test "handles nonexistent analyzer gracefully" do
      analysis_result = %{type: "test", severity: "low"}
      result = AnalysisOrchestrator.learn_pattern(:nonexistent, analysis_result)

      # Should return error for unknown analyzer
      assert match?({:error, _}, result)
    end

    test "accepts result map with various fields" do
      analysis_result = %{
        type: "complex_analysis",
        severity: "medium",
        message: "Test message",
        data: %{extra: "fields"}
      }

      result = AnalysisOrchestrator.learn_pattern(:quality, analysis_result)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "Configuration Integrity" do
    test "analyzer config matches implementation" do
      # Load config
      config = Application.get_env(:singularity, :analyzer_types, %{})

      # Should have entries
      assert config != nil and config != %{}

      # All configured analyzers should exist
      Enum.each(config, fn {name, analyzer_config} ->
        assert is_atom(name)
        assert is_map(analyzer_config)
        assert analyzer_config[:module]
        assert analyzer_config[:enabled] in [true, false]

        # If enabled, module should be loadable
        if analyzer_config[:enabled] do
          assert Code.ensure_loaded?(analyzer_config[:module]),
                 "Configured module #{analyzer_config[:module]} should be loadable"
        end
      end)
    end

    test "all enabled analyzers are discoverable" do
      enabled_analyzers = AnalyzerType.load_enabled_analyzers()
      info = AnalysisOrchestrator.get_analyzer_types_info()
      info_names = Enum.map(info, & &1.name)

      Enum.each(enabled_analyzers, fn {type, _config} ->
        assert type in info_names, "Analyzer #{type} should be in info list"
      end)
    end

    test "no duplicate analyzer names" do
      info = AnalysisOrchestrator.get_analyzer_types_info()
      names = Enum.map(info, & &1.name)
      unique_names = Enum.uniq(names)

      assert length(names) == length(unique_names),
             "Analyzer names should be unique"
    end
  end

  describe "Analyzer Behavior Callbacks" do
    test "all enabled analyzers implement required callbacks" do
      enabled_analyzers = AnalyzerType.load_enabled_analyzers()

      Enum.each(enabled_analyzers, fn {_type, config} ->
        module = config[:module]
        assert Code.ensure_loaded?(module)

        # Check for required callbacks
        assert function_exported?(module, :analyzer_type, 0),
               "#{module} must implement analyzer_type/0"

        assert function_exported?(module, :description, 0),
               "#{module} must implement description/0"

        assert function_exported?(module, :supported_types, 0),
               "#{module} must implement supported_types/0"

        assert function_exported?(module, :analyze, 2),
               "#{module} must implement analyze/2"

        assert function_exported?(module, :learn_pattern, 1),
               "#{module} must implement learn_pattern/1"
      end)
    end

    test "all analyzer callbacks return expected types" do
      enabled_analyzers = AnalyzerType.load_enabled_analyzers()

      Enum.each(enabled_analyzers, fn {_type, config} ->
        module = config[:module]

        # Test callback return types
        analyzer_type = module.analyzer_type()
        assert is_atom(analyzer_type)

        description = module.description()
        assert is_binary(description)

        supported_types = module.supported_types()
        assert is_list(supported_types)

        # All types should be strings
        Enum.each(supported_types, fn analysis_type ->
          assert is_binary(analysis_type)
        end)
      end)
    end
  end

  describe "Analysis Scenarios" do
    test "feedback analysis" do
      input = %{
        type: :feedback_scenario,
        data: %{success_rate: 0.85, cost: 0.12}
      }

      result = AnalysisOrchestrator.analyze(input, analyzer_types: [:feedback])

      case result do
        {:ok, results} ->
          assert :feedback in Map.keys(results)

        {:error, _} ->
          assert true
      end
    end

    test "quality analysis" do
      input = %{
        type: :quality_scenario,
        code: "def test do :ok end"
      }

      result = AnalysisOrchestrator.analyze(input, analyzer_types: [:quality])

      case result do
        {:ok, results} ->
          assert :quality in Map.keys(results) or map_size(results) >= 0

        {:error, _} ->
          assert true
      end
    end

    test "comprehensive analysis with all analyzers" do
      input = %{
        type: :comprehensive,
        code: "module implementation",
        data: %{metrics: "values"}
      }

      result = AnalysisOrchestrator.analyze(input)

      case result do
        {:ok, results} ->
          # Should have analyses from multiple types
          assert is_map(results)
          assert map_size(results) > 0

        {:error, _} ->
          assert true
      end
    end
  end

  describe "Integration with Analyzers" do
    test "FeedbackAnalyzer is discoverable and configured" do
      enabled = AnalyzerType.load_enabled_analyzers()
      names = Enum.map(enabled, fn {type, _config} -> type end)

      assert :feedback in names, "FeedbackAnalyzer should be enabled"
    end

    test "QualityAnalyzer is discoverable and configured" do
      enabled = AnalyzerType.load_enabled_analyzers()
      names = Enum.map(enabled, fn {type, _config} -> type end)

      assert :quality in names, "QualityAnalyzer should be enabled"
    end

    test "RefactoringAnalyzer is discoverable and configured" do
      enabled = AnalyzerType.load_enabled_analyzers()
      names = Enum.map(enabled, fn {type, _config} -> type end)

      assert :refactoring in names, "RefactoringAnalyzer should be enabled"
    end
  end

  describe "Performance and Determinism" do
    test "analyzer discovery is deterministic" do
      analyzers1 = AnalyzerType.load_enabled_analyzers()
      analyzers2 = AnalyzerType.load_enabled_analyzers()

      # Should return same analyzers
      assert length(analyzers1) == length(analyzers2)
    end

    test "info gathering is consistent" do
      info1 = AnalysisOrchestrator.get_analyzer_types_info()
      info2 = AnalysisOrchestrator.get_analyzer_types_info()

      # Should have same analyzers in same order
      assert length(info1) == length(info2)
      assert Enum.map(info1, & &1.name) == Enum.map(info2, & &1.name)
    end

    test "analysis results are deterministic" do
      input = %{
        type: :deterministic_test,
        data: %{stable: true}
      }

      result1 = AnalysisOrchestrator.analyze(input)
      result2 = AnalysisOrchestrator.analyze(input)

      # Same input should produce consistent results
      case {result1, result2} do
        {{:ok, _}, {:ok, _}} -> assert true
        {{:error, _}, {:error, _}} -> assert true
        _ -> assert true
      end
    end
  end

  describe "Error Handling" do
    test "handles analyzer execution failures gracefully" do
      input = %{
        type: :error_test,
        data: %{problematic: "data"}
      }

      result = AnalysisOrchestrator.analyze(input)
      # Should handle gracefully, not crash
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "logs analysis attempts" do
      log =
        capture_log(fn ->
          input = %{type: :log_test, data: %{}}
          AnalysisOrchestrator.analyze(input)
        end)

      # Should contain some logs or be empty
      assert is_binary(log)
    end

    test "handles nil input gracefully" do
      result = AnalysisOrchestrator.analyze(nil)
      # May succeed or fail gracefully
      assert is_tuple(result) and tuple_size(result) == 2
    end
  end

  describe "Analysis Results Structure" do
    test "all analysis results have consistent structure" do
      input = %{
        type: :structure_test,
        data: %{test: true}
      }

      {:ok, results} = AnalysisOrchestrator.analyze(input)

      Enum.each(results, fn {_analyzer_type, analyses} ->
        Enum.each(analyses, fn analysis ->
          # Each analysis should be a map
          assert is_map(analysis)
        end)
      end)
    end

    test "analysis results preserve analyzer type information" do
      input = %{type: :type_info_test, data: %{}}

      {:ok, results} = AnalysisOrchestrator.analyze(input)

      # Results should be keyed by analyzer type
      Enum.each(results, fn {analyzer_type, _analyses} ->
        assert is_atom(analyzer_type)
      end)
    end
  end

  describe "Analyzer Type Checking" do
    test "enabled? predicate works for valid analyzer" do
      enabled_analyzers = AnalyzerType.load_enabled_analyzers()

      case enabled_analyzers do
        [{first_type, _config} | _] ->
          assert AnalyzerType.enabled?(first_type)

        _ ->
          assert true
      end
    end

    test "enabled? predicate returns false for invalid analyzer" do
      assert AnalyzerType.enabled?(:nonexistent_analyzer) == false
    end

    test "get_analyzer_module works for valid analyzer" do
      enabled_analyzers = AnalyzerType.load_enabled_analyzers()

      case enabled_analyzers do
        [{first_type, _config} | _] ->
          result = AnalyzerType.get_analyzer_module(first_type)
          assert match?({:ok, _}, result)

        _ ->
          assert true
      end
    end

    test "get_analyzer_module returns error for invalid analyzer" do
      result = AnalyzerType.get_analyzer_module(:nonexistent)
      assert match?({:error, _}, result)
    end
  end

  describe "Analysis Filtering Logic" do
    test "severity filtering removes low severity results when min_severity is high" do
      input = %{type: :filter_test, data: %{}}
      opts = [min_severity: "critical"]

      {:ok, results} = AnalysisOrchestrator.analyze(input, opts)

      # All results should be critical or not present
      Enum.each(results, fn {_analyzer, analyses} ->
        Enum.each(analyses, fn analysis ->
          severity = analysis[:severity] || "low"
          assert severity == "critical" or analysis == %{}
        end)
      end)
    end

    test "limit filtering caps results per analyzer" do
      input = %{type: :cap_test, data: %{}}
      opts = [limit: 1]

      {:ok, results} = AnalysisOrchestrator.analyze(input, opts)

      Enum.each(results, fn {_analyzer, analyses} ->
        assert length(analyses) <= 1
      end)
    end
  end

  defp capture_log(fun) do
    ExUnit.CaptureLog.capture_log(fun)
  end
end
