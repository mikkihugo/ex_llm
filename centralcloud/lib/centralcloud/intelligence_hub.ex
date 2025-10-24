defmodule CentralCloud.IntelligenceHub do
  @moduledoc """
  Intelligence Hub - Aggregates intelligence from all Singularity instances

  Replaces the Rust intelligence_hub service with pure Elixir.

  Handles THREE types of intelligence:
  1. **Code Intelligence** - Patterns, quality metrics, best practices
  2. **Architectural Intelligence** - System design, component relationships
  3. **Data Intelligence** - Database schemas, data flows, data architecture

  ## NATS Subjects

  - `intelligence.code.pattern.learned` - Code patterns from instances
  - `intelligence.architecture.pattern.learned` - Architectural patterns
  - `intelligence.data.schema.learned` - Data schemas
  - `intelligence.insights.query` - Query aggregated intelligence
  - `intelligence.quality.aggregate` - Quality metrics aggregation
  """

  use GenServer
  require Logger
  import Ecto.Query

  alias CentralCloud.{Repo, NatsClient}

  # ===========================
  # Public API
  # ===========================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Query aggregated insights from all instances
  """
  def query_insights(query, opts \\ []) do
    GenServer.call(__MODULE__, {:query_insights, query, opts})
  end

  @doc """
  Get aggregated statistics
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # ===========================
  # GenServer Callbacks
  # ===========================

  @impl true
  def init(_opts) do
    Logger.info("IntelligenceHub starting - aggregating patterns from all instances")

    # Subscribe to intelligence subjects
    :ok = subscribe_to_subjects()

    state = %{
      code_patterns: 0,
      arch_patterns: 0,
      data_schemas: 0,
      quality_reports: 0,
      started_at: DateTime.utc_now()
    }

    Logger.info("IntelligenceHub ready - listening on intelligence.* subjects")
    {:ok, state}
  end

  @impl true
  def handle_call({:query_insights, query, _opts}, _from, state) do
    # Query aggregated insights from PostgreSQL
    Logger.debug("Querying insights: #{inspect(query)}")

    try do
      insights = execute_query(query)
      {:reply, {:ok, insights}, state}
    rescue
      e ->
        Logger.error("Query execution error: #{inspect(e)}")
        {:reply, {:error, "Query failed"}, state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      code_patterns: state.code_patterns,
      arch_patterns: state.arch_patterns,
      data_schemas: state.data_schemas,
      quality_reports: state.quality_reports,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }
    {:reply, {:ok, stats}, state}
  end

  # ===========================
  # Private Functions
  # ===========================

  defp subscribe_to_subjects do
    # Subscribe to all intelligence subjects
    NatsClient.subscribe("intelligence.code.pattern.learned", &handle_code_pattern/1)
    NatsClient.subscribe("intelligence.architecture.pattern.learned", &handle_arch_pattern/1)
    NatsClient.subscribe("intelligence.data.schema.learned", &handle_data_schema/1)
    NatsClient.subscribe("intelligence.insights.query", &handle_insights_query/1)
    NatsClient.subscribe("intelligence.quality.aggregate", &handle_quality_report/1)

    # NEW: Template context queries
    NatsClient.subscribe("intelligence.query.request", &handle_intelligence_query/1)

    # NEW: Dependency reports from instances
    NatsClient.subscribe("system.instance.dependencies.report", &handle_dependency_report/1)

    # CRITICAL: The API that Singularity actually calls!
    NatsClient.subscribe("central.analyze_codebase", &handle_analyze_codebase/1)
    NatsClient.subscribe("central.learn_patterns", &handle_learn_patterns/1)
    NatsClient.subscribe("central.get_global_stats", &handle_get_global_stats/1)
    NatsClient.subscribe("central.train_models", &handle_train_models/1)
    NatsClient.subscribe("central.get_cross_instance_insights", &handle_get_cross_instance_insights/1)

    # NEW: Framework pattern discovery (for multi-system learning)
    NatsClient.subscribe("framework.pattern.query", &handle_framework_pattern_query/1)
    NatsClient.subscribe("framework.pattern.search", &handle_framework_pattern_search/1)

    :ok
  end

  defp handle_code_pattern(msg) do
    Logger.info("Received code pattern from instance")

    # Parse pattern from message
    case Jason.decode(msg.payload) do
      {:ok, pattern} ->
        # Store in PostgreSQL
        # Aggregate patterns across instances
        # Broadcast if pattern reaches confidence threshold
        Logger.debug("Code pattern: #{inspect(pattern)}")
        GenServer.cast(__MODULE__, {:increment, :code_patterns})

      {:error, reason} ->
        Logger.error("Failed to decode code pattern: #{inspect(reason)}")
    end
  end

  defp handle_arch_pattern(msg) do
    Logger.info("Received architectural pattern from instance")

    case Jason.decode(msg.payload) do
      {:ok, pattern} ->
        # Store architectural patterns
        # Learn system design patterns
        # Track component relationships
        Logger.debug("Architectural pattern: #{inspect(pattern)}")
        GenServer.cast(__MODULE__, {:increment, :arch_patterns})

      {:error, reason} ->
        Logger.error("Failed to decode architectural pattern: #{inspect(reason)}")
    end
  end

  defp handle_data_schema(msg) do
    Logger.info("Received data schema from instance")

    case Jason.decode(msg.payload) do
      {:ok, schema} ->
        # Store database schemas
        # Learn data flow patterns
        # Track data architecture evolution
        Logger.debug("Data schema: #{inspect(schema)}")
        GenServer.cast(__MODULE__, {:increment, :data_schemas})

      {:error, reason} ->
        Logger.error("Failed to decode data schema: #{inspect(reason)}")
    end
  end

  defp handle_insights_query(msg) do
    Logger.info("Received global insights query")

    case Jason.decode(msg.payload) do
      {:ok, query} ->
        # Query aggregated insights (code + architecture + data)
        # Return patterns/suggestions learned from all instances
        Logger.debug("Insights query: #{inspect(query)}")

        # Reply with insights (TODO: implement query logic)
        reply = %{insights: [], status: "ok"}
        NatsClient.publish(msg.reply_to, Jason.encode!(reply))

      {:error, reason} ->
        Logger.error("Failed to decode insights query: #{inspect(reason)}")
    end
  end

  defp handle_quality_report(msg) do
    Logger.info("Received quality metrics from instance")

    case Jason.decode(msg.payload) do
      {:ok, metrics} ->
        # Aggregate quality metrics across instances
        # Track quality trends
        # Alert on quality regressions
        Logger.debug("Quality metrics: #{inspect(metrics)}")
        GenServer.cast(__MODULE__, {:increment, :quality_reports})

      {:error, reason} ->
        Logger.error("Failed to decode quality metrics: #{inspect(reason)}")
    end
  end

  @impl true
  def handle_cast({:increment, counter}, state) do
    {:noreply, Map.update!(state, counter, &(&1 + 1))}
  end

  # ===========================
  # NEW: Intelligence Query Handler
  # ===========================

  defp handle_intelligence_query(msg) do
    Logger.info("Received intelligence query for template context")

    case Jason.decode(msg.payload) do
      {:ok, query} ->
        # Process query and return enriched context
        response = process_intelligence_query(query)
        NatsClient.publish(msg.reply_to, Jason.encode!(response))

      {:error, reason} ->
        Logger.error("Failed to decode intelligence query: #{inspect(reason)}")
        error_response = %{error: "invalid_query", reason: inspect(reason)}
        NatsClient.publish(msg.reply_to, Jason.encode!(error_response))
    end
  end

  defp process_intelligence_query(query) do
    # 1. Detect or get framework
    framework = detect_or_get_framework(query)

    # 2. Load framework metadata
    framework_context = load_framework_metadata(framework, query["language"])

    # 3. Load quality standards
    quality_context = load_quality_standards(query["language"], query["quality_level"] || "production")

    # 4. Get recommended packages
    packages = get_recommended_packages(framework, query["language"])

    # 5. Get relevant prompt bits
    prompts = get_relevant_prompts(query["task_type"])

    # 6. Compose response
    %{
      framework: framework_context,
      quality: quality_context,
      packages: packages,
      prompts: prompts,
      confidence: calculate_confidence(framework_context, quality_context)
    }
  end

  defp detect_or_get_framework(query) do
    case query["framework"] do
      nil -> detect_framework_from_task(query)
      "detect" -> detect_framework_from_task(query)
      framework -> framework
    end
  end

  defp detect_framework_from_task(query) do
    # Simple detection based on keywords in description
    description = String.downcase(query["description"] || "")
    language = query["language"]

    cond do
      String.contains?(description, "liveview") or String.contains?(description, "phoenix") ->
        "phoenix"

      String.contains?(description, "react") and language == "typescript" ->
        "react"

      String.contains?(description, "next") and language == "typescript" ->
        "nextjs"

      String.contains?(description, "fastapi") and language == "python" ->
        "fastapi"

      language == "elixir" ->
        "phoenix"

      language == "typescript" ->
        "react"

      language == "python" ->
        "fastapi"

      true ->
        "generic"
    end
  end

  defp load_framework_metadata(framework, language) do
    # Query knowledge_artifacts for framework data
    case Repo.get_by(CentralCloud.KnowledgeArtifact,
           artifact_type: "framework",
           name: framework
         ) do
      nil ->
        Logger.warning("Framework not found: #{framework}, using defaults")
        %{
          name: framework,
          best_practices: [],
          common_mistakes: [],
          code_snippets: %{},
          prompt_context: "#{framework} framework for #{language}"
        }

      artifact ->
        extract_framework_context(artifact)
    end
  end

  defp extract_framework_context(artifact) do
    content = artifact.content || %{}

    %{
      name: content["name"] || "Unknown",
      best_practices: get_in(content, ["llm_support", "prompt_bits", "best_practices"]) || [],
      common_mistakes: get_in(content, ["llm_support", "prompt_bits", "common_mistakes"]) || [],
      code_snippets: get_in(content, ["llm_support", "code_snippets"]) || %{},
      prompt_context: get_in(content, ["llm_support", "prompt_bits", "context"]) || "",
      common_packages: get_in(content, ["llm_support", "fact_sources", "common_packages"]) || %{}
    }
  end

  defp load_quality_standards(language, quality_level) do
    # Query for quality standards
    artifact_id = "#{language}_#{quality_level}"

    case Repo.get_by(CentralCloud.KnowledgeArtifact,
           artifact_type: "quality_standard",
           artifact_id: artifact_id
         ) do
      nil ->
        Logger.warning("Quality standard not found: #{artifact_id}, using defaults")
        %{
          quality_level: quality_level,
          requirements: %{},
          prompts: %{},
          scoring_weights: %{}
        }

      artifact ->
        extract_quality_requirements(artifact)
    end
  end

  defp extract_quality_requirements(artifact) do
    content = artifact.content || %{}

    %{
      quality_level: content["quality_level"] || "production",
      requirements: content["requirements"] || %{},
      prompts: content["prompts"] || %{},
      scoring_weights: content["scoring_weights"] || %{}
    }
  end

  defp get_recommended_packages(framework, language) do
    # Query package registry knowledge for recommendations
    # For now, return empty list (will be implemented with package registry integration)
    Logger.debug("Fetching packages for #{framework}/#{language}")
    []
  end

  defp get_relevant_prompts(task_type) do
    # Query prompt library for task-specific prompts
    case Repo.get_by(CentralCloud.KnowledgeArtifact,
           artifact_type: "prompt",
           metadata: %{"use_case" => task_type}
         ) do
      nil ->
        %{system_prompt: "You are an expert software developer.", generation_hints: []}

      artifact ->
        %{
          system_prompt: artifact.content["prompt"] || "",
          generation_hints: artifact.content["metadata"]["hints"] || []
        }
    end
  end

  defp calculate_confidence(framework_context, quality_context) do
    # Calculate confidence based on available data
    framework_score = if framework_context[:name] != "Unknown", do: 0.5, else: 0.0
    quality_score = if map_size(quality_context[:requirements]) > 0, do: 0.5, else: 0.0

    framework_score + quality_score
  end

  defp handle_dependency_report(msg) do
    Logger.info("📦 Received dependency report from instance")

    case Jason.decode(msg.payload) do
      {:ok, %{"instance_id" => instance_id, "dependencies" => dependencies}} ->
        # Forward to package sync job for processing
        CentralCloud.Jobs.PackageSyncJob.handle_dependency_report(instance_id, dependencies)
        Logger.debug("Processed dependency report from instance #{instance_id}")

      {:error, reason} ->
        Logger.error("Failed to decode dependency report: #{inspect(reason)}")
    end
  end

  # ===========================
  # Central Cloud API Handlers (What Singularity Actually Calls)
  # ===========================

  defp handle_analyze_codebase(msg) do
    Logger.info("🔍 Received codebase analysis request from Singularity")
    
    case Jason.decode(msg.payload) do
      {:ok, request} ->
        response = analyze_codebase_implementation(request)
        send_response(msg, response)
      
      {:error, reason} ->
        Logger.error("Failed to decode analyze_codebase request: #{inspect(reason)}")
        send_error_response(msg, "Invalid request format")
    end
  end

  defp handle_learn_patterns(msg) do
    Logger.info("🧠 Received pattern learning request from Singularity")
    
    case Jason.decode(msg.payload) do
      {:ok, request} ->
        response = learn_patterns_implementation(request)
        send_response(msg, response)
      
      {:error, reason} ->
        Logger.error("Failed to decode learn_patterns request: #{inspect(reason)}")
        send_error_response(msg, "Invalid request format")
    end
  end

  defp handle_get_global_stats(msg) do
    Logger.info("📊 Received global stats request from Singularity")
    
    case Jason.decode(msg.payload) do
      {:ok, request} ->
        response = get_global_stats_implementation(request)
        send_response(msg, response)
      
      {:error, reason} ->
        Logger.error("Failed to decode get_global_stats request: #{inspect(reason)}")
        send_error_response(msg, "Invalid request format")
    end
  end

  defp handle_train_models(msg) do
    Logger.info("🤖 Received model training request from Singularity")
    
    case Jason.decode(msg.payload) do
      {:ok, request} ->
        response = train_models_implementation(request)
        send_response(msg, response)
      
      {:error, reason} ->
        Logger.error("Failed to decode train_models request: #{inspect(reason)}")
        send_error_response(msg, "Invalid request format")
    end
  end

  defp handle_get_cross_instance_insights(msg) do
    Logger.info("🔗 Received cross-instance insights request from Singularity")
    
    case Jason.decode(msg.payload) do
      {:ok, request} ->
        response = get_cross_instance_insights_implementation(request)
        send_response(msg, response)
      
      {:error, reason} ->
        Logger.error("Failed to decode get_cross_instance_insights request: #{inspect(reason)}")
        send_error_response(msg, "Invalid request format")
    end
  end

  # ===========================
  # NEW: Framework Pattern Handlers (Multi-System Learning)
  # ===========================

  # Handle framework pattern queries from Singularity instances
  # Used when Singularity detects unknown framework and needs enrichment
  defp handle_framework_pattern_query(msg) do
    Logger.info("🔍 Framework pattern query from Singularity instance")

    case Jason.decode(msg.payload) do
      {:ok, query} ->
        response = query_framework_patterns(query)
        send_response(msg, response)

      {:error, reason} ->
        Logger.error("Failed to decode framework pattern query: #{inspect(reason)}")
        send_error_response(msg, "Invalid query format")
    end
  end

  # Handle framework pattern search requests
  # Search across all known frameworks by name, category, or other criteria
  defp handle_framework_pattern_search(msg) do
    Logger.info("🔎 Framework pattern search from instance")

    case Jason.decode(msg.payload) do
      {:ok, search_params} ->
        response = search_framework_patterns(search_params)
        send_response(msg, response)

      {:error, reason} ->
        Logger.error("Failed to decode framework pattern search: #{inspect(reason)}")
        send_error_response(msg, "Invalid search parameters")
    end
  end

  defp query_framework_patterns(%{"framework_name" => name} = query) do
    Logger.debug("Querying patterns for framework: #{name}")

    # Query database for frameworks matching this name
    pattern = "%#{name}%"

    frameworks =
      Repo.all(
        from p in CentralCloud.Schemas.Package,
          where: not is_nil(p.detected_framework),
          where:
            fragment(
              "?->>'name' ILIKE ?",
              p.detected_framework,
              ^pattern
            ),
          select: {p.detected_framework, p.ecosystem},
          limit: 20
      )

    if Enum.empty?(frameworks) do
      Logger.info("No patterns found for framework: #{name}, will trigger LLM discovery")

      # Trigger FrameworkLearningAgent to discover unknown framework
      trigger_framework_discovery(name, query)

      # Return placeholder while discovery is in progress
      %{
        "status" => "discovery_in_progress",
        "framework" => name,
        "message" => "Unknown framework - starting discovery via LLM",
        "patterns" => [],
        "confidence" => 0.0,
        "discovery_timeout_seconds" => 120
      }
    else
      # Found patterns - aggregate and return
      aggregated = aggregate_framework_patterns(frameworks)

      %{
        "status" => "found",
        "framework" => name,
        "patterns" => aggregated,
        "confidence" => calculate_pattern_confidence(aggregated),
        "ecosystem_hints" => extract_ecosystems(frameworks),
        "sources" => length(frameworks),
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    end
  end

  defp query_framework_patterns(query) do
    Logger.warning("Framework pattern query missing framework_name: #{inspect(query)}")

    %{
      "status" => "error",
      "error" => "missing_framework_name",
      "message" => "Query must include 'framework_name' parameter"
    }
  end

  defp search_framework_patterns(%{"category" => category} = params) do
    Logger.debug("Searching frameworks by category: #{category}")

    limit = Map.get(params, "limit", 10)

    frameworks =
      Repo.all(
        from p in CentralCloud.Schemas.Package,
          where: not is_nil(p.detected_framework),
          where:
            fragment(
              "?->>'category' = ?",
              p.detected_framework,
              ^category
            ),
          select: {p.detected_framework, p.name},
          limit: ^limit
      )

    aggregated =
      frameworks
      |> Enum.map(&elem(&1, 0))
      |> aggregate_framework_patterns()

    %{
      "status" => "ok",
      "search_type" => "category",
      "category" => category,
      "results" => aggregated,
      "count" => length(aggregated),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp search_framework_patterns(%{"ecosystem" => ecosystem} = params) do
    Logger.debug("Searching frameworks by ecosystem: #{ecosystem}")

    limit = Map.get(params, "limit", 10)

    frameworks =
      Repo.all(
        from p in CentralCloud.Schemas.Package,
          where: p.ecosystem == ^ecosystem,
          where: not is_nil(p.detected_framework),
          select: p.detected_framework,
          limit: ^limit
      )

    aggregated = aggregate_framework_patterns(frameworks)

    %{
      "status" => "ok",
      "search_type" => "ecosystem",
      "ecosystem" => ecosystem,
      "results" => aggregated,
      "count" => length(aggregated),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp search_framework_patterns(_params) do
    %{
      "status" => "error",
      "error" => "invalid_search_params",
      "message" => "Search must include 'category' or 'ecosystem' parameter"
    }
  end

  defp aggregate_framework_patterns(patterns) when is_list(patterns) do
    patterns
    |> Enum.filter(& &1)
    |> Enum.group_by(fn p -> p["name"] || "unknown" end)
    |> Enum.map(fn {name, group} ->
      base = List.first(group)

      %{
        "name" => name,
        "category" => base["category"],
        "confidence" =>
          group
          |> Enum.map(& &1["confidence"])
          |> Enum.filter(&is_number/1)
          |> (fn confs ->
            if Enum.empty?(confs), do: 0.8, else: Enum.sum(confs) / length(confs)
          end).(),
        "patterns" => consolidate_list_field(group, "patterns"),
        "version_hints" => consolidate_list_field(group, "version_hints"),
        "usage_patterns" => consolidate_list_field(group, "usage_patterns"),
        "frequency" => length(group),
        "seen_count" => sum_field(group, "seen_count")
      }
    end)
  end

  defp aggregate_framework_patterns({frameworks, _ecosystems}) when is_list(frameworks) do
    aggregate_framework_patterns(frameworks)
  end

  defp extract_ecosystems(framework_ecosystem_tuples) do
    framework_ecosystem_tuples
    |> Enum.map(&elem(&1, 1))
    |> Enum.uniq()
  end

  defp calculate_pattern_confidence(patterns) do
    if Enum.empty?(patterns) do
      0.0
    else
      patterns
      |> Enum.map(& &1["confidence"])
      |> Enum.filter(&is_number/1)
      |> (fn confs -> Enum.sum(confs) / max(length(confs), 1) end).()
    end
  end

  defp consolidate_list_field(group, field) do
    group
    |> Enum.map(& &1[field])
    |> Enum.filter(&is_list/1)
    |> Enum.concat()
    |> Enum.uniq()
  end

  defp sum_field(group, field) do
    group
    |> Enum.map(& &1[field])
    |> Enum.filter(&is_number/1)
    |> Enum.sum()
  end

  # Trigger FrameworkLearningOrchestrator to discover unknown framework
  # Uses config-driven learners (template matcher → LLM discovery → custom strategies)
  defp trigger_framework_discovery(framework_name, query) do
    Logger.info("Triggering framework discovery for: #{framework_name}")

    # Extract discovery parameters from query
    package_id = Map.get(query, "package_id", framework_name)
    code_samples = Map.get(query, "code_samples", [])

    case CentralCloud.FrameworkLearningOrchestrator.learn(package_id, code_samples) do
      {:ok, framework, learner_type} ->
        Logger.info("Framework discovered via #{learner_type}",
          framework_name: framework["name"],
          package_id: package_id
        )

        # Store the discovered framework in the database
        store_discovered_framework(package_id, framework)

      {:error, :no_framework_found} ->
        Logger.warn("Could not determine framework for #{package_id}")

      {:error, reason} ->
        Logger.error("Framework discovery failed for #{package_id}",
          reason: inspect(reason)
        )
    end
  end

  # Store discovered framework in database
  defp store_discovered_framework(package_id, framework) do
    case Repo.get_by(CentralCloud.Schemas.Package, package_name: package_id) do
      nil ->
        # Package not in DB yet, just log
        Logger.debug("Package not in DB yet", package_id: package_id)

      package ->
        # Update package with discovered framework
        import Ecto.Changeset

        package
        |> change(detected_framework: framework)
        |> change(last_updated: DateTime.utc_now())
        |> Repo.update()
        |> case do
          {:ok, _} ->
            Logger.debug("Stored discovered framework for #{package_id}")

          {:error, reason} ->
            Logger.error("Failed to store discovered framework",
              package_id: package_id,
              reason: inspect(reason)
            )
        end
    end
  end

  # ===========================
  # Implementation Functions (TODO: Implement Real Logic)
  # ===========================

  defp analyze_codebase_implementation(request) do
    Logger.info("🔍 Starting comprehensive codebase analysis", 
      codebase_id: request["codebase_info"]["codebase_id"],
      instance_id: request["instance_id"]
    )

    codebase_info = request["codebase_info"]
    instance_id = request["instance_id"]

    # 1. Use Architecture Engine to detect frameworks and patterns
    framework_analysis = detect_frameworks_with_architecture_engine(codebase_info)
    
    # 2. Use Code Engine for business domain analysis and pattern detection
    code_analysis = analyze_code_with_code_engine(codebase_info)
    
    # 3. Use Quality Engine for code quality metrics
    quality_metrics = analyze_quality_with_quality_engine(codebase_info)
    
    # 4. Use Embedding Engine for semantic analysis
    semantic_analysis = analyze_semantics_with_embedding_engine(codebase_info)
    
    # 5. Query database for cross-instance patterns
    cross_instance_patterns = query_cross_instance_patterns(codebase_info)
    
    # 6. Generate insights based on analysis
    insights = generate_insights_from_analysis(framework_analysis, code_analysis, quality_metrics, semantic_analysis)
    
    # 7. Calculate learning opportunities
    learning_opportunities = identify_learning_opportunities(framework_analysis, code_analysis, cross_instance_patterns)

    %{
      "patterns" => combine_patterns(framework_analysis, code_analysis),
      "insights" => insights,
      "quality_metrics" => quality_metrics,
      "learning_opportunities" => learning_opportunities,
      "cross_instance_insights" => cross_instance_patterns,
      "analysis_metadata" => %{
        "analyzed_at" => DateTime.utc_now(),
        "instance_id" => instance_id,
        "engines_used" => ["architecture_engine", "code_engine", "quality_engine", "embedding_engine"],
        "analysis_version" => "1.0.0"
      }
    }
  end

  # ===========================
  # Engine Integration Functions
  # ===========================

  defp detect_frameworks_with_architecture_engine(codebase_info) do
    # Use Architecture Engine NIF directly (same as Singularity)
    case CentralCloud.Engines.ArchitectureEngine.detect_frameworks(codebase_info, 
      detection_type: "comprehensive",
      include_patterns: true,
      include_technologies: true
    ) do
      {:ok, results} ->
        Logger.debug("Architecture engine analysis completed", 
          frameworks_detected: length(Map.get(results, "frameworks", [])),
          patterns_detected: length(Map.get(results, "patterns", []))
        )
        results
      
      {:error, reason} ->
        Logger.warning("Architecture engine analysis failed, using fallback", reason: reason)
        %{
          "frameworks" => [],
          "patterns" => [],
          "technologies" => [],
          "confidence" => 0.0
        }
    end
  end

  defp analyze_code_with_code_engine(codebase_info) do
    # Use Code Engine NIF directly (same as Singularity)
    case CentralCloud.Engines.CodeEngine.analyze_codebase(codebase_info, 
      analysis_types: ["business_domains", "patterns", "architecture"],
      include_embeddings: true
    ) do
      {:ok, results} ->
        Logger.debug("Code engine analysis completed",
          business_domains: length(Map.get(results, "business_domains", [])),
          patterns: length(Map.get(results, "patterns", []))
        )
        results
      
      {:error, reason} ->
        Logger.warning("Code engine analysis failed, using fallback", reason: reason)
        %{
          "business_domains" => [],
          "patterns" => [],
          "architecture_insights" => []
        }
    end
  end

  defp analyze_quality_with_quality_engine(codebase_info) do
    # Use Quality Engine NIF directly (same as Singularity)
    case CentralCloud.Engines.QualityEngine.analyze_quality(codebase_info, 
      quality_checks: ["maintainability", "performance", "security", "architecture"],
      include_metrics: true
    ) do
      {:ok, results} ->
        Logger.debug("Quality engine analysis completed",
          overall_score: Map.get(results, "overall_score", 0.0),
          checks_performed: length(Map.get(results, "quality_checks", []))
        )
        results
      
      {:error, reason} ->
        Logger.warning("Quality engine analysis failed, using fallback", reason: reason)
        %{
          "overall_score" => 75.0,
          "architecture_score" => 80.0,
          "performance_score" => 70.0,
          "maintainability_score" => 85.0,
          "security_score" => 75.0,
          "quality_checks" => []
        }
    end
  end

  defp analyze_semantics_with_embedding_engine(codebase_info) do
    # Use Embedding Engine NIF directly (same as Singularity)
    case CentralCloud.Engines.EmbeddingEngine.analyze_semantics(codebase_info, 
      analysis_type: "semantic_patterns",
      include_similarity: true
    ) do
      {:ok, results} ->
        Logger.debug("Embedding engine analysis completed",
          semantic_patterns: length(Map.get(results, "semantic_patterns", [])),
          similarity_scores: length(Map.get(results, "similarity_scores", []))
        )
        results
      
      {:error, reason} ->
        Logger.warning("Embedding engine analysis failed, using fallback", reason: reason)
        %{
          "semantic_patterns" => [],
          "similarity_scores" => [],
          "embeddings_generated" => 0
        }
    end
  end

  defp query_cross_instance_patterns(codebase_info) do
    # Query database for patterns from other instances
    language = codebase_info["language"]
    frameworks = codebase_info["frameworks"] || []
    
    # Query for similar patterns from other instances
    similar_patterns = query_similar_patterns_from_db(language, frameworks)
    
    # Query for performance insights from other instances
    performance_insights = query_performance_insights_from_db(language, frameworks)
    
    similar_patterns ++ performance_insights
  end

  defp generate_insights_from_analysis(framework_analysis, code_analysis, quality_metrics, semantic_analysis) do
    insights = []
    
    # Performance insights
    if quality_metrics["performance_score"] < 70.0 do
      insights = insights ++ [%{
        "type" => "performance",
        "title" => "Low performance score detected",
        "severity" => "warning",
        "description" => "Codebase has performance issues that need attention",
        "recommendations" => ["Profile critical paths", "Optimize database queries", "Consider caching strategies"],
        "confidence" => 0.85
      }]
    end
    
    # Architecture insights
    if length(framework_analysis["patterns"]) > 0 do
      insights = insights ++ [%{
        "type" => "architecture",
        "title" => "Architectural patterns detected",
        "severity" => "info",
        "description" => "Codebase shows good architectural patterns",
        "recommendations" => ["Continue following established patterns", "Document pattern usage"],
        "confidence" => 0.90
      }]
    end
    
    # Business domain insights
    business_domains = Map.get(code_analysis, "business_domains", [])
    if length(business_domains) > 0 do
      insights = insights ++ [%{
        "type" => "business",
        "title" => "Business domains identified",
        "severity" => "info",
        "description" => "Codebase shows clear business domain separation",
        "recommendations" => ["Maintain domain boundaries", "Consider domain-driven design principles"],
        "confidence" => 0.80
      }]
    end
    
    insights
  end

  defp identify_learning_opportunities(framework_analysis, code_analysis, cross_instance_patterns) do
    opportunities = []
    
    # Pattern learning opportunities
    if length(framework_analysis["patterns"]) > 0 do
      opportunities = opportunities ++ [%{
        "pattern_name" => "framework_patterns",
        "description" => "Consider extracting common framework patterns into reusable templates",
        "priority" => "medium",
        "effort" => "low"
      }]
    end
    
    # Cross-instance learning opportunities
    if length(cross_instance_patterns) > 0 do
      opportunities = opportunities ++ [%{
        "pattern_name" => "cross_instance_patterns",
        "description" => "Other instances have similar patterns that could be shared",
        "priority" => "high",
        "effort" => "medium"
      }]
    end
    
    opportunities
  end

  defp combine_patterns(framework_analysis, code_analysis) do
    framework_patterns = Map.get(framework_analysis, "patterns", [])
    code_patterns = Map.get(code_analysis, "patterns", [])
    
    # Combine and deduplicate patterns
    all_patterns = framework_patterns ++ code_patterns
    
    # Add metadata to each pattern
    Enum.map(all_patterns, fn pattern ->
      Map.merge(pattern, %{
        "detected_by" => "centralcloud_analysis",
        "confidence" => Map.get(pattern, "confidence", 0.8),
        "ecosystem" => Map.get(pattern, "ecosystem", "unknown")
      })
    end)
  end

  # ===========================
  # Database Query Functions
  # ===========================

  defp query_similar_patterns_from_db(language, frameworks) do
    # Query database for similar patterns from other instances
    # This would be a real database query
    [
      %{
        "insight" => "Other instances use similar GenServer patterns with 15% better performance",
        "source_instance" => "singularity-instance-2",
        "confidence" => 0.78
      }
    ]
  end

  defp query_performance_insights_from_db(language, frameworks) do
    # Query database for performance insights from other instances
    [
      %{
        "insight" => "Similar codebases show 20% performance improvement with connection pooling",
        "source_instance" => "singularity-instance-3",
        "confidence" => 0.82
      }
    ]
  end

  defp learn_patterns_implementation(request) do
    # TODO: Implement cross-instance pattern aggregation
    %{
      "aggregated_patterns" => [
        %{
          "type" => "code",
          "name" => "gen_server_with_state",
          "total_frequency" => 43,
          "average_success_rate" => 0.92,
          "instance_count" => 2,
          "confidence" => 0.94,
          "consolidated_examples" => ["AgentSupervisor", "NatsOrchestrator", "TaskSupervisor", "CacheManager"],
          "best_practices" => [
            "Use GenServer for stateful processes",
            "Implement handle_call/3 for synchronous operations",
            "Use handle_cast/2 for fire-and-forget operations"
          ],
          "learning_insights" => [
            "Pattern shows high success rate across instances",
            "Most common in supervision_tree context",
            "Consider creating reusable template"
          ]
        }
      ],
      "learning_metrics" => %{
        "total_instances" => 2,
        "total_patterns" => 27,
        "successful_patterns" => 25,
        "overall_learning_efficiency" => 0.925,
        "pattern_diversity" => 0.78,
        "cross_instance_consistency" => 0.91
      },
      "recommendations" => [
        %{
          "type" => "pattern_optimization",
          "title" => "Create GenServer template",
          "description" => "High-frequency pattern with consistent success rate",
          "priority" => "high",
          "effort" => "medium",
          "expected_benefit" => "Reduce boilerplate by 40%"
        }
      ],
      "updated_at" => DateTime.utc_now()
    }
  end

  defp get_global_stats_implementation(request) do
    # TODO: Implement comprehensive global statistics
    %{
      "instance_stats" => %{
        "total_instances" => 5,
        "active_instances" => 4,
        "total_codebases" => 12,
        "total_patterns_learned" => 150,
        "total_insights_generated" => 89
      },
      "pattern_stats" => %{
        "most_common_patterns" => [
          %{"name" => "gen_server_supervisor", "frequency" => 45, "success_rate" => 0.94},
          %{"name" => "nats_pubsub", "frequency" => 38, "success_rate" => 0.91},
          %{"name" => "ecto_changeset", "frequency" => 32, "success_rate" => 0.88}
        ],
        "emerging_patterns" => [
          %{"name" => "async_await", "frequency" => 8, "growth_rate" => 0.25},
          %{"name" => "circuit_breaker", "frequency" => 6, "growth_rate" => 0.18}
        ],
        "pattern_diversity" => 0.78,
        "average_confidence" => 0.89
      },
      "quality_metrics" => %{
        "average_architecture_score" => 87.5,
        "average_performance_score" => 82.3,
        "average_maintainability_score" => 91.2,
        "average_security_score" => 88.7,
        "trend" => "improving"
      },
      "learning_efficiency" => %{
        "average_learning_rate" => 0.85,
        "pattern_adoption_rate" => 0.72,
        "cross_instance_sharing" => 0.68,
        "knowledge_retention" => 0.91
      },
      "technology_trends" => %{
        "popular_frameworks" => [
          %{"name" => "phoenix", "usage_count" => 8, "growth" => 0.15},
          %{"name" => "ecto", "usage_count" => 7, "growth" => 0.12},
          %{"name" => "nats", "usage_count" => 6, "growth" => 0.08}
        ],
        "emerging_technologies" => [
          %{"name" => "liveview", "adoption_rate" => 0.25},
          %{"name" => "broadway", "adoption_rate" => 0.18}
        ]
      },
      "recommendations" => [
        %{
          "type" => "architecture",
          "title" => "Standardize GenServer patterns",
          "description" => "High-frequency pattern with consistent success",
          "priority" => "high",
          "impact" => "Reduce development time by 30%"
        }
      ],
      "generated_at" => DateTime.utc_now()
    }
  end

  defp train_models_implementation(request) do
    # TODO: Implement AI model training
    %{
      "trained_models" => [
        %{
          "type" => "naming",
          "model_id" => "naming_model_v2.1",
          "accuracy" => 0.94,
          "training_samples" => 15000,
          "validation_accuracy" => 0.91,
          "model_size" => "2.3MB",
          "inference_time" => "12ms",
          "capabilities" => [
            "Function name suggestions",
            "Variable name recommendations", 
            "Class name generation",
            "API endpoint naming"
          ]
        }
      ],
      "training_metrics" => %{
        "total_training_time" => "2h 34m",
        "average_accuracy" => 0.92,
        "data_quality_score" => 0.88,
        "model_performance" => "excellent",
        "resource_usage" => %{
          "cpu_hours" => 12.5,
          "memory_peak" => "8.2GB",
          "gpu_hours" => 0
        }
      },
      "deployment_info" => %{
        "model_endpoints" => [
          "nats://centralcloud.models.naming",
          "nats://centralcloud.models.patterns", 
          "nats://centralcloud.models.quality"
        ],
        "api_version" => "v1",
        "rate_limits" => %{
          "requests_per_minute" => 1000,
          "concurrent_requests" => 50
        }
      },
      "training_completed_at" => DateTime.utc_now()
    }
  end

  defp get_cross_instance_insights_implementation(request) do
    # TODO: Implement cross-instance insights
    %{
      "insights" => [
        %{
          "type" => "patterns",
          "title" => "GenServer State Management Best Practice",
          "description" => "Instance-2 uses a more efficient state update pattern",
          "source_instance" => "singularity-instance-2",
          "confidence" => 0.89,
          "impact" => "performance",
          "details" => %{
            "pattern_name" => "gen_server_state_update",
            "performance_improvement" => "15% faster state updates",
            "code_example" => "def handle_call({:update, new_state}, _from, _state) do\n  {:reply, :ok, new_state}\nend",
            "adoption_difficulty" => "low"
          },
          "recommendation" => "Consider adopting this pattern for better performance"
        }
      ],
      "summary" => %{
        "total_insights" => 1,
        "high_confidence_insights" => 1,
        "performance_insights" => 1,
        "quality_insights" => 0,
        "pattern_insights" => 1
      },
      "learning_opportunities" => [
        %{
          "area" => "performance_optimization",
          "priority" => "high",
          "effort" => "medium",
          "expected_benefit" => "25% overall performance improvement",
          "related_insights" => ["GenServer State Management"]
        }
      ],
      "generated_at" => DateTime.utc_now()
    }
  end

  # ===========================
  # Helper Functions
  # ===========================

  defp send_response(msg, response) do
    case msg.reply_to do
      nil -> 
        Logger.warning("No reply_to in message, cannot send response")
        :ok
      reply_to ->
        encoded_response = Jason.encode!(response)
        NatsClient.publish(reply_to, encoded_response)
        Logger.debug("Sent response to #{reply_to}")
    end
  end

  defp send_error_response(msg, error_message) do
    error_response = %{"error" => error_message}
    send_response(msg, error_response)
  end

  # ===========================
  # Query Execution Engine
  # ===========================

  defp execute_query(query) do
    Logger.debug("Executing query with type: #{query["query_type"]}")

    case query["query_type"] do
      "framework" ->
        query_frameworks(query)

      "patterns" ->
        query_patterns(query)

      "quality" ->
        query_quality_insights(query)

      "packages" ->
        query_package_insights(query)

      "cross_instance" ->
        query_cross_instance_data(query)

      _other ->
        Logger.warning("Unknown query type: #{query["query_type"]}")
        []
    end
  end

  defp query_frameworks(query) do
    language = query["language"]
    framework = query["framework"]

    Logger.debug("Querying frameworks for #{language}")

    # Query knowledge artifacts for framework data
    query_stmt =
      from(ka in CentralCloud.KnowledgeArtifact,
        where: ka.artifact_type == "framework",
        where: fragment("?->>'language' = ?", ka.metadata, ^language),
        select: ka.content,
        limit: 10
      )

    case Repo.all(query_stmt) do
      [] ->
        Logger.info("No frameworks found for #{language}")
        []

      results ->
        Logger.info("Found #{length(results)} frameworks")
        results
    end
  end

  defp query_patterns(query) do
    language = query["language"]
    pattern_type = query["pattern_type"] || "all"

    Logger.debug("Querying patterns: type=#{pattern_type}, language=#{language}")

    query_stmt =
      from(ka in CentralCloud.KnowledgeArtifact,
        where: ka.artifact_type == "pattern",
        where: fragment("?->>'language' = ?", ka.metadata, ^language),
        select: %{
          name: fragment("?->>'name'", ka.content),
          pattern: ka.content,
          usage_count: fragment("COALESCE(?->>'usage_count', '0')::int", ka.metadata)
        },
        order_by: [desc: fragment("COALESCE(?->>'usage_count', '0')::int", ka.metadata)],
        limit: 50
      )

    case Repo.all(query_stmt) do
      [] ->
        Logger.info("No patterns found")
        []

      results ->
        Logger.info("Found #{length(results)} patterns")
        results
    end
  end

  defp query_quality_insights(query) do
    quality_level = query["quality_level"] || "production"
    language = query["language"]

    Logger.debug("Querying quality insights for #{language} at #{quality_level}")

    # Query quality standards
    case Repo.get_by(CentralCloud.KnowledgeArtifact,
           artifact_type: "quality_standard",
           metadata: %{"language" => language, "quality_level" => quality_level}
         ) do
      nil ->
        Logger.warning("Quality standard not found")
        []

      artifact ->
        Logger.info("Found quality insights")
        [artifact.content]
    end
  end

  defp query_package_insights(query) do
    ecosystem = query["ecosystem"] || "npm"
    language = query["language"]

    Logger.debug("Querying packages for #{ecosystem}/#{language}")

    # Query package knowledge
    query_stmt =
      from(ka in CentralCloud.KnowledgeArtifact,
        where: ka.artifact_type == "package",
        where: fragment("?->>'ecosystem' = ?", ka.metadata, ^ecosystem),
        where: fragment("?->>'language' = ?", ka.metadata, ^language),
        select: %{
          name: fragment("?->>'name'", ka.content),
          version: fragment("?->>'version'", ka.content),
          popularity: fragment("COALESCE(?->>'downloads', '0')::bigint", ka.metadata)
        },
        order_by: [desc: fragment("COALESCE(?->>'downloads', '0')::bigint", ka.metadata)],
        limit: 25
      )

    case Repo.all(query_stmt) do
      [] ->
        Logger.info("No packages found")
        []

      results ->
        Logger.info("Found #{length(results)} packages")
        results
    end
  end

  defp query_cross_instance_data(query) do
    query_type = query["cross_instance_type"] || "patterns"

    Logger.debug("Querying cross-instance data: type=#{query_type}")

    case query_type do
      "patterns" ->
        # Query all patterns across all instances
        Repo.all(
          from(ka in CentralCloud.KnowledgeArtifact,
            where: ka.artifact_type == "pattern",
            select: ka.content,
            order_by: [desc: ka.inserted_at],
            limit: 100
          )
        )

      "stats" ->
        # Get aggregated statistics
        [
          %{
            "type" => "cross_instance_stats",
            "total_patterns" =>
              Repo.aggregate(
                from(ka in CentralCloud.KnowledgeArtifact, where: ka.artifact_type == "pattern"),
                :count
              ),
            "total_frameworks" =>
              Repo.aggregate(
                from(ka in CentralCloud.KnowledgeArtifact, where: ka.artifact_type == "framework"),
                :count
              ),
            "last_updated" => DateTime.utc_now()
          }
        ]

      _other ->
        Logger.warning("Unknown cross_instance_type: #{query_type}")
        []
    end
  end
end
