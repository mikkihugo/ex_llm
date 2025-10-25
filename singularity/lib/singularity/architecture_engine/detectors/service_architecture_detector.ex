defmodule Singularity.Architecture.Detectors.ServiceArchitectureDetector do
  @moduledoc """
  Service Architecture Pattern Detector - Detects 20+ architecture patterns.

  Implements `@behaviour PatternType` to detect architectural patterns in codebases.
  Replaces the old `MicroserviceAnalyzer` module.

  ## Learning & Maintenance

  **IMPORTANT:** The detection logic (how to identify each pattern) is maintained by the LLM team via CentralCloud:

  1. **This Module (ServiceArchitectureDetector)**: Defines supported pattern types
  2. **CentralCloud (ML Team)**: Maintains detection rules, indicators, heuristics
  3. **Knowledge Base (PostgreSQL)**: Stores learned patterns with confidence scores
  4. **Continuous Learning**: Patterns evolve as codebases are analyzed

  To add/update pattern detection logic:
  - CentralCloud learns from analyzing many codebases
  - Stores detection rules: file patterns, dependencies, config files, code signatures
  - Distributes via NATS → Singularity for local execution
  - No hardcoding detection logic in this module!

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Architecture.Detectors.ServiceArchitectureDetector",
    "type": "detector",
    "purpose": "Detect microservice vs monolith architecture patterns",
    "layer": "architecture_engine",
    "behavior": "PatternType",
    "registered_in": "config :singularity, :pattern_types, service_architecture: ...",
    "scope": "Service boundary detection, architecture classification, deployment patterns"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A[detect/2] --> B[detect_architecture]
      B --> C[discover_services]
      B --> D[detect_service_mesh]
      C --> E[language detection]
      C --> F[build config check]
      E --> G[classify_architecture]
      F --> G
      D --> G
      G --> H[return pattern type]
      H --> I[monolith/modular/distributed/microservices]
  ```

  ## Call Graph (YAML)

  ```yaml
  calls:
    - Singularity.CodeAnalysis.LanguageDetection (service language detection)
    - Singularity.Architecture.PatternStore (confidence tracking)
    - Logger (error handling)

  called_by:
    - Singularity.Architecture.PatternDetector (orchestrator)
    - Architecture assessment pipelines
    - Microservice migration analysis
    - Service boundary discovery
  ```

  ## Anti-Patterns

  - ❌ `MicroserviceAnalyzer` - Use ServiceArchitectureDetector (consolidated)
  - ❌ `ServiceBoundaryDetector` - Use service_architecture detector
  - ✅ Use PatternDetector for discovery
  - ✅ Learn patterns via `learn_pattern/1` callback

  ## Detection Heuristics

  ### Core Styles
  - **Monolith**: Single codebase without service separation
  - **Modular**: 1 service with clear module boundaries
  - **Distributed**: 2-3 independent services
  - **Microservices**: 4+ independent services with separate build/deploy configs

  ### Microservices Implementation Variants
  - **Microservices**: Basic service decomposition
  - **Microservices + Saga**: Distributed transaction coordination via sagas
  - **Microservices + Event Sourcing**: All changes stored as immutable events
  - **Microservices + CQRS**: Separate read and write models

  ### Domain-Driven Design
  - **Domain Driven Design**: Clear bounded contexts with domain modeling
  - **Domain Driven Monolith**: Single app with strong domain boundaries
  - **Subdomain Services**: Services organized by business subdomains

  ### Communication Patterns
  - **Request/Response**: Synchronous HTTP/RPC calls
  - **Publish/Subscribe**: Event-based async communication
  - **Message Queue**: Async messaging via queues (RabbitMQ, NATS, Kafka)

  ### Other Patterns
  - **Event Driven**: Architecture built around event streams
  - **Layered**: Traditional 3-tier, 4-tier architectures
  - **API Gateway**: Unified entry point for services
  - **Service Mesh**: Infrastructure for service-to-service communication
  - **Serverless**: Function-based architecture (Lambda, Cloud Functions)
  - **Peer-to-Peer**: Decentralized services without central coordinator
  - **Hybrid**: Mix of multiple architectural styles

  ## Search Keywords

  service architecture, microservices, monolith detection, service boundaries,
  distributed systems, architecture patterns, deployment patterns, build systems
  """

  @behaviour Singularity.Architecture.PatternType
  require Logger
  alias Singularity.CodeAnalysis.LanguageDetection

  @impl true
  def pattern_type, do: :service_architecture

  @impl true
  def description, do: "Detect microservice vs monolith architecture patterns"

  @impl true
  def supported_types do
    [
      # Core architecture styles
      "monolith",
      "modular",
      "distributed",
      # Microservices variants
      "microservices",
      "microservices_saga",
      "microservices_event_sourcing",
      "microservices_cqrs",
      # Distributed patterns
      "service_mesh",
      "event_driven",
      "layered",
      "api_gateway",
      # Domain-driven patterns
      "domain_driven_design",
      "domain_driven_monolith",
      "subdomain_services",
      # Communication patterns
      "request_response",
      "publish_subscribe",
      "message_queue",
      # Other patterns
      "serverless",
      "peer_to_peer",
      "hybrid"
    ]
  end

  @impl true
  def detect(path, _opts \\ []) when is_binary(path) do
    detect_architecture(path)
  end

  @impl true
  def learn_pattern(result) do
    # Update architecture confidence in PatternStore
    case result do
      %{name: name, success: true} ->
        Singularity.Architecture.PatternStore.update_confidence(:service_architecture, name,
          success: true
        )

      %{name: name, success: false} ->
        Singularity.Architecture.PatternStore.update_confidence(:service_architecture, name,
          success: false
        )

      _ ->
        :ok
    end
  end

  # Private: Architecture detection logic

  defp detect_architecture(path) do
    services = discover_services(path)

    case {length(services), detect_service_mesh(path)} do
      {count, true} when count >= 2 ->
        [
          %{
            name: "microservices_with_service_mesh",
            type: "service_mesh",
            confidence: 0.95,
            description: "Microservices with service mesh (Istio/Consul/Linkerd)",
            metadata: %{service_count: count, services: services}
          }
        ]

      {count, _} when count >= 4 ->
        [
          %{
            name: "microservices",
            type: "microservices",
            confidence: 0.90,
            description: "Microservice architecture",
            metadata: %{service_count: count, services: services}
          }
        ]

      {count, _} when count == 3 ->
        [
          %{
            name: "distributed",
            type: "distributed",
            confidence: 0.85,
            description: "Distributed system with multiple services",
            metadata: %{service_count: count, services: services}
          }
        ]

      {count, _} when count == 2 ->
        [
          %{
            name: "distributed",
            type: "distributed",
            confidence: 0.75,
            description: "Two-service distributed system",
            metadata: %{service_count: count, services: services}
          }
        ]

      {1, _} ->
        [
          %{
            name: "modular",
            type: "modular",
            confidence: 0.80,
            description: "Single service with clear module boundaries",
            metadata: %{service_count: 1}
          }
        ]

      {0, _} ->
        [
          %{
            name: "monolith",
            type: "monolith",
            confidence: 0.70,
            description: "Monolithic single codebase",
            metadata: %{service_count: 0}
          }
        ]
    end
  end

  defp discover_services(root_path) do
    root_path
    |> list_subdirs()
    |> Enum.map(fn service_path ->
      case detect_service(service_path) do
        nil -> nil
        service -> service
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp detect_service(service_path) do
    # A service must have clear build/deploy markers
    case LanguageDetection.detect(service_path) do
      {:ok, language} ->
        if has_build_config?(service_path, language) do
          %{
            path: service_path,
            language: language_name(language),
            build_system: detect_build_system(service_path)
          }
        else
          nil
        end

      {:error, _} ->
        nil
    end
  end

  defp has_build_config?(service_path, language) do
    case language do
      :typescript -> has_any_file?(service_path, ["package.json", "tsconfig.json"])
      :rust -> has_file?(service_path, "Cargo.toml")
      :python -> has_any_file?(service_path, ["pyproject.toml", "setup.py", "requirements.txt"])
      :go -> has_file?(service_path, "go.mod")
      :java -> has_any_file?(service_path, ["pom.xml", "build.gradle"])
      :elixir -> has_file?(service_path, "mix.exs")
      _ -> false
    end
  end

  defp detect_build_system(service_path) do
    cond do
      has_file?(service_path, "package.json") -> "npm"
      has_file?(service_path, "Cargo.toml") -> "cargo"
      has_file?(service_path, "pyproject.toml") -> "poetry"
      has_file?(service_path, "requirements.txt") -> "pip"
      has_file?(service_path, "setup.py") -> "setuptools"
      has_file?(service_path, "go.mod") -> "go"
      has_file?(service_path, "pom.xml") -> "maven"
      has_file?(service_path, "build.gradle") -> "gradle"
      has_file?(service_path, "mix.exs") -> "mix"
      true -> "unknown"
    end
  end

  defp detect_service_mesh(path) do
    has_any_file?(path, [
      "istio.yaml",
      "istio.yml",
      "consul.hcl",
      "linkerd.yaml",
      "linkerd.yml"
    ])
  end

  # Helpers

  defp list_subdirs(root) do
    case File.ls(root) do
      {:ok, entries} ->
        entries
        |> Enum.map(&Path.join(root, &1))
        |> Enum.filter(&File.dir?/1)

      {:error, _} ->
        []
    end
  rescue
    _ -> []
  end

  defp has_file?(path, filename) do
    File.exists?(Path.join(path, filename))
  end

  defp has_any_file?(path, filenames) do
    Enum.any?(filenames, fn f -> has_file?(path, f) end)
  end

  defp language_name(:typescript), do: "TypeScript"
  defp language_name(:javascript), do: "JavaScript"
  defp language_name(:rust), do: "Rust"
  defp language_name(:python), do: "Python"
  defp language_name(:go), do: "Go"
  defp language_name(:elixir), do: "Elixir"
  defp language_name(:java), do: "Java"
  defp language_name(:ruby), do: "Ruby"
  defp language_name(other), do: Atom.to_string(other)
end
