defmodule CentralCloud.Consumers.PatternLearningConsumer do
  @moduledoc """
  Consumes pattern learning messages from Singularity instances.

  Reads from:
  - pgmq: pattern_discoveries_published
  - pgmq: patterns_learned_published

  Aggregates patterns across instances and stores in local database
  for later broadcasting back to all instances via patterns_aggregated_broadcast.

  ## Message Format

  Pattern Discovery:
  ```json
  {
    "type": "pattern_discovery",
    "instance_id": "singularity-1",
    "patterns": [
      {
        "name": "gen_server_pattern",
        "frequency": 45,
        "confidence": 0.92,
        "ecosystem": "elixir"
      }
    ],
    "timestamp": "2025-01-10T..."
  }
  ```

  Learned Pattern:
  ```json
  {
    "type": "patterns_learned",
    "instance_id": "singularity-1",
    "artifacts": [...],
    "usage_count": 100,
    "success_rate": 0.95,
    "timestamp": "2025-01-10T..."
  }
  ```
  """

  require Logger
  alias Singularity.Knowledge.Requests, as: KnowledgeRequests

  @doc """
  Handle incoming pattern message from queue.

  Returns :ok on success, {:error, reason} on failure.
  """
  def handle_message(%{"type" => "pattern_discovery", "instance_id" => instance_id} = msg) do
    Logger.info("[PatternLearning] Received pattern discovery from #{instance_id}",
      pattern_count: length(Map.get(msg, "patterns", []))
    )

    case store_pattern_discovery(msg) do
      :ok ->
        Logger.debug("[PatternLearning] Stored pattern discovery from #{instance_id}")
        :ok

      {:error, reason} ->
        Logger.error("[PatternLearning] Failed to store pattern discovery: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_message(%{"type" => "patterns_learned", "instance_id" => instance_id} = msg) do
    Logger.info("[PatternLearning] Received learned patterns from #{instance_id}",
      artifact_count: length(Map.get(msg, "artifacts", [])),
      success_rate: Map.get(msg, "success_rate", 0.0)
    )

    case store_learned_patterns(msg) do
      :ok ->
        Logger.debug("[PatternLearning] Stored learned patterns from #{instance_id}")
        :ok

      {:error, reason} ->
        Logger.error("[PatternLearning] Failed to store learned patterns: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_message(msg) do
    Logger.warning("[PatternLearning] Unknown message type: #{inspect(msg)}")
    {:error, :unknown_message_type}
  end

  # ===========================
  # Private Functions
  # ===========================

  defp store_pattern_discovery(%{
         "instance_id" => instance_id,
         "patterns" => patterns,
         "timestamp" => timestamp
       }) do
    try do
      # Store each pattern in database for aggregation
      Enum.each(patterns, fn pattern ->
        # Store in approved_patterns table with instance_id, timestamp
        # This aggregates patterns across instances for later broadcast
        store_single_pattern(instance_id, pattern, timestamp)
      end)

      :ok
    rescue
      e ->
        Logger.error("Error storing pattern discovery: #{inspect(e)}")
        {:error, e}
    end
  end

  defp store_pattern_discovery(_msg), do: {:error, :invalid_format}

  defp store_learned_patterns(%{
         "instance_id" => instance_id,
         "artifacts" => artifacts,
         "usage_count" => usage_count,
         "success_rate" => success_rate,
         "timestamp" => timestamp
       }) do
    try do
      # Store high-quality patterns for curation and export
      Enum.each(artifacts, fn artifact ->
        # Store in templates table (category="pattern") with quality metrics
        # High-quality learned patterns become templates for distribution
        store_learned_artifact(instance_id, artifact, usage_count, success_rate, timestamp)
      end)

      :ok
    rescue
      e ->
        Logger.error("Error storing learned patterns: #{inspect(e)}")
        {:error, e}
    end
  end

  defp store_learned_patterns(_msg), do: {:error, :invalid_format}

  defp store_single_pattern(instance_id, pattern, _timestamp) do
    Logger.debug("[PatternLearning] Storing pattern #{pattern["name"]} from #{instance_id}")

    try do
      name = pattern["name"]
      frequency = pattern["frequency"] || 1
      confidence = pattern["confidence"] || 0.0
      ecosystem = pattern["ecosystem"] || "unknown"

      # Upsert pattern: if exists, increment frequency; if new, insert
      case CentralCloud.Repo.query("""
        INSERT INTO approved_patterns (
          id, name, ecosystem, frequency, confidence, instances_count, approved_at, inserted_at, updated_at
        ) VALUES (
          uuid_generate_v7(), $1, $2, $3, $4, 1, NOW(), NOW(), NOW()
        )
        ON CONFLICT (name, ecosystem) DO UPDATE SET
          frequency = approved_patterns.frequency + $3,
          confidence = GREATEST(approved_patterns.confidence, $4),
          instances_count = approved_patterns.instances_count + 1,
          updated_at = NOW()
        """, [name, ecosystem, frequency, confidence]) do
        {:ok, _} ->
          Logger.debug("[PatternLearning] ✓ Stored pattern #{name}")
          resolve_requests(pattern, :technology, %{
            "pattern_name" => name,
            "ecosystem" => ecosystem,
            "confidence" => confidence,
            "instance_id" => instance_id
          })

          # Trigger real-time sync if confidence >= 0.85
          if confidence >= 0.85 do
            trigger_realtime_sync(:pattern, name, ecosystem, confidence)
          end

        {:error, reason} ->
          Logger.error("[PatternLearning] ✗ Failed to store pattern: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("[PatternLearning] Exception storing pattern: #{inspect(e)}")
    end
  end

  defp store_learned_artifact(instance_id, artifact, usage_count, success_rate, timestamp) do
    Logger.debug("[PatternLearning] Storing learned artifact from #{instance_id}",
      name: artifact["name"],
      usage_count: usage_count,
      success_rate: success_rate
    )

    try do
      name = artifact["name"]
      ecosystem = artifact["ecosystem"] || "unknown"
      description = artifact["description"]
      examples = artifact["examples"] || []

      last_used =
        timestamp ||
          artifact["last_used"] ||
          DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

      # Store high-quality learned artifact (success_rate >= 0.9)
      if success_rate >= 0.9 do
        # Store in approved_patterns table (for aggregation)
        case CentralCloud.Repo.query("""
          INSERT INTO approved_patterns (
            id, name, ecosystem, frequency, confidence, description, examples, approved_at, inserted_at, updated_at
          ) VALUES (
            uuid_generate_v7(), $1, $2, $3, $4, $5, $6, NOW(), NOW(), NOW()
          )
          ON CONFLICT (name, ecosystem) DO UPDATE SET
            description = COALESCE($5, approved_patterns.description),
            examples = COALESCE($6, approved_patterns.examples),
            confidence = GREATEST(approved_patterns.confidence, $4),
            approved_at = NOW(),
            updated_at = NOW()
          """, [name, ecosystem, usage_count, success_rate, description, Jason.encode!(examples)]) do
          {:ok, _} ->
            # Also store in templates table (category="pattern") for distribution
            template_data = %{
              "id" => "#{name}-#{ecosystem}",
              "category" => "pattern",
              "metadata" => %{
                "name" => name,
                "description" => description || "",
                "ecosystem" => ecosystem,
                "instance_id" => instance_id
              },
              "content" => %{
                "type" => "learned_pattern",
                "examples" => examples,
                "usage_count" => usage_count,
                "success_rate" => success_rate
              },
              "quality_score" => success_rate,
              "usage_stats" => %{
                "count" => usage_count,
                "success_rate" => success_rate,
                "last_used" => last_used
              },
              "version" => "1.0.0"
            }
            
            case CentralCloud.TemplateService.store_template(template_data) do
              {:ok, _template} ->
                Logger.debug("[PatternLearning] Stored pattern in templates table")
              {:error, reason} ->
                Logger.warning("[PatternLearning] Failed to store pattern template: #{inspect(reason)}")
            end
            
            Logger.info("[PatternLearning] ✓ Approved learned artifact #{name}",
              success_rate: success_rate,
              usage_count: usage_count
            )

            resolve_requests(artifact, :framework, %{
              "pattern_name" => name,
              "ecosystem" => ecosystem,
              "success_rate" => success_rate,
              "instance_id" => instance_id
            })

            # Trigger immediate sync for high-quality patterns
            trigger_realtime_sync(:learned_artifact, name, ecosystem, success_rate)

          {:error, reason} ->
            Logger.error("[PatternLearning] ✗ Failed to store learned artifact: #{inspect(reason)}")
        end
      end
    rescue
      e ->
        Logger.error("[PatternLearning] Exception storing learned artifact: #{inspect(e)}")
    end
  end

  defp trigger_realtime_sync(pattern_type, name, ecosystem, confidence) do
    Logger.info("[PatternLearning] 🔄 Triggering real-time sync",
      type: pattern_type,
      pattern: name,
      confidence: confidence
    )

    # Call UpdateBroadcaster to sync immediately (non-blocking)
    spawn(fn ->
      CentralCloud.Consumers.UpdateBroadcaster.sync_single_pattern(name, ecosystem, pattern_type)
    end)
  end

  defp resolve_requests(pattern, default_type, resolution_payload) do
    try do
      pattern_type = determine_pattern_type(pattern, default_type)
      extension = extract_extension(pattern)
      ecosystem = Map.get(pattern, "ecosystem")
      source_reference =
        Map.get(pattern, "repo_path") ||
          Map.get(pattern, "source_reference") ||
          Map.get(pattern, "codebase")

      KnowledgeRequests.resolve_pattern(pattern_type, extension, resolution_payload)
      KnowledgeRequests.resolve_pattern_by_ecosystem(pattern_type, ecosystem, resolution_payload)
      KnowledgeRequests.resolve_by_source(:pattern, source_reference, resolution_payload)
      KnowledgeRequests.resolve_by_source(:anti_pattern, pattern["name"], resolution_payload)
    rescue
      error ->
        Logger.debug("[PatternLearning] Unable to resolve knowledge requests automatically",
          reason: inspect(error),
          pattern: pattern
        )
    end
  end

  defp determine_pattern_type(%{"pattern_type" => type}, _default) when is_binary(type) do
    case String.downcase(type) do
      "framework" -> :framework
      "technology" -> :technology
      _ -> :technology
    end
  end

  defp determine_pattern_type(%{"pattern_type" => type}, _default) when is_atom(type) do
    case type do
      :framework -> :framework
      :technology -> :technology
      _ -> :technology
    end
  end

  defp determine_pattern_type(_pattern, default), do: default

  defp extract_extension(pattern) do
    cond do
      is_binary(pattern["extension"]) ->
        pattern["extension"]

      is_list(pattern["file_patterns"]) ->
        pattern["file_patterns"]
        |> Enum.find_value(&extension_from_pattern/1)

      is_binary(pattern["file_pattern"]) ->
        extension_from_pattern(pattern["file_pattern"])

      true ->
        nil
    end
  end

  defp extension_from_pattern(pattern) when is_binary(pattern) do
    pattern
    |> String.split(".")
    |> List.last()
    |> case do
      nil -> nil
      fragment ->
        fragment =
          fragment
          |> String.replace(~r/[^a-zA-Z0-9]/, "")
          |> String.downcase()

        if fragment == "" do
          nil
        else
          ".#{fragment}"
        end
    end
  end

  defp extension_from_pattern(_), do: nil
end
