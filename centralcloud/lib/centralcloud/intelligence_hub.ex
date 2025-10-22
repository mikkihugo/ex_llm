defmodule Centralcloud.IntelligenceHub do
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

  alias Centralcloud.{Repo, NatsClient}

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
    # TODO: Implement query logic
    Logger.debug("Querying insights: #{inspect(query)}")
    {:reply, {:ok, []}, state}
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
    NatsClient.subscribe("intelligence.query", &handle_intelligence_query/1)

    # NEW: Dependency reports from instances
    NatsClient.subscribe("instance.dependencies.report", &handle_dependency_report/1)

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
    case Repo.get_by(Centralcloud.KnowledgeArtifact,
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

    case Repo.get_by(Centralcloud.KnowledgeArtifact,
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
    case Repo.get_by(Centralcloud.KnowledgeArtifact,
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
        Centralcloud.Jobs.PackageSyncJob.handle_dependency_report(instance_id, dependencies)
        Logger.debug("Processed dependency report from instance #{instance_id}")

      {:error, reason} ->
        Logger.error("Failed to decode dependency report: #{inspect(reason)}")
    end
  end
end
