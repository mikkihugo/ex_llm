defmodule Singularity.Tools.CodebaseUnderstanding do
  @moduledoc """
  Agent tools for codebase understanding and analysis.

  Wraps existing powerful analysis capabilities:
  - CodeEngine - NIF-based code analysis and generation
  - CodeSearch - Vector-based code search
  - ArchitectureEngine - Naming and architecture patterns
  - TechnologyAgent - Tech stack detection
  """

  alias Singularity.Tools.{Catalog, Tool}
  alias Singularity.{CodeSearch, TechnologyAgent, CodeEngine}
  alias Singularity.CodeAnalysis.DependencyMapper
  alias Singularity.Code.Analyzers.MicroserviceAnalyzer

  @doc "Register codebase understanding tools with the shared registry."
  def register(provider) do
    Catalog.add_tools(provider, [
      codebase_search_tool(),
      codebase_analyze_tool(),
      codebase_technologies_tool(),
      codebase_dependencies_tool(),
      codebase_services_tool(),
      codebase_architecture_tool()
    ])
  end

  defp codebase_search_tool do
    Tool.new!(%{
      name: "codebase_search",
      description:
        "Search codebase using semantic similarity. Find code by natural language description.",
      display_text: "Semantic Code Search",
      parameters: [
        %{
          name: "query",
          type: :string,
          required: true,
          description: "Natural language search query"
        },
        %{
          name: "codebase_id",
          type: :string,
          required: false,
          description: "Codebase ID (default: current)"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Max results (default: 10)"
        }
      ],
      function: &codebase_search/2
    })
  end

  defp codebase_analyze_tool do
    Tool.new!(%{
      name: "codebase_analyze",
      description:
        "Perform comprehensive codebase analysis including architecture, patterns, and quality metrics.",
      display_text: "Codebase Analysis",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "analysis_type",
          type: :string,
          required: false,
          description: "Type: 'full', 'architecture', 'patterns' (default: 'full')"
        }
      ],
      function: &codebase_analyze/2
    })
  end

  defp codebase_technologies_tool do
    Tool.new!(%{
      name: "codebase_technologies",
      description: "Detect technologies, frameworks, and tools used in the codebase.",
      display_text: "Technology Detection",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "include_patterns",
          type: :boolean,
          required: false,
          description: "Include code patterns (default: true)"
        }
      ],
      function: &codebase_technologies/2
    })
  end

  defp codebase_dependencies_tool do
    Tool.new!(%{
      name: "codebase_dependencies",
      description: "Analyze dependencies and coupling between services/modules.",
      display_text: "Dependency Analysis",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "service_name",
          type: :string,
          required: false,
          description: "Specific service to analyze (optional)"
        }
      ],
      function: &codebase_dependencies/2
    })
  end

  defp codebase_services_tool do
    Tool.new!(%{
      name: "codebase_services",
      description: "Analyze microservices and their structure, dependencies, and health.",
      display_text: "Service Analysis",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "service_type",
          type: :string,
          required: false,
          description: "Filter by type: 'typescript', 'rust', 'python', 'go' (optional)"
        }
      ],
      function: &codebase_services/2
    })
  end

  defp codebase_architecture_tool do
    Tool.new!(%{
      name: "codebase_architecture",
      description: "Get high-level architecture overview and patterns.",
      display_text: "Architecture Overview",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "detail_level",
          type: :string,
          required: false,
          description: "Detail level: 'high', 'medium', 'low' (default: 'medium')"
        }
      ],
      function: &codebase_architecture/2
    })
  end

  # Tool implementations

  def codebase_search(%{"query" => query} = args, _ctx) do
    codebase_id = Map.get(args, "codebase_id", "current")
    limit = Map.get(args, "limit", 10)

    case CodeSearch.semantic_search(Singularity.Repo, codebase_id, query, limit) do
      {:ok, results} ->
        formatted_results =
          Enum.map(results, fn result ->
            %{
              file: result.file_path,
              content: result.content,
              similarity: result.similarity,
              language: result.language,
              line_number: result.line_number
            }
          end)

        {:ok, %{query: query, results: formatted_results, count: length(formatted_results)}}

      {:error, reason} ->
        {:error, "Semantic search failed: #{inspect(reason)}"}
    end
  end

  def codebase_analyze(%{"codebase_path" => path} = args, _ctx) do
    analysis_type = Map.get(args, "analysis_type", "full")

    # Use CodeEngine for codebase analysis
    case CodeEngine.analyze_code(path, "auto") do
      {:ok, analysis} ->
        {:ok,
         %{
           codebase_path: path,
           analysis_type: analysis_type,
           summary: analysis.summary,
           metrics: analysis.metrics,
           patterns: analysis.patterns,
           technologies: analysis.technologies,
           architecture: analysis.architecture
         }}

      {:error, reason} ->
        {:error, "Codebase analysis failed: #{inspect(reason)}"}
    end
  end

  def codebase_technologies(%{"codebase_path" => path} = args, _ctx) do
    include_patterns = Map.get(args, "include_patterns", true)

    case TechnologyAgent.analyze_code_patterns(path, include_patterns: include_patterns) do
      {:ok, technologies} ->
        {:ok,
         %{
           codebase_path: path,
           frameworks: technologies.frameworks,
           databases: technologies.databases,
           messaging: technologies.messaging,
           monitoring: technologies.monitoring,
           security: technologies.security,
           ai_frameworks: technologies.ai_frameworks,
           cloud_platforms: technologies.cloud_platforms,
           architecture_patterns: technologies.architecture_patterns
         }}

      {:error, reason} ->
        {:error, "Technology detection failed: #{inspect(reason)}"}
    end
  end

  def codebase_dependencies(%{"codebase_path" => path} = args, _ctx) do
    service_name = Map.get(args, "service_name")

    case DependencyMapper.analyze_service_coupling(service_name, path) do
      {:ok, analysis} ->
        {:ok,
         %{
           codebase_path: path,
           service_name: service_name,
           coupling_score: analysis.coupling_score,
           dependencies: analysis.dependencies,
           dependents: analysis.dependents,
           recommendations: analysis.recommendations
         }}

      {:error, reason} ->
        {:error, "Dependency analysis failed: #{inspect(reason)}"}
    end
  end

  def codebase_services(%{"codebase_path" => path} = args, _ctx) do
    service_type = Map.get(args, "service_type")

    services =
      case service_type do
        "typescript" -> %{typescript: MicroserviceAnalyzer.analyze_typescript_service(path)}
        "rust" -> %{rust: MicroserviceAnalyzer.analyze_rust_service(path)}
        "python" -> %{python: MicroserviceAnalyzer.analyze_python_service(path)}
        "go" -> %{go: MicroserviceAnalyzer.analyze_go_service(path)}
        _ -> MicroserviceAnalyzer.analyze_services(path)
      end

    {:ok,
     %{
       codebase_path: path,
       service_type: service_type,
       services: services
     }}
  end

  def codebase_architecture(%{"codebase_path" => path} = args, _ctx) do
    detail_level = Map.get(args, "detail_level", "medium")

    # Use CodeEngine for architecture analysis
    case CodeEngine.analyze_code(path, "auto") do
      {:ok, architecture} ->
        filtered_architecture =
          case detail_level do
            "high" -> architecture
            "medium" -> Map.take(architecture, [:overview, :patterns, :layers, :services])
            "low" -> Map.take(architecture, [:overview, :patterns])
          end

        {:ok,
         %{
           codebase_path: path,
           detail_level: detail_level,
           architecture: filtered_architecture
         }}

      {:error, reason} ->
        {:error, "Architecture analysis failed: #{inspect(reason)}"}
    end
  end
end
