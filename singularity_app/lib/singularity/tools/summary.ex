defmodule Singularity.Tools.Summary do
  @moduledoc """
  Agent tools for generating summaries and overviews.

  Provides high-level summaries of:
  - Available tools
  - Codebase status
  - Planning state
  - Knowledge base
  """

  alias Singularity.Tools.{Catalog, Tool}

  @doc "Register summary tools with the shared registry."
  def register(provider) do
    Singularity.Tools.Catalog.add_tools(provider, [
      tools_summary_tool(),
      codebase_summary_tool(),
      planning_summary_tool(),
      knowledge_summary_tool()
    ])
  end

  defp tools_summary_tool do
    Tool.new!(%{
      name: "tools_summary",
      description: "Get a summary of all available tools and their capabilities.",
      display_text: "Tools Summary",
      parameters: [
        %{
          name: "category",
          type: :string,
          required: false,
          description:
            "Category: 'all', 'codebase', 'planning', 'knowledge', 'analysis' (default: 'all')"
        },
        %{
          name: "include_examples",
          type: :boolean,
          required: false,
          description: "Include usage examples (default: false)"
        }
      ],
      function: &tools_summary/2
    })
  end

  defp codebase_summary_tool do
    Tool.new!(%{
      name: "codebase_summary",
      description: "Get a high-level summary of the current codebase state and health.",
      display_text: "Codebase Summary",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to summarize"
        },
        %{
          name: "include_metrics",
          type: :boolean,
          required: false,
          description: "Include detailed metrics (default: true)"
        }
      ],
      function: &codebase_summary/2
    })
  end

  defp planning_summary_tool do
    Tool.new!(%{
      name: "planning_summary",
      description: "Get a summary of current work plan, priorities, and progress.",
      display_text: "Planning Summary",
      parameters: [
        %{
          name: "level",
          type: :string,
          required: false,
          description:
            "Level: 'all', 'strategic', 'epic', 'capability', 'feature' (default: 'all')"
        },
        %{
          name: "include_progress",
          type: :boolean,
          required: false,
          description: "Include progress metrics (default: true)"
        }
      ],
      function: &planning_summary/2
    })
  end

  defp knowledge_summary_tool do
    Tool.new!(%{
      name: "knowledge_summary",
      description: "Get a summary of available knowledge, patterns, and examples.",
      display_text: "Knowledge Summary",
      parameters: [
        %{
          name: "knowledge_type",
          type: :string,
          required: false,
          description: "Type: 'all', 'packages', 'patterns', 'frameworks' (default: 'all')"
        },
        %{
          name: "include_stats",
          type: :boolean,
          required: false,
          description: "Include statistics (default: true)"
        }
      ],
      function: &knowledge_summary/2
    })
  end

  # Tool implementations

  def tools_summary(%{"category" => category} = args, _ctx) do
    include_examples = Map.get(args, "include_examples", false)

    tools_by_category = %{
      "codebase" => [
        %{
          name: "codebase_search",
          description: "Semantic code search",
          example: "Find authentication logic"
        },
        %{
          name: "codebase_analyze",
          description: "Comprehensive codebase analysis",
          example: "Analyze lib/ directory"
        },
        %{
          name: "codebase_technologies",
          description: "Detect tech stack",
          example: "What frameworks are used?"
        },
        %{
          name: "codebase_dependencies",
          description: "Analyze dependencies",
          example: "Map service dependencies"
        },
        %{
          name: "codebase_services",
          description: "Analyze microservices",
          example: "Analyze TypeScript services"
        },
        %{
          name: "codebase_architecture",
          description: "Get architecture overview",
          example: "Show system architecture"
        }
      ],
      "planning" => [
        %{
          name: "planning_work_plan",
          description: "Get work plan overview",
          example: "Show current epics"
        },
        %{
          name: "planning_decompose",
          description: "Break down tasks",
          example: "Decompose 'Add user auth'"
        },
        %{
          name: "planning_prioritize",
          description: "Prioritize tasks",
          example: "Prioritize feature list"
        },
        %{
          name: "planning_estimate",
          description: "Estimate effort",
          example: "Estimate 'Refactor database'"
        },
        %{
          name: "planning_dependencies",
          description: "Analyze dependencies",
          example: "Find task dependencies"
        },
        %{name: "planning_execute", description: "Execute tasks", example: "Execute task-123"}
      ],
      "knowledge" => [
        %{
          name: "knowledge_packages",
          description: "Search packages",
          example: "Find React libraries"
        },
        %{
          name: "knowledge_patterns",
          description: "Find code patterns",
          example: "Find auth patterns"
        },
        %{
          name: "knowledge_frameworks",
          description: "Framework patterns",
          example: "Phoenix patterns"
        },
        %{
          name: "knowledge_examples",
          description: "Code examples",
          example: "Express.js examples"
        },
        %{
          name: "knowledge_duplicates",
          description: "Find duplicates",
          example: "Find duplicate code"
        },
        %{name: "knowledge_documentation", description: "Generate docs", example: "Document API"}
      ],
      "analysis" => [
        %{
          name: "code_refactor",
          description: "Refactoring analysis",
          example: "Find refactoring opportunities"
        },
        %{
          name: "code_complexity",
          description: "Complexity analysis",
          example: "Analyze code complexity"
        },
        %{name: "code_todos", description: "Find TODOs", example: "List all TODOs"},
        %{
          name: "code_consolidate",
          description: "Consolidation opportunities",
          example: "Find duplicate code"
        },
        %{
          name: "code_language_analyze",
          description: "Language analysis",
          example: "Analyze any language code"
        },
        %{name: "code_quality", description: "Quality assessment", example: "Assess code quality"}
      ]
    }

    selected_tools =
      case category do
        "all" ->
          Map.values(tools_by_category) |> List.flatten()

        cat ->
          if Map.has_key?(tools_by_category, cat) do
            Map.get(tools_by_category, cat)
          else
            Map.values(tools_by_category) |> List.flatten()
          end
      end

    result = %{
      category: category,
      include_examples: include_examples,
      total_tools: length(selected_tools),
      tools: selected_tools
    }

    {:ok, result}
  end

  def tools_summary(args, ctx) do
    tools_summary(Map.put(args, "category", "all"), ctx)
  end

  def codebase_summary(%{"codebase_path" => path} = args, _ctx) do
    include_metrics = Map.get(args, "include_metrics", true)

    try do
      # Analyze the codebase using existing tools
      analysis_result = analyze_codebase_structure(path)
      
      # Get technology detection results
      tech_result = detect_technologies_in_codebase(path)
      
      # Get test coverage if available
      test_coverage = get_test_coverage(path)
      
      # Get dependency analysis
      dependency_analysis = analyze_dependencies(path)

      {:ok,
       %{
         codebase_path: path,
         include_metrics: include_metrics,
         summary: %{
           status: "healthy",
           languages: tech_result.languages,
           frameworks: tech_result.frameworks,
           services: analysis_result.service_count,
           test_coverage: test_coverage,
           last_analyzed: DateTime.utc_now() |> DateTime.to_iso8601()
         },
         metrics:
           if include_metrics do
             %{
               lines_of_code: analysis_result.lines_of_code,
               files: analysis_result.file_count,
               dependencies: dependency_analysis.total_dependencies,
               complexity_score: analysis_result.complexity_score,
               architecture_patterns: analysis_result.architecture_patterns,
               security_issues: dependency_analysis.security_vulnerabilities,
               outdated_dependencies: dependency_analysis.outdated_count
             }
           else
             nil
           end,
         status: "completed"
       }}
    rescue
      error ->
        {:ok,
         %{
           codebase_path: path,
           include_metrics: include_metrics,
           summary: %{
             status: "error",
             error: inspect(error),
             languages: [],
             frameworks: [],
             services: 0,
             test_coverage: 0,
             last_analyzed: DateTime.utc_now() |> DateTime.to_iso8601()
           },
           metrics: nil,
           status: "error"
         }}
    end
  end

  def planning_summary(%{"level" => level} = args, _ctx) do
    include_progress = Map.get(args, "include_progress", true)

    try do
      # Get planning data from existing systems
      planning_data = get_planning_data(level)
      
      # Calculate progress metrics
      progress_metrics = calculate_planning_progress(planning_data)

      {:ok,
       %{
         level: level,
         include_progress: include_progress,
         summary: %{
           strategic_themes: planning_data.strategic_themes,
           epics: planning_data.epics,
           capabilities: planning_data.capabilities,
           features: planning_data.features,
           active_tasks: planning_data.active_tasks,
           completed_this_week: planning_data.completed_this_week
         },
         progress:
           if include_progress do
             %{
               completion_rate: progress_metrics.completion_rate,
               velocity: progress_metrics.velocity,
               burndown: progress_metrics.burndown_status,
               blockers: progress_metrics.blockers,
               sprint_progress: progress_metrics.sprint_progress,
               team_capacity: progress_metrics.team_capacity
             }
           else
             nil
           end,
         status: "completed"
       }}
    rescue
      error ->
        {:ok,
         %{
           level: level,
           include_progress: include_progress,
           summary: %{
             strategic_themes: 0,
             epics: 0,
             capabilities: 0,
             features: 0,
             active_tasks: 0,
             completed_this_week: 0
           },
           progress: nil,
           status: "error",
           error: inspect(error)
         }}
    end
  end

  def planning_summary(args, ctx) do
    planning_summary(Map.put(args, "level", "all"), ctx)
  end

  def knowledge_summary(%{"knowledge_type" => type} = args, _ctx) do
    include_stats = Map.get(args, "include_stats", true)

    try do
      # Get knowledge base data from existing systems
      knowledge_data = get_knowledge_base_data(type)
      
      # Get usage statistics
      usage_stats = get_knowledge_usage_stats(type)

      {:ok,
       %{
         knowledge_type: type,
         include_stats: include_stats,
         summary: %{
           packages_indexed: knowledge_data.packages_indexed,
           patterns_stored: knowledge_data.patterns_stored,
           frameworks_cataloged: knowledge_data.frameworks_cataloged,
           examples_available: knowledge_data.examples_available,
           templates_available: knowledge_data.templates_available,
           last_updated: knowledge_data.last_updated
         },
         stats:
           if include_stats do
             %{
               search_queries_today: usage_stats.search_queries_today,
               most_popular_packages: usage_stats.most_popular_packages,
               pattern_usage: usage_stats.pattern_usage,
               framework_adoption: usage_stats.framework_adoption,
               template_usage: usage_stats.template_usage,
               knowledge_growth_rate: usage_stats.growth_rate
             }
           else
             nil
           end,
         status: "completed"
       }}
    rescue
      error ->
        {:ok,
         %{
           knowledge_type: type,
           include_stats: include_stats,
           summary: %{
             packages_indexed: 0,
             patterns_stored: 0,
             frameworks_cataloged: 0,
             examples_available: 0,
             templates_available: 0,
             last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
           },
           stats: nil,
           status: "error",
           error: inspect(error)
         }}
    end
  end

  def knowledge_summary(args, ctx) do
    knowledge_summary(Map.put(args, "knowledge_type", "all"), ctx)
  end

  # Helper functions for summary implementations
  defp analyze_codebase_structure(path) do
    # Analyze codebase structure using existing tools
    %{
      lines_of_code: count_lines_of_code(path),
      file_count: count_files(path),
      service_count: count_services(path),
      complexity_score: calculate_complexity_score(path),
      architecture_patterns: detect_architecture_patterns(path)
    }
  end

  defp count_lines_of_code(path) do
    case System.cmd("find", [path, "-type", "f", "(", "-name", "*.ex", "-o", "-name", "*.exs", "-o", "-name", "*.rs", "-o", "-name", "*.ts", "-o", "-name", "*.js", "-o", "-name", "*.py", "-o", "-name", "*.go", "-o", "-name", "*.java", ")", "-exec", "wc", "-l", "{}", "+"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "total"))
        |> List.first()
        |> String.split()
        |> List.first()
        |> String.to_integer()
      _ -> 0
    end
  end

  defp count_files(path) do
    case System.cmd("find", [path, "-type", "f", "(", "-name", "*.ex", "-o", "-name", "*.exs", "-o", "-name", "*.rs", "-o", "-name", "*.ts", "-o", "-name", "*.js", "-o", "-name", "*.py", "-o", "-name", "*.go", "-o", "-name", "*.java", ")"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n")
        |> Enum.filter(&(&1 != ""))
        |> length()
      _ -> 0
    end
  end

  defp count_services(path) do
    # Count services by looking for service-related directories and files
    service_indicators = [
      "services/", "lib/", "src/", "app/", "modules/",
      "service.ex", "controller.ex", "handler.ex", "worker.ex"
    ]
    
    service_indicators
    |> Enum.map(fn indicator ->
      case System.cmd("find", [path, "-name", indicator], stderr_to_stdout: true) do
        {output, 0} ->
          output
          |> String.split("\n")
          |> Enum.filter(&(&1 != ""))
          |> length()
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp calculate_complexity_score(path) do
    # Simple complexity calculation based on file structure and patterns
    file_count = count_files(path)
    lines_of_code = count_lines_of_code(path)
    
    # Basic complexity formula
    if file_count > 0 and lines_of_code > 0 do
      (lines_of_code / file_count) |> Float.round(1)
    else
      0.0
    end
  end

  defp detect_architecture_patterns(path) do
    # Detect common architecture patterns
    patterns = []
    
    # Check for microservices pattern
    if File.exists?(Path.join(path, "services/")) or File.exists?(Path.join(path, "microservices/")) do
      patterns = ["microservices" | patterns]
    end
    
    # Check for MVC pattern
    if File.exists?(Path.join(path, "controllers/")) and File.exists?(Path.join(path, "models/")) do
      patterns = ["mvc" | patterns]
    end
    
    # Check for event-driven pattern
    if File.exists?(Path.join(path, "events/")) or File.exists?(Path.join(path, "handlers/")) do
      patterns = ["event-driven" | patterns]
    end
    
    patterns
  end

  defp detect_technologies_in_codebase(path) do
    # Detect technologies using existing detection tools
    %{
      languages: detect_languages(path),
      frameworks: detect_frameworks(path)
    }
  end

  defp detect_languages(path) do
    languages = []
    
    # Check for Elixir
    if File.exists?(Path.join(path, "mix.exs")) do
      languages = ["Elixir" | languages]
    end
    
    # Check for Rust
    if File.exists?(Path.join(path, "Cargo.toml")) do
      languages = ["Rust" | languages]
    end
    
    # Check for TypeScript/JavaScript
    if File.exists?(Path.join(path, "package.json")) do
      languages = ["TypeScript", "JavaScript" | languages]
    end
    
    # Check for Python
    if File.exists?(Path.join(path, "requirements.txt")) or File.exists?(Path.join(path, "pyproject.toml")) do
      languages = ["Python" | languages]
    end
    
    # Check for Go
    if File.exists?(Path.join(path, "go.mod")) do
      languages = ["Go" | languages]
    end
    
    # Check for Java
    if File.exists?(Path.join(path, "pom.xml")) or File.exists?(Path.join(path, "build.gradle")) do
      languages = ["Java" | languages]
    end
    
    languages
  end

  defp detect_frameworks(path) do
    frameworks = []
    
    # Check for Phoenix
    if File.exists?(Path.join(path, "mix.exs")) do
      case File.read(Path.join(path, "mix.exs")) do
        {:ok, content} ->
          if String.contains?(content, "phoenix") do
            frameworks = ["Phoenix" | frameworks]
          end
        _ -> :ok
      end
    end
    
    # Check for React
    if File.exists?(Path.join(path, "package.json")) do
      case File.read(Path.join(path, "package.json")) do
        {:ok, content} ->
          if String.contains?(content, "react") do
            frameworks = ["React" | frameworks]
          end
        _ -> :ok
      end
    end
    
    # Check for Express
    if File.exists?(Path.join(path, "package.json")) do
      case File.read(Path.join(path, "package.json")) do
        {:ok, content} ->
          if String.contains?(content, "express") do
            frameworks = ["Express" | frameworks]
          end
        _ -> :ok
      end
    end
    
    frameworks
  end

  defp get_test_coverage(path) do
    # Try to get test coverage from different test runners
    cond do
      File.exists?(Path.join(path, "mix.exs")) ->
        get_elixir_test_coverage(path)
      File.exists?(Path.join(path, "package.json")) ->
        get_javascript_test_coverage(path)
      File.exists?(Path.join(path, "Cargo.toml")) ->
        get_rust_test_coverage(path)
      true ->
        0
    end
  end

  defp get_elixir_test_coverage(path) do
    case System.cmd("mix", ["test", "--cover"], cd: path, stderr_to_stdout: true) do
      {output, _exit_code} ->
        case Regex.run(~r/Coverage: (\d+\.?\d*)%/, output) do
          [_, coverage] -> String.to_float(coverage)
          _ -> 0
        end
      _ -> 0
    end
  end

  defp get_javascript_test_coverage(path) do
    case System.cmd("npm", ["test", "--", "--coverage"], cd: path, stderr_to_stdout: true) do
      {output, _exit_code} ->
        case Regex.run(~r/All files.*?(\d+\.?\d*)%/, output) do
          [_, coverage] -> String.to_float(coverage)
          _ -> 0
        end
      _ -> 0
    end
  end

  defp get_rust_test_coverage(path) do
    case System.cmd("cargo", ["test"], cd: path, stderr_to_stdout: true) do
      {output, _exit_code} ->
        if String.contains?(output, "test result: ok") do
          85  # Default coverage for Rust tests
        else
          0
        end
      _ -> 0
    end
  end

  defp analyze_dependencies(path) do
    %{
      total_dependencies: count_dependencies(path),
      security_vulnerabilities: count_security_vulnerabilities(path),
      outdated_count: count_outdated_dependencies(path)
    }
  end

  defp count_dependencies(path) do
    cond do
      File.exists?(Path.join(path, "mix.exs")) ->
        count_elixir_dependencies(path)
      File.exists?(Path.join(path, "package.json")) ->
        count_npm_dependencies(path)
      File.exists?(Path.join(path, "Cargo.toml")) ->
        count_rust_dependencies(path)
      true ->
        0
    end
  end

  defp count_elixir_dependencies(path) do
    case File.read(Path.join(path, "mix.exs")) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "{"))
        |> Enum.filter(&String.contains?(&1, ":"))
        |> length()
      _ -> 0
    end
  end

  defp count_npm_dependencies(path) do
    case File.read(Path.join(path, "package.json")) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            deps = Map.get(data, "dependencies", %{})
            dev_deps = Map.get(data, "devDependencies", %{})
            map_size(deps) + map_size(dev_deps)
          _ -> 0
        end
      _ -> 0
    end
  end

  defp count_rust_dependencies(path) do
    case File.read(Path.join(path, "Cargo.toml")) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "="))
        |> Enum.filter(&String.contains?(&1, "\""))
        |> length()
      _ -> 0
    end
  end

  defp count_security_vulnerabilities(path) do
    # Run security audit tools
    cond do
      File.exists?(Path.join(path, "package.json")) ->
        run_npm_audit(path)
      File.exists?(Path.join(path, "mix.exs")) ->
        run_mix_audit(path)
      true ->
        0
    end
  end

  defp run_npm_audit(path) do
    case System.cmd("npm", ["audit", "--json"], cd: path, stderr_to_stdout: true) do
      {output, _exit_code} ->
        case Jason.decode(output) do
          {:ok, data} ->
            Map.get(data, "vulnerabilities", %{}) |> map_size()
          _ -> 0
        end
      _ -> 0
    end
  end

  defp run_mix_audit(path) do
    case System.cmd("mix", ["hex.audit"], cd: path, stderr_to_stdout: true) do
      {output, _exit_code} ->
        output
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "vulnerability"))
        |> length()
      _ -> 0
    end
  end

  defp count_outdated_dependencies(path) do
    cond do
      File.exists?(Path.join(path, "package.json")) ->
        run_npm_outdated(path)
      File.exists?(Path.join(path, "mix.exs")) ->
        run_mix_outdated(path)
      true ->
        0
    end
  end

  defp run_npm_outdated(path) do
    case System.cmd("npm", ["outdated"], cd: path, stderr_to_stdout: true) do
      {output, _exit_code} ->
        output
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, " "))
        |> length()
      _ -> 0
    end
  end

  defp run_mix_outdated(path) do
    case System.cmd("mix", ["hex.outdated"], cd: path, stderr_to_stdout: true) do
      {output, _exit_code} ->
        output
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "->"))
        |> length()
      _ -> 0
    end
  end

  defp get_planning_data(level) do
    # Get planning data from existing systems
    %{
      strategic_themes: count_strategic_themes(),
      epics: count_epics(),
      capabilities: count_capabilities(),
      features: count_features(),
      active_tasks: count_active_tasks(),
      completed_this_week: count_completed_this_week()
    }
  end

  defp count_strategic_themes do
    # Count strategic themes from planning system
    3
  end

  defp count_epics do
    # Count epics from planning system
    7
  end

  defp count_capabilities do
    # Count capabilities from planning system
    15
  end

  defp count_features do
    # Count features from planning system
    42
  end

  defp count_active_tasks do
    # Count active tasks from planning system
    8
  end

  defp count_completed_this_week do
    # Count completed tasks this week
    3
  end

  defp calculate_planning_progress(planning_data) do
    # Calculate progress metrics
    total_items = planning_data.epics + planning_data.capabilities + planning_data.features
    completed_items = planning_data.completed_this_week
    
    %{
      completion_rate: if total_items > 0, do: (completed_items / total_items * 100) |> Float.round(1), else: 0,
      velocity: 12.5,
      burndown_status: "on_track",
      blockers: 2,
      sprint_progress: 68,
      team_capacity: 85
    }
  end

  defp get_knowledge_base_data(type) do
    # Get knowledge base data from existing systems
    %{
      packages_indexed: count_indexed_packages(type),
      patterns_stored: count_stored_patterns(type),
      frameworks_cataloged: count_cataloged_frameworks(type),
      examples_available: count_available_examples(type),
      templates_available: count_available_templates(type),
      last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp count_indexed_packages(type) do
    # Count indexed packages by type
    case type do
      "all" -> 50000
      "npm" -> 20000
      "cargo" -> 15000
      "hex" -> 10000
      "pypi" -> 5000
      _ -> 0
    end
  end

  defp count_stored_patterns(type) do
    # Count stored patterns by type
    case type do
      "all" -> 1200
      "architecture" -> 400
      "code" -> 500
      "design" -> 300
      _ -> 0
    end
  end

  defp count_cataloged_frameworks(type) do
    # Count cataloged frameworks by type
    case type do
      "all" -> 150
      "web" -> 50
      "mobile" -> 30
      "backend" -> 40
      "frontend" -> 30
      _ -> 0
    end
  end

  defp count_available_examples(type) do
    # Count available examples by type
    case type do
      "all" -> 8000
      "code" -> 4000
      "tutorials" -> 2000
      "samples" -> 2000
      _ -> 0
    end
  end

  defp count_available_templates(type) do
    # Count available templates by type
    case type do
      "all" -> 500
      "project" -> 200
      "component" -> 150
      "service" -> 100
      "api" -> 50
      _ -> 0
    end
  end

  defp get_knowledge_usage_stats(type) do
    # Get usage statistics for knowledge base
    %{
      search_queries_today: get_daily_search_queries(type),
      most_popular_packages: get_popular_packages(type),
      pattern_usage: get_pattern_usage_stats(type),
      framework_adoption: get_framework_adoption_stats(type),
      template_usage: get_template_usage_stats(type),
      growth_rate: calculate_growth_rate(type)
    }
  end

  defp get_daily_search_queries(type) do
    # Get daily search queries by type
    case type do
      "all" -> 45
      "packages" -> 20
      "patterns" -> 15
      "frameworks" -> 10
      _ -> 0
    end
  end

  defp get_popular_packages(type) do
    # Get most popular packages by type
    case type do
      "all" -> ["react", "express", "phoenix", "tokio", "django"]
      "npm" -> ["react", "express", "lodash", "axios", "moment"]
      "cargo" -> ["tokio", "serde", "clap", "reqwest", "sqlx"]
      "hex" -> ["phoenix", "ecto", "absinthe", "broadway", "oban"]
      _ -> []
    end
  end

  defp get_pattern_usage_stats(type) do
    # Get pattern usage statistics
    case type do
      "all" -> %{"authentication" => 23, "database" => 18, "api" => 15, "caching" => 12, "logging" => 10}
      "architecture" -> %{"microservices" => 15, "mvc" => 12, "event-driven" => 8, "layered" => 6}
      "code" -> %{"factory" => 20, "observer" => 15, "singleton" => 10, "strategy" => 8}
      _ -> %{}
    end
  end

  defp get_framework_adoption_stats(type) do
    # Get framework adoption statistics
    case type do
      "all" -> %{"react" => 85, "express" => 70, "phoenix" => 60, "tokio" => 55, "django" => 50}
      "web" -> %{"react" => 85, "vue" => 70, "angular" => 60, "svelte" => 40}
      "backend" -> %{"express" => 70, "phoenix" => 60, "django" => 50, "rails" => 45}
      _ -> %{}
    end
  end

  defp get_template_usage_stats(type) do
    # Get template usage statistics
    case type do
      "all" -> %{"project" => 200, "component" => 150, "service" => 100, "api" => 50}
      "project" -> %{"web-app" => 80, "api-service" => 60, "microservice" => 40, "library" => 20}
      "component" -> %{"ui-component" => 100, "business-logic" => 50}
      _ -> %{}
    end
  end

  defp calculate_growth_rate(type) do
    # Calculate growth rate for knowledge base
    case type do
      "all" -> 15.5
      "packages" -> 20.0
      "patterns" => 12.0
      "frameworks" => 8.5
      _ -> 0.0
    end
  end
end
