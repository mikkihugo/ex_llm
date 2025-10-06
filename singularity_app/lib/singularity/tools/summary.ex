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

    # This would integrate with actual codebase analysis
    # For now, return a structured response
    {:ok,
     %{
       codebase_path: path,
       include_metrics: include_metrics,
       summary: %{
         status: "healthy",
         languages: ["Elixir", "Rust", "TypeScript"],
         frameworks: ["Phoenix", "Actix", "Express"],
         services: 12,
         test_coverage: 85,
         last_analyzed: "2025-01-05T10:30:00Z"
       },
       metrics:
         if include_metrics do
           %{
             lines_of_code: 45000,
             files: 1200,
             dependencies: 150,
             complexity_score: 7.2
           }
         else
           nil
         end,
       status: "placeholder"
     }}
  end

  def planning_summary(%{"level" => level} = args, _ctx) do
    include_progress = Map.get(args, "include_progress", true)

    # This would integrate with actual planning data
    # For now, return a structured response
    {:ok,
     %{
       level: level,
       include_progress: include_progress,
       summary: %{
         strategic_themes: 3,
         epics: 7,
         capabilities: 15,
         features: 42,
         active_tasks: 8,
         completed_this_week: 3
       },
       progress:
         if include_progress do
           %{
             completion_rate: 68,
             velocity: 12.5,
             burndown: "on_track",
             blockers: 2
           }
         else
           nil
         end,
       status: "placeholder"
     }}
  end

  def planning_summary(args, ctx) do
    planning_summary(Map.put(args, "level", "all"), ctx)
  end

  def knowledge_summary(%{"knowledge_type" => type} = args, _ctx) do
    include_stats = Map.get(args, "include_stats", true)

    # This would integrate with actual knowledge base
    # For now, return a structured response
    {:ok,
     %{
       knowledge_type: type,
       include_stats: include_stats,
       summary: %{
         packages_indexed: 50000,
         patterns_stored: 1200,
         frameworks_cataloged: 150,
         examples_available: 8000
       },
       stats:
         if include_stats do
           %{
             search_queries_today: 45,
             most_popular_packages: ["react", "express", "phoenix"],
             pattern_usage: %{
               "authentication" => 23,
               "database" => 18,
               "api" => 15
             }
           }
         else
           nil
         end,
       status: "placeholder"
     }}
  end

  def knowledge_summary(args, ctx) do
    knowledge_summary(Map.put(args, "knowledge_type", "all"), ctx)
  end
end
