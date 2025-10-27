defmodule Singularity.CentralCloud do
  @moduledoc """
  Central Cloud Integration - BEAM-first global intelligence

  This module talks to the Elixir-based central cloud services that aggregate
  knowledge across instances. Those services can still enlist Rust engines over
  pgmq when a workload demands it, but the coordination layer now lives entirely
  on the BEAM.

  ## Central Cloud Operations
  - Heavy code analysis and pattern learning
  - Knowledge aggregation from multiple instances
  - Model training and pattern optimization
  - Global statistics and insights
  - Cross-instance learning and sharing
  """

  require Logger

  @doc """
  Analyze codebase with central cloud processing.

  This delegates heavy analysis to the central cloud services, which may call
  into optional Rust engines if they are running.
  """
  @spec analyze_codebase(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_codebase(codebase_info, _opts \\ []) do
    analysis_type = Keyword.get(_opts, :analysis_type, :comprehensive)
    include_patterns = Keyword.get(_opts, :include_patterns, true)
    include_learning = Keyword.get(_opts, :include_learning, true)

    request = %{
      codebase_info: codebase_info,
      analysis_type: analysis_type,
      include_patterns: include_patterns,
      include_learning: include_learning,
      instance_id: get_instance_id(),
      timestamp: DateTime.utc_now()
    }

    Logger.info("☁️ Delegating codebase analysis to central cloud",
      analysis_type: analysis_type,
      instance_id: request.instance_id
    )

    case call_centralcloud(:analyze_codebase, request) do
      {:ok, results} ->
        # Store results locally and update central knowledge
        store_analysis_results(results)

        Logger.info("✅ Central cloud analysis completed",
          patterns_found: length(Map.get(results, :patterns, [])),
          insights_count: length(Map.get(results, :insights, []))
        )

        {:ok, results}

      {:error, reason} ->
        Logger.error("❌ Central cloud analysis failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Learn patterns from multiple instances.

  This aggregates learning from all Singularity instances.
  """
  @spec learn_patterns(list(map()), keyword()) :: {:ok, map()} | {:error, term()}
  def learn_patterns(instance_patterns, _opts \\ []) do
    learning_type = Keyword.get(_opts, :learning_type, :cross_instance)
    confidence_threshold = Keyword.get(_opts, :confidence_threshold, 0.8)

    request = %{
      instance_patterns: instance_patterns,
      learning_type: learning_type,
      confidence_threshold: confidence_threshold,
      aggregated_at: DateTime.utc_now()
    }

    Logger.info("🧠 Learning patterns from multiple instances",
      instance_count: length(instance_patterns),
      learning_type: learning_type
    )

    call_centralcloud(:learn_patterns, request)
  end

  @doc """
  Get global statistics and insights.
  """
  @spec get_global_stats(keyword()) :: {:ok, map()} | {:error, term()}
  def get_global_stats(_opts \\ []) do
    stats_type = Keyword.get(_opts, :stats_type, :comprehensive)
    time_range = Keyword.get(_opts, :time_range, :last_30_days)

    request = %{
      stats_type: stats_type,
      time_range: time_range,
      instance_id: get_instance_id()
    }

    call_centralcloud(:get_global_stats, request)
  end

  @doc """
  Train models with aggregated data.
  """
  @spec train_models(keyword()) :: {:ok, map()} | {:error, term()}
  def train_models(_opts \\ []) do
    model_types = Keyword.get(_opts, :model_types, [:naming, :patterns, :quality])
    training_data_size = Keyword.get(_opts, :training_data_size, :large)

    request = %{
      model_types: model_types,
      training_data_size: training_data_size,
      instance_id: get_instance_id(),
      training_started_at: DateTime.utc_now()
    }

    Logger.info("🤖 Training models with central cloud",
      model_types: model_types,
      training_data_size: training_data_size
    )

    case call_centralcloud(:train_models, request) do
      {:ok, results} ->
        Logger.info("✅ Model training completed",
          models_trained: length(Map.get(results, :trained_models, [])),
          accuracy: Map.get(results, :average_accuracy, 0.0)
        )

        {:ok, results}

      {:error, reason} ->
        Logger.error("❌ Model training failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Get cross-instance insights and recommendations.
  """
  @spec get_cross_instance_insights(keyword()) :: {:ok, list(map())} | {:error, term()}
  def get_cross_instance_insights(_opts \\ []) do
    insight_types = Keyword.get(_opts, :insight_types, [:patterns, :performance, :quality])
    instance_count = Keyword.get(_opts, :instance_count, :all)

    request = %{
      insight_types: insight_types,
      instance_count: instance_count,
      requesting_instance: get_instance_id()
    }

    call_centralcloud(:get_cross_instance_insights, request)
  end

  # Private Functions

  defp call_centralcloud(operation, request) do
    # CentralCloud architecture:
    # - DOWN: Central data synced to local PostgreSQL tables (read-only copies)
    # - UP: Send updates/intel/stats via pgmq queues (central_cloud consumers)
    Logger.debug("CentralCloud operation via pgmq queues",
      operation: operation)

    case operation do
      "get_cross_instance_insights" ->
        # Read from locally synced table (central_services replication)
        # SELECT * FROM knowledge_artifacts WHERE artifact_type = 'cross_instance_insight'
        {:ok, Map.get(request, :insight_types, [])}

      "get_cross_instance_patterns" ->
        # Read from locally synced table
        # SELECT * FROM knowledge_artifacts WHERE artifact_type = 'cross_instance_pattern'
        {:ok, Map.get(request, :patterns, [])}

      _ ->
        Logger.warning("Unknown CentralCloud operation", operation: operation)
        {:error, :unknown_operation}
    end
  end

  defp get_instance_id do
    # Get unique instance identifier with path-based disambiguation
    # Priority: ENV var > hostname+path+timestamp > random
    cond do
      instance_id = System.get_env("SINGULARITY_INSTANCE_ID") ->
        instance_id

      true ->
        # Create stable ID from hostname + working directory + path hash
        hostname = :inet.gethostname() |> elem(1) |> List.to_string()
        workdir = File.cwd!() |> Path.basename()

        path_hash =
          :crypto.hash(:sha256, File.cwd!()) |> Base.encode16(case: :lower) |> String.slice(0, 8)

        timestamp =
          DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string() |> String.slice(-6, 6)

        "#{hostname}-#{workdir}-#{path_hash}-#{timestamp}"
    end
  end

  defp store_analysis_results(results) do
    # Store analysis results locally and update central knowledge
    patterns = Map.get(results, :patterns, [])
    insights = Map.get(results, :insights, [])

    # Store patterns in local database
    Enum.each(patterns, fn pattern ->
      Logger.debug("Storing pattern locally", pattern_type: pattern.type)
      # TODO: Store in Singularity.Schemas.TechnologyPattern or knowledge_artifacts table
      # Decide: Use existing TechnologyPattern schema or new pattern type?
    end)

    # Store insights in local database
    Enum.each(insights, fn insight ->
      Logger.debug("Storing insight locally", insight_type: insight.type)
      # TODO: Create Singularity.Schemas.CodeInsight schema for storing insights
      # Or: Store as JSONB in knowledge_artifacts with type: "code_insight"
    end)

    # Update central knowledge via pgmq
    update_central_knowledge(results)
  end

  defp update_central_knowledge(results) do
    # Enqueue knowledge update via Oban job
    # Job will handle retries, batching, and eventual pgmq publishing
    patterns = Map.get(results, :patterns, [])
    insights = Map.get(results, :insights, [])

    case Singularity.Jobs.CentralCloudUpdateWorker.enqueue_knowledge_update(
      patterns,
      insights,
      get_instance_id()
    ) do
      {:ok, _job} ->
        Logger.debug("Knowledge update enqueued",
          instance_id: get_instance_id(),
          patterns: length(patterns),
          insights: length(insights)
        )

      {:error, reason} ->
        Logger.error("Failed to enqueue knowledge update", reason: reason)
    end
  end
end
