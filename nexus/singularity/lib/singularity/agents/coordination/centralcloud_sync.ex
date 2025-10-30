defmodule Singularity.Agents.Coordination.CentralCloudSync do
  @moduledoc """
  CentralCloud Capability Sync - Sync learned agent capabilities across instances.

  Provides multi-instance learning by:
  1. Periodically pushing local agent capabilities to CentralCloud
  2. Pulling aggregated capability insights from other instances
  3. Merging cross-instance learnings into local CapabilityRegistry

  Only active when CentralCloud service is available.

  ## Architecture

  ```
  Instance A (Singularity)
      ↓ push local capabilities
  CentralCloud (Aggregation)
      ↓ aggregate across instances
  Instance B (Singularity)
      ↓ pull merged learnings
  Both instances benefit from collective intelligence
  ```

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Agents.Coordination.CentralCloudSync",
    "purpose": "Sync learned agent capabilities across Singularity instances",
    "layer": "coordination",
    "pattern": "Periodic sync",
    "responsibilities": [
      "Push local capabilities to CentralCloud",
      "Pull aggregated learnings from other instances",
      "Merge cross-instance improvements",
      "Handle offline gracefully"
    ]
  }
  ```
  """

  require Logger
  alias Singularity.Agents.Coordination.CapabilityRegistry

  @centralcloud_push_queue "centralcloud_updates"
  @centralcloud_poll_queue "centralcloud_responses"
  @instance_id System.get_env("SINGULARITY_INSTANCE_ID", "instance_default")

  @doc """
  Sync capabilities with CentralCloud.

  Fetches aggregated capability insights from other instances
  and merges them into local CapabilityRegistry.

  Non-blocking - logs failures without disrupting local operation.
  """
  def sync_with_centralcloud do
    case fetch_aggregated_capabilities() do
      {:ok, aggregated_caps} ->
        merged_count = merge_into_registry(aggregated_caps)
        log_sync_success(aggregated_caps, merged_count)

      {:error, reason} ->
        Logger.info("[CentralCloudSync] CentralCloud unavailable (graceful degradation)",
          reason: inspect(reason)
        )
    end
  end

  @doc """
  Push local agent capabilities to CentralCloud.

  Called periodically to share this instance's learned capabilities
  with the aggregation service for cross-instance learning.
  """
  def push_local_capabilities do
    try do
      capabilities = CapabilityRegistry.all_agents()
      push_to_centralcloud(capabilities)
    rescue
      e ->
        Logger.warning("[CentralCloudSync] Failed to push capabilities",
          error: inspect(e)
        )
    end
  end

  # Private

  defp fetch_aggregated_capabilities do
    # Ensure queues exist
    with :ok <- ensure_queues(),
         # Poll for messages from CentralCloud (other instances' aggregated learnings)
         {:ok, messages} <- poll_responses() do
      # Aggregate messages into capability maps
      aggregated = aggregate_messages(messages)
      {:ok, aggregated}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_queues do
    try do
      MessageQueue.create_queue(@centralcloud_push_queue)
      MessageQueue.create_queue(@centralcloud_poll_queue)
      :ok
    rescue
      _ -> {:error, :queue_creation_failed}
    end
  end

  defp poll_responses do
    try do
      # Read up to 10 aggregated capability updates from other instances
      messages = read_batch_messages(@centralcloud_poll_queue, 10)

      {:ok, messages}
    rescue
      e ->
        Logger.debug("[CentralCloudSync] Error polling responses",
          error: inspect(e)
        )

        {:error, :poll_failed}
    end
  end

  # Helper to read batch messages and acknowledge them
  defp read_batch_messages(queue_name, limit) do
    Enum.reduce(1..limit, [], fn _, acc ->
      case MessageQueue.receive_message(queue_name) do
        {:ok, {msg_id, message}} ->
          # Acknowledge after reading
          MessageQueue.acknowledge(queue_name, msg_id)
          [{msg_id, message} | acc]

        :empty ->
          acc

        {:error, _reason} ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp aggregate_messages(messages) do
    # Convert pgmq messages to aggregated capability map
    # Format: {message_id, %{"agent" => name, "domains" => [...], "success_rate" => 0.95, ...}}
    messages
    |> Enum.map(fn {_msg_id, body} ->
      case Jason.decode(body) do
        {:ok, data} -> data
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(%{}, fn capability, acc ->
      agent_name = capability["agent"]

      if agent_name do
        # Store with metadata for weighted merging
        Map.put(acc, agent_name, %{
          "domains" => capability["domains"] || [],
          "success_rate" => capability["success_rate"] || 0.0,
          "sample_size" => capability["sample_size"] || 0,
          "updated_at" => capability["updated_at"],
          "instance_id" => capability["instance_id"],
          "complexity_level" => capability["complexity_level"]
        })
      else
        acc
      end
    end)
  end

  defp push_to_centralcloud(capabilities) do
    try do
      # Prepare message with current instance's capabilities
      message = %{
        "instance_id" => @instance_id,
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "capabilities" =>
          Enum.map(capabilities, fn cap ->
            %{
              "agent" => Atom.to_string(cap.name),
              "role" => Atom.to_string(cap.role),
              "domains" => Enum.map(cap.domains, &Atom.to_string/1),
              "success_rate" => cap.success_rate,
              "complexity_level" => Atom.to_string(cap.complexity_level),
              "availability" => cap.availability
            }
          end)
      }

      # Publish to CentralCloud via pgflow (pgmq + NOTIFY)
      case Singularity.Infrastructure.PgFlow.Queue.send_with_notify(@centralcloud_push_queue, message) do
        {:ok, :sent} ->
          Logger.info("[CentralCloudSync] Pushed capabilities to CentralCloud via pgflow",
            capability_count: length(capabilities),
            instance_id: @instance_id
          )

        {:ok, workflow_id} when is_integer(workflow_id) ->
          Logger.info("[CentralCloudSync] Pushed capabilities to CentralCloud via pgflow",
            capability_count: length(capabilities),
            instance_id: @instance_id,
            workflow_id: workflow_id
          )

        {:error, reason} ->
          Logger.error("[CentralCloudSync] Failed to push capabilities to CentralCloud",
            reason: reason,
            capability_count: length(capabilities)
          )
      end
    rescue
      e ->
        Logger.warning("[CentralCloudSync] Exception pushing capabilities",
          error: inspect(e)
        )
    end
  end

  defp merge_into_registry(aggregated_caps) when is_map(aggregated_caps) do
    # Only merge if we have data from other instances
    if map_size(aggregated_caps) == 0 do
      Logger.debug("[CentralCloudSync] No aggregated capabilities to merge")
      0
    else
      # For each aggregated capability, compute weighted score and update if beneficial
      merged_count =
        Enum.reduce(aggregated_caps, 0, fn {agent_name_str, cross_instance_data}, count ->
          # Convert agent name back to atom
          agent_name = String.to_atom(agent_name_str)

          # Get current capability from local registry
          case CapabilityRegistry.get_capability(agent_name) do
            {:ok, local_cap} ->
              # Compute confidence weight based on sample size and recency
              confidence = calculate_confidence(cross_instance_data)

              # Weighted averaging: prefer local learnings for now, blend cross-instance insights
              # Weight: 70% local, 30% cross-instance (conservative blending)
              new_success_rate =
                local_cap.success_rate * 0.7 +
                  cross_instance_data["success_rate"] * 0.3 * confidence

              # Update registry with blended rate
              case CapabilityRegistry.update_success_rate(agent_name, new_success_rate) do
                :ok ->
                  Logger.debug("[CentralCloudSync] Updated agent success rate",
                    agent: agent_name,
                    previous_rate: Float.round(local_cap.success_rate, 3),
                    new_rate: Float.round(new_success_rate, 3),
                    confidence: Float.round(confidence, 2)
                  )

                  count + 1

                {:error, reason} ->
                  Logger.warning("[CentralCloudSync] Failed to update agent",
                    agent: agent_name,
                    reason: inspect(reason)
                  )

                  count
              end

            {:error, :not_found} ->
              # Agent not registered locally - skip (don't auto-register unknown agents)
              Logger.debug("[CentralCloudSync] Cross-instance agent not found locally",
                agent: agent_name
              )

              count
          end
        end)

      merged_count
    end
  end

  defp calculate_confidence(cross_instance_data) do
    # Confidence score (0.0-1.0) based on:
    # 1. Sample size: more executions = higher confidence
    # 2. Recency: recent updates = higher confidence

    sample_size = cross_instance_data["sample_size"] || 0
    updated_at_str = cross_instance_data["updated_at"]

    # Sample size confidence: assume 50+ samples = max confidence
    sample_confidence = min(1.0, sample_size / 50)

    # Recency confidence: updates within last 24 hours = full confidence
    recency_confidence =
      if updated_at_str do
        case DateTime.from_iso8601(updated_at_str) do
          {:ok, update_time, _offset} ->
            now = DateTime.utc_now()
            seconds_old = DateTime.diff(now, update_time)
            hours_old = seconds_old / 3600

            # Linear decay: 24 hours = 1.0, 168 hours (1 week) = 0.0
            min(1.0, max(0.0, 1.0 - hours_old / 168))

          {:error, _} ->
            # Default if parsing fails
            0.5
        end
      else
        # Default if no timestamp
        0.5
      end

    # Weighted average: 60% sample size, 40% recency
    sample_confidence * 0.6 + recency_confidence * 0.4
  end

  defp log_sync_success(aggregated, merged_count) do
    Logger.info("[CentralCloudSync] Synced with CentralCloud",
      aggregated_insights: map_size(aggregated),
      merged_capabilities: merged_count,
      timestamp: DateTime.utc_now()
    )
  end
end
