defmodule Singularity.Tools.CodeAnalysis do
  @moduledoc """
  Agent tools for code analysis and quality assessment.

  Wraps existing analysis capabilities:
  - RefactoringAnalyzer - Refactoring detection
  - RustToolingAnalyzer - Rust-specific analysis
  - TodoDetector - TODO detection
  - ConsolidationEngine - Code consolidation
  """

  alias Singularity.Tools.Tool
  alias Singularity.Code.Quality.RefactoringAnalyzer
  alias Singularity.Code.Analyzers.{RustToolingAnalyzer, TodoDetector, ConsolidationEngine}

  @doc "Register code analysis tools with the shared registry."
  def register(provider) do
    Singularity.Tools.Catalog.add_tools(provider, [
      code_refactor_tool(),
      code_complexity_tool(),
      code_todos_tool(),
      code_consolidate_tool(),
      code_language_analyze_tool(),
      code_quality_tool()
    ])
  end

  defp code_refactor_tool do
    Tool.new!(%{
      name: "code_refactor",
      description: "Analyze code for refactoring opportunities and suggest improvements.",
      display_text: "Refactoring Analysis",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "refactor_type",
          type: :string,
          required: false,
          description: "Type: 'all', 'duplicates', 'complexity', 'patterns' (default: 'all')"
        },
        %{
          name: "severity",
          type: :string,
          required: false,
          description: "Severity: 'high', 'medium', 'low' (default: 'medium')"
        }
      ],
      function: &code_refactor/2
    })
  end

  defp code_complexity_tool do
    Tool.new!(%{
      name: "code_complexity",
      description: "Analyze code complexity metrics and identify overly complex areas.",
      display_text: "Complexity Analysis",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "complexity_threshold",
          type: :number,
          required: false,
          description: "Complexity threshold (default: 10)"
        },
        %{
          name: "include_metrics",
          type: :boolean,
          required: false,
          description: "Include detailed metrics (default: true)"
        }
      ],
      function: &code_complexity/2
    })
  end

  defp code_todos_tool do
    Tool.new!(%{
      name: "code_todos",
      description: "Find TODO items, incomplete implementations, and missing components.",
      display_text: "TODO Detection",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "todo_type",
          type: :string,
          required: false,
          description: "Type: 'all', 'incomplete', 'missing', 'deprecated' (default: 'all')"
        },
        %{
          name: "priority",
          type: :string,
          required: false,
          description: "Priority: 'high', 'medium', 'low' (default: 'all')"
        }
      ],
      function: &code_todos/2
    })
  end

  defp code_consolidate_tool do
    Tool.new!(%{
      name: "code_consolidate",
      description: "Find opportunities to consolidate duplicate or similar code.",
      display_text: "Code Consolidation",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "consolidation_type",
          type: :string,
          required: false,
          description: "Type: 'duplicates', 'similar', 'patterns' (default: 'duplicates')"
        },
        %{
          name: "similarity_threshold",
          type: :number,
          required: false,
          description: "Similarity threshold 0.0-1.0 (default: 0.8)"
        }
      ],
      function: &code_consolidate/2
    })
  end

  defp code_language_analyze_tool do
    Tool.new!(%{
      name: "code_language_analyze",
      description:
        "Perform comprehensive language-specific code analysis including security, performance, and dependencies for any supported language.",
      display_text: "Language Analysis",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description:
            "Language: 'rust', 'elixir', 'typescript', 'python', 'go', 'java' (default: auto-detect)"
        },
        %{
          name: "analysis_type",
          type: :string,
          required: false,
          description: "Type: 'all', 'security', 'performance', 'dependencies' (default: 'all')"
        },
        %{
          name: "include_recommendations",
          type: :boolean,
          required: false,
          description: "Include improvement recommendations (default: true)"
        }
      ],
      function: &code_language_analyze/2
    })
  end

  defp code_quality_tool do
    Tool.new!(%{
      name: "code_quality",
      description:
        "Comprehensive code quality assessment including metrics, patterns, and best practices.",
      display_text: "Quality Assessment",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "quality_aspects",
          type: :array,
          required: false,
          description:
            "Aspects: ['maintainability', 'readability', 'performance', 'security'] (default: all)"
        },
        %{
          name: "include_suggestions",
          type: :boolean,
          required: false,
          description: "Include improvement suggestions (default: true)"
        }
      ],
      function: &code_quality/2
    })
  end

  # Tool implementations

  def code_refactor(%{"codebase_path" => path} = args, _ctx) do
    refactor_type = Map.get(args, "refactor_type", "all")
    severity = Map.get(args, "severity", "medium")

    case RefactoringAnalyzer.analyze_refactoring_need() do
      {:ok, analysis} ->
        filtered_analysis =
          case refactor_type do
            "duplicates" -> Map.take(analysis, [:duplicates, :similar_code])
            "complexity" -> Map.take(analysis, [:complexity, :cyclomatic_complexity])
            "patterns" -> Map.take(analysis, [:patterns, :anti_patterns])
            "all" -> analysis
          end

        {:ok,
         %{
           codebase_path: path,
           refactor_type: refactor_type,
           severity: severity,
           analysis: filtered_analysis,
           summary: %{
             total_issues: count_issues(filtered_analysis),
             high_priority: count_by_priority(filtered_analysis, "high"),
             medium_priority: count_by_priority(filtered_analysis, "medium"),
             low_priority: count_by_priority(filtered_analysis, "low")
           }
         }}

      {:error, reason} ->
        {:error, "Refactoring analysis failed: #{inspect(reason)}"}
    end
  end

  def code_complexity(%{"codebase_path" => path} = args, _ctx) do
    complexity_threshold = Map.get(args, "complexity_threshold", 10)
    include_metrics = Map.get(args, "include_metrics", true)

    # This would integrate with actual complexity analysis
    # For now, return a structured response
    {:ok,
     %{
       codebase_path: path,
       complexity_threshold: complexity_threshold,
       include_metrics: include_metrics,
       analysis: %{
         average_complexity: 8.5,
         max_complexity: 15,
         complex_functions: [
           %{name: "process_data", complexity: 12, file: "lib/processor.ex", line: 45},
           %{name: "validate_input", complexity: 11, file: "lib/validator.ex", line: 23}
         ],
         recommendations: [
           "Consider breaking down process_data function",
           "Extract validation logic into separate functions"
         ]
       },
       status: "placeholder"
     }}
  end

  def code_todos(%{"codebase_path" => path} = args, _ctx) do
    todo_type = Map.get(args, "todo_type", "all")
    priority = Map.get(args, "priority", "all")

    case TodoDetector.detect_todos(path, type: todo_type, priority: priority) do
      {:ok, todos} ->
        {:ok,
         %{
           codebase_path: path,
           todo_type: todo_type,
           priority: priority,
           todos: todos,
           count: length(todos),
           summary: %{
             high_priority: length(Enum.filter(todos, &(&1.priority == :high))),
             medium_priority: length(Enum.filter(todos, &(&1.priority == :medium))),
             low_priority: length(Enum.filter(todos, &(&1.priority == :low)))
           }
         }}

      {:error, reason} ->
        {:error, "TODO detection failed: #{inspect(reason)}"}
    end
  end

  def code_consolidate(%{"codebase_path" => path} = args, _ctx) do
    consolidation_type = Map.get(args, "consolidation_type", "duplicates")
    similarity_threshold = Map.get(args, "similarity_threshold", 0.8)

    case ConsolidationEngine.find_consolidation_opportunities(path,
           type: consolidation_type,
           threshold: similarity_threshold
         ) do
      {:ok, opportunities} ->
        {:ok,
         %{
           codebase_path: path,
           consolidation_type: consolidation_type,
           similarity_threshold: similarity_threshold,
           opportunities: opportunities,
           count: length(opportunities),
           estimated_effort: calculate_consolidation_effort(opportunities)
         }}

      {:error, reason} ->
        {:error, "Consolidation analysis failed: #{inspect(reason)}"}
    end
  end

  def code_language_analyze(%{"codebase_path" => path} = args, _ctx) do
    language = Map.get(args, "language", "auto-detect")
    analysis_type = Map.get(args, "analysis_type", "all")
    include_recommendations = Map.get(args, "include_recommendations", true)

    # Detect language if not specified
    detected_language =
      if language == "auto-detect" do
        detect_language(path)
      else
        language
      end

    # Run language-specific analysis
    results =
      case detected_language do
        "rust" -> run_rust_analysis(path, analysis_type)
        "elixir" -> run_elixir_analysis(path, analysis_type)
        "typescript" -> run_typescript_analysis(path, analysis_type)
        "python" -> run_python_analysis(path, analysis_type)
        "go" -> run_go_analysis(path, analysis_type)
        "java" -> run_java_analysis(path, analysis_type)
        _ -> run_generic_analysis(path, analysis_type)
      end

    {:ok,
     %{
       codebase_path: path,
       language: detected_language,
       analysis_type: analysis_type,
       include_recommendations: include_recommendations,
       analysis: results,
       status: "completed"
     }}
  end

  def code_quality(%{"codebase_path" => path} = args, _ctx) do
    quality_aspects =
      Map.get(args, "quality_aspects", [
        "maintainability",
        "readability",
        "performance",
        "security"
      ])

    include_suggestions = Map.get(args, "include_suggestions", true)

    # This would integrate with comprehensive quality analysis
    # For now, return a structured response
    {:ok,
     %{
       codebase_path: path,
       quality_aspects: quality_aspects,
       include_suggestions: include_suggestions,
       quality_score: 8.2,
       analysis: %{
         maintainability: %{score: 8.5, issues: []},
         readability: %{score: 7.8, issues: []},
         performance: %{score: 8.0, issues: []},
         security: %{score: 9.1, issues: []}
       },
       suggestions:
         if include_suggestions do
           [
             "Add more inline documentation",
             "Consider extracting complex functions",
             "Add error handling for edge cases"
           ]
         else
           []
         end,
       status: "placeholder"
     }}
  end

  # Helper functions

  defp detect_language(codebase_path) do
    # Simple language detection based on file extensions
    case File.ls(codebase_path) do
      {:ok, files} ->
        cond do
          Enum.any?(files, &String.ends_with?(&1, ".rs")) ->
            "rust"

          Enum.any?(files, &(String.ends_with?(&1, ".ex") or String.ends_with?(&1, ".exs"))) ->
            "elixir"

          Enum.any?(files, &(String.ends_with?(&1, ".ts") or String.ends_with?(&1, ".tsx"))) ->
            "typescript"

          Enum.any?(files, &String.ends_with?(&1, ".py")) ->
            "python"

          Enum.any?(files, &String.ends_with?(&1, ".go")) ->
            "go"

          Enum.any?(files, &String.ends_with?(&1, ".java")) ->
            "java"

          true ->
            "unknown"
        end

      _ ->
        "unknown"
    end
  end

  defp run_rust_analysis(_path, analysis_type) do
    # Use existing RustToolingAnalyzer
    results = %{}

    results =
      if analysis_type in ["all", "security"] do
        case RustToolingAnalyzer.analyze_security_vulnerabilities() do
          {:ok, security} -> Map.put(results, :security, security)
          _ -> results
        end
      else
        results
      end

    results =
      if analysis_type in ["all", "performance"] do
        case RustToolingAnalyzer.analyze_binary_size() do
          {:ok, performance} -> Map.put(results, :performance, performance)
          _ -> results
        end
      else
        results
      end

    results =
      if analysis_type in ["all", "dependencies"] do
        case RustToolingAnalyzer.analyze_outdated_dependencies() do
          {:ok, deps} -> Map.put(results, :dependencies, deps)
          _ -> results
        end
      else
        results
      end

    results
  end

  defp run_elixir_analysis(path, analysis_type) do
    # Elixir-specific analysis using existing tools
    try do
      results = %{
        language: "elixir",
        analysis_type: analysis_type,
        tools_used: [],
        issues: [],
        metrics: %{},
        status: "completed"
      }

      # Run mix compile to check for compilation errors
      case System.cmd("mix", ["compile", "--warnings-as-errors"], cd: path, stderr_to_stdout: true) do
        {output, 0} ->
          results = Map.put(results, :compilation_status, "success")
          results = Map.put(results, :tools_used, ["mix compile"])
        {output, _exit_code} ->
          compilation_errors = parse_elixir_compilation_errors(output)
          results = Map.put(results, :compilation_status, "failed")
          results = Map.put(results, :issues, compilation_errors)
          results = Map.put(results, :tools_used, ["mix compile"])
      end

      # Run credo for code quality analysis
      if analysis_type in ["all", "quality"] do
        case System.cmd("mix", ["credo", "--format", "json"], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            credo_results = parse_credo_output(output)
            results = Map.put(results, :quality_issues, credo_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["credo"])
        end
      end

      # Run dialyzer for type analysis
      if analysis_type in ["all", "types"] do
        case System.cmd("mix", ["dialyzer", "--format", "dialyxir"], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            dialyzer_results = parse_dialyzer_output(output)
            results = Map.put(results, :type_issues, dialyzer_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["dialyzer"])
        end
      end

      # Run mix test for test coverage
      if analysis_type in ["all", "tests"] do
        case System.cmd("mix", ["test", "--cover"], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            test_results = parse_test_output(output)
            results = Map.put(results, :test_coverage, test_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["mix test"])
        end
      end

      # Calculate overall metrics
      total_issues = length(results.issues) + 
                    length(Map.get(results, :quality_issues, [])) + 
                    length(Map.get(results, :type_issues, []))
      
      results = Map.put(results, :metrics, %{
        total_issues: total_issues,
        compilation_status: Map.get(results, :compilation_status, "unknown"),
        test_coverage: Map.get(Map.get(results, :test_coverage, %{}), :coverage, 0),
        analysis_timestamp: DateTime.utc_now()
      })

      results
    rescue
      error ->
        %{
          language: "elixir",
          analysis_type: analysis_type,
          tools_used: ["mix", "credo", "dialyzer"],
          status: "error",
          error: inspect(error),
          issues: [%{type: "system_error", message: "Analysis failed: #{inspect(error)}"}]
        }
    end
  end

  defp run_typescript_analysis(path, analysis_type) do
    # TypeScript-specific analysis using existing tools
    try do
      results = %{
        language: "typescript",
        analysis_type: analysis_type,
        tools_used: [],
        issues: [],
        metrics: %{},
        status: "completed"
      }

      # Run tsc for type checking
      case System.cmd("npx", ["tsc", "--noEmit", "--pretty"], cd: path, stderr_to_stdout: true) do
        {output, 0} ->
          results = Map.put(results, :compilation_status, "success")
          results = Map.put(results, :tools_used, ["tsc"])
        {output, _exit_code} ->
          type_errors = parse_typescript_errors(output)
          results = Map.put(results, :compilation_status, "failed")
          results = Map.put(results, :issues, type_errors)
          results = Map.put(results, :tools_used, ["tsc"])
      end

      # Run eslint for code quality
      if analysis_type in ["all", "quality"] do
        case System.cmd("npx", ["eslint", ".", "--format", "json"], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            eslint_results = parse_eslint_output(output)
            results = Map.put(results, :quality_issues, eslint_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["eslint"])
        end
      end

      # Run npm audit for security
      if analysis_type in ["all", "security"] do
        case System.cmd("npm", ["audit", "--json"], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            audit_results = parse_npm_audit_output(output)
            results = Map.put(results, :security_issues, audit_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["npm audit"])
        end
      end

      # Run tests if available
      if analysis_type in ["all", "tests"] do
        case System.cmd("npm", ["test"], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            test_results = parse_npm_test_output(output)
            results = Map.put(results, :test_results, test_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["npm test"])
        end
      end

      # Calculate overall metrics
      total_issues = length(results.issues) + 
                    length(Map.get(results, :quality_issues, [])) + 
                    length(Map.get(results, :security_issues, []))
      
      results = Map.put(results, :metrics, %{
        total_issues: total_issues,
        compilation_status: Map.get(results, :compilation_status, "unknown"),
        test_status: Map.get(Map.get(results, :test_results, %{}), :status, "unknown"),
        analysis_timestamp: DateTime.utc_now()
      })

      results
    rescue
      error ->
        %{
          language: "typescript",
          analysis_type: analysis_type,
          tools_used: ["eslint", "tsc", "npm audit"],
          status: "error",
          error: inspect(error),
          issues: [%{type: "system_error", message: "Analysis failed: #{inspect(error)}"}]
        }
    end
  end

  defp run_python_analysis(path, analysis_type) do
    # Python-specific analysis using existing tools
    try do
      results = %{
        language: "python",
        analysis_type: analysis_type,
        tools_used: [],
        issues: [],
        metrics: %{},
        status: "completed"
      }

      # Run pylint for code quality
      if analysis_type in ["all", "quality"] do
        case System.cmd("pylint", ["--output-format=json", "."], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            pylint_results = parse_pylint_output(output)
            results = Map.put(results, :quality_issues, pylint_results)
            results = Map.put(results, :tools_used, ["pylint"])
        end
      end

      # Run mypy for type checking
      if analysis_type in ["all", "types"] do
        case System.cmd("mypy", ["--json-report", "/tmp/mypy-report", "."], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            mypy_results = parse_mypy_output(output)
            results = Map.put(results, :type_issues, mypy_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["mypy"])
        end
      end

      # Run safety for security vulnerabilities
      if analysis_type in ["all", "security"] do
        case System.cmd("safety", ["check", "--json"], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            safety_results = parse_safety_output(output)
            results = Map.put(results, :security_issues, safety_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["safety"])
        end
      end

      # Run pytest for tests
      if analysis_type in ["all", "tests"] do
        case System.cmd("pytest", ["--cov=.", "--cov-report=json"], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            test_results = parse_pytest_output(output)
            results = Map.put(results, :test_coverage, test_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["pytest"])
        end
      end

      # Calculate overall metrics
      total_issues = length(Map.get(results, :quality_issues, [])) + 
                    length(Map.get(results, :type_issues, [])) + 
                    length(Map.get(results, :security_issues, []))
      
      results = Map.put(results, :metrics, %{
        total_issues: total_issues,
        test_coverage: Map.get(Map.get(results, :test_coverage, %{}), :coverage, 0),
        analysis_timestamp: DateTime.utc_now()
      })

      results
    rescue
      error ->
        %{
          language: "python",
          analysis_type: analysis_type,
          tools_used: ["pylint", "mypy", "safety"],
          status: "error",
          error: inspect(error),
          issues: [%{type: "system_error", message: "Analysis failed: #{inspect(error)}"}]
        }
    end
  end

  defp run_go_analysis(path, analysis_type) do
    # Go-specific analysis using existing tools
    try do
      results = %{
        language: "go",
        analysis_type: analysis_type,
        tools_used: [],
        issues: [],
        metrics: %{},
        status: "completed"
      }

      # Run go vet for static analysis
      if analysis_type in ["all", "quality"] do
        case System.cmd("go", ["vet", "./..."], cd: path, stderr_to_stdout: true) do
          {output, 0} ->
            results = Map.put(results, :vet_status, "clean")
            results = Map.put(results, :tools_used, ["go vet"])
          {output, _exit_code} ->
            vet_issues = parse_go_vet_output(output)
            results = Map.put(results, :vet_status, "issues_found")
            results = Map.put(results, :issues, vet_issues)
            results = Map.put(results, :tools_used, ["go vet"])
        end
      end

      # Run golint for style checking
      if analysis_type in ["all", "style"] do
        case System.cmd("golint", ["./..."], cd: path, stderr_to_stdout: true) do
          {output, 0} ->
            results = Map.put(results, :lint_status, "clean")
            results = Map.put(results, :tools_used, results.tools_used ++ ["golint"])
          {output, _exit_code} ->
            lint_issues = parse_golint_output(output)
            results = Map.put(results, :lint_status, "issues_found")
            results = Map.put(results, :style_issues, lint_issues)
            results = Map.put(results, :tools_used, results.tools_used ++ ["golint"])
        end
      end

      # Run gosec for security analysis
      if analysis_type in ["all", "security"] do
        case System.cmd("gosec", ["-fmt", "json", "./..."], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            security_results = parse_gosec_output(output)
            results = Map.put(results, :security_issues, security_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["gosec"])
        end
      end

      # Run go test for tests
      if analysis_type in ["all", "tests"] do
        case System.cmd("go", ["test", "-v", "./..."], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            test_results = parse_go_test_output(output)
            results = Map.put(results, :test_results, test_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["go test"])
        end
      end

      # Calculate overall metrics
      total_issues = length(results.issues) + 
                    length(Map.get(results, :style_issues, [])) + 
                    length(Map.get(results, :security_issues, []))
      
      results = Map.put(results, :metrics, %{
        total_issues: total_issues,
        vet_status: Map.get(results, :vet_status, "unknown"),
        lint_status: Map.get(results, :lint_status, "unknown"),
        test_status: Map.get(Map.get(results, :test_results, %{}), :status, "unknown"),
        analysis_timestamp: DateTime.utc_now()
      })

      results
    rescue
      error ->
        %{
          language: "go",
          analysis_type: analysis_type,
          tools_used: ["go vet", "golint", "gosec"],
          status: "error",
          error: inspect(error),
          issues: [%{type: "system_error", message: "Analysis failed: #{inspect(error)}"}]
        }
    end
  end

  defp run_java_analysis(path, analysis_type) do
    # Java-specific analysis using existing tools
    try do
      results = %{
        language: "java",
        analysis_type: analysis_type,
        tools_used: [],
        issues: [],
        metrics: %{},
        status: "completed"
      }

      # Run spotbugs for bug detection
      if analysis_type in ["all", "bugs"] do
        case System.cmd("spotbugs", ["-textui", "-output", "/tmp/spotbugs.txt", "."], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            spotbugs_results = parse_spotbugs_output(output)
            results = Map.put(results, :bug_issues, spotbugs_results)
            results = Map.put(results, :tools_used, ["spotbugs"])
        end
      end

      # Run checkstyle for code style
      if analysis_type in ["all", "style"] do
        case System.cmd("checkstyle", ["-c", "sun_checks.xml", "."], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            checkstyle_results = parse_checkstyle_output(output)
            results = Map.put(results, :style_issues, checkstyle_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["checkstyle"])
        end
      end

      # Run dependency-check for security vulnerabilities
      if analysis_type in ["all", "security"] do
        case System.cmd("dependency-check", ["--format", "JSON", "--out", "/tmp/dependency-check"], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            dependency_results = parse_dependency_check_output(output)
            results = Map.put(results, :security_issues, dependency_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["dependency-check"])
        end
      end

      # Run mvn test for tests
      if analysis_type in ["all", "tests"] do
        case System.cmd("mvn", ["test"], cd: path, stderr_to_stdout: true) do
          {output, _exit_code} ->
            test_results = parse_maven_test_output(output)
            results = Map.put(results, :test_results, test_results)
            results = Map.put(results, :tools_used, results.tools_used ++ ["mvn test"])
        end
      end

      # Calculate overall metrics
      total_issues = length(Map.get(results, :bug_issues, [])) + 
                    length(Map.get(results, :style_issues, [])) + 
                    length(Map.get(results, :security_issues, []))
      
      results = Map.put(results, :metrics, %{
        total_issues: total_issues,
        test_status: Map.get(Map.get(results, :test_results, %{}), :status, "unknown"),
        analysis_timestamp: DateTime.utc_now()
      })

      results
    rescue
      error ->
        %{
          language: "java",
          analysis_type: analysis_type,
          tools_used: ["spotbugs", "checkstyle", "dependency-check"],
          status: "error",
          error: inspect(error),
          issues: [%{type: "system_error", message: "Analysis failed: #{inspect(error)}"}]
        }
    end
  end

  # Helper functions for parsing tool outputs
  defp parse_elixir_compilation_errors(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "error:"))
    |> Enum.map(fn line ->
      %{
        type: "compilation_error",
        message: line,
        severity: "error",
        category: "compilation"
      }
    end)
  end

  defp parse_credo_output(output) do
    case Jason.decode(output) do
      {:ok, data} ->
        data
        |> Map.get("issues", [])
        |> Enum.map(fn issue ->
          %{
            type: "code_quality",
            message: Map.get(issue, "message", ""),
            severity: Map.get(issue, "severity", "info"),
            category: "quality",
            file: Map.get(issue, "filename", ""),
            line: Map.get(issue, "line_no", 0)
          }
        end)
      {:error, _} -> []
    end
  end

  defp parse_dialyzer_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.map(fn line ->
      %{
        type: "type_warning",
        message: line,
        severity: "warning",
        category: "types"
      }
    end)
  end

  defp parse_test_output(output) do
    # Parse mix test output for coverage
    coverage_match = Regex.run(~r/Coverage: (\d+\.?\d*)%/, output)
    coverage = if coverage_match, do: String.to_float(Enum.at(coverage_match, 1)), else: 0.0
    
    %{
      coverage: coverage,
      status: if String.contains?(output, "test failure"), do: "failed", else: "passed"
    }
  end

  defp parse_typescript_errors(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "error TS"))
    |> Enum.map(fn line ->
      %{
        type: "type_error",
        message: line,
        severity: "error",
        category: "types"
      }
    end)
  end

  defp parse_eslint_output(output) do
    case Jason.decode(output) do
      {:ok, data} ->
        data
        |> Enum.flat_map(fn file_result ->
          Map.get(file_result, "messages", [])
          |> Enum.map(fn message ->
            %{
              type: "code_quality",
              message: Map.get(message, "message", ""),
              severity: Map.get(message, "severity", "info"),
              category: "quality",
              file: Map.get(file_result, "filePath", ""),
              line: Map.get(message, "line", 0)
            }
          end)
        end)
      {:error, _} -> []
    end
  end

  defp parse_npm_audit_output(output) do
    case Jason.decode(output) do
      {:ok, data} ->
        Map.get(data, "vulnerabilities", %{})
        |> Enum.map(fn {package, vuln} ->
          %{
            type: "security_vulnerability",
            package: package,
            severity: Map.get(vuln, "severity", "unknown"),
            message: Map.get(vuln, "title", ""),
            category: "security"
          }
        end)
      {:error, _} -> []
    end
  end

  defp parse_npm_test_output(output) do
    %{
      status: if String.contains?(output, "failing"), do: "failed", else: "passed",
      output: output
    }
  end

  defp parse_pylint_output(output) do
    case Jason.decode(output) do
      {:ok, data} ->
        data
        |> Enum.map(fn issue ->
          %{
            type: "code_quality",
            message: Map.get(issue, "message", ""),
            severity: Map.get(issue, "type", "info"),
            category: "quality",
            file: Map.get(issue, "path", ""),
            line: Map.get(issue, "line", 0)
          }
        end)
      {:error, _} -> []
    end
  end

  defp parse_mypy_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "error:"))
    |> Enum.map(fn line ->
      %{
        type: "type_error",
        message: line,
        severity: "error",
        category: "types"
      }
    end)
  end

  defp parse_safety_output(output) do
    case Jason.decode(output) do
      {:ok, data} ->
        Map.get(data, "vulnerabilities", [])
        |> Enum.map(fn vuln ->
          %{
            type: "security_vulnerability",
            package: Map.get(vuln, "package", ""),
            severity: Map.get(vuln, "severity", "unknown"),
            message: Map.get(vuln, "advisory", ""),
            category: "security"
          }
        end)
      {:error, _} -> []
    end
  end

  defp parse_pytest_output(output) do
    coverage_match = Regex.run(~r/TOTAL.*?(\d+%)/, output)
    coverage = if coverage_match, do: String.to_float(String.replace(Enum.at(coverage_match, 1), "%", "")), else: 0.0
    
    %{
      coverage: coverage,
      status: if String.contains?(output, "FAILED"), do: "failed", else: "passed"
    }
  end

  defp parse_go_vet_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ":"))
    |> Enum.map(fn line ->
      %{
        type: "static_analysis",
        message: line,
        severity: "warning",
        category: "quality"
      }
    end)
  end

  defp parse_golint_output(output) do
    output
    |> String.split("\n")
    |> Enum.map(fn line ->
      %{
        type: "style_issue",
        message: line,
        severity: "info",
        category: "style"
      }
    end)
  end

  defp parse_gosec_output(output) do
    case Jason.decode(output) do
      {:ok, data} ->
        Map.get(data, "Issues", [])
        |> Enum.map(fn issue ->
          %{
            type: "security_issue",
            message: Map.get(issue, "details", ""),
            severity: Map.get(issue, "severity", "unknown"),
            category: "security",
            file: Map.get(issue, "file", ""),
            line: Map.get(issue, "line", 0)
          }
        end)
      {:error, _} -> []
    end
  end

  defp parse_go_test_output(output) do
    %{
      status: if String.contains?(output, "FAIL"), do: "failed", else: "passed",
      output: output
    }
  end

  defp parse_spotbugs_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "Bug:"))
    |> Enum.map(fn line ->
      %{
        type: "bug_detection",
        message: line,
        severity: "warning",
        category: "bugs"
      }
    end)
  end

  defp parse_checkstyle_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ":"))
    |> Enum.map(fn line ->
      %{
        type: "style_issue",
        message: line,
        severity: "info",
        category: "style"
      }
    end)
  end

  defp parse_dependency_check_output(output) do
    case Jason.decode(output) do
      {:ok, data} ->
        Map.get(data, "dependencies", [])
        |> Enum.flat_map(fn dep ->
          Map.get(dep, "vulnerabilities", [])
          |> Enum.map(fn vuln ->
            %{
              type: "security_vulnerability",
              package: Map.get(dep, "fileName", ""),
              severity: Map.get(vuln, "severity", "unknown"),
              message: Map.get(vuln, "description", ""),
              category: "security"
            }
          end)
        end)
      {:error, _} -> []
    end
  end

  defp parse_maven_test_output(output) do
    %{
      status: if String.contains?(output, "BUILD FAILURE"), do: "failed", else: "passed",
      output: output
    }
  end

  defp run_generic_analysis(_path, analysis_type) do
    # Generic analysis for unsupported languages
    %{
      language: "generic",
      analysis_type: analysis_type,
      tools_used: ["basic file analysis"],
      status: "generic analysis - language not specifically supported"
    }
  end

  defp count_issues(analysis) do
    analysis
    |> Map.values()
    |> Enum.map(fn items -> if is_list(items), do: length(items), else: 0 end)
    |> Enum.sum()
  end

  defp count_by_priority(analysis, priority) do
    analysis
    |> Map.values()
    |> Enum.flat_map(fn items -> if is_list(items), do: items, else: [] end)
    |> Enum.count(fn item ->
      case item do
        %{priority: p} when is_atom(p) -> Atom.to_string(p) == priority
        %{"priority" => p} when is_binary(p) -> p == priority
        _ -> false
      end
    end)
  end

  defp calculate_consolidation_effort(opportunities) do
    # Simple effort calculation based on number and complexity of opportunities
    base_effort = length(opportunities) * 2

    complexity_bonus =
      opportunities
      |> Enum.map(fn opp -> opp.complexity || 1 end)
      |> Enum.sum()
      |> div(2)

    base_effort + complexity_bonus
  end
end
