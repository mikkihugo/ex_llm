defmodule Singularity.Tools.EnhancedDescriptions do
  @moduledoc """
  Enhanced tool descriptions optimized for AI agent understanding.

  Provides:
  - Clear when-to-use guidance
  - Input/output examples
  - Context about tool relationships
  - Performance considerations
  """

  @tool_descriptions %{
    # Codebase Understanding Tools
    "codebase_search" => %{
      description: """
      Search codebase using semantic similarity. Find code by natural language description.

      WHEN TO USE:
      - Looking for specific functionality ("authentication logic", "database queries")
      - Finding similar implementations ("error handling patterns")
      - Exploring codebase structure ("API endpoints", "data models")

      EXAMPLES:
      - "Find user authentication code" → Returns auth-related functions
      - "Show database connection setup" → Returns DB config and connection code
      - "Find error handling patterns" → Returns try/catch blocks and error handling

      PERFORMANCE: Fast (vector search), returns top 10 results by default
      """,
      input_example: %{
        query: "user authentication logic",
        codebase_id: "my-project",
        limit: 5
      },
      output_example: %{
        query: "user authentication logic",
        results: [
          %{file: "lib/auth.ex", content: "def authenticate_user(token)", similarity: 0.94},
          %{file: "lib/session.ex", content: "def create_session(user_id)", similarity: 0.87}
        ],
        count: 2
      }
    },
    "codebase_analyze" => %{
      description: """
      Perform comprehensive codebase analysis including architecture, patterns, and quality metrics.

      WHEN TO USE:
      - Getting overall codebase health ("How is this project structured?")
      - Understanding architecture ("What patterns are used?")
      - Quality assessment ("What are the main issues?")
      - Onboarding to new codebase

      EXAMPLES:
      - "Analyze lib/ directory" → Full analysis of Elixir code
      - "Analyze frontend architecture" → React/Vue patterns and structure
      - "Get codebase health report" → Quality metrics and recommendations

      PERFORMANCE: Slow (comprehensive analysis), use for high-level understanding
      """,
      input_example: %{
        codebase_path: "./lib",
        analysis_type: "full"
      },
      output_example: %{
        codebase_path: "./lib",
        analysis_type: "full",
        summary: %{languages: ["Elixir"], frameworks: ["Phoenix"], patterns: ["MVC"]},
        metrics: %{complexity: 7.2, test_coverage: 85}
      }
    },
    "codebase_technologies" => %{
      description: """
      Detect technologies, frameworks, and tools used in the codebase.

      WHEN TO USE:
      - Understanding tech stack ("What frameworks are used?")
      - Dependency analysis ("What databases are connected?")
      - Technology migration planning ("What needs to be updated?")
      - Documentation generation

      EXAMPLES:
      - "What databases are used?" → PostgreSQL, Redis, etc.
      - "What frontend frameworks?" → React, Vue, Angular
      - "What testing tools?" → Jest, ExUnit, pytest

      PERFORMANCE: Medium (pattern matching), good for tech stack overview
      """,
      input_example: %{
        codebase_path: "./",
        include_patterns: true
      },
      output_example: %{
        codebase_path: "./",
        frameworks: ["Phoenix", "React"],
        databases: ["PostgreSQL", "Redis"],
        messaging: ["pgmq"]
      }
    },

    # Planning Tools
    "planning_work_plan" => %{
      description: """
      Get current work plan with strategic themes, epics, capabilities, and features.

      WHEN TO USE:
      - Understanding project roadmap ("What are we building?")
      - Task prioritization ("What should I work on next?")
      - Progress tracking ("How are we doing?")
      - Stakeholder updates

      EXAMPLES:
      - "Show current epics" → List of active epics with status
      - "What features are planned?" → Upcoming feature list
      - "Show strategic themes" → High-level business goals

      PERFORMANCE: Fast (cached data), use for planning context
      """,
      input_example: %{
        level: "epic",
        status: "active"
      },
      output_example: %{
        level: "epic",
        work_plan: %{
          epics: [
            %{name: "User Authentication", status: "in_progress", progress: 60},
            %{name: "API Development", status: "planned", progress: 0}
          ]
        }
      }
    },
    "planning_decompose" => %{
      description: """
      Break down a high-level task into smaller, manageable subtasks using TaskGraph.

      WHEN TO USE:
      - Breaking down large features ("How do I implement user auth?")
      - Task planning ("What steps are needed?")
      - Effort estimation ("How complex is this?")
      - Sprint planning

      EXAMPLES:
      - "Decompose 'Add user authentication'" → Login, registration, sessions, etc.
      - "Break down 'API refactor'" → Endpoints, validation, testing, etc.
      - "Plan 'Database migration'" → Backup, schema changes, testing, etc.

      PERFORMANCE: Medium (AI decomposition), use for complex task planning
      """,
      input_example: %{
        task_description: "Add user authentication system",
        complexity: "medium",
        max_depth: 3
      },
      output_example: %{
        task_description: "Add user authentication system",
        total_tasks: 8,
        tasks: [
          %{name: "Create user model", complexity: "simple"},
          %{name: "Implement login endpoint", complexity: "medium"},
          %{name: "Add session management", complexity: "medium"}
        ]
      }
    },

    # Knowledge Tools
    "knowledge_packages" => %{
      description: """
      Search package registries (npm, cargo, hex, pypi) for libraries and tools.

      WHEN TO USE:
      - Finding libraries ("What React components are available?")
      - Technology research ("What's the best ORM for Elixir?")
      - Dependency selection ("Should I use Express or Fastify?")
      - Package comparison

      EXAMPLES:
      - "Find React UI libraries" → Material-UI, Ant Design, Chakra UI
      - "Search Elixir HTTP clients" → Finch, Req, Tesla
      - "Look for Rust web frameworks" → Actix, Warp, Axum

      PERFORMANCE: Fast (cached registry data), use for library research
      """,
      input_example: %{
        query: "React UI components",
        ecosystem: "npm",
        limit: 5
      },
      output_example: %{
        query: "React UI components",
        packages: [
          %{name: "material-ui", description: "React components", stars: 85000},
          %{name: "ant-design", description: "Enterprise UI library", stars: 90000}
        ]
      }
    },
    "knowledge_patterns" => %{
      description: """
      Find code patterns and templates from existing codebases.

      WHEN TO USE:
      - Learning from existing code ("How do others handle auth?")
      - Pattern recognition ("What's the standard way to...?")
      - Code generation ("Generate a typical CRUD controller")
      - Best practices research

      EXAMPLES:
      - "Find authentication patterns" → Login flows, JWT handling, etc.
      - "Show database query patterns" → ORM usage, query optimization
      - "Look for error handling patterns" → Try/catch, error types

      PERFORMANCE: Medium (semantic search), use for pattern learning
      """,
      input_example: %{
        query: "authentication patterns",
        language: "elixir",
        pattern_type: "semantic"
      },
      output_example: %{
        query: "authentication patterns",
        patterns: [
          %{name: "JWT Authentication", language: "elixir", confidence: 0.92},
          %{name: "Session-based Auth", language: "elixir", confidence: 0.88}
        ]
      }
    },

    # Code Analysis Tools
    "code_refactor" => %{
      description: """
      Analyze code for refactoring opportunities and suggest improvements.

      WHEN TO USE:
      - Code quality issues ("This function is too complex")
      - Technical debt ("What needs refactoring?")
      - Code review ("How can this be improved?")
      - Maintenance planning

      EXAMPLES:
      - "Find refactoring opportunities" → Complex functions, duplicated code
      - "Analyze lib/auth.ex" → Specific file analysis
      - "Check for code smells" → Anti-patterns and issues

      PERFORMANCE: Medium (static analysis), use for code improvement
      """,
      input_example: %{
        codebase_path: "./lib",
        refactor_type: "all",
        severity: "medium"
      },
      output_example: %{
        codebase_path: "./lib",
        analysis: %{
          duplicates: [%{files: ["auth.ex", "session.ex"], similarity: 0.85}],
          complexity: [%{function: "process_data", complexity: 12}]
        }
      }
    },
    "code_quality" => %{
      description: """
      Comprehensive code quality assessment including metrics, patterns, and best practices.

      WHEN TO USE:
      - Overall quality assessment ("How good is this code?")
      - Quality gates ("Does this meet standards?")
      - Improvement planning ("What should we focus on?")
      - Team quality metrics

      EXAMPLES:
      - "Assess code quality" → Overall quality score and issues
      - "Check maintainability" → Code maintainability metrics
      - "Quality report for lib/" → Detailed quality analysis

      PERFORMANCE: Slow (comprehensive analysis), use for quality assessment
      """,
      input_example: %{
        codebase_path: "./lib",
        quality_aspects: ["maintainability", "readability"],
        include_suggestions: true
      },
      output_example: %{
        codebase_path: "./lib",
        quality_score: 8.2,
        analysis: %{
          maintainability: %{score: 8.5, issues: []},
          readability: %{score: 7.8, issues: ["Add comments"]}
        }
      }
    }
  }

  @doc """
  Get enhanced description for a tool.
  """
  def get_description(tool_name) do
    Map.get(@tool_descriptions, tool_name)
  end

  @doc """
  Get all tool descriptions.
  """
  def get_all_descriptions do
    @tool_descriptions
  end

  @doc """
  Get tools grouped by category with descriptions.
  """
  def get_tools_by_category do
    %{
      "codebase_understanding" => %{
        description: "Tools for understanding and exploring codebases",
        tools: [
          "codebase_search",
          "codebase_analyze",
          "codebase_technologies",
          "codebase_dependencies",
          "codebase_services",
          "codebase_architecture"
        ]
      },
      "planning" => %{
        description: "Tools for planning, prioritizing, and managing work",
        tools: [
          "planning_work_plan",
          "planning_decompose",
          "planning_prioritize",
          "planning_estimate",
          "planning_dependencies",
          "planning_execute"
        ]
      },
      "knowledge" => %{
        description: "Tools for searching and managing knowledge, patterns, and examples",
        tools: [
          "knowledge_packages",
          "knowledge_patterns",
          "knowledge_frameworks",
          "knowledge_examples",
          "knowledge_duplicates",
          "knowledge_documentation"
        ]
      },
      "code_analysis" => %{
        description:
          "Tools for analyzing code quality, complexity, and refactoring opportunities",
        tools: [
          "code_refactor",
          "code_complexity",
          "code_todos",
          "code_consolidate",
          "code_language_analyze",
          "code_quality"
        ]
      },
      "summary" => %{
        description: "Tools for generating summaries and overviews",
        tools: ["tools_summary", "codebase_summary", "planning_summary", "knowledge_summary"]
      }
    }
  end
end
