defmodule Singularity.AdvancedAnalyzer do
  @moduledoc """
  Advanced Codebase Analyzer - Intelligent Technology Detection and Discovery

  This module provides sophisticated codebase analysis capabilities including:

  - Dynamic technology discovery
  - Unknown framework detection
  - Confidence-based scoring
  - Pattern analysis
  - Import analysis
  - API pattern discovery
  - Data pattern discovery
  - Workflow pattern discovery

  ## Features

  ### Dynamic Discovery
  - Discovers unknown technologies by analyzing patterns
  - Detects custom frameworks and build systems
  - Identifies unrecognized file extensions and structures

  ### Advanced Analysis
  - Import pattern analysis across languages
  - API endpoint discovery
  - Data flow pattern detection
  - Workflow and process pattern analysis

  ### Confidence Scoring
  - Multi-factor confidence calculation
  - Pattern matching (60% weight)
  - Config file detection (25% weight)
  - Dependency analysis (15% weight)

  ## Usage

      # Detect all technologies with dynamic discovery
      {:ok, result} = Singularity.AdvancedAnalyzer.detect_technologies("/path/to/codebase")
      
      # Get discovered unknown technologies
      unknown_techs = result.discovered_technologies
      
      # Analyze import patterns
      import_patterns = result.import_patterns
      
      # Discover API patterns
      api_patterns = result.api_patterns
  """

  @doc """
  Detect technologies with advanced dynamic discovery capabilities.

  Returns a comprehensive analysis including:
  - Known technologies with confidence scores
  - Discovered unknown technologies
  - Import patterns
  - API patterns
  - Data patterns
  - Workflow patterns
  """
  def detect_technologies(codebase_path) do
    # Use the advanced TechnologyDetector with dynamic discovery
    Singularity.TechnologyDetector.detect_technologies(codebase_path)
  end

  @doc """
  Discover unknown technologies by analyzing patterns not in our known registry.

  This function analyzes:
  - Unrecognized file extensions
  - Custom directory structures
  - Unknown configuration formats
  - Unusual build patterns
  - Custom frameworks
  - Dynamic technology patterns from actual code
  """
  def discover_unknown_technologies(codebase_path) do
    # Analyze file extensions
    unknown_extensions = discover_unknown_file_extensions(codebase_path)

    # Analyze directory structures
    unknown_structures = discover_unknown_directory_structures(codebase_path)

    # Analyze configuration patterns
    unknown_configs = discover_unknown_config_patterns(codebase_path)

    # Analyze build patterns
    unknown_builds = discover_unknown_build_patterns(codebase_path)

    # Analyze actual code patterns for dynamic technology discovery
    dynamic_technologies = discover_dynamic_technologies(codebase_path)

    # Combine and score discoveries
    combine_unknown_discoveries([
      unknown_extensions,
      unknown_structures,
      unknown_configs,
      unknown_builds,
      dynamic_technologies
    ])
  end

  @doc """
  Analyze import patterns across all languages in the codebase.

  Discovers:
  - Import statements and their patterns
  - Module dependencies
  - Package usage patterns
  - Cross-language imports
  """
  def analyze_import_patterns(codebase_path) do
    source_files = find_source_files(codebase_path)

    import_patterns = %{
      javascript_imports: analyze_javascript_imports(source_files),
      python_imports: analyze_python_imports(source_files),
      rust_imports: analyze_rust_imports(source_files),
      elixir_imports: analyze_elixir_imports(source_files),
      go_imports: analyze_go_imports(source_files),
      cross_language_imports: analyze_cross_language_imports(source_files)
    }

    # Calculate import complexity and patterns
    complexity_analysis = analyze_import_complexity(import_patterns)

    Map.put(import_patterns, :complexity_analysis, complexity_analysis)
  end

  @doc """
  Discover API patterns in the codebase.

  Finds:
  - REST API endpoints
  - GraphQL schemas
  - RPC interfaces
  - WebSocket connections
  - gRPC services
  - Custom API patterns
  """
  def discover_api_patterns(codebase_path) do
    source_files = find_source_files(codebase_path)

    api_patterns = %{
      rest_endpoints: discover_rest_endpoints(source_files),
      graphql_schemas: discover_graphql_schemas(source_files),
      rpc_interfaces: discover_rpc_interfaces(source_files),
      websocket_connections: discover_websocket_connections(source_files),
      grpc_services: discover_grpc_services(source_files),
      custom_apis: discover_custom_api_patterns(source_files)
    }

    # Analyze API architecture patterns
    architecture_analysis = analyze_api_architecture(api_patterns)

    Map.put(api_patterns, :architecture_analysis, architecture_analysis)
  end

  @doc """
  Discover data patterns in the codebase.

  Identifies:
  - Database schemas and migrations
  - Data models and entities
  - Serialization formats
  - Data validation patterns
  - Data transformation pipelines
  """
  def discover_data_patterns(codebase_path) do
    source_files = find_source_files(codebase_path)

    data_patterns = %{
      database_schemas: discover_database_schemas(source_files),
      data_models: discover_data_models(source_files),
      serialization_formats: discover_serialization_formats(source_files),
      validation_patterns: discover_validation_patterns(source_files),
      transformation_pipelines: discover_transformation_pipelines(source_files)
    }

    # Analyze data flow patterns
    data_flow_analysis = analyze_data_flow_patterns(data_patterns)

    Map.put(data_patterns, :data_flow_analysis, data_flow_analysis)
  end

  @doc """
  Discover workflow patterns in the codebase.

  Finds:
  - Business process patterns
  - Workflow engines
  - State machines
  - Event handlers
  - Process orchestration
  - BPMN processes (singularity-engine specific)
  - Sandbox frameworks (E2B, Firecracker, Modal)
  - AI workflows and orchestration
  - MCP servers and toolchains
  - Vector databases and embeddings
  """
  def discover_workflow_patterns(codebase_path) do
    source_files = find_source_files(codebase_path)

    workflow_patterns = %{
      business_processes: discover_business_processes(source_files),
      workflow_engines: discover_workflow_engines(source_files),
      state_machines: discover_state_machines(source_files),
      event_handlers: discover_event_handlers(source_files),
      process_orchestration: discover_process_orchestration(source_files),
      # Singularity-engine specific patterns
      bpmn_processes: discover_bpmn_processes(source_files),
      sandbox_frameworks: discover_sandbox_frameworks(source_files),
      ai_workflows: discover_ai_workflows(source_files),
      mcp_servers: discover_mcp_servers(source_files),
      vector_databases: discover_vector_databases(source_files)
    }

    # Analyze workflow complexity
    workflow_analysis = analyze_workflow_complexity(workflow_patterns)

    Map.put(workflow_patterns, :workflow_analysis, workflow_analysis)
  end

  ## Private Functions

  defp discover_unknown_file_extensions(codebase_path) do
    all_files =
      Path.wildcard(Path.join(codebase_path, "**/*"))
      |> Enum.filter(&File.regular?/1)

    # Known extensions
    known_extensions = [
      ".js",
      ".jsx",
      ".ts",
      ".tsx",
      ".vue",
      ".svelte",
      ".py",
      ".rs",
      ".go",
      ".java",
      ".cs",
      ".php",
      ".ex",
      ".exs",
      ".gleam",
      ".erl",
      ".hrl",
      ".json",
      ".yaml",
      ".yml",
      ".toml",
      ".xml",
      ".md",
      ".txt",
      ".log",
      ".conf",
      ".config"
    ]

    # Find unknown extensions
    unknown_extensions =
      all_files
      |> Enum.map(&Path.extname/1)
      |> Enum.uniq()
      |> Enum.reject(fn ext -> ext in known_extensions or ext == "" end)

    # Analyze patterns in unknown extensions
    Enum.map(unknown_extensions, fn ext ->
      files_with_ext = Enum.filter(all_files, &String.ends_with?(&1, ext))

      %{
        extension: ext,
        file_count: length(files_with_ext),
        sample_files: Enum.take(files_with_ext, 5),
        confidence: calculate_extension_confidence(files_with_ext),
        patterns: analyze_extension_patterns(files_with_ext)
      }
    end)
  end

  defp discover_unknown_directory_structures(codebase_path) do
    directories =
      Path.wildcard(Path.join(codebase_path, "**/"))
      |> Enum.filter(&File.dir?/1)

    # Known directory patterns
    known_patterns = [
      "src/",
      "lib/",
      "app/",
      "test/",
      "tests/",
      "spec/",
      "node_modules/",
      "target/",
      ".git/",
      "dist/",
      "build/",
      "public/",
      "assets/",
      "config/",
      "docs/",
      "scripts/"
    ]

    # Find unusual directory structures
    unusual_dirs =
      directories
      |> Enum.reject(fn dir ->
        Enum.any?(known_patterns, fn pattern ->
          String.contains?(dir, pattern)
        end)
      end)

    # Analyze directory patterns
    Enum.map(unusual_dirs, fn dir ->
      files_in_dir =
        Path.wildcard(Path.join(dir, "*"))
        |> Enum.filter(&File.regular?/1)

      %{
        directory: dir,
        file_count: length(files_in_dir),
        file_types: analyze_directory_file_types(files_in_dir),
        confidence: calculate_directory_confidence(files_in_dir),
        patterns: analyze_directory_patterns(files_in_dir)
      }
    end)
  end

  defp discover_unknown_config_patterns(codebase_path) do
    config_files =
      Path.wildcard(Path.join(codebase_path, "**/*"))
      |> Enum.filter(&File.regular?/1)
      |> Enum.filter(fn file ->
        filename = Path.basename(file)

        String.contains?(filename, "config") or
          String.contains?(filename, "conf") or
          String.contains?(filename, "settings") or
          String.contains?(filename, "env")
      end)

    # Known config patterns
    known_configs = [
      "package.json",
      "tsconfig.json",
      "webpack.config.js",
      "vite.config.js",
      "next.config.js",
      "nuxt.config.js",
      "mix.exs",
      "rebar.config",
      "gleam.toml",
      "Cargo.toml",
      "go.mod",
      "requirements.txt",
      "pyproject.toml",
      "setup.py",
      "pom.xml",
      "build.gradle",
      "composer.json",
      "Gemfile"
    ]

    # Find unknown config files
    unknown_configs =
      config_files
      |> Enum.reject(fn file ->
        filename = Path.basename(file)
        filename in known_configs
      end)

    # Analyze unknown config patterns
    Enum.map(unknown_configs, fn config_file ->
      case File.read(config_file) do
        {:ok, content} ->
          %{
            file: config_file,
            format: detect_config_format(content),
            patterns: analyze_config_patterns(content),
            confidence: calculate_config_confidence(content),
            size: byte_size(content)
          }

        _ ->
          %{
            file: config_file,
            format: "unknown",
            patterns: [],
            confidence: 0.1,
            size: 0
          }
      end
    end)
  end

  defp discover_unknown_build_patterns(codebase_path) do
    build_files =
      Path.wildcard(Path.join(codebase_path, "**/*"))
      |> Enum.filter(&File.regular?/1)
      |> Enum.filter(fn file ->
        filename = Path.basename(file)

        String.contains?(filename, "build") or
          String.contains?(filename, "make") or
          String.contains?(filename, "script") or
          String.contains?(filename, "task")
      end)

    # Known build patterns
    known_builds = [
      "Makefile",
      "makefile",
      "CMakeLists.txt",
      "build.sh",
      "build.bat",
      "compile.sh",
      "webpack.config.js",
      "rollup.config.js",
      "vite.config.js",
      "esbuild.config.js"
    ]

    # Find unknown build files
    unknown_builds =
      build_files
      |> Enum.reject(fn file ->
        filename = Path.basename(file)
        filename in known_builds
      end)

    # Analyze unknown build patterns
    Enum.map(unknown_builds, fn build_file ->
      case File.read(build_file) do
        {:ok, content} ->
          %{
            file: build_file,
            patterns: analyze_build_patterns(content),
            confidence: calculate_build_confidence(content),
            commands: extract_build_commands(content),
            size: byte_size(content)
          }

        _ ->
          %{
            file: build_file,
            patterns: [],
            confidence: 0.1,
            commands: [],
            size: 0
          }
      end
    end)
  end

  defp discover_dynamic_technologies(codebase_path) do
    source_files = find_source_files(codebase_path)

    # Analyze code patterns to discover technologies dynamically
    dynamic_discoveries = %{
      # Discover technologies from actual code patterns
      bpmn_technologies: discover_bpmn_from_code(source_files),
      sandbox_technologies: discover_sandbox_from_code(source_files),
      ai_technologies: discover_ai_from_code(source_files),
      messaging_technologies: discover_messaging_from_code(source_files),
      database_technologies: discover_database_from_code(source_files),
      build_technologies: discover_build_from_code(source_files),
      deployment_technologies: discover_deployment_from_code(source_files),
      monitoring_technologies: discover_monitoring_from_code(source_files),
      security_technologies: discover_security_from_code(source_files),
      cloud_technologies: discover_cloud_from_code(source_files)
    }

    # Calculate confidence scores for each discovery
    Enum.map(dynamic_discoveries, fn {category, discoveries} ->
      {category,
       Enum.map(discoveries, fn discovery ->
         Map.put(discovery, :confidence, calculate_dynamic_confidence(discovery))
       end)}
    end)
  end

  defp discover_bpmn_from_code(files) do
    bpmn_patterns = [
      ~r/bpmn|BPMN/i,
      ~r/process.*definition/i,
      ~r/workflow.*engine/i,
      ~r/process.*instance/i,
      ~r/process.*deployment/i,
      ~r/process.*execution/i,
      ~r/process.*repository/i,
      ~r/process.*variables/i,
      ~r/process.*metadata/i,
      ~r/process.*state/i,
      ~r/process.*event/i,
      ~r/process.*task/i,
      ~r/process.*gateway/i,
      ~r/process.*sequence/i,
      ~r/process.*flow/i,
      ~r/business.*process/i,
      ~r/process.*orchestration/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            bpmn_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{
                technology: "BPMN Process Engine",
                pattern: pattern,
                file: file,
                type: "Workflow Engine",
                evidence: extract_pattern_context(content, pattern)
              }
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_sandbox_from_code(files) do
    sandbox_patterns = [
      ~r/sandbox.*framework/i,
      ~r/sandbox.*provider/i,
      ~r/sandbox.*instance/i,
      ~r/sandbox.*config/i,
      ~r/sandbox.*execution/i,
      ~r/sandbox.*security/i,
      ~r/sandbox.*isolation/i,
      ~r/e2b|E2B/i,
      ~r/firecracker|Firecracker/i,
      ~r/modal|Modal/i,
      ~r/sandbox.*pool/i,
      ~r/sandbox.*selector/i,
      ~r/sandbox.*metrics/i,
      ~r/sandbox.*logs/i,
      ~r/sandbox.*lifecycle/i,
      ~r/sandbox.*capabilities/i,
      ~r/sandbox.*limits/i,
      ~r/sandbox.*cost/i,
      ~r/secure.*execution/i,
      ~r/isolated.*execution/i,
      ~r/container.*execution/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            sandbox_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{
                technology: "Sandbox Framework",
                pattern: pattern,
                file: file,
                type: "Security Layer",
                evidence: extract_pattern_context(content, pattern)
              }
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_ai_from_code(files) do
    ai_patterns = [
      ~r/ai.*framework/i,
      ~r/ai.*integration/i,
      ~r/ai.*service/i,
      ~r/ai.*task/i,
      ~r/ai.*orchestration/i,
      ~r/ai.*pipeline/i,
      ~r/ai.*model/i,
      ~r/ai.*inference/i,
      ~r/ai.*training/i,
      ~r/ai.*deployment/i,
      ~r/ai.*monitoring/i,
      ~r/ai.*scaling/i,
      ~r/ai.*load.*balancing/i,
      ~r/ai.*resource.*management/i,
      ~r/ai.*cost.*optimization/i,
      ~r/ai.*performance/i,
      ~r/ai.*metrics/i,
      ~r/ai.*logging/i,
      ~r/ai.*debugging/i,
      ~r/machine.*learning/i,
      ~r/ml.*pipeline/i,
      ~r/neural.*network/i,
      ~r/deep.*learning/i,
      ~r/llm|LLM/i,
      ~r/large.*language.*model/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            ai_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{
                technology: "AI Framework",
                pattern: pattern,
                file: file,
                type: "AI/ML",
                evidence: extract_pattern_context(content, pattern)
              }
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_messaging_from_code(files) do
    messaging_patterns = [
      ~r/nats.*jetstream/i,
      ~r/jetstream.*nats/i,
      ~r/nats.*streaming/i,
      ~r/nats.*cluster/i,
      ~r/event.*bus/i,
      ~r/bus.*event/i,
      ~r/event.*stream/i,
      ~r/stream.*event/i,
      ~r/event.*pipeline/i,
      ~r/pipeline.*event/i,
      ~r/event.*orchestration/i,
      ~r/orchestration.*event/i,
      ~r/service.*mesh/i,
      ~r/mesh.*service/i,
      ~r/service.*discovery/i,
      ~r/discovery.*service/i,
      ~r/service.*registry/i,
      ~r/registry.*service/i,
      ~r/service.*communication/i,
      ~r/communication.*service/i,
      ~r/message.*queue/i,
      ~r/queue.*message/i,
      ~r/pub.*sub/i,
      ~r/publish.*subscribe/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            messaging_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{
                technology: "Messaging System",
                pattern: pattern,
                file: file,
                type: "Communication",
                evidence: extract_pattern_context(content, pattern)
              }
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_database_from_code(files) do
    database_patterns = [
      ~r/vector.*database/i,
      ~r/vector.*search/i,
      ~r/vector.*embedding/i,
      ~r/vector.*index/i,
      ~r/vector.*similarity/i,
      ~r/vector.*distance/i,
      ~r/vector.*query/i,
      ~r/vector.*storage/i,
      ~r/vector.*retrieval/i,
      ~r/vector.*matching/i,
      ~r/vector.*clustering/i,
      ~r/vector.*classification/i,
      ~r/vector.*recommendation/i,
      ~r/vector.*analytics/i,
      ~r/vector.*ml/i,
      ~r/vector.*ai/i,
      ~r/vector.*model/i,
      ~r/vector.*inference/i,
      ~r/vector.*training/i,
      ~r/vector.*deployment/i,
      ~r/pgvector|pgvector/i,
      ~r/vector.*extension/i,
      ~r/vector.*plugin/i,
      ~r/vector.*integration/i,
      ~r/embedding.*database/i,
      ~r/semantic.*search/i,
      ~r/similarity.*search/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            database_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{
                technology: "Vector Database",
                pattern: pattern,
                file: file,
                type: "Database",
                evidence: extract_pattern_context(content, pattern)
              }
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_build_from_code(files) do
    build_patterns = [
      ~r/moon.*orchestration/i,
      ~r/orchestration.*moon/i,
      ~r/moon.*build/i,
      ~r/build.*moon/i,
      ~r/moon.*task/i,
      ~r/task.*moon/i,
      ~r/moon.*project/i,
      ~r/project.*moon/i,
      ~r/monorepo.*orchestration/i,
      ~r/orchestration.*monorepo/i,
      ~r/workspace.*orchestration/i,
      ~r/orchestration.*workspace/i,
      ~r/build.*orchestration/i,
      ~r/orchestration.*build/i,
      ~r/task.*orchestration/i,
      ~r/orchestration.*task/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            build_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{
                technology: "Build Orchestration",
                pattern: pattern,
                file: file,
                type: "Build System",
                evidence: extract_pattern_context(content, pattern)
              }
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_deployment_from_code(files) do
    deployment_patterns = [
      ~r/kubernetes.*deployment/i,
      ~r/deployment.*kubernetes/i,
      ~r/k8s.*deployment/i,
      ~r/deployment.*k8s/i,
      ~r/helm.*chart/i,
      ~r/chart.*helm/i,
      ~r/container.*orchestration/i,
      ~r/orchestration.*container/i,
      ~r/service.*mesh/i,
      ~r/mesh.*service/i,
      ~r/istio/i,
      ~r/envoy/i,
      ~r/cilium/i,
      ~r/argo.*cd/i,
      ~r/flux.*cd/i,
      ~r/gitops/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            deployment_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{
                technology: "Deployment Platform",
                pattern: pattern,
                file: file,
                type: "Deployment",
                evidence: extract_pattern_context(content, pattern)
              }
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_monitoring_from_code(files) do
    monitoring_patterns = [
      ~r/prometheus.*metrics/i,
      ~r/metrics.*prometheus/i,
      ~r/grafana.*dashboard/i,
      ~r/dashboard.*grafana/i,
      ~r/jaeger.*tracing/i,
      ~r/tracing.*jaeger/i,
      ~r/opentelemetry/i,
      ~r/otel/i,
      ~r/distributed.*tracing/i,
      ~r/tracing.*distributed/i,
      ~r/metrics.*collection/i,
      ~r/collection.*metrics/i,
      ~r/observability/i,
      ~r/monitoring.*stack/i,
      ~r/stack.*monitoring/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            monitoring_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{
                technology: "Monitoring Stack",
                pattern: pattern,
                file: file,
                type: "Observability",
                evidence: extract_pattern_context(content, pattern)
              }
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_security_from_code(files) do
    security_patterns = [
      ~r/spiffe.*spire/i,
      ~r/spire.*spiffe/i,
      ~r/identity.*management/i,
      ~r/management.*identity/i,
      ~r/service.*identity/i,
      ~r/identity.*service/i,
      ~r/workload.*identity/i,
      ~r/identity.*workload/i,
      ~r/opa.*policy/i,
      ~r/policy.*opa/i,
      ~r/openpolicyagent/i,
      ~r/rego.*policy/i,
      ~r/policy.*rego/i,
      ~r/falco.*security/i,
      ~r/security.*falco/i,
      ~r/runtime.*security/i,
      ~r/security.*runtime/i,
      ~r/security.*monitoring/i,
      ~r/monitoring.*security/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            security_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{
                technology: "Security Platform",
                pattern: pattern,
                file: file,
                type: "Security",
                evidence: extract_pattern_context(content, pattern)
              }
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_cloud_from_code(files) do
    cloud_patterns = [
      ~r/aws.*services/i,
      ~r/services.*aws/i,
      ~r/azure.*services/i,
      ~r/services.*azure/i,
      ~r/gcp.*services/i,
      ~r/services.*gcp/i,
      ~r/google.*cloud/i,
      ~r/cloud.*google/i,
      ~r/microsoft.*azure/i,
      ~r/azure.*microsoft/i,
      ~r/amazon.*aws/i,
      ~r/aws.*amazon/i,
      ~r/cloud.*native/i,
      ~r/native.*cloud/i,
      ~r/serverless/i,
      ~r/function.*as.*a.*service/i,
      ~r/faaS/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            cloud_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{
                technology: "Cloud Platform",
                pattern: pattern,
                file: file,
                type: "Cloud",
                evidence: extract_pattern_context(content, pattern)
              }
            end
          )

        _ ->
          []
      end
    end)
  end

  defp extract_pattern_context(content, pattern) do
    # Extract context around the pattern match
    case Regex.run(pattern, content, return: :index) do
      [{start, length}] ->
        context_start = max(0, start - 50)
        context_end = min(byte_size(content), start + length + 50)
        context = String.slice(content, context_start, context_end - context_start)
        %{context: context, position: start}

      _ ->
        %{context: "", position: 0}
    end
  end

  defp calculate_dynamic_confidence(discovery) do
    # Calculate confidence based on pattern strength and context
    base_confidence = 0.5

    # Increase confidence for multiple patterns in same file
    pattern_strength =
      case discovery.pattern do
        pattern when is_binary(pattern) -> 0.1
        _ -> 0.05
      end

    # Increase confidence for specific technology keywords
    technology_confidence =
      case discovery.technology do
        "BPMN Process Engine" -> 0.3
        "Sandbox Framework" -> 0.3
        "AI Framework" -> 0.2
        "Vector Database" -> 0.2
        _ -> 0.1
      end

    Float.round(base_confidence + pattern_strength + technology_confidence, 3)
  end

  defp combine_unknown_discoveries(discoveries) do
    %{
      unknown_extensions: discoveries |> Enum.at(0, []),
      unknown_structures: discoveries |> Enum.at(1, []),
      unknown_configs: discoveries |> Enum.at(2, []),
      unknown_builds: discoveries |> Enum.at(3, []),
      dynamic_technologies: discoveries |> Enum.at(4, []),
      total_discoveries: Enum.sum(Enum.map(discoveries, &length/1)),
      confidence_score: calculate_overall_confidence(discoveries)
    }
  end

  defp analyze_javascript_imports(files) do
    js_files =
      Enum.filter(files, fn file ->
        String.ends_with?(file, ".js") or String.ends_with?(file, ".jsx") or
          String.ends_with?(file, ".ts") or String.ends_with?(file, ".tsx")
      end)

    Enum.flat_map(js_files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          extract_javascript_imports(content)

        _ ->
          []
      end
    end)
  end

  defp analyze_python_imports(files) do
    py_files = Enum.filter(files, &String.ends_with?(&1, ".py"))

    Enum.flat_map(py_files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          extract_python_imports(content)

        _ ->
          []
      end
    end)
  end

  defp analyze_rust_imports(files) do
    rs_files = Enum.filter(files, &String.ends_with?(&1, ".rs"))

    Enum.flat_map(rs_files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          extract_rust_imports(content)

        _ ->
          []
      end
    end)
  end

  defp analyze_elixir_imports(files) do
    ex_files =
      Enum.filter(files, fn file ->
        String.ends_with?(file, ".ex") or String.ends_with?(file, ".exs")
      end)

    Enum.flat_map(ex_files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          extract_elixir_imports(content)

        _ ->
          []
      end
    end)
  end

  defp analyze_go_imports(files) do
    go_files = Enum.filter(files, &String.ends_with?(&1, ".go"))

    Enum.flat_map(go_files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          extract_go_imports(content)

        _ ->
          []
      end
    end)
  end

  defp analyze_cross_language_imports(files) do
    # Look for patterns that suggest cross-language integration
    cross_language_patterns = [
      ~r/ffi|foreign.*function|native.*interface/i,
      ~r/bindings?|wrapper|bridge/i,
      ~r/jni|jna|ctypes|pybind/i,
      ~r/wasm|webassembly/i,
      ~r/grpc|protobuf|thrift/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            cross_language_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_rest_endpoints(files) do
    rest_patterns = [
      ~r/@(Get|Post|Put|Delete|Patch)/,
      ~r/app\.(get|post|put|delete|patch)/,
      ~r/express\(\)\.(get|post|put|delete|patch)/,
      ~r/FastAPI.*@.*\.(get|post|put|delete|patch)/,
      ~r/def\s+(index|create|update|delete|show)/
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            rest_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "REST"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_graphql_schemas(files) do
    graphql_patterns = [
      ~r/type\s+\w+\s*\{/,
      ~r/Query\s*\{/,
      ~r/Mutation\s*\{/,
      ~r/Subscription\s*\{/,
      ~r/schema\.graphql/,
      ~r/graphql.*schema/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            graphql_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "GraphQL"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_rpc_interfaces(files) do
    rpc_patterns = [
      ~r/rpc.*interface/i,
      ~r/service\s+\w+/,
      ~r/proto.*service/i,
      ~r/thrift.*service/i,
      ~r/grpc.*service/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            rpc_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "RPC"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_websocket_connections(files) do
    websocket_patterns = [
      ~r/WebSocket|websocket/i,
      ~r/socket\.io/i,
      ~r/ws:|wss:/,
      ~r/socket.*connection/i,
      ~r/real.*time.*connection/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            websocket_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "WebSocket"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_grpc_services(files) do
    grpc_patterns = [
      ~r/grpc/i,
      ~r/protobuf|proto.*buf/i,
      ~r/\.proto$/,
      ~r/gRPC/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            grpc_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "gRPC"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_custom_api_patterns(files) do
    # Look for custom API patterns not covered by standard patterns
    custom_patterns = [
      ~r/api.*endpoint/i,
      ~r/endpoint.*api/i,
      ~r/custom.*api/i,
      ~r/internal.*api/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            custom_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Custom API"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_database_schemas(files) do
    schema_patterns = [
      ~r/CREATE\s+TABLE/i,
      ~r/ALTER\s+TABLE/i,
      ~r/migration/i,
      ~r/schema.*sql/i,
      ~r/\.sql$/,
      ~r/sequelize.*define/i,
      ~r/mongoose.*schema/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            schema_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Database Schema"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_data_models(files) do
    model_patterns = [
      ~r/class\s+\w+.*Model/i,
      ~r/interface\s+\w+.*Model/i,
      ~r/type\s+\w+.*Model/i,
      ~r/struct\s+\w+.*Model/i,
      ~r/defmodule\s+\w+.*Model/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            model_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Data Model"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_serialization_formats(files) do
    serialization_patterns = [
      ~r/json\.parse|JSON\.parse/i,
      ~r/xml\.parse|XML\.parse/i,
      ~r/yaml\.parse|YAML\.parse/i,
      ~r/protobuf|protobuf/i,
      ~r/avro|avro/i,
      ~r/msgpack|msgpack/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            serialization_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Serialization"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_validation_patterns(files) do
    validation_patterns = [
      ~r/validate|validation/i,
      ~r/schema.*validation/i,
      ~r/joi|yup|zod/i,
      ~r/validator|validates/i,
      ~r/constraint|constraints/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            validation_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Validation"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_transformation_pipelines(files) do
    transformation_patterns = [
      ~r/transform|transformation/i,
      ~r/pipeline|pipeline/i,
      ~r/etl|ETL/i,
      ~r/map.*reduce/i,
      ~r/stream.*processing/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            transformation_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Transformation"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_business_processes(files) do
    business_patterns = [
      ~r/business.*process/i,
      ~r/workflow.*engine/i,
      ~r/process.*orchestration/i,
      ~r/bpmn|BPMN/i,
      ~r/process.*definition/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            business_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Business Process"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_workflow_engines(files) do
    workflow_patterns = [
      ~r/workflow.*engine/i,
      ~r/airflow|Airflow/i,
      ~r/luigi|Luigi/i,
      ~r/prefect|Prefect/i,
      ~r/argo.*workflows/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            workflow_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Workflow Engine"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_state_machines(files) do
    state_patterns = [
      ~r/state.*machine/i,
      ~r/fsm|finite.*state/i,
      ~r/state.*transition/i,
      ~r/state.*pattern/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            state_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "State Machine"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_event_handlers(files) do
    event_patterns = [
      ~r/event.*handler/i,
      ~r/on.*event/i,
      ~r/event.*listener/i,
      ~r/event.*bus/i,
      ~r/pub.*sub|publish.*subscribe/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            event_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Event Handler"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_process_orchestration(files) do
    orchestration_patterns = [
      ~r/orchestration|orchestrator/i,
      ~r/process.*orchestration/i,
      ~r/service.*mesh/i,
      ~r/microservice.*orchestration/i,
      ~r/container.*orchestration/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            orchestration_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Process Orchestration"}
            end
          )

        _ ->
          []
      end
    end)
  end

  # Singularity-engine specific discovery functions

  defp discover_bpmn_processes(files) do
    bpmn_patterns = [
      ~r/bpmn|BPMN/i,
      ~r/process.*definition/i,
      ~r/workflow.*engine/i,
      ~r/process.*instance/i,
      ~r/process.*deployment/i,
      ~r/process.*execution/i,
      ~r/process.*repository/i,
      ~r/process.*variables/i,
      ~r/process.*metadata/i,
      ~r/process.*state/i,
      ~r/process.*event/i,
      ~r/process.*task/i,
      ~r/process.*gateway/i,
      ~r/process.*sequence/i,
      ~r/process.*flow/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            bpmn_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "BPMN Process"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_sandbox_frameworks(files) do
    sandbox_patterns = [
      ~r/sandbox.*framework/i,
      ~r/sandbox.*provider/i,
      ~r/sandbox.*instance/i,
      ~r/sandbox.*config/i,
      ~r/sandbox.*execution/i,
      ~r/sandbox.*security/i,
      ~r/sandbox.*isolation/i,
      ~r/e2b|E2B/i,
      ~r/firecracker|Firecracker/i,
      ~r/modal|Modal/i,
      ~r/sandbox.*pool/i,
      ~r/sandbox.*selector/i,
      ~r/sandbox.*metrics/i,
      ~r/sandbox.*logs/i,
      ~r/sandbox.*lifecycle/i,
      ~r/sandbox.*capabilities/i,
      ~r/sandbox.*limits/i,
      ~r/sandbox.*cost/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            sandbox_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Sandbox Framework"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_ai_workflows(files) do
    ai_workflow_patterns = [
      ~r/ai.*workflow/i,
      ~r/ai.*framework/i,
      ~r/ai.*integration/i,
      ~r/ai.*service/i,
      ~r/ai.*task/i,
      ~r/ai.*orchestration/i,
      ~r/ai.*pipeline/i,
      ~r/ai.*model/i,
      ~r/ai.*inference/i,
      ~r/ai.*training/i,
      ~r/ai.*deployment/i,
      ~r/ai.*monitoring/i,
      ~r/ai.*scaling/i,
      ~r/ai.*load.*balancing/i,
      ~r/ai.*resource.*management/i,
      ~r/ai.*cost.*optimization/i,
      ~r/ai.*performance/i,
      ~r/ai.*metrics/i,
      ~r/ai.*logging/i,
      ~r/ai.*debugging/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            ai_workflow_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "AI Workflow"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_mcp_servers(files) do
    mcp_patterns = [
      ~r/mcp.*server/i,
      ~r/model.*context.*protocol/i,
      ~r/mcp.*integration/i,
      ~r/mcp.*toolchain/i,
      ~r/mcp.*capabilities/i,
      ~r/mcp.*context/i,
      ~r/mcp.*session/i,
      ~r/mcp.*state/i,
      ~r/mcp.*assistance/i,
      ~r/mcp.*development/i,
      ~r/mcp.*task/i,
      ~r/mcp.*workflow/i,
      ~r/mcp.*orchestration/i,
      ~r/mcp.*monitoring/i,
      ~r/mcp.*management/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            mcp_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "MCP Server"}
            end
          )

        _ ->
          []
      end
    end)
  end

  defp discover_vector_databases(files) do
    vector_patterns = [
      ~r/vector.*database/i,
      ~r/vector.*search/i,
      ~r/vector.*embedding/i,
      ~r/vector.*index/i,
      ~r/vector.*similarity/i,
      ~r/vector.*distance/i,
      ~r/vector.*query/i,
      ~r/vector.*storage/i,
      ~r/vector.*retrieval/i,
      ~r/vector.*matching/i,
      ~r/vector.*clustering/i,
      ~r/vector.*classification/i,
      ~r/vector.*recommendation/i,
      ~r/vector.*analytics/i,
      ~r/vector.*ml/i,
      ~r/vector.*ai/i,
      ~r/vector.*model/i,
      ~r/vector.*inference/i,
      ~r/vector.*training/i,
      ~r/vector.*deployment/i,
      ~r/pgvector|pgvector/i,
      ~r/vector.*extension/i,
      ~r/vector.*plugin/i,
      ~r/vector.*integration/i
    ]

    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          Enum.filter_map(
            vector_patterns,
            fn pattern ->
              Regex.match?(pattern, content)
            end,
            fn pattern ->
              %{pattern: pattern, file: file, type: "Vector Database"}
            end
          )

        _ ->
          []
      end
    end)
  end

  # Helper functions for pattern extraction
  defp extract_javascript_imports(content) do
    import_patterns = [
      ~r/import\s+.*from\s+['"]([^'"]+)['"]/,
      ~r/require\(['"]([^'"]+)['"]\)/,
      ~r/import\(['"]([^'"]+)['"]\)/
    ]

    Enum.flat_map(import_patterns, fn pattern ->
      Regex.scan(pattern, content)
      |> Enum.map(fn [_, module] -> %{module: module, type: "JavaScript"} end)
    end)
  end

  defp extract_python_imports(content) do
    import_patterns = [
      ~r/import\s+([a-zA-Z_][a-zA-Z0-9_]*)/,
      ~r/from\s+([a-zA-Z_][a-zA-Z0-9_.]*)\s+import/
    ]

    Enum.flat_map(import_patterns, fn pattern ->
      Regex.scan(pattern, content)
      |> Enum.map(fn [_, module] -> %{module: module, type: "Python"} end)
    end)
  end

  defp extract_rust_imports(content) do
    import_patterns = [
      ~r/use\s+([a-zA-Z_][a-zA-Z0-9_:]*)/,
      ~r/mod\s+([a-zA-Z_][a-zA-Z0-9_]*)/
    ]

    Enum.flat_map(import_patterns, fn pattern ->
      Regex.scan(pattern, content)
      |> Enum.map(fn [_, module] -> %{module: module, type: "Rust"} end)
    end)
  end

  defp extract_elixir_imports(content) do
    import_patterns = [
      ~r/use\s+([A-Z][a-zA-Z0-9_.]*)/,
      ~r/import\s+([A-Z][a-zA-Z0-9_.]*)/,
      ~r/alias\s+([A-Z][a-zA-Z0-9_.]*)/
    ]

    Enum.flat_map(import_patterns, fn pattern ->
      Regex.scan(pattern, content)
      |> Enum.map(fn [_, module] -> %{module: module, type: "Elixir"} end)
    end)
  end

  defp extract_go_imports(content) do
    import_patterns = [
      ~r/import\s+['"]([^'"]+)['"]/,
      ~r/import\s+\([\s\S]*?\)/
    ]

    Enum.flat_map(import_patterns, fn pattern ->
      Regex.scan(pattern, content)
      |> Enum.map(fn [_, module] -> %{module: module, type: "Go"} end)
    end)
  end

  defp find_source_files(codebase_path) do
    Path.wildcard(Path.join(codebase_path, "**/*"))
    |> Enum.filter(&File.regular?/1)
    |> Enum.reject(fn file ->
      # Skip common non-source files
      filename = Path.basename(file)
      filename in ["package-lock.json", "yarn.lock", "Cargo.lock", "go.sum"]
    end)
  end

  # Confidence calculation helpers
  defp calculate_extension_confidence(files) do
    case length(files) do
      0 -> 0.0
      count when count < 5 -> 0.3
      count when count < 20 -> 0.6
      _ -> 0.9
    end
  end

  defp calculate_directory_confidence(files) do
    case length(files) do
      0 -> 0.0
      count when count < 10 -> 0.4
      count when count < 50 -> 0.7
      _ -> 0.9
    end
  end

  defp calculate_config_confidence(content) do
    case byte_size(content) do
      0 -> 0.0
      size when size < 100 -> 0.2
      size when size < 1000 -> 0.5
      _ -> 0.8
    end
  end

  defp calculate_build_confidence(content) do
    # Look for common build command patterns
    build_indicators = [
      ~r/compile|build|make|run/i,
      ~r/npm|yarn|pip|cargo|go\s+build/i,
      ~r/webpack|rollup|esbuild/i
    ]

    matches =
      Enum.count(build_indicators, fn pattern ->
        Regex.match?(pattern, content)
      end)

    case matches do
      0 -> 0.1
      1 -> 0.4
      2 -> 0.7
      _ -> 0.9
    end
  end

  defp calculate_overall_confidence(discoveries) do
    total_discoveries = Enum.sum(Enum.map(discoveries, &length/1))

    case total_discoveries do
      0 -> 0.0
      count when count < 5 -> 0.3
      count when count < 20 -> 0.6
      _ -> 0.9
    end
  end

  # Pattern analysis helpers
  defp analyze_extension_patterns(files) do
    # Analyze file naming patterns, content patterns, etc.
    %{
      naming_patterns: analyze_naming_patterns(files),
      content_patterns: analyze_content_patterns(files),
      directory_patterns: analyze_directory_patterns(files)
    }
  end

  defp analyze_directory_patterns(files) do
    # Analyze patterns in directory structure
    %{
      depth_distribution: analyze_depth_distribution(files),
      file_type_distribution: analyze_file_type_distribution(files)
    }
  end

  defp analyze_config_patterns(content) do
    # Analyze configuration patterns
    %{
      format: detect_config_format(content),
      structure: analyze_config_structure(content),
      complexity: calculate_config_complexity(content)
    }
  end

  defp analyze_build_patterns(content) do
    # Analyze build patterns
    %{
      commands: extract_build_commands(content),
      tools: extract_build_tools(content),
      complexity: calculate_build_complexity(content)
    }
  end

  defp analyze_naming_patterns(files) do
    # Analyze file naming patterns
    Enum.map(files, fn file ->
      filename = Path.basename(file)

      %{
        filename: filename,
        has_numbers: Regex.match?(~r/\d/, filename),
        has_underscores: String.contains?(filename, "_"),
        has_dashes: String.contains?(filename, "-"),
        has_dots: String.contains?(filename, "."),
        length: String.length(filename)
      }
    end)
  end

  defp analyze_content_patterns(files) do
    # Analyze content patterns in files
    Enum.map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          %{
            file: file,
            size: byte_size(content),
            has_binary: String.contains?(content, <<0>>),
            has_json: Regex.match?(~r/\{.*\}/, content),
            has_xml: Regex.match?(~r/<.*>/, content),
            has_yaml: Regex.match?(~r/^[a-zA-Z_][a-zA-Z0-9_]*:/m, content)
          }

        _ ->
          %{file: file, error: "Could not read file"}
      end
    end)
  end

  defp analyze_depth_distribution(files) do
    depths =
      Enum.map(files, fn file ->
        String.split(file, "/") |> length()
      end)

    %{
      min_depth: Enum.min(depths, fn -> 0 end),
      max_depth: Enum.max(depths, fn -> 0 end),
      avg_depth: Enum.sum(depths) / max(length(depths), 1)
    }
  end

  defp analyze_file_type_distribution(files) do
    extensions =
      Enum.map(files, &Path.extname/1)
      |> Enum.frequencies()

    %{extensions: extensions}
  end

  defp detect_config_format(content) do
    cond do
      Regex.match?(~r/^\s*\{/, content) -> "JSON"
      Regex.match?(~r/^\s*[a-zA-Z_][a-zA-Z0-9_]*:/m, content) -> "YAML"
      Regex.match?(~r/^\s*\[/, content) -> "TOML"
      Regex.match?(~r/^\s*</, content) -> "XML"
      Regex.match?(~r/^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*=/, content) -> "Properties"
      true -> "Unknown"
    end
  end

  defp analyze_config_structure(content) do
    %{
      has_nested_objects: Regex.match?(~r/\{[^}]*\{/, content),
      has_arrays: Regex.match?(~r/\[/, content),
      has_comments: Regex.match?(~r/\/\/|\#|\/\*/, content),
      line_count: String.split(content, "\n") |> length()
    }
  end

  defp calculate_config_complexity(content) do
    # Simple complexity calculation based on structure
    nested_count = Regex.scan(~r/\{/, content) |> length()
    array_count = Regex.scan(~r/\[/, content) |> length()
    line_count = String.split(content, "\n") |> length()

    (nested_count + array_count + line_count) / 10.0
  end

  defp extract_build_commands(content) do
    command_patterns = [
      ~r/(npm|yarn|pip|cargo|go|make|cmake|gcc|g\+\+)\s+[a-zA-Z-]+/i,
      ~r/webpack|rollup|esbuild|vite|parcel/i
    ]

    Enum.flat_map(command_patterns, fn pattern ->
      Regex.scan(pattern, content)
      |> Enum.map(fn [match] -> match end)
    end)
  end

  defp extract_build_tools(content) do
    tool_patterns = [
      ~r/webpack|rollup|esbuild|vite|parcel/i,
      ~r/make|cmake|ninja/i,
      ~r/gcc|g\+\+|clang/i
    ]

    Enum.flat_map(tool_patterns, fn pattern ->
      Regex.scan(pattern, content)
      |> Enum.map(fn [match] -> match end)
    end)
  end

  defp calculate_build_complexity(content) do
    # Calculate build complexity based on commands and tools
    command_count = length(extract_build_commands(content))
    tool_count = length(extract_build_tools(content))
    line_count = String.split(content, "\n") |> length()

    (command_count + tool_count + line_count) / 20.0
  end

  defp analyze_directory_file_types(files) do
    Enum.map(files, fn file ->
      %{
        file: file,
        extension: Path.extname(file),
        basename: Path.basename(file)
      }
    end)
  end

  defp analyze_import_complexity(import_patterns) do
    total_imports =
      Enum.sum(
        Enum.map(import_patterns, fn {_lang, imports} ->
          length(imports)
        end)
      )

    unique_modules =
      import_patterns
      |> Enum.flat_map(fn {_lang, imports} -> imports end)
      |> Enum.map(& &1.module)
      |> Enum.uniq()
      |> length()

    %{
      total_imports: total_imports,
      unique_modules: unique_modules,
      complexity_score: total_imports / max(unique_modules, 1),
      cross_language_imports: length(import_patterns.cross_language_imports)
    }
  end

  defp analyze_api_architecture(api_patterns) do
    total_apis =
      Enum.sum(
        Enum.map(api_patterns, fn {_type, apis} ->
          length(apis)
        end)
      )

    %{
      total_endpoints: total_apis,
      rest_endpoints: length(api_patterns.rest_endpoints),
      graphql_schemas: length(api_patterns.graphql_schemas),
      rpc_interfaces: length(api_patterns.rpc_interfaces),
      websocket_connections: length(api_patterns.websocket_connections),
      grpc_services: length(api_patterns.grpc_services),
      custom_apis: length(api_patterns.custom_apis),
      architecture_complexity: calculate_api_complexity(api_patterns)
    }
  end

  defp calculate_api_complexity(api_patterns) do
    # Calculate API architecture complexity
    api_types =
      Enum.count(api_patterns, fn {_type, apis} ->
        length(apis) > 0
      end)

    total_apis =
      Enum.sum(
        Enum.map(api_patterns, fn {_type, apis} ->
          length(apis)
        end)
      )

    api_types * total_apis / 10.0
  end

  defp analyze_data_flow_patterns(data_patterns) do
    %{
      total_patterns:
        Enum.sum(
          Enum.map(data_patterns, fn {_type, patterns} ->
            length(patterns)
          end)
        ),
      database_schemas: length(data_patterns.database_schemas),
      data_models: length(data_patterns.data_models),
      serialization_formats: length(data_patterns.serialization_formats),
      validation_patterns: length(data_patterns.validation_patterns),
      transformation_pipelines: length(data_patterns.transformation_pipelines),
      data_complexity: calculate_data_complexity(data_patterns)
    }
  end

  defp calculate_data_complexity(data_patterns) do
    # Calculate data complexity
    data_types =
      Enum.count(data_patterns, fn {_type, patterns} ->
        length(patterns) > 0
      end)

    total_patterns =
      Enum.sum(
        Enum.map(data_patterns, fn {_type, patterns} ->
          length(patterns)
        end)
      )

    data_types * total_patterns / 5.0
  end

  defp analyze_workflow_complexity(workflow_patterns) do
    %{
      total_patterns:
        Enum.sum(
          Enum.map(workflow_patterns, fn {_type, patterns} ->
            length(patterns)
          end)
        ),
      business_processes: length(workflow_patterns.business_processes),
      workflow_engines: length(workflow_patterns.workflow_engines),
      state_machines: length(workflow_patterns.state_machines),
      event_handlers: length(workflow_patterns.event_handlers),
      process_orchestration: length(workflow_patterns.process_orchestration),
      workflow_complexity: calculate_workflow_complexity(workflow_patterns)
    }
  end

  defp calculate_workflow_complexity(workflow_patterns) do
    # Calculate workflow complexity
    workflow_types =
      Enum.count(workflow_patterns, fn {_type, patterns} ->
        length(patterns) > 0
      end)

    total_patterns =
      Enum.sum(
        Enum.map(workflow_patterns, fn {_type, patterns} ->
          length(patterns)
        end)
      )

    workflow_types * total_patterns / 3.0
  end
end
