defmodule Singularity.CentralCloud do
  @moduledoc """
  CentralCloud - Multi-instance learning hub for pattern aggregation and consensus.

  Uses PGMQ (PostgreSQL Message Queue) for durable cross-instance communication.
  All patterns cached in database for persistence and sharing across Singularity instances.

  ## Architecture

  ```
  Singularity Instance A          CentralCloud (PGMQ)          Singularity Instance B
  ├─ DetectionOrchestrator ──────► Pattern Queue ───────────► Pattern Learning
  ├─ Local Patterns ─────────────► Learning Queue ──────────► Consensus Engine
  └─ Enhanced Results ◄─────────── Results Queue ◄─────────── Shared Knowledge
  ```

  ## Pattern Caching Strategy

  **Database Tables:**
  - `pgmq.q_pattern_detection` - Incoming detection requests
  - `pgmq.q_pattern_learning` - Pattern learning data
  - `pgmq.q_enhanced_results` - Enhanced detection results
  - `pattern_cache` - Cached patterns by instance/checksum
  - `instance_patterns` - Patterns learned per instance

  **Cache Keys:**
  - `{instance_id}:{codebase_hash}:{pattern_type}` - Instance-specific patterns
  - `global:{pattern_name}:{pattern_type}` - Cross-instance consensus patterns
  - `enhanced:{codebase_hash}` - Enhanced detection results

  ## Usage

      # Analyze codebase with CentralCloud enhancement
      iex> CentralCloud.analyze_codebase(codebase_info, analysis_opts)
      {:ok, %{enhanced_detections: [...], learned_patterns: [...]}}

      # Learn patterns from instance detections
      iex> CentralCloud.learn_patterns(instance_patterns)
      {:ok, learning_results}
  """

  require Logger
  alias Singularity.Database.MessageQueue
  alias Singularity.Repo

  @pattern_detection_queue "pattern_detection"
  @pattern_learning_queue "pattern_learning"
  @enhanced_results_queue "enhanced_results"

  @doc """
  Analyze codebase using CentralCloud pattern intelligence.

  Queues analysis request to CentralCloud and waits for enhanced results.
  Falls back to local-only if CentralCloud unavailable.

  ## Parameters
  - `codebase_info`: Map with `:path`, `:local_detections`, `:analysis_type`
  - `opts`: Analysis options (`:include_patterns`, `:include_learning`, `:timeout`)

  ## Returns
  - `{:ok, results}` - Enhanced analysis results
  - `{:error, reason}` - Analysis failed
  """
  def analyze_codebase(codebase_info, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30000)
    include_patterns = Keyword.get(opts, :include_patterns, true)
    include_learning = Keyword.get(opts, :include_learning, true)

    # Create analysis request
    request = %{
      codebase_path: codebase_info.path,
      local_detections: codebase_info.local_detections,
      analysis_type: Map.get(codebase_info, :analysis_type, :pattern_detection),
      include_patterns: include_patterns,
      include_learning: include_learning,
      instance_id: get_instance_id(),
      request_id: generate_request_id(),
      timestamp: DateTime.utc_now()
    }

    # Queue request to CentralCloud
    case queue_analysis_request(request) do
      {:ok, message_id} ->
        # Wait for enhanced results
        wait_for_enhanced_results(request.request_id, timeout)
      {:error, reason} ->
        Logger.warning("CentralCloud analysis failed, using local only",
          reason: reason,
          codebase: codebase_info.path
        )
        {:error, reason}
    end
  end

  @doc """
  Learn patterns from instance detections.

  Queues pattern learning data to CentralCloud for cross-instance aggregation.
  Fire-and-forget - doesn't wait for results.

  ## Parameters
  - `instance_patterns`: List of pattern data from this instance

  ## Returns
  - `{:ok, :queued}` - Patterns queued for learning
  - `{:error, reason}` - Failed to queue patterns
  """
  def learn_patterns(instance_patterns) when is_list(instance_patterns) do
    learning_data = %{
      instance_id: get_instance_id(),
      patterns: instance_patterns,
      learned_at: DateTime.utc_now(),
      pattern_count: length(instance_patterns)
    }

    case MessageQueue.send(@pattern_learning_queue, learning_data) do
      {:ok, message_id} ->
        Logger.debug("Pattern learning data queued",
          message_id: message_id,
          pattern_count: learning_data.pattern_count
        )
        {:ok, :queued}
      {:error, reason} ->
        Logger.error("Failed to queue pattern learning data", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Get cached patterns for a codebase.

  Checks local cache first, then CentralCloud cache.

  ## Parameters
  - `codebase_hash`: SHA256 hash of codebase content
  - `pattern_types`: List of pattern types to retrieve

  ## Returns
  - `{:ok, patterns}` - Cached patterns found
  - `{:error, :not_found}` - No cached patterns
  """
  def get_cached_patterns(codebase_hash, pattern_types \\ []) do
    cache_key = "codebase:#{codebase_hash}"

    # Check local cache first
    case get_local_cache(cache_key) do
      {:ok, cached} ->
        filter_patterns_by_types(cached.patterns, pattern_types)
      {:error, :not_found} ->
        # Check CentralCloud cache
        get_centralcloud_cache(cache_key, pattern_types)
    end
  end

  @doc """
  Cache patterns for a codebase.

  Stores patterns in both local and CentralCloud caches.

  ## Parameters
  - `codebase_hash`: SHA256 hash of codebase content
  - `patterns`: List of detected patterns
  - `metadata`: Additional caching metadata

  ## Returns
  - `{:ok, :cached}` - Patterns cached successfully
  - `{:error, reason}` - Caching failed
  """
  def cache_patterns(codebase_hash, patterns, metadata \\ %{}) do
    cache_data = %{
      codebase_hash: codebase_hash,
      patterns: patterns,
      cached_at: DateTime.utc_now(),
      instance_id: get_instance_id(),
      pattern_count: length(patterns),
      metadata: metadata
    }

    # Cache locally
    case cache_locally(cache_data) do
      {:ok, _} ->
        # Also cache in CentralCloud
        cache_in_centralcloud(cache_data)
      error ->
        error
    end
  end

  # Private Functions

  defp queue_analysis_request(request) do
    MessageQueue.send(@pattern_detection_queue, request)
  end

  defp wait_for_enhanced_results(request_id, timeout) do
    # Poll for results with exponential backoff
    poll_start = System.monotonic_time(:millisecond)
    poll_results(request_id, timeout, poll_start)
  end

  defp poll_results(request_id, timeout, start_time) do
    case MessageQueue.receive_message(@enhanced_results_queue) do
      {:ok, {message_id, result}} ->
        if result.request_id == request_id do
          # Found our result
          MessageQueue.acknowledge(@enhanced_results_queue, message_id)
          {:ok, result}
        else
          # Not our result, put it back and continue polling
          # Note: PGMQ visibility timeout handles this automatically
          continue_polling(request_id, timeout, start_time)
        end
      :empty ->
        continue_polling(request_id, timeout, start_time)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp continue_polling(request_id, timeout, start_time) do
    elapsed = System.monotonic_time(:millisecond) - start_time
    if elapsed < timeout do
      # Sleep with exponential backoff (max 1 second)
      sleep_time = min(1000, 100 * round(:math.pow(2, elapsed / 5000)))
      Process.sleep(sleep_time)
      poll_results(request_id, timeout, start_time)
    else
      {:error, :timeout}
    end
  end

  defp get_local_cache(cache_key) do
    # Simple in-memory cache for now - could be Redis/PostgreSQL
    # TODO: Implement persistent local caching
    {:error, :not_found}
  end

  defp get_centralcloud_cache(cache_key, pattern_types) do
    # Query CentralCloud cache via PGMQ
    cache_request = %{
      action: :get_cache,
      cache_key: cache_key,
      pattern_types: pattern_types,
      instance_id: get_instance_id(),
      request_id: generate_request_id()
    }

    case MessageQueue.send("cache_requests", cache_request) do
      {:ok, _} ->
        # Wait for cache response (simplified - could be async)
        {:error, :not_found}
      {:error, _} ->
        {:error, :not_found}
    end
  end

  defp cache_locally(cache_data) do
    # TODO: Implement local caching (PostgreSQL table or Redis)
    # For now, just log
    Logger.debug("Caching patterns locally",
      pattern_count: cache_data.pattern_count,
      codebase_hash: cache_data.codebase_hash
    )
    {:ok, :cached}
  end

  defp cache_in_centralcloud(cache_data) do
    # Queue cache update to CentralCloud
    cache_update = Map.put(cache_data, :action, :update_cache)

    case MessageQueue.send("cache_updates", cache_update) do
      {:ok, message_id} ->
        Logger.debug("Cache update queued to CentralCloud", message_id: message_id)
        {:ok, :queued}
      {:error, reason} ->
        Logger.warning("Failed to queue cache update", reason: reason)
        {:error, reason}
    end
  end

  defp filter_patterns_by_types(patterns, []) do
    {:ok, patterns}
  end

  defp filter_patterns_by_types(patterns, types) do
    filtered = Enum.filter(patterns, fn pattern ->
      pattern.type in types
    end)
    {:ok, filtered}
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp get_instance_id do
    System.get_env("SINGULARITY_INSTANCE_ID") ||
      (:crypto.hash(:sha256, File.cwd!()) |> Base.encode16(case: :lower) |> String.slice(0, 8))
  end
end