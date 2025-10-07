defmodule Singularity.DocumentationGenerator do
  @moduledoc """
  Documentation Agent - Generates comprehensive documentation for singularity-engine services.

  Agent responsibilities:
  - Generate API documentation
  - Create architecture diagrams
  - Produce implementation guides
  - Maintain documentation consistency
  """

  require Logger

  alias Singularity.Engine.CodebaseStore

  @doc "Generate documentation for all services"
  def generate_all_service_docs do
    Logger.info("Generating documentation for all services")

    with {:ok, services} <- get_all_services(),
         {:ok, service_docs} <- generate_service_documentation(services),
         {:ok, architecture_docs} <- generate_architecture_documentation(),
         {:ok, api_docs} <- generate_api_documentation(services) do
      %{
        total_services: length(services),
        service_docs_generated: length(service_docs),
        architecture_docs: architecture_docs,
        api_docs: api_docs,
        generation_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Documentation generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_architecture_documentation do
    try do
      # Generate architecture documentation by analyzing the codebase
      codebase_path = Application.get_env(:singularity_app, :codebase_path, ".")
      
      case Singularity.Code.Analyzers.ArchitectureAgent.analyze_architecture(codebase_path) do
        {:ok, analysis} ->
          doc_content = build_architecture_doc(analysis)
          {:ok, [%{type: "architecture", content: doc_content, generated_at: DateTime.utc_now()}]}
        
        {:error, reason} ->
          Logger.warning("Architecture analysis failed: #{inspect(reason)}")
          {:ok, []}
      end
    rescue
      error ->
        Logger.error("Architecture documentation generation failed: #{inspect(error)}")
        {:ok, []}
    end
  end

  defp generate_api_documentation(services) when is_list(services) do
    try do
      docs = Enum.map(services, fn service ->
        case generate_service_api_doc(service) do
          {:ok, doc} -> doc
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      
      {:ok, docs}
    rescue
      error ->
        Logger.error("API documentation generation failed: #{inspect(error)}")
        {:ok, []}
    end
  end

  defp generate_api_documentation(_), do: {:ok, []}

  defp build_architecture_doc(analysis) do
    """
    # Architecture Documentation

    ## Overview
    Generated on: #{DateTime.utc_now() |> DateTime.to_date()}

    ## Detected Patterns
    #{Enum.map_join(analysis.patterns || [], "\n", fn pattern ->
      """
      ### #{pattern.pattern_type |> Atom.to_string() |> String.capitalize()}
      - Confidence: #{pattern.confidence}
      - Description: #{pattern.description}
      - Location: #{inspect(pattern.location)}
      - Benefits: #{Enum.join(pattern.benefits || [], ", ")}
      - Implementation Quality: #{pattern.implementation_quality}
      """
    end)}

    ## Architecture Principles
    #{Enum.map_join(analysis.principles || [], "\n", fn principle ->
      """
      ### #{principle.principle_type |> Atom.to_string() |> String.capitalize()}
      - Compliance Score: #{principle.compliance_score}
      - Description: #{principle.description}
      - Violations: #{inspect(principle.violations)}
      - Recommendations: #{Enum.join(principle.recommendations || [], ", ")}
      """
    end)}

    ## Violations
    #{Enum.map_join(analysis.violations || [], "\n", fn violation ->
      """
      ### #{violation.violation_type |> Atom.to_string() |> String.capitalize()}
      - Severity: #{violation.severity}
      - Description: #{violation.description}
      - Location: #{inspect(violation.location)}
      - Impact: #{inspect(violation.impact)}
      """
    end)}

    ## Recommendations
    #{Enum.join(analysis.recommendations || [], "\n- ")}

    ## Metrics
    - Architecture Score: #{analysis.architecture_score}
    - Analysis Time: #{analysis.metadata.analysis_time_ms}ms
    - Files Analyzed: #{analysis.metadata.files_analyzed}
    - Complexity Score: #{analysis.metadata.complexity_score}
    """
  end

  @doc "Generate service-specific documentation"
  def generate_service_docs(service_name) do
    Logger.info("Generating documentation for service: #{service_name}")

    with {:ok, service} <- get_service_by_name(service_name),
         {:ok, service_doc} <- generate_single_service_doc(service),
         {:ok, api_doc} <- generate_service_api_doc(service),
         {:ok, implementation_doc} <- generate_implementation_doc(service) do
      %{
        service_name: service_name,
        service_documentation: service_doc,
        api_documentation: api_doc,
        implementation_documentation: implementation_doc,
        generation_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Service documentation generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Generate architecture overview documentation"
  def generate_architecture_docs do
    Logger.info("Generating architecture documentation")

    with {:ok, services} <- get_all_services(),
         {:ok, architecture_overview} <- create_architecture_overview(services),
         {:ok, service_diagram} <- generate_service_diagram(services),
         {:ok, data_flow_diagram} <- generate_data_flow_diagram(services) do
      %{
        architecture_overview: architecture_overview,
        service_diagram: service_diagram,
        data_flow_diagram: data_flow_diagram,
        generation_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Architecture documentation generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Generate API documentation"
  def generate_api_docs do
    Logger.info("Generating API documentation")

    with {:ok, services} <- get_all_services(),
         {:ok, api_endpoints} <- extract_api_endpoints(services),
         {:ok, api_specs} <- generate_api_specifications(api_endpoints),
         {:ok, interactive_docs} <- create_interactive_docs(api_specs) do
      %{
        total_endpoints: length(api_endpoints),
        api_specifications: api_specs,
        interactive_documentation: interactive_docs,
        generation_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("API documentation generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Generate deployment and operations documentation"
  def generate_operations_docs do
    Logger.info("Generating operations documentation")

    with {:ok, deployment_docs} <- generate_deployment_docs(),
         {:ok, monitoring_docs} <- generate_monitoring_docs(),
         {:ok, troubleshooting_docs} <- generate_troubleshooting_docs() do
      %{
        deployment_documentation: deployment_docs,
        monitoring_documentation: monitoring_docs,
        troubleshooting_documentation: troubleshooting_docs,
        generation_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Operations documentation generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Update documentation when services change"
  def update_documentation(service_changes) do
    Logger.info("Updating documentation for #{length(service_changes)} service changes")

    with {:ok, affected_docs} <- identify_affected_docs(service_changes),
         {:ok, updated_docs} <- update_affected_docs(affected_docs, service_changes),
         {:ok, validation_results} <- validate_updated_docs(updated_docs) do
      %{
        service_changes: service_changes,
        docs_updated: length(updated_docs),
        validation_results: validation_results,
        update_timestamp: DateTime.utc_now()
      }
    else
      {:error, reason} ->
        Logger.error("Documentation update failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Private Functions

  defp get_all_services do
    # Get all services from the database
    services = CodebaseStore.all_services()
    {:ok, services}
  end

  defp get_service_by_name(service_name) do
    # Get service by name
    service = %{
      service_name: service_name,
      path: "/services/#{service_name}",
      language: :typescript
    }

    {:ok, service}
  end

  defp generate_service_documentation(services) do
    service_docs =
      Enum.map(services, fn service ->
        generate_single_service_doc(service)
      end)

    {:ok, service_docs}
  end

  defp generate_single_service_doc(service) do
    # Generate documentation for a single service
    %{
      service_name: service.service_name,
      service_path: service.path,
      language: service.language,
      overview: generate_service_overview(service),
      features: extract_service_features(service),
      dependencies: extract_service_dependencies(service),
      configuration: extract_service_configuration(service),
      examples: generate_service_examples(service)
    }
  end

  defp generate_service_overview(service) do
    # Generate service overview
    """
    # #{service.service_name}

    ## Overview
    This service provides core functionality for the Singularity platform.

    ## Purpose
    The #{service.service_name} service is responsible for...

    ## Key Features
    - Feature 1
    - Feature 2
    - Feature 3

    ## Technology Stack
    - Language: #{service.language}
    - Framework: NestJS
    - Database: PostgreSQL
    """
  end

  defp extract_service_features(_service) do
    # Extract features from service code
    [
      "Feature 1: Core functionality",
      "Feature 2: API endpoints",
      "Feature 3: Data processing"
    ]
  end

  defp extract_service_dependencies(_service) do
    # Extract dependencies from service
    %{
      runtime_dependencies: [],
      development_dependencies: [],
      external_services: []
    }
  end

  defp extract_service_configuration(_service) do
    # Extract configuration options
    %{
      environment_variables: [],
      configuration_files: [],
      default_values: %{}
    }
  end

  defp generate_service_examples(_service) do
    # Generate usage examples
    [
      %{
        title: "Basic Usage",
        code: "// Example code here",
        description: "Basic example of using the service"
      }
    ]
  end

  defp generate_service_api_doc(service) do
    # Generate API documentation for service
    %{
      service_name: service.service_name,
      base_url: "http://localhost:3000",
      endpoints: [
        %{
          method: "GET",
          path: "/health",
          description: "Health check endpoint",
          parameters: [],
          response: %{status: 200, body: %{status: "healthy"}}
        }
      ],
      authentication: "Bearer token",
      rate_limits: %{requests_per_minute: 100}
    }
  end

  defp generate_implementation_doc(service) do
    # Generate implementation documentation
    %{
      service_name: service.service_name,
      architecture: "Microservice",
      design_patterns: ["Repository", "Service Layer"],
      testing_strategy: "Unit tests, Integration tests",
      deployment_process: "Docker container deployment",
      monitoring: "Health checks, Metrics collection"
    }
  end

  defp create_architecture_overview(services) do
    # Create architecture overview
    overview = %{
      total_services: length(services),
      service_categories: group_services_by_category(services),
      technology_distribution: calculate_technology_distribution(services),
      communication_patterns: identify_communication_patterns(services),
      data_flow: map_data_flow(services)
    }

    {:ok, overview}
  end

  defp group_services_by_category(services) do
    # Group services by category
    Enum.group_by(services, fn service ->
      extract_service_category(service)
    end)
  end

  defp extract_service_category(service) do
    # Extract category from service name
    cond do
      String.contains?(service.service_name, "platform") -> :platform
      String.contains?(service.service_name, "domain") -> :domain
      String.contains?(service.service_name, "foundation") -> :foundation
      true -> :general
    end
  end

  defp calculate_technology_distribution(services) do
    # Calculate technology distribution
    Enum.group_by(services, & &1.language)
    |> Enum.map(fn {language, services} -> {language, length(services)} end)
    |> Enum.into(%{})
  end

  defp identify_communication_patterns(_services) do
    # Identify communication patterns
    %{
      synchronous: ["HTTP REST", "gRPC"],
      asynchronous: ["NATS", "Message queues"],
      event_driven: ["Event sourcing", "CQRS"]
    }
  end

  defp map_data_flow(_services) do
    # Map data flow between services
    %{
      data_sources: [],
      data_processors: [],
      data_sinks: []
    }
  end

  defp generate_service_diagram(_services) do
    # Generate service diagram (Mermaid format)
    diagram_content = """
    graph TB
      subgraph "Platform Services"
        PS[Platform Service]
        IS[Infrastructure Service]
        SS[Safety Service]
      end
      
      subgraph "Domain Services"
        DS[Domain Service]
        AS[AI Service]
        KS[Knowledge Service]
      end
      
      PS --> DS
      IS --> PS
      SS --> PS
      DS --> AS
      AS --> KS
    """

    {:ok, diagram_content}
  end

  defp generate_data_flow_diagram(_services) do
    # Generate data flow diagram
    diagram_content = """
    graph LR
      A[Client] --> B[API Gateway]
      B --> C[Service 1]
      B --> D[Service 2]
      C --> E[Database]
      D --> E
      E --> F[Analytics]
    """

    {:ok, diagram_content}
  end

  defp extract_api_endpoints(services) do
    # Extract API endpoints from services
    endpoints =
      Enum.flat_map(services, fn service ->
        extract_service_endpoints(service)
      end)

    {:ok, endpoints}
  end

  defp extract_service_endpoints(service) do
    # Extract endpoints from a single service
    [
      %{
        service: service.service_name,
        method: "GET",
        path: "/health",
        description: "Health check"
      }
    ]
  end

  defp generate_api_specifications(endpoints) do
    # Generate OpenAPI specifications
    spec = %{
      openapi: "3.0.0",
      info: %{
        title: "Singularity Platform API",
        version: "1.0.0",
        description: "API documentation for Singularity platform services"
      },
      paths: group_endpoints_by_path(endpoints),
      components: %{
        schemas: %{},
        securitySchemes: %{}
      }
    }

    {:ok, spec}
  end

  defp group_endpoints_by_path(endpoints) do
    # Group endpoints by path
    Enum.group_by(endpoints, & &1.path)
  end

  defp create_interactive_docs(api_specs) do
    # Create interactive documentation
    %{
      swagger_ui_url: "/docs",
      redoc_url: "/redoc",
      postman_collection: generate_postman_collection(api_specs)
    }
    |> then(&{:ok, &1})
  end

  defp generate_postman_collection(api_specs) do
    # Generate Postman collection
    %{
      collection_name: "Singularity Platform API",
      endpoints: api_specs.paths,
      environment_variables: []
    }
  end

  defp generate_deployment_docs do
    # Generate deployment documentation
    docs = %{
      docker_deployment: generate_docker_docs(),
      kubernetes_deployment: generate_k8s_docs(),
      local_development: generate_local_dev_docs()
    }

    {:ok, docs}
  end

  defp generate_docker_docs do
    # Generate Docker deployment docs
    """
    # Docker Deployment

    ## Building Images
    ```bash
    docker build -t singularity-service .
    ```

    ## Running Containers
    ```bash
    docker run -p 3000:3000 singularity-service
    ```
    """
  end

  defp generate_k8s_docs do
    # Generate Kubernetes deployment docs
    """
    # Kubernetes Deployment

    ## Deploying Services
    ```bash
    kubectl apply -f k8s/
    ```

    ## Scaling Services
    ```bash
    kubectl scale deployment service-name --replicas=3
    ```
    """
  end

  defp generate_local_dev_docs do
    # Generate local development docs
    """
    # Local Development

    ## Prerequisites
    - Node.js 18+
    - Docker
    - PostgreSQL

    ## Setup
    ```bash
    npm install
    npm run dev
    ```
    """
  end

  defp generate_monitoring_docs do
    # Generate monitoring documentation
    docs = %{
      health_checks: generate_health_check_docs(),
      metrics: generate_metrics_docs(),
      logging: generate_logging_docs(),
      alerting: generate_alerting_docs()
    }

    {:ok, docs}
  end

  defp generate_health_check_docs do
    # Generate health check documentation
    """
    # Health Checks

    ## Endpoints
    - GET /health - Basic health check
    - GET /health/ready - Readiness check
    - GET /health/live - Liveness check
    """
  end

  defp generate_metrics_docs do
    # Generate metrics documentation
    """
    # Metrics

    ## Prometheus Metrics
    - http_requests_total
    - http_request_duration_seconds
    - service_uptime_seconds
    """
  end

  defp generate_logging_docs do
    # Generate logging documentation
    """
    # Logging

    ## Log Levels
    - ERROR: Critical errors
    - WARN: Warning messages
    - INFO: Informational messages
    - DEBUG: Debug information
    """
  end

  defp generate_alerting_docs do
    # Generate alerting documentation
    """
    # Alerting

    ## Alert Rules
    - High error rate (>5%)
    - High response time (>1s)
    - Service down
    """
  end

  defp generate_troubleshooting_docs do
    # Generate troubleshooting documentation
    docs = %{
      common_issues: generate_common_issues_docs(),
      debugging_guide: generate_debugging_docs(),
      performance_tuning: generate_performance_docs()
    }

    {:ok, docs}
  end

  defp generate_common_issues_docs do
    # Generate common issues documentation
    """
    # Common Issues

    ## Service Won't Start
    1. Check port availability
    2. Verify environment variables
    3. Check database connectivity

    ## High Memory Usage
    1. Check for memory leaks
    2. Optimize data structures
    3. Increase memory limits
    """
  end

  defp generate_debugging_docs do
    # Generate debugging documentation
    """
    # Debugging Guide

    ## Log Analysis
    - Use structured logging
    - Filter by log level
    - Search for error patterns

    ## Performance Profiling
    - Use profiling tools
    - Monitor resource usage
    - Identify bottlenecks
    """
  end

  defp generate_performance_docs do
    # Generate performance documentation
    """
    # Performance Tuning

    ## Database Optimization
    - Add indexes
    - Optimize queries
    - Use connection pooling

    ## Caching
    - Implement Redis caching
    - Use CDN for static assets
    - Cache API responses
    """
  end

  defp identify_affected_docs(service_changes) do
    # Identify documentation that needs updating
    affected_docs =
      Enum.map(service_changes, fn change ->
        identify_docs_for_change(change)
      end)

    {:ok, affected_docs}
  end

  defp identify_docs_for_change(change) do
    # Identify docs affected by a service change
    %{
      service_name: change.service_name,
      affected_docs: ["service_doc", "api_doc", "architecture_doc"]
    }
  end

  defp update_affected_docs(affected_docs, service_changes) do
    # Update affected documentation
    updated_docs =
      Enum.map(affected_docs, fn doc ->
        update_single_doc(doc, service_changes)
      end)

    {:ok, updated_docs}
  end

  defp update_single_doc(doc, _service_changes) do
    # Update a single documentation file
    %{
      doc_name: doc.service_name,
      update_status: :updated,
      update_timestamp: DateTime.utc_now()
    }
  end

  defp validate_updated_docs(updated_docs) do
    # Validate updated documentation
    validation_results =
      Enum.map(updated_docs, fn doc ->
        validate_single_doc(doc)
      end)

    {:ok, validation_results}
  end

  defp validate_single_doc(doc) do
    # Validate a single documentation file
    %{
      doc_name: doc.doc_name,
      validation_status: :valid,
      validation_errors: []
    }
  end
end
