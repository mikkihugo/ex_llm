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
  def analyze_codebase(codebase_info, opts \\ []) do
    analysis_type = Keyword.get(opts, :analysis_type, :comprehensive)
    include_patterns = Keyword.get(opts, :include_patterns, true)
    include_learning = Keyword.get(opts, :include_learning, true)

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
  def learn_patterns(instance_patterns, opts \\ []) do
    learning_type = Keyword.get(opts, :learning_type, :cross_instance)
    confidence_threshold = Keyword.get(opts, :confidence_threshold, 0.8)

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
  def get_global_stats(opts \\ []) do
    stats_type = Keyword.get(opts, :stats_type, :comprehensive)
    time_range = Keyword.get(opts, :time_range, :last_30_days)

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
  def train_models(opts \\ []) do
    model_types = Keyword.get(opts, :model_types, [:naming, :patterns, :quality])
    training_data_size = Keyword.get(opts, :training_data_size, :large)

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
  def get_cross_instance_insights(opts \\ []) do
    insight_types = Keyword.get(opts, :insight_types, [:patterns, :performance, :quality])
    instance_count = Keyword.get(opts, :instance_count, :all)

    request = %{
      insight_types: insight_types,
      instance_count: instance_count,
      requesting_instance: get_instance_id()
    }

    call_centralcloud(:get_cross_instance_insights, request)
  end

  @doc """
  Cache a pattern with TTL for performance optimization.

  This stores patterns in the local database cache for fast retrieval
  and cross-instance sharing.
  """
  @spec cache_pattern(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def cache_pattern(pattern, opts \\ []) do
    ttl_seconds = Keyword.get(opts, :ttl_seconds, 3600) # 1 hour default
    instance_id = Keyword.get(opts, :instance_id, get_instance_id())

    cache_entry = %{
      pattern_key: generate_pattern_key(pattern),
      pattern_data: pattern,
      instance_id: instance_id,
      ttl_seconds: ttl_seconds,
      cached_at: DateTime.utc_now(),
      expires_at: DateTime.add(DateTime.utc_now(), ttl_seconds, :second)
    }

    case Singularity.Repo.insert(%Singularity.Schemas.PatternCache{
      pattern_key: cache_entry.pattern_key,
      pattern_data: Jason.encode!(cache_entry.pattern_data),
      instance_id: cache_entry.instance_id,
      expires_at: cache_entry.expires_at,
      metadata: %{cached_at: cache_entry.cached_at, ttl_seconds: cache_entry.ttl_seconds}
    }) do
      {:ok, _record} ->
        Logger.debug("Pattern cached successfully",
          pattern_key: cache_entry.pattern_key,
          instance_id: instance_id
        )
        {:ok, cache_entry}

      {:error, changeset} ->
        Logger.error("Failed to cache pattern", error: changeset.errors)
        {:error, changeset.errors}
    end
  end

  @doc """
  Get cached pattern by key.

  Returns the cached pattern if it exists and hasn't expired.
  """
  @spec get_cached_pattern(String.t()) :: {:ok, map()} | {:error, :not_found | :expired}
  def get_cached_pattern(pattern_key) do
    case Singularity.Repo.get_by(Singularity.Schemas.PatternCache,
           pattern_key: pattern_key,
           instance_id: get_instance_id()
         ) do
      nil ->
        {:error, :not_found}

      cache_record ->
        if DateTime.compare(cache_record.expires_at, DateTime.utc_now()) == :lt do
          # Expired, clean up and return error
          Singularity.Repo.delete(cache_record)
          {:error, :expired}
        else
          # Valid cache hit
          {:ok, Jason.decode!(cache_record.pattern_data)}
        end
    end
  end

  @doc """
  Invalidate cached pattern by key.
  """
  @spec invalidate_pattern(String.t()) :: :ok | {:error, term()}
  def invalidate_pattern(pattern_key) do
    case Singularity.Repo.get_by(Singularity.Schemas.PatternCache,
           pattern_key: pattern_key,
           instance_id: get_instance_id()
         ) do
      nil ->
        :ok

      cache_record ->
        case Singularity.Repo.delete(cache_record) do
          {:ok, _} ->
            Logger.debug("Pattern cache invalidated", pattern_key: pattern_key)
            :ok

          {:error, reason} ->
            Logger.error("Failed to invalidate pattern cache", reason: reason)
            {:error, reason}
        end
    end
  end

  @doc """
  Get pattern consensus across instances.

  This aggregates pattern confidence scores from multiple instances
  to determine the most reliable patterns.
  """
  @spec get_pattern_consensus(String.t()) :: {:ok, map()} | {:error, term()}
  def get_pattern_consensus(pattern_key) do
    # Get all instances that have this pattern
    consensus_records = Singularity.Repo.all(
      from pc in Singularity.Schemas.PatternConsensus,
      where: pc.pattern_key == ^pattern_key,
      preload: [:instance_patterns]
    )

    if Enum.empty?(consensus_records) do
      {:error, :no_consensus_data}
    else
      # Calculate consensus metrics
      total_instances = length(consensus_records)
      avg_confidence = Enum.reduce(consensus_records, 0.0, fn record, acc ->
        acc + record.average_confidence
      end) / total_instances

      consensus = %{
        pattern_key: pattern_key,
        total_instances: total_instances,
        average_confidence: avg_confidence,
        consensus_level: calculate_consensus_level(avg_confidence, total_instances),
        last_updated: Enum.max_by(consensus_records, & &1.updated_at).updated_at
      }

      {:ok, consensus}
    end
  end

  @doc """
  Update pattern consensus with new instance data.
  """
  @spec update_pattern_consensus(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def update_pattern_consensus(pattern_key, instance_data) do
    instance_id = Map.get(instance_data, :instance_id, get_instance_id())
    confidence_score = Map.get(instance_data, :confidence_score, 0.5)

    # Insert or update instance pattern
    case Singularity.Repo.insert(
           %Singularity.Schemas.InstancePattern{
             pattern_key: pattern_key,
             instance_id: instance_id,
             confidence_score: confidence_score,
             detected_at: DateTime.utc_now(),
             metadata: Map.get(instance_data, :metadata, %{})
           },
           on_conflict: [set: [confidence_score: confidence_score, detected_at: DateTime.utc_now()]],
           conflict_target: [:pattern_key, :instance_id]
         ) do
      {:ok, instance_pattern} ->
        # Update consensus aggregation
        update_consensus_aggregation(pattern_key)
        {:ok, instance_pattern}

      {:error, reason} ->
        Logger.error("Failed to update pattern consensus", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Get enhanced results from cache and consensus.

  This combines cached patterns with cross-instance consensus
  to provide the most reliable detection results.
  """
  @spec get_enhanced_results(String.t()) :: {:ok, map()} | {:error, term()}
  def get_enhanced_results(pattern_key) do
    with {:ok, cached_pattern} <- get_cached_pattern(pattern_key),
         {:ok, consensus} <- get_pattern_consensus(pattern_key) do

      enhanced_results = %{
        pattern: cached_pattern,
        consensus: consensus,
        enhanced_confidence: calculate_enhanced_confidence(cached_pattern, consensus),
        cross_instance_validated: consensus.total_instances > 1,
        last_enhanced: DateTime.utc_now()
      }

      {:ok, enhanced_results}
    else
      {:error, :not_found} ->
        {:error, :no_cached_data}

      {:error, :expired} ->
        {:error, :cache_expired}

      {:error, :no_consensus_data} ->
        # Return cached pattern without consensus enhancement
        case get_cached_pattern(pattern_key) do
          {:ok, pattern} ->
            {:ok, %{
              pattern: pattern,
              consensus: nil,
              enhanced_confidence: Map.get(pattern, :confidence, 0.5),
              cross_instance_validated: false,
              last_enhanced: DateTime.utc_now()
            }}

          error ->
            error
        end
    end
  end

  # Private Functions

  defp call_centralcloud(operation, request) do
    # CentralCloud architecture:
    # - DOWN: Central data synced to local PostgreSQL tables (read-only copies)
    # - UP: Send updates/intel/stats via pgmq queues (central_cloud consumers)
    Logger.debug("CentralCloud operation via pgmq queues",
      operation: operation)

    case operation do
      :analyze_codebase ->
        # Delegate to central cloud analysis service via PGMQ
        enqueue_analysis_request(request)

      :learn_patterns ->
        # Send pattern learning data via PGMQ
        enqueue_pattern_learning(request)

      :get_global_stats ->
        # Read from locally synced global stats table
        get_local_global_stats(request)

      :train_models ->
        # Send training request via PGMQ
        enqueue_model_training(request)

      :get_cross_instance_insights ->
        # Read from locally synced table (central_services replication)
        get_local_insights(request)

      :get_cross_instance_patterns ->
        # Read from locally synced table
        get_local_patterns(request)

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

  defp generate_pattern_key(pattern) do
    # Generate a stable key from pattern characteristics
    key_components = [
      Map.get(pattern, :type, "unknown"),
      Map.get(pattern, :name, ""),
      Map.get(pattern, :language, ""),
      Map.get(pattern, :framework, "")
    ]

    :crypto.hash(:sha256, Enum.join(key_components, ":")) |> Base.encode16(case: :lower)
  end

  defp calculate_consensus_level(avg_confidence, instance_count) do
    # Consensus levels: low, medium, high, very_high
    cond do
      avg_confidence >= 0.9 && instance_count >= 5 -> :very_high
      avg_confidence >= 0.8 && instance_count >= 3 -> :high
      avg_confidence >= 0.7 && instance_count >= 2 -> :medium
      true -> :low
    end
  end

  defp calculate_enhanced_confidence(pattern, consensus) do
    # Enhance confidence based on consensus data
    base_confidence = Map.get(pattern, :confidence, 0.5)
    consensus_multiplier = case consensus.consensus_level do
      :very_high -> 1.2
      :high -> 1.1
      :medium -> 1.05
      :low -> 1.0
    end

    min(base_confidence * consensus_multiplier, 1.0)
  end

  defp update_consensus_aggregation(pattern_key) do
    # Calculate and update consensus aggregation
    instance_patterns = Singularity.Repo.all(
      from ip in Singularity.Schemas.InstancePattern,
      where: ip.pattern_key == ^pattern_key
    )

    if length(instance_patterns) > 0 do
      avg_confidence = Enum.reduce(instance_patterns, 0.0, fn ip, acc ->
        acc + ip.confidence_score
      end) / length(instance_patterns)

      consensus_data = %{
        pattern_key: pattern_key,
        total_instances: length(instance_patterns),
        average_confidence: avg_confidence,
        consensus_level: calculate_consensus_level(avg_confidence, length(instance_patterns)),
        updated_at: DateTime.utc_now()
      }

      Singularity.Repo.insert(
        %Singularity.Schemas.PatternConsensus{
          pattern_key: pattern_key,
          total_instances: consensus_data.total_instances,
          average_confidence: consensus_data.average_confidence,
          consensus_level: Atom.to_string(consensus_data.consensus_level),
          updated_at: consensus_data.updated_at
        },
        on_conflict: [set: [
          total_instances: consensus_data.total_instances,
          average_confidence: consensus_data.average_confidence,
          consensus_level: Atom.to_string(consensus_data.consensus_level),
          updated_at: consensus_data.updated_at
        ]],
        conflict_target: :pattern_key
      )
    end
  end

  defp enqueue_analysis_request(request) do
    # Send analysis request via PGMQ to central cloud
    message = %{
      type: "codebase_analysis",
      request: request,
      enqueued_at: DateTime.utc_now()
    }

    case enqueue_message("pattern_detection", message) do
      {:ok, _msg_id} ->
        # Return mock results for now - in production this would wait for response
        {:ok, %{
          patterns: [
            %{type: "framework", name: "Phoenix", confidence: 0.95},
            %{type: "language", name: "Elixir", confidence: 0.98}
          ],
          insights: [
            %{type: "architecture", description: "MVC pattern detected", confidence: 0.87}
          ]
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp enqueue_pattern_learning(request) do
    # Send pattern learning data via PGMQ
    message = %{
      type: "pattern_learning",
      request: request,
      enqueued_at: DateTime.utc_now()
    }

    case enqueue_message("pattern_learning", message) do
      {:ok, _msg_id} ->
        {:ok, %{status: "learning_enqueued", patterns_processed: length(request.instance_patterns)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_local_global_stats(request) do
    # Read from locally synced global stats table
    # In production, this would query actual synced tables
    {:ok, %{
      total_instances: 1,
      patterns_learned: 0,
      models_trained: 0,
      last_sync: DateTime.utc_now()
    }}
  end

  defp enqueue_model_training(request) do
    # Send training request via PGMQ
    message = %{
      type: "model_training",
      request: request,
      enqueued_at: DateTime.utc_now()
    }

    case enqueue_message("model_training", message) do
      {:ok, _msg_id} ->
        {:ok, %{status: "training_enqueued", models: request.model_types}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_local_insights(request) do
    # Read from locally synced insights table
    insight_types = Map.get(request, :insight_types, [])
    {:ok, Enum.map(insight_types, fn type ->
      %{type: type, description: "Sample insight for #{type}", confidence: 0.8}
    end)}
  end

  defp get_local_patterns(request) do
    # Read from locally synced patterns table
    patterns = Map.get(request, :patterns, [])
    {:ok, Enum.map(patterns, fn pattern ->
      Map.put(pattern, :source, "central_cloud")
    end)}
  end

  defp enqueue_message(queue_name, message) do
    # Use PGMQ to enqueue message
    # This would use the actual PGMQ library in production
    Logger.debug("Enqueuing message to #{queue_name}", message: message)

    # Mock successful enqueue for now
    {:ok, :erlang.unique_integer([:positive])}
  end
end
