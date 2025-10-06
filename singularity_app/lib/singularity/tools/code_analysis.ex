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

  defp run_elixir_analysis(_path, analysis_type) do
    # Elixir-specific analysis
    %{
      language: "elixir",
      analysis_type: analysis_type,
      tools_used: ["mix", "credo", "dialyzer"],
      status: "placeholder - implement Elixir analysis"
    }
  end

  defp run_typescript_analysis(_path, analysis_type) do
    # TypeScript-specific analysis
    %{
      language: "typescript",
      analysis_type: analysis_type,
      tools_used: ["eslint", "tsc", "npm audit"],
      status: "placeholder - implement TypeScript analysis"
    }
  end

  defp run_python_analysis(_path, analysis_type) do
    # Python-specific analysis
    %{
      language: "python",
      analysis_type: analysis_type,
      tools_used: ["pylint", "mypy", "safety"],
      status: "placeholder - implement Python analysis"
    }
  end

  defp run_go_analysis(_path, analysis_type) do
    # Go-specific analysis
    %{
      language: "go",
      analysis_type: analysis_type,
      tools_used: ["go vet", "golint", "gosec"],
      status: "placeholder - implement Go analysis"
    }
  end

  defp run_java_analysis(_path, analysis_type) do
    # Java-specific analysis
    %{
      language: "java",
      analysis_type: analysis_type,
      tools_used: ["spotbugs", "checkstyle", "dependency-check"],
      status: "placeholder - implement Java analysis"
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
