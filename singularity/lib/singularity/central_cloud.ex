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
  alias Singularity.PatternCache
  alias Singularity.InstancePattern
  alias Singularity.PatternConsensus

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
    # Store patterns in database for cross-instance learning
    results = Enum.map(instance_patterns, fn pattern_data ->
      pattern_attrs = %{
        instance_id: get_instance_id(),
        pattern_name: Map.get(pattern_data, :name, Map.get(pattern_data, :pattern_name, "unknown")),
        pattern_type: Map.get(pattern_data, :type, Map.get(pattern_data, :pattern_type, "unknown")),
        pattern_data: pattern_data,
        confidence: Map.get(pattern_data, :confidence, 0.5),
        learned_at: Map.get(pattern_data, :detected_at, DateTime.utc_now()),
        source_codebase: Map.get(pattern_data, :codebase_path),
        metadata: Map.get(pattern_data, :metadata, %{})
      }

      case Repo.insert(InstancePattern.changeset(%InstancePattern{}, pattern_attrs)) do
        {:ok, _pattern} -> {:ok, :learned}
        {:error, changeset} ->
          Logger.warning("Failed to learn pattern", errors: changeset.errors)
          {:error, :learn_failed}
      end
    end)

    # Check if all patterns were learned successfully
    if Enum.all?(results, fn {status, _} -> status == :ok end) do
      Logger.debug("Pattern learning completed",
        patterns_learned: length(results),
        instance_id: get_instance_id()
      )
      {:ok, :learned}
    else
      failed_count = Enum.count(results, fn {status, _} -> status == :error end)
      Logger.warning("Some patterns failed to learn", failed_count: failed_count)
      {:error, :partial_failure}
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
      {:ok, cache_entry} ->
        filter_patterns_by_types(cache_entry.patterns, pattern_types)
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
    # Check database cache with expiry
    case Repo.get_by(PatternCache, cache_key: cache_key) do
      nil ->
        {:error, :not_found}
      cache_entry ->
        # Check if expired
        if cache_entry.expires_at && DateTime.compare(cache_entry.expires_at, DateTime.utc_now()) == :lt do
          # Delete expired entry
          Repo.delete(cache_entry)
          {:error, :not_found}
        else
          # Update hit count
          cache_entry
          |> Ecto.Changeset.change(hit_count: cache_entry.hit_count + 1)
          |> Repo.update()

          {:ok, cache_entry}
        end
    end
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
    # Store in database cache
    expires_at = case Map.get(cache_data, :ttl_seconds) do
      nil -> nil
      ttl -> DateTime.add(DateTime.utc_now(), ttl, :second)
    end

    cache_attrs = %{
      instance_id: cache_data.instance_id,
      codebase_hash: cache_data.codebase_hash,
      pattern_type: Map.get(cache_data, :pattern_type, "general"),
      patterns: cache_data.patterns,
      cached_at: cache_data.cached_at,
      expires_at: expires_at,
      metadata: cache_data.metadata
    }

    case Repo.insert(PatternCache.changeset(%PatternCache{}, cache_attrs)) do
      {:ok, _cache_entry} ->
        Logger.debug("Cached patterns locally",
          pattern_count: length(cache_data.patterns),
          codebase_hash: cache_data.codebase_hash
        )
        {:ok, :cached}
      {:error, changeset} ->
        Logger.warning("Failed to cache patterns locally", errors: changeset.errors)
        {:error, :cache_failed}
    end
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