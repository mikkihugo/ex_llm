defmodule Singularity.Tools.Testing do
  @moduledoc """
  Testing Tools - Test execution and quality analysis for autonomous agents

  Provides comprehensive testing capabilities for agents to:
  - Run tests and analyze results
  - Generate test coverage reports
  - Find and create tests
  - Assess test quality and completeness
  - Monitor test performance

  Supports multiple test frameworks and languages.
  """

  alias Singularity.Tools.Catalog
  alias Singularity.Schemas.Tools.Tool

  def register(provider) do
    Catalog.add_tools(provider, [
      test_run_tool(),
      test_coverage_tool(),
      test_find_tool(),
      test_create_tool(),
      test_quality_tool(),
      test_performance_tool(),
      test_analyze_tool()
    ])
  end

  defp test_run_tool do
    Tool.new!(%{
      name: "test_run",
      description: "Run tests and analyze results",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Specific test file or directory path"
        },
        %{
          name: "pattern",
          type: :string,
          required: false,
          description: "Test pattern to match (e.g., 'test_*', '*_test.exs')"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language (elixir, javascript, python, etc.)"
        },
        %{
          name: "framework",
          type: :string,
          required: false,
          description: "Test framework (exunit, jest, pytest, etc.)"
        },
        %{
          name: "timeout",
          type: :integer,
          required: false,
          description: "Test timeout in seconds (default: 300)"
        },
        %{
          name: "verbose",
          type: :boolean,
          required: false,
          description: "Verbose output (default: false)"
        }
      ],
      function: &test_run/2
    })
  end

  defp test_coverage_tool do
    Tool.new!(%{
      name: "test_coverage",
      description: "Generate and analyze test coverage reports",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Specific file or directory to analyze"
        },
        %{
          name: "format",
          type: :string,
          required: false,
          description: "Coverage format: 'html', 'json', 'text' (default: 'text')"
        },
        %{
          name: "threshold",
          type: :number,
          required: false,
          description: "Minimum coverage threshold (0.0-1.0, default: 0.8)"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language (elixir, javascript, python, etc.)"
        }
      ],
      function: &test_coverage/2
    })
  end

  defp test_find_tool do
    Tool.new!(%{
      name: "test_find",
      description: "Find tests for specific modules, functions, or files",
      parameters: [
        %{
          name: "target",
          type: :string,
          required: true,
          description: "Module name, function name, or file path to find tests for"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language (elixir, javascript, python, etc.)"
        },
        %{
          name: "type",
          type: :string,
          required: false,
          description: "Test type: 'unit', 'integration', 'e2e', 'all' (default: 'all')"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of tests to return (default: 20)"
        }
      ],
      function: &test_find/2
    })
  end

  defp test_create_tool do
    Tool.new!(%{
      name: "test_create",
      description: "Generate test skeleton or boilerplate code",
      parameters: [
        %{
          name: "target",
          type: :string,
          required: true,
          description: "Module, function, or file to create tests for"
        },
        %{
          name: "language",
          type: :string,
          required: true,
          description: "Programming language (elixir, javascript, python, etc.)"
        },
        %{
          name: "type",
          type: :string,
          required: false,
          description: "Test type: 'unit', 'integration', 'e2e' (default: 'unit')"
        },
        %{
          name: "framework",
          type: :string,
          required: false,
          description: "Test framework (exunit, jest, pytest, etc.)"
        },
        %{
          name: "template",
          type: :string,
          required: false,
          description: "Test template to use (basic, comprehensive, minimal)"
        }
      ],
      function: &test_create/2
    })
  end

  defp test_quality_tool do
    Tool.new!(%{
      name: "test_quality",
      description: "Assess test quality, completeness, and best practices",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Test file or directory to analyze"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language (elixir, javascript, python, etc.)"
        },
        %{
          name: "checks",
          type: :array,
          required: false,
          description: "Specific quality checks to run (coverage, assertions, mocks, etc.)"
        },
        %{
          name: "strict",
          type: :boolean,
          required: false,
          description: "Use strict quality standards (default: false)"
        }
      ],
      function: &test_quality/2
    })
  end

  defp test_performance_tool do
    Tool.new!(%{
      name: "test_performance",
      description: "Analyze test performance and identify slow tests",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Test file or directory to analyze"
        },
        %{
          name: "threshold",
          type: :number,
          required: false,
          description: "Slow test threshold in seconds (default: 1.0)"
        },
        %{
          name: "format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'text', 'table' (default: 'text')"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language (elixir, javascript, python, etc.)"
        }
      ],
      function: &test_performance/2
    })
  end

  defp test_analyze_tool do
    Tool.new!(%{
      name: "test_analyze",
      description: "Comprehensive test analysis including coverage, quality, and performance",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Test file or directory to analyze"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language (elixir, javascript, python, etc.)"
        },
        %{
          name: "include_coverage",
          type: :boolean,
          required: false,
          description: "Include coverage analysis (default: true)"
        },
        %{
          name: "include_quality",
          type: :boolean,
          required: false,
          description: "Include quality analysis (default: true)"
        },
        %{
          name: "include_performance",
          type: :boolean,
          required: false,
          description: "Include performance analysis (default: true)"
        }
      ],
      function: &test_analyze/2
    })
  end

  # Implementation functions

  def test_run(
        %{
          "path" => path,
          "pattern" => pattern,
          "language" => language,
          "framework" => framework,
          "timeout" => timeout,
          "verbose" => verbose
        },
        _ctx
      ) do
    test_run_impl(path, pattern, language, framework, timeout, verbose)
  end

  def test_run(
        %{
          "path" => path,
          "pattern" => pattern,
          "language" => language,
          "framework" => framework,
          "timeout" => timeout
        },
        _ctx
      ) do
    test_run_impl(path, pattern, language, framework, timeout, false)
  end

  def test_run(
        %{"path" => path, "pattern" => pattern, "language" => language, "framework" => framework},
        _ctx
      ) do
    test_run_impl(path, pattern, language, framework, 300, false)
  end

  def test_run(%{"path" => path, "pattern" => pattern, "language" => language}, _ctx) do
    test_run_impl(path, pattern, language, nil, 300, false)
  end

  def test_run(%{"path" => path, "pattern" => pattern}, _ctx) do
    test_run_impl(path, pattern, nil, nil, 300, false)
  end

  def test_run(%{"path" => path}, _ctx) do
    test_run_impl(path, nil, nil, nil, 300, false)
  end

  def test_run(%{}, _ctx) do
    test_run_impl(nil, nil, nil, nil, 300, false)
  end

  defp test_run_impl(path, pattern, language, framework, timeout, verbose) do
    try do
      # Detect language and framework if not specified
      detected_language = language || detect_language(path)
      detected_framework = framework || detect_framework(detected_language)

      # Build test command
      cmd = build_test_command(detected_language, detected_framework, path, pattern, verbose)

      # Execute test command with timeout
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      # Parse test results
      results = parse_test_results(output, detected_language, detected_framework)

      {:ok,
       %{
         path: path,
         pattern: pattern,
         language: detected_language,
         framework: detected_framework,
         timeout: timeout,
         verbose: verbose,
         command: cmd,
         exit_code: exit_code,
         output: output,
         results: results,
         success: exit_code == 0,
         duration: results.duration || 0
       }}
    rescue
      error -> {:error, "Test run error: #{inspect(error)}"}
    end
  end

  def test_coverage(
        %{"path" => path, "format" => format, "threshold" => threshold, "language" => language},
        _ctx
      ) do
    test_coverage_impl(path, format, threshold, language)
  end

  def test_coverage(%{"path" => path, "format" => format, "threshold" => threshold}, _ctx) do
    test_coverage_impl(path, format, threshold, nil)
  end

  def test_coverage(%{"path" => path, "format" => format}, _ctx) do
    test_coverage_impl(path, format, 0.8, nil)
  end

  def test_coverage(%{"path" => path}, _ctx) do
    test_coverage_impl(path, "text", 0.8, nil)
  end

  def test_coverage(%{}, _ctx) do
    test_coverage_impl(nil, "text", 0.8, nil)
  end

  defp test_coverage_impl(path, format, threshold, language) do
    try do
      detected_language = language || detect_language(path)

      # Build coverage command
      cmd = build_coverage_command(detected_language, format, path)

      # Execute coverage command
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      # Parse coverage results
      coverage_data = parse_coverage_results(output, detected_language, format)

      # Check if coverage meets threshold
      meets_threshold = coverage_data.overall_coverage >= threshold

      {:ok,
       %{
         path: path,
         format: format,
         threshold: threshold,
         language: detected_language,
         command: cmd,
         exit_code: exit_code,
         output: output,
         coverage: coverage_data,
         meets_threshold: meets_threshold,
         success: exit_code == 0
       }}
    rescue
      error -> {:error, "Test coverage error: #{inspect(error)}"}
    end
  end

  def test_find(
        %{"target" => target, "language" => language, "type" => type, "limit" => limit},
        _ctx
      ) do
    test_find_impl(target, language, type, limit)
  end

  def test_find(%{"target" => target, "language" => language, "type" => type}, _ctx) do
    test_find_impl(target, language, type, 20)
  end

  def test_find(%{"target" => target, "language" => language}, _ctx) do
    test_find_impl(target, language, "all", 20)
  end

  def test_find(%{"target" => target}, _ctx) do
    test_find_impl(target, nil, "all", 20)
  end

  defp test_find_impl(target, language, type, limit) do
    try do
      detected_language = language || detect_language_from_target(target)

      # Find test files
      test_files = find_test_files(target, detected_language, type)

      # Limit results
      limited_files = Enum.take(test_files, limit)

      # Analyze each test file
      test_analysis =
        Enum.map(limited_files, fn file ->
          analyze_test_file(file, detected_language)
        end)

      {:ok,
       %{
         target: target,
         language: detected_language,
         type: type,
         limit: limit,
         test_files: limited_files,
         test_analysis: test_analysis,
         total_found: length(test_files),
         total_analyzed: length(limited_files)
       }}
    rescue
      error -> {:error, "Test find error: #{inspect(error)}"}
    end
  end

  def test_create(
        %{
          "target" => target,
          "language" => language,
          "type" => type,
          "framework" => framework,
          "template" => template
        },
        _ctx
      ) do
    test_create_impl(target, language, type, framework, template)
  end

  def test_create(
        %{"target" => target, "language" => language, "type" => type, "framework" => framework},
        _ctx
      ) do
    test_create_impl(target, language, type, framework, "basic")
  end

  def test_create(%{"target" => target, "language" => language, "type" => type}, _ctx) do
    test_create_impl(target, language, type, nil, "basic")
  end

  def test_create(%{"target" => target, "language" => language}, _ctx) do
    test_create_impl(target, language, "unit", nil, "basic")
  end

  defp test_create_impl(target, language, type, framework, template) do
    try do
      detected_framework = framework || detect_framework(language)

      # Generate test code
      test_code = generate_test_code(target, language, type, detected_framework, template)

      # Determine output file path
      output_path = determine_test_file_path(target, language, type)

      {:ok,
       %{
         target: target,
         language: language,
         type: type,
         framework: detected_framework,
         template: template,
         test_code: test_code,
         output_path: output_path,
         success: true
       }}
    rescue
      error -> {:error, "Test create error: #{inspect(error)}"}
    end
  end

  def test_quality(
        %{"path" => path, "language" => language, "checks" => checks, "strict" => strict},
        _ctx
      ) do
    test_quality_impl(path, language, checks, strict)
  end

  def test_quality(%{"path" => path, "language" => language, "checks" => checks}, _ctx) do
    test_quality_impl(path, language, checks, false)
  end

  def test_quality(%{"path" => path, "language" => language}, _ctx) do
    test_quality_impl(path, language, nil, false)
  end

  def test_quality(%{"path" => path}, _ctx) do
    test_quality_impl(path, nil, nil, false)
  end

  def test_quality(%{}, _ctx) do
    test_quality_impl(nil, nil, nil, false)
  end

  defp test_quality_impl(path, language, checks, strict) do
    try do
      detected_language = language || detect_language(path)
      default_checks = ["coverage", "assertions", "mocks", "naming", "structure"]
      checks_to_run = checks || default_checks

      # Run quality checks
      quality_results = run_quality_checks(path, detected_language, checks_to_run, strict)

      # Calculate overall quality score
      overall_score = calculate_quality_score(quality_results)

      {:ok,
       %{
         path: path,
         language: detected_language,
         checks: checks_to_run,
         strict: strict,
         results: quality_results,
         overall_score: overall_score,
         quality_level: determine_quality_level(overall_score),
         recommendations: generate_quality_recommendations(quality_results)
       }}
    rescue
      error -> {:error, "Test quality error: #{inspect(error)}"}
    end
  end

  def test_performance(
        %{"path" => path, "threshold" => threshold, "format" => format, "language" => language},
        _ctx
      ) do
    test_performance_impl(path, threshold, format, language)
  end

  def test_performance(%{"path" => path, "threshold" => threshold, "format" => format}, _ctx) do
    test_performance_impl(path, threshold, format, nil)
  end

  def test_performance(%{"path" => path, "threshold" => threshold}, _ctx) do
    test_performance_impl(path, threshold, "text", nil)
  end

  def test_performance(%{"path" => path}, _ctx) do
    test_performance_impl(path, 1.0, "text", nil)
  end

  def test_performance(%{}, _ctx) do
    test_performance_impl(nil, 1.0, "text", nil)
  end

  defp test_performance_impl(path, threshold, format, language) do
    try do
      detected_language = language || detect_language(path)

      # Run tests with timing
      {output, exit_code} = run_tests_with_timing(path, detected_language)

      # Parse performance data
      performance_data = parse_performance_results(output, detected_language, threshold)

      {:ok,
       %{
         path: path,
         threshold: threshold,
         format: format,
         language: detected_language,
         output: output,
         exit_code: exit_code,
         performance: performance_data,
         slow_tests: performance_data.slow_tests || [],
         total_duration: performance_data.total_duration || 0,
         success: exit_code == 0
       }}
    rescue
      error -> {:error, "Test performance error: #{inspect(error)}"}
    end
  end

  def test_analyze(
        %{
          "path" => path,
          "language" => language,
          "include_coverage" => include_coverage,
          "include_quality" => include_quality,
          "include_performance" => include_performance
        },
        _ctx
      ) do
    test_analyze_impl(path, language, include_coverage, include_quality, include_performance)
  end

  def test_analyze(
        %{
          "path" => path,
          "language" => language,
          "include_coverage" => include_coverage,
          "include_quality" => include_quality
        },
        _ctx
      ) do
    test_analyze_impl(path, language, include_coverage, include_quality, true)
  end

  def test_analyze(
        %{"path" => path, "language" => language, "include_coverage" => include_coverage},
        _ctx
      ) do
    test_analyze_impl(path, language, include_coverage, true, true)
  end

  def test_analyze(%{"path" => path, "language" => language}, _ctx) do
    test_analyze_impl(path, language, true, true, true)
  end

  def test_analyze(%{"path" => path}, _ctx) do
    test_analyze_impl(path, nil, true, true, true)
  end

  def test_analyze(%{}, _ctx) do
    test_analyze_impl(nil, nil, true, true, true)
  end

  defp test_analyze_impl(path, language, include_coverage, include_quality, include_performance) do
    try do
      detected_language = language || detect_language(path)

      analysis = %{}

      # Run coverage analysis if requested
      analysis =
        if include_coverage do
          case test_coverage_impl(path, "text", 0.8, detected_language) do
            {:ok, coverage_result} -> Map.put(analysis, :coverage, coverage_result)
            _ -> Map.put(analysis, :coverage, %{error: "Coverage analysis failed"})
          end
        else
          analysis
        end

      # Run quality analysis if requested
      analysis =
        if include_quality do
          case test_quality_impl(path, detected_language, nil, false) do
            {:ok, quality_result} -> Map.put(analysis, :quality, quality_result)
            _ -> Map.put(analysis, :quality, %{error: "Quality analysis failed"})
          end
        else
          analysis
        end

      # Run performance analysis if requested
      analysis =
        if include_performance do
          case test_performance_impl(path, 1.0, "text", detected_language) do
            {:ok, performance_result} -> Map.put(analysis, :performance, performance_result)
            _ -> Map.put(analysis, :performance, %{error: "Performance analysis failed"})
          end
        else
          analysis
        end

      # Generate overall assessment
      overall_assessment = generate_overall_assessment(analysis)

      {:ok,
       %{
         path: path,
         language: detected_language,
         include_coverage: include_coverage,
         include_quality: include_quality,
         include_performance: include_performance,
         analysis: analysis,
         overall_assessment: overall_assessment,
         generated_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "Test analyze error: #{inspect(error)}"}
    end
  end

  # Helper functions

  defp detect_language(path) do
    cond do
      String.ends_with?(path || "", ".ex") or String.ends_with?(path || "", ".exs") -> "elixir"
      String.ends_with?(path || "", ".js") or String.ends_with?(path || "", ".ts") -> "javascript"
      String.ends_with?(path || "", ".py") -> "python"
      String.ends_with?(path || "", ".rb") -> "ruby"
      String.ends_with?(path || "", ".go") -> "go"
      String.ends_with?(path || "", ".rs") -> "rust"
      String.ends_with?(path || "", ".java") -> "java"
      # Default to Elixir for this project
      true -> "elixir"
    end
  end

  defp detect_language_from_target(target) do
    # Try to detect language from target string
    cond do
      String.contains?(target, ".ex") or String.contains?(target, "Elixir") -> "elixir"
      String.contains?(target, ".js") or String.contains?(target, "JavaScript") -> "javascript"
      String.contains?(target, ".py") or String.contains?(target, "Python") -> "python"
      String.contains?(target, ".rb") or String.contains?(target, "Ruby") -> "ruby"
      String.contains?(target, ".go") or String.contains?(target, "Go") -> "go"
      String.contains?(target, ".rs") or String.contains?(target, "Rust") -> "rust"
      String.contains?(target, ".java") or String.contains?(target, "Java") -> "java"
      # Default to Elixir for this project
      true -> "elixir"
    end
  end

  defp detect_framework(language) do
    case language do
      "elixir" -> "exunit"
      "javascript" -> "jest"
      "python" -> "pytest"
      "ruby" -> "rspec"
      "go" -> "testing"
      "rust" -> "cargo test"
      "java" -> "junit"
      _ -> "exunit"
    end
  end

  defp build_test_command(language, framework, path, pattern, verbose) do
    # Detect framework using Architecture Engine
    detected_framework = detect_testing_framework(language, path)
    effective_framework = framework || detected_framework

    case language do
      "elixir" ->
        cmd = "mix test"
        cmd = if path, do: "#{cmd} #{path}", else: cmd
        cmd = if pattern, do: "#{cmd} --pattern #{pattern}", else: cmd
        cmd = if verbose, do: "#{cmd} --trace", else: cmd
        # Add framework-specific test options based on detected framework
        cmd = add_framework_test_options(cmd, effective_framework, language)
        cmd

      "javascript" ->
        cmd = "npm test"
        cmd = if path, do: "#{cmd} #{path}", else: cmd
        cmd = if pattern, do: "#{cmd} --testNamePattern=#{pattern}", else: cmd
        cmd = if verbose, do: "#{cmd} --verbose", else: cmd
        cmd

      "python" ->
        cmd = "python -m pytest"
        cmd = if path, do: "#{cmd} #{path}", else: cmd
        cmd = if pattern, do: "#{cmd} -k #{pattern}", else: cmd
        cmd = if verbose, do: "#{cmd} -v", else: cmd
        cmd

      _ ->
        "echo 'Unsupported language: #{language}'"
    end
  end

  defp build_coverage_command(language, format, path) do
    # Detect framework using Architecture Engine
    detected_framework = detect_testing_framework(language, path)

    case language do
      "elixir" ->
        cmd = "mix test --cover"
        cmd = if path, do: "#{cmd} #{path}", else: cmd
        # Add format-specific coverage options
        cmd = add_coverage_format_options(cmd, format, language)
        # Add framework-specific coverage options
        cmd = add_framework_coverage_options(cmd, detected_framework, language)
        cmd

      "javascript" ->
        cmd = "npm test -- --coverage"
        cmd = if path, do: "#{cmd} #{path}", else: cmd
        cmd

      "python" ->
        cmd = "python -m pytest --cov"
        cmd = if path, do: "#{cmd} #{path}", else: cmd
        cmd

      _ ->
        "echo 'Coverage not supported for language: #{language}'"
    end
  end

  defp parse_test_results(output, language, framework) do
    case language do
      "elixir" ->
        parse_exunit_results(output, framework)

      "javascript" ->
        parse_jest_results(output, framework)

      "python" ->
        parse_pytest_results(output)

      _ ->
        %{total: 0, passed: 0, failed: 0, skipped: 0, duration: 0}
    end
  end

  defp parse_exunit_results(output) do
    # Parse ExUnit output
    total_match = Regex.run(~r/(\d+) tests?/, output)
    failed_match = Regex.run(~r/(\d+) failures?/, output)
    duration_match = Regex.run(~r/(\d+\.?\d*)s/, output)

    total = if total_match, do: String.to_integer(Enum.at(total_match, 1)), else: 0
    failed = if failed_match, do: String.to_integer(Enum.at(failed_match, 1)), else: 0
    duration = if duration_match, do: String.to_float(Enum.at(duration_match, 1)), else: 0

    %{
      total: total,
      passed: total - failed,
      failed: failed,
      skipped: 0,
      duration: duration
    }
  end

  defp parse_jest_results(output) do
    # Parse Jest output
    total_match = Regex.run(~r/Tests:\s+(\d+)\s+failed,\s+(\d+)\s+total/, output)
    duration_match = Regex.run(~r/Time:\s+(\d+\.?\d*)s/, output)

    if total_match do
      failed = String.to_integer(Enum.at(total_match, 1))
      total = String.to_integer(Enum.at(total_match, 2))
      duration = if duration_match, do: String.to_float(Enum.at(duration_match, 1)), else: 0

      %{
        total: total,
        passed: total - failed,
        failed: failed,
        skipped: 0,
        duration: duration
      }
    else
      %{total: 0, passed: 0, failed: 0, skipped: 0, duration: 0}
    end
  end

  defp parse_pytest_results(output) do
    # Parse pytest output
    total_match = Regex.run(~r/(\d+) failed, (\d+) passed/, output)
    duration_match = Regex.run(~r/in ([\d.]+)s/, output)

    if total_match do
      failed = String.to_integer(Enum.at(total_match, 1))
      passed = String.to_integer(Enum.at(total_match, 2))
      total = passed + failed
      duration = if duration_match, do: String.to_float(Enum.at(duration_match, 1)), else: 0

      %{
        total: total,
        passed: passed,
        failed: failed,
        skipped: 0,
        duration: duration
      }
    else
      %{total: 0, passed: 0, failed: 0, skipped: 0, duration: 0}
    end
  end

  defp parse_coverage_results(output, language, _format) do
    case language do
      "elixir" ->
        parse_exunit_coverage(output)

      "javascript" ->
        parse_jest_coverage(output)

      "python" ->
        parse_pytest_coverage(output)

      _ ->
        %{overall_coverage: 0.0, line_coverage: 0.0, branch_coverage: 0.0}
    end
  end

  defp parse_exunit_coverage(output) do
    # Parse ExUnit coverage output
    coverage_match = Regex.run(~r/Coverage: ([\d.]+)%/, output)

    overall_coverage =
      if coverage_match do
        String.to_float(Enum.at(coverage_match, 1)) / 100
      else
        0.0
      end

    %{
      overall_coverage: overall_coverage,
      line_coverage: overall_coverage,
      branch_coverage: overall_coverage
    }
  end

  defp parse_jest_coverage(output) do
    # Parse Jest coverage output
    coverage_match = Regex.run(~r/All files\s+\|\s+([\d.]+)/, output)

    overall_coverage =
      if coverage_match do
        String.to_float(Enum.at(coverage_match, 1)) / 100
      else
        0.0
      end

    %{
      overall_coverage: overall_coverage,
      line_coverage: overall_coverage,
      branch_coverage: overall_coverage
    }
  end

  defp parse_pytest_coverage(output) do
    # Parse pytest coverage output
    coverage_match = Regex.run(~r/TOTAL\s+(\d+)\s+(\d+)\s+([\d.]+)%/, output)

    overall_coverage =
      if coverage_match do
        String.to_float(Enum.at(coverage_match, 3)) / 100
      else
        0.0
      end

    %{
      overall_coverage: overall_coverage,
      line_coverage: overall_coverage,
      branch_coverage: overall_coverage
    }
  end

  defp find_test_files(target, language, type) do
    # Find test files based on target and language
    test_patterns =
      case language do
        "elixir" -> ["test/**/*_test.exs", "test/**/*_test.ex"]
        "javascript" -> ["**/*.test.js", "**/*.spec.js", "**/__tests__/**/*.js"]
        "python" -> ["**/*_test.py", "**/test_*.py", "**/tests/**/*.py"]
        _ -> ["**/*test*", "**/test/**"]
      end

    # Use target to filter patterns more specifically
    target_patterns =
      if target do
        # Add target-specific patterns
        case language do
          "elixir" ->
            ["test/**/#{target}_test.exs", "test/**/#{target}_test.ex"] ++ test_patterns

          "javascript" ->
            ["**/#{target}.test.js", "**/#{target}.spec.js"] ++ test_patterns

          "python" ->
            ["**/test_#{target}.py", "**/#{target}_test.py"] ++ test_patterns

          _ ->
            ["**/*#{target}*test*", "**/test/**/*#{target}*"] ++ test_patterns
        end
      else
        test_patterns
      end

    # Filter by type if specified
    filtered_patterns =
      case type do
        "unit" ->
          Enum.filter(
            target_patterns,
            &(String.contains?(&1, "unit") or String.contains?(&1, "_test"))
          )

        "integration" ->
          Enum.filter(target_patterns, &String.contains?(&1, "integration"))

        "e2e" ->
          Enum.filter(
            target_patterns,
            &(String.contains?(&1, "e2e") or String.contains?(&1, "end_to_end"))
          )

        _ ->
          target_patterns
      end

    # Find files matching patterns
    Enum.flat_map(filtered_patterns, fn pattern ->
      case System.cmd("find", [".", "-name", pattern, "-type", "f"], stderr_to_stdout: true) do
        {files, 0} -> String.split(files, "\n") |> Enum.reject(&(&1 == ""))
        _ -> []
      end
    end)
  end

  defp analyze_test_file(file, language) do
    # Analyze a test file for quality metrics
    case File.read(file) do
      {:ok, content} ->
        %{
          file: file,
          language: language,
          lines: String.split(content, "\n") |> length(),
          test_count: count_tests(content, language),
          has_setup: String.contains?(content, "setup") or String.contains?(content, "before"),
          has_teardown:
            String.contains?(content, "teardown") or String.contains?(content, "after"),
          has_mocks: String.contains?(content, "mock") or String.contains?(content, "stub"),
          has_assertions: count_assertions(content, language)
        }

      {:error, _} ->
        %{file: file, error: "Could not read file"}
    end
  end

  defp count_tests(content, language) do
    case language do
      "elixir" ->
        Regex.scan(~r/test\s+["']/, content) |> length()

      "javascript" ->
        Regex.scan(~r/(it|test|describe)\s*\(/, content) |> length()

      "python" ->
        Regex.scan(~r/def test_/, content) |> length()

      _ ->
        0
    end
  end

  defp count_assertions(content, language) do
    case language do
      "elixir" ->
        Regex.scan(~r/assert/, content) |> length()

      "javascript" ->
        Regex.scan(~r/expect/, content) |> length()

      "python" ->
        Regex.scan(~r/assert/, content) |> length()

      _ ->
        0
    end
  end

  defp generate_test_code(target, language, type, framework, template) do
    case language do
      "elixir" ->
        generate_elixir_test(target, type, template)

      "javascript" ->
        generate_javascript_test(target, type, framework, template)

      "python" ->
        generate_python_test(target, type, template)

      _ ->
        "// Test code generation not supported for #{language}"
    end
  end

  defp generate_elixir_test(target, type, template) do
    module_name = extract_module_name(target)

    # Generate test code based on type
    test_setup =
      case type do
        "unit" ->
          """
          setup do
            # Unit test setup - minimal dependencies
            :ok
          end
          """

        "integration" ->
          """
          setup do
            # Integration test setup - database, external services
            Ecto.Adapters.SQL.Sandbox.checkout(Singularity.Repo)
            :ok
          end
          """

        "e2e" ->
          """
          setup do
            # End-to-end test setup - full application stack
            :ok
          end
          """

        _ ->
          """
          setup do
            # Default test setup
            :ok
          end
          """
      end

    case template do
      "comprehensive" ->
        """
        defmodule #{module_name}Test do
          use ExUnit.Case, async: #{type != "integration"}
          alias #{module_name}

          describe "#{module_name}" do
            #{test_setup}

            test "should work correctly" do
              # Test implementation
              assert true
            end

            test "should handle edge cases" do
              # Edge case testing
              assert true
            end
          end
        end
        """

      "minimal" ->
        """
        defmodule #{module_name}Test do
          use ExUnit.Case

          test "#{module_name} works" do
            assert true
          end
        end
        """

      _ ->
        """
        defmodule #{module_name}Test do
          use ExUnit.Case

          test "should work" do
            # Test implementation
            assert true
          end
        end
        """
    end
  end

  defp generate_javascript_test(target, type, framework, template) do
    # Generate test code based on type and template
    test_imports =
      case {framework, type} do
        {"jest", "unit"} ->
          "import { render, screen } from '@testing-library/react';\nimport '@testing-library/jest-dom';"

        {"jest", "integration"} ->
          "import { render, screen, waitFor } from '@testing-library/react';\nimport '@testing-library/jest-dom';\nimport { server } from './mocks/server';"

        {"jest", "e2e"} ->
          "import { render, screen, waitFor } from '@testing-library/react';\nimport '@testing-library/jest-dom';\nimport { setupServer } from 'msw/node';"

        {"mocha", _} ->
          "import { expect } from 'chai';\nimport { describe, it, beforeEach, afterEach } from 'mocha';"

        _ ->
          ""
      end

    test_setup =
      case type do
        "unit" ->
          """
          beforeEach(() => {
            // Unit test setup
          });
          """

        "integration" ->
          """
          beforeEach(() => {
            // Integration test setup
            server.listen();
          });

          afterEach(() => {
            server.resetHandlers();
          });
          """

        "e2e" ->
          """
          beforeAll(() => {
            // E2E test setup
          });
          """

        _ ->
          ""
      end

    # Generate test code based on template
    test_content =
      case template do
        "comprehensive" ->
          """
          describe('#{target}', () => {
            #{test_setup}
            
            test('should work correctly', () => {
              expect(true).toBe(true);
            });
            
            test('should handle edge cases', () => {
              expect(true).toBe(true);
            });
          });
          """

        "minimal" ->
          """
          describe('#{target}', () => {
            test('should work', () => {
              expect(true).toBe(true);
            });
          });
          """

        _ ->
          """
          describe('#{target}', () => {
            #{test_setup}
            
            test('should work correctly', () => {
              expect(true).toBe(true);
            });
          });
          """
      end

    case framework do
      "jest" ->
        """
        #{test_imports}

        #{test_content}
        """

      _ ->
        """
        // Test for #{target}
        test('should work', () => {
          expect(true).toBe(true);
        });
        """
    end
  end

  defp generate_python_test(target, type, template) do
    # Generate Python test code based on type and template
    test_imports =
      case type do
        "unit" ->
          "import unittest\nfrom unittest.mock import Mock, patch"

        "integration" ->
          "import unittest\nimport requests\nfrom unittest.mock import patch"

        "e2e" ->
          "import unittest\nimport requests\nimport time\nfrom selenium import webdriver"

        _ ->
          "import unittest"
      end

    test_setup =
      case type do
        "unit" ->
          """
          def setUp(self):
              # Unit test setup
              pass
          """

        "integration" ->
          """
          def setUp(self):
              # Integration test setup
              self.base_url = "http://localhost:8000"
          """

        "e2e" ->
          """
          def setUp(self):
              # E2E test setup
              self.driver = webdriver.Chrome()
              self.driver.implicitly_wait(10)
          """

        _ ->
          """
          def setUp(self):
              # Default test setup
              pass
          """
      end

    # Generate test code based on template
    test_methods =
      case template do
        "comprehensive" ->
          """
          def test_should_work(self):
              self.assertTrue(True)
              
          def test_should_handle_edge_cases(self):
              self.assertTrue(True)
              
          def test_should_validate_input(self):
              self.assertTrue(True)
          """

        "minimal" ->
          """
          def test_should_work(self):
              self.assertTrue(True)
          """

        _ ->
          """
          def test_should_work(self):
              self.assertTrue(True)
          """
      end

    """
    #{test_imports}

    class Test#{String.capitalize(target)}:
        #{test_setup}
        
        #{test_methods}
    """
  end

  defp extract_module_name(target) do
    # Extract module name from target string
    target
    |> String.split(".")
    |> List.first()
    |> String.split("/")
    |> List.last()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
  end

  defp determine_test_file_path(target, language, type) do
    # Generate test file path based on language and type
    base_path =
      case language do
        "elixir" ->
          "test/#{String.downcase(target)}_test.exs"

        "javascript" ->
          "#{target}.test.js"

        "python" ->
          "test_#{String.downcase(target)}.py"

        _ ->
          "#{target}_test"
      end

    # Add type-specific path modifications
    case type do
      "unit" ->
        case language do
          "elixir" -> "test/unit/#{String.downcase(target)}_test.exs"
          "javascript" -> "tests/unit/#{target}.test.js"
          "python" -> "tests/unit/test_#{String.downcase(target)}.py"
          _ -> "tests/unit/#{target}_test"
        end

      "integration" ->
        case language do
          "elixir" -> "test/integration/#{String.downcase(target)}_test.exs"
          "javascript" -> "tests/integration/#{target}.test.js"
          "python" -> "tests/integration/test_#{String.downcase(target)}.py"
          _ -> "tests/integration/#{target}_test"
        end

      "e2e" ->
        case language do
          "elixir" -> "test/e2e/#{String.downcase(target)}_test.exs"
          "javascript" -> "tests/e2e/#{target}.test.js"
          "python" -> "tests/e2e/test_#{String.downcase(target)}.py"
          _ -> "tests/e2e/#{target}_test"
        end

      _ ->
        base_path
    end
  end

  defp run_quality_checks(path, language, checks, strict) do
    # Run various quality checks
    Enum.map(checks, fn check ->
      case check do
        "coverage" -> check_coverage_quality(path, language, strict)
        "assertions" -> check_assertions_quality(path, language, strict)
        "mocks" -> check_mocks_quality(path, language, strict)
        "naming" -> check_naming_quality(path, language, strict)
        "structure" -> check_structure_quality(path, language, strict)
        _ -> %{check: check, score: 0.5, message: "Check not implemented"}
      end
    end)
  end

  defp check_coverage_quality(path, language, strict) do
    # Check test coverage quality
    threshold = if strict, do: 0.9, else: 0.8

    case test_coverage_impl(path, "text", threshold, language) do
      {:ok, result} ->
        score = if result.meets_threshold, do: 1.0, else: result.coverage.overall_coverage

        %{
          check: "coverage",
          score: score,
          message: "Coverage: #{result.coverage.overall_coverage * 100}%"
        }

      _ ->
        %{check: "coverage", score: 0.0, message: "Could not determine coverage"}
    end
  end

  defp check_assertions_quality(path, language, strict) do
    # Check assertion quality
    case File.read(path || "test/") do
      {:ok, content} ->
        assertion_count = count_assertions(content, language)
        test_count = count_tests(content, language)

        ratio = if test_count > 0, do: assertion_count / test_count, else: 0
        score = if strict and ratio >= 2.0, do: 1.0, else: min(ratio / 2.0, 1.0)

        %{check: "assertions", score: score, message: "Assertions per test: #{ratio}"}

      _ ->
        %{check: "assertions", score: 0.0, message: "Could not read test files"}
    end
  end

  defp check_mocks_quality(path, language, strict) do
    # Check mock usage quality based on language and strictness
    case File.read(path || "test/") do
      {:ok, content} ->
        # Language-specific mock detection
        mock_patterns =
          case language do
            "elixir" -> ["Mock", "stub", "with_mock", "expect"]
            "javascript" -> ["jest.mock", "mock", "stub", "spy", "mockImplementation"]
            "python" -> ["mock", "patch", "MagicMock", "Mock"]
            _ -> ["mock", "stub"]
          end

        # Check for mock usage
        has_mocks = Enum.any?(mock_patterns, &String.contains?(content, &1))

        # Calculate score based on strictness and language
        base_score = if has_mocks, do: 1.0, else: 0.5

        # Adjust score based on strictness
        adjusted_score =
          case strict do
            true ->
              # Strict mode: require proper mock patterns
              if has_mocks and String.contains?(content, "verify") do
                base_score
              else
                base_score * 0.8
              end

            false ->
              base_score

            _ ->
              base_score
          end

        # Language-specific recommendations
        recommendation =
          case {language, has_mocks} do
            {"elixir", false} -> "Consider using Mox for mocking external dependencies"
            {"javascript", false} -> "Consider using Jest mocks for better test isolation"
            {"python", false} -> "Consider using unittest.mock for better test control"
            {_, true} -> "Good mock usage detected"
            _ -> "Mock usage could be improved"
          end

        %{
          check: "mocks",
          score: adjusted_score,
          message: if(has_mocks, do: "Uses mocks/stubs", else: "No mocks detected"),
          recommendation: recommendation,
          language: language,
          strict_mode: strict
        }

      _ ->
        %{check: "mocks", score: 0.0, message: "Could not read test files"}
    end
  end

  defp check_naming_quality(path, language, strict) do
    # Check test naming quality
    case File.read(path || "test/") do
      {:ok, content} ->
        # Simple heuristic for good test naming
        good_names =
          Regex.scan(~r/test\s+["'](should|when|given|it should)/i, content) |> length()

        total_tests = count_tests(content, language)

        ratio = if total_tests > 0, do: good_names / total_tests, else: 0
        score = if strict and ratio >= 0.8, do: 1.0, else: ratio

        %{check: "naming", score: score, message: "Good naming ratio: #{ratio}"}

      _ ->
        %{check: "naming", score: 0.0, message: "Could not read test files"}
    end
  end

  defp check_structure_quality(path, language, strict) do
    # Check test structure quality
    case File.read(path || "test/") do
      {:ok, content} ->
        has_setup = String.contains?(content, "setup") or String.contains?(content, "before")
        has_teardown = String.contains?(content, "teardown") or String.contains?(content, "after")

        has_describe =
          String.contains?(content, "describe") or String.contains?(content, "context")

        structure_score =
          [has_setup, has_teardown, has_describe] |> Enum.count(& &1) |> Kernel./(3)

        score = if strict and structure_score >= 0.8, do: 1.0, else: structure_score

        %{check: "structure", score: score, message: "Structure completeness: #{structure_score}"}

      _ ->
        %{check: "structure", score: 0.0, message: "Could not read test files"}
    end
  end

  defp calculate_quality_score(quality_results) do
    scores = Enum.map(quality_results, & &1.score)
    Enum.sum(scores) / length(scores)
  end

  defp determine_quality_level(score) do
    cond do
      score >= 0.9 -> "excellent"
      score >= 0.8 -> "good"
      score >= 0.6 -> "fair"
      score >= 0.4 -> "poor"
      true -> "very_poor"
    end
  end

  defp generate_quality_recommendations(quality_results) do
    low_scores = Enum.filter(quality_results, &(&1.score < 0.7))

    Enum.map(low_scores, fn result ->
      case result.check do
        "coverage" -> "Improve test coverage by adding more test cases"
        "assertions" -> "Add more assertions per test to improve validation"
        "mocks" -> "Consider using mocks/stubs for better isolation"
        "naming" -> "Improve test naming with descriptive should/when patterns"
        "structure" -> "Add setup/teardown and organize tests with describe blocks"
        _ -> "Review and improve #{result.check}"
      end
    end)
  end

  defp run_tests_with_timing(path, language) do
    cmd = build_test_command(language, detect_framework(language), path, nil, true)
    System.cmd("sh", ["-c", "time #{cmd}"], stderr_to_stdout: true)
  end

  defp parse_performance_results(output, language, threshold) do
    # Parse performance data from test output
    duration_match = Regex.run(~r/real\s+(\d+)m([\d.]+)s/, output)

    total_duration =
      if duration_match do
        minutes = String.to_integer(Enum.at(duration_match, 1))
        seconds = String.to_float(Enum.at(duration_match, 2))
        minutes * 60 + seconds
      else
        0
      end

    # Extract individual test times (simplified)
    slow_tests = extract_slow_tests(output, language, threshold)

    %{
      total_duration: total_duration,
      slow_tests: slow_tests,
      threshold: threshold
    }
  end

  defp extract_slow_tests(output, language, threshold) do
    # Extract slow tests from output (simplified implementation)
    # This would need to be customized per test framework
    []
  end

  defp generate_overall_assessment(analysis) do
    # Generate overall assessment from all analysis results
    %{
      summary: "Test analysis completed",
      recommendations: [],
      overall_score: 0.8
    }
  end

  # Detect testing framework using Architecture Engine
  defp detect_testing_framework(language, path) do
    case Singularity.ArchitectureEngine.detect_frameworks([], []) do
      {:ok, %{frameworks: frameworks}} ->
        # Look for testing frameworks in the detected frameworks
        testing_frameworks =
          Enum.filter(frameworks, fn fw ->
            fw.name && String.contains?(String.downcase(fw.name), "test")
          end)

        case testing_frameworks do
          [%{name: name} | _] -> String.downcase(name)
          _ -> get_default_testing_framework(language)
        end

      {:error, _} ->
        # Fallback to file-based detection
        detect_framework_from_files(language, path)
    end
  end

  # Fallback framework detection from files
  defp detect_framework_from_files(language, path) do
    case language do
      "elixir" ->
        cond do
          File.exists?(Path.join(path, "test/support/conn_case.ex")) -> "phoenix"
          File.exists?(Path.join(path, "test/support/data_case.ex")) -> "ecto"
          true -> "exunit"
        end

      "javascript" ->
        cond do
          File.exists?(Path.join(path, "jest.config.js")) -> "jest"
          File.exists?(Path.join(path, ".mocharc.json")) -> "mocha"
          true -> "jest"
        end

      "python" ->
        cond do
          File.exists?(Path.join(path, "pytest.ini")) -> "pytest"
          File.exists?(Path.join(path, "setup.py")) -> "unittest"
          true -> "pytest"
        end

      _ ->
        get_default_testing_framework(language)
    end
  end

  # Helper function to add framework-specific test options
  defp add_framework_test_options(cmd, framework, language) do
    case {language, framework} do
      {"elixir", "phoenix"} ->
        "#{cmd} --exclude integration"

      {"elixir", "ecto"} ->
        "#{cmd} --exclude slow"

      {"javascript", "jest"} ->
        "#{cmd} --passWithNoTests"

      {"javascript", "mocha"} ->
        "#{cmd} --reporter spec"

      {"python", "pytest"} ->
        "#{cmd} -v"

      {"python", "unittest"} ->
        "#{cmd} -v"

      _ ->
        cmd
    end
  end

  # Helper function to add format-specific coverage options
  defp add_coverage_format_options(cmd, format, language) do
    case {language, format} do
      {"elixir", "html"} ->
        "#{cmd} --cover-format=html"

      {"elixir", "json"} ->
        "#{cmd} --cover-format=json"

      {"javascript", "html"} ->
        "#{cmd} --coverageReporters=html"

      {"javascript", "json"} ->
        "#{cmd} --coverageReporters=json"

      {"python", "html"} ->
        "#{cmd} --cov-report=html"

      {"python", "json"} ->
        "#{cmd} --cov-report=json"

      _ ->
        cmd
    end
  end

  # Helper function to add framework-specific coverage options
  defp add_framework_coverage_options(cmd, framework, language) do
    case {language, framework} do
      {"elixir", "phoenix"} ->
        "#{cmd} --cover-exclude=test/support/"

      {"elixir", "ecto"} ->
        "#{cmd} --cover-exclude=test/support/data_case.ex"

      {"javascript", "jest"} ->
        "#{cmd} --coverageDirectory=coverage"

      {"javascript", "mocha"} ->
        "#{cmd} --reporter json"

      _ ->
        cmd
    end
  end

  # Get default testing framework for a language
  defp get_default_testing_framework(language) do
    case language do
      "elixir" -> "exunit"
      "javascript" -> "jest"
      "python" -> "pytest"
      "java" -> "junit"
      "go" -> "testing"
      "rust" -> "test"
      _ -> "default"
    end
  end

  # Parse ExUnit test results with framework context
  defp parse_exunit_results(output, framework) do
    # Parse ExUnit output
    total_match = Regex.run(~r/(\d+) tests?/, output)
    failed_match = Regex.run(~r/(\d+) failures?/, output)
    duration_match = Regex.run(~r/(\d+\.?\d*)s/, output)

    total = if total_match, do: String.to_integer(Enum.at(total_match, 1)), else: 0
    failed = if failed_match, do: String.to_integer(Enum.at(failed_match, 1)), else: 0
    duration = if duration_match, do: String.to_float(Enum.at(duration_match, 1)), else: 0.0

    passed = total - failed

    # Add framework-specific parsing
    framework_notes =
      case framework do
        "phoenix" -> "Phoenix integration tests included"
        "ecto" -> "Ecto database tests included"
        _ -> ""
      end

    %{
      total: total,
      passed: passed,
      failed: failed,
      skipped: 0,
      duration: duration,
      framework: framework,
      notes: framework_notes
    }
  end

  # Parse Jest test results with framework context
  defp parse_jest_results(output, framework) do
    # Parse Jest output
    total_match = Regex.run(~r/Tests:\s+(\d+)/, output)
    failed_match = Regex.run(~r/Failed:\s+(\d+)/, output)
    passed_match = Regex.run(~r/Passed:\s+(\d+)/, output)
    duration_match = Regex.run(~r/Time:\s+(\d+\.?\d*)s/, output)

    total = if total_match, do: String.to_integer(Enum.at(total_match, 1)), else: 0
    failed = if failed_match, do: String.to_integer(Enum.at(failed_match, 1)), else: 0
    passed = if passed_match, do: String.to_integer(Enum.at(passed_match, 1)), else: 0
    duration = if duration_match, do: String.to_float(Enum.at(duration_match, 1)), else: 0.0

    # Add framework-specific parsing
    framework_notes =
      case framework do
        "jest" -> "Jest test runner"
        "mocha" -> "Mocha test runner"
        _ -> ""
      end

    %{
      total: total,
      passed: passed,
      failed: failed,
      skipped: 0,
      duration: duration,
      framework: framework,
      notes: framework_notes
    }
  end
end
