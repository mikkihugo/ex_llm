defmodule CentralCloud.Evolution.Pgflow.Producers do
  @moduledoc """
  PgFlow Producers - Send messages to Singularity instance queues.

  Handles asynchronous, durable messaging to Singularity instances via ex_pgflow.
  All messages are persisted in PostgreSQL and automatically retried on failure.

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "CentralCloud.Evolution.Pgflow.Producers",
    "purpose": "Publish messages to Singularity instances via durable queues",
    "role": "service",
    "layer": "integration",
    "features": ["consensus_distribution", "rollback_triggers", "profile_updates"]
  }
  ```

  ### Call Graph (YAML)
  ```yaml
  Producers:
    calls_from:
      - Consensus.Engine (send_consensus_result)
      - Guardian.RollbackService (send_rollback)
      - PatternLearningLoop (send_profiles)
    calls_to:
      - ExPgflow.publish
      - Telemetry
  ```

  ### Anti-Patterns
  - ❌ DO NOT call Singularity services directly
  - ❌ DO NOT assume instances are available
  - ✅ DO publish all results to queues
  - ✅ DO handle publish failures gracefully

  ### Search Keywords
  pgflow producers, consensus distribution, rollback triggers, safety profile updates,
  instance messaging, queue-based communication

  ## Usage

  ```elixir
  # Send consensus voting result to instance
  {:ok, msg_id} = Producers.send_consensus_result(instance_id, proposal_id, status, votes)

  # Send rollback trigger on metric anomaly
  {:ok, msg_id} = Producers.send_rollback_trigger(instance_id, proposal_id, reason)

  # Send updated safety thresholds from learning loop
  {:ok, msg_id} = Producers.send_safety_profile_update(agent_type, profile)
  ```

  ## Queue Configuration

  - `consensus_results_queue` - 2 workers
  - `rollback_triggers_queue` - 1 worker (priority)
  - `guardian_safety_profiles_queue` - 1 worker
  """

  require Logger

  @doc """
  Send consensus voting result to instance.

  Publishes the outcome of multi-instance consensus voting on a proposal.

  Returns `{:ok, message_id}` or `{:error, reason}`.
  """
  def send_consensus_result(instance_id, proposal_id, status, votes, confidence \\ 0.0) do
    message = build_consensus_result_message(instance_id, proposal_id, status, votes, confidence)

    case publish_message("consensus_results_queue", message) do
      {:ok, message_id} ->
        Logger.info(
          "Published consensus result for proposal #{proposal_id} to #{instance_id} (#{status})"
        )

        :telemetry.execute(
          [:evolution, :pgflow, :consensus_result_published],
          %{confidence: confidence},
          %{proposal_id: proposal_id, status: status, instance_id: instance_id}
        )

        {:ok, message_id}

      {:error, reason} ->
        Logger.error(
          "Failed to publish consensus result for #{proposal_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Send rollback trigger to instance.

  Alerts instance that Guardian detected anomalies and proposal needs rollback.
  This is high-priority messaging to ensure quick rollback.

  Returns `{:ok, message_id}` or `{:error, reason}`.
  """
  def send_rollback_trigger(instance_id, proposal_id, reason, threshold_details \\ %{}) do
    message = build_rollback_trigger_message(instance_id, proposal_id, reason, threshold_details)

    case publish_message("rollback_triggers_queue", message) do
      {:ok, message_id} ->
        Logger.warn(
          "Published rollback trigger for proposal #{proposal_id} to #{instance_id}: #{reason}"
        )

        :telemetry.execute(
          [:evolution, :pgflow, :rollback_trigger_published],
          %{},
          %{proposal_id: proposal_id, reason: reason, instance_id: instance_id}
        )

        {:ok, message_id}

      {:error, error_reason} ->
        Logger.error(
          "Failed to publish rollback trigger for #{proposal_id}: #{inspect(error_reason)}"
        )

        {:error, error_reason}
    end
  end

  @doc """
  Send safety profile update to instance(s).

  Publishes updated safety thresholds from Guardian/Genesis learning loop.
  Can target specific instance or broadcast to all.

  Returns `{:ok, message_id}` or `{:error, reason}`.
  """
  def send_safety_profile_update(agent_type, safety_profile, instance_id \\ :all) do
    message = build_safety_profile_message(agent_type, safety_profile, instance_id)

    case publish_message("guardian_safety_profiles_queue", message) do
      {:ok, message_id} ->
        target = if instance_id == :all, do: "all instances", else: instance_id
        Logger.info("Published safety profile update for #{agent_type} to #{target}")

        :telemetry.execute(
          [:evolution, :pgflow, :profile_update_published],
          %{},
          %{agent_type: agent_type, target: target}
        )

        {:ok, message_id}

      {:error, reason} ->
        Logger.error("Failed to publish safety profile update: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp build_consensus_result_message(instance_id, proposal_id, status, votes, confidence) do
    %{
      "type" => "consensus_result",
      "proposal_id" => proposal_id,
      "instance_id" => instance_id,
      "status" => status,
      "votes" => votes,
      "confidence" => confidence,
      "decision_rationale" => "Multi-instance consensus voting",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp build_rollback_trigger_message(instance_id, proposal_id, reason, threshold_details) do
    %{
      "type" => "rollback_trigger",
      "proposal_id" => proposal_id,
      "instance_id" => instance_id,
      "reason" => reason,
      "threshold" => threshold_details,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp build_safety_profile_message(agent_type, safety_profile, instance_id) do
    %{
      "type" => "safety_profile_update",
      "instance_id" => if(instance_id == :all, do: "broadcast", else: instance_id),
      "agent_type" => agent_type,
      "safety_profile" => safety_profile,
      "source" => "genesis_learning_loop",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp publish_message(queue_name, message) do
    try do
      {:ok, message_id} = ExPgflow.publish(
        :centralcloud,
        queue_name,
        message,
        [
          max_retries: 3,
          retry_delay_ms: 1000
        ]
      )

      {:ok, message_id}
    rescue
      e ->
        Logger.error("Exception publishing to #{queue_name}: #{inspect(e)}")
        {:error, {:exception, e}}
    catch
      kind, value ->
        Logger.error("Caught error publishing to #{queue_name}: #{kind} #{inspect(value)}")
        {:error, {:caught, {kind, value}}}
    end
  end
end
