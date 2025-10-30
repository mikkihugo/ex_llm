defmodule Singularity.Evolution.QuantumFlow.Producers do
  @moduledoc """
  PgFlow Producers - Send messages to CentralCloud queues.

  Handles asynchronous, durable messaging to CentralCloud services via ex_quantum_flow.
  All messages are persisted in PostgreSQL and automatically retried on failure.

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Evolution.QuantumFlow.Producers",
    "purpose": "Publish messages to CentralCloud via durable queues",
    "role": "service",
    "layer": "integration",
    "features": ["async_messaging", "durable_queues", "automatic_retry"]
  }
  ```

  ### Anti-Patterns
  - ❌ DO NOT make direct calls to CentralCloud services
  - ❌ DO NOT assume CentralCloud is always available
  - ✅ DO use this for all Singularity → CentralCloud messaging
  - ✅ DO handle {:error, reason} gracefully

  ### Search Keywords
  QuantumFlow producers, message publishing, asynchronous messaging, durable queues,
  centralcloud integration, proposal broadcasting, metrics reporting

  ## Usage

  ```elixir
  # Publish proposal for consensus voting
  {:ok, msg_id} = Producers.propose_for_consensus(proposal)

  # Report execution metrics to Guardian
  {:ok, msg_id} = Producers.report_metrics_to_guardian(proposal, before, after)

  # Report discovered pattern to Aggregator
  {:ok, msg_id} = Producers.report_pattern_to_aggregator(pattern_type, ...)
  ```

  ## Queue Configuration

  Each queue is configured in `config/config.exs`:
  - `proposals_for_consensus_queue` - 2 workers
  - `metrics_to_guardian_queue` - 2 workers
  - `patterns_for_aggregator_queue` - 1 worker

  Messages automatically retry with exponential backoff (max 3 retries).
  Failed messages go to dead-letter queue for manual review.
  """

  require Logger

  @doc """
  Publish proposal to consensus queue for voting.

  Sends proposal to CentralCloud.Consensus.Engine for multi-instance voting.
  Returns immediately (async) - message will retry if delivery fails.

  Returns `{:ok, message_id}` or `{:error, reason}`.
  """
  def propose_for_consensus(proposal) do
    message = build_proposal_message(proposal)

    case publish_message("proposals_for_consensus_queue", message) do
      {:ok, message_id} ->
        Logger.info(
          "Published proposal #{proposal.id} for consensus (msg_id: #{message_id})"
        )

        :telemetry.execute(
          [:evolution, :quantum_flow, :proposal_published],
          %{},
          %{proposal_id: proposal.id}
        )

        {:ok, message_id}

      {:error, reason} ->
        Logger.error("Failed to publish proposal #{proposal.id}: #{inspect(reason)}")

        :telemetry.execute(
          [:evolution, :quantum_flow, :publish_failed],
          %{},
          %{proposal_id: proposal.id, reason: inspect(reason)}
        )

        {:error, reason}
    end
  end

  @doc """
  Report execution metrics to Guardian for monitoring.

  Sends before/after metrics to CentralCloud.Guardian.RollbackService.
  Non-blocking - safe to call even if Guardian is temporarily down.

  Returns `{:ok, message_id}` or `{:error, reason}`.
  """
  def report_metrics_to_guardian(proposal, metrics_before, metrics_after) do
    message = build_metrics_message(proposal, metrics_before, metrics_after)

    case publish_message("metrics_to_guardian_queue", message) do
      {:ok, message_id} ->
        Logger.debug("Published metrics for proposal #{proposal.id} (msg_id: #{message_id})")

        :telemetry.execute(
          [:evolution, :quantum_flow, :metrics_published],
          %{},
          %{proposal_id: proposal.id}
        )

        {:ok, message_id}

      {:error, reason} ->
        # Non-critical - don't fail execution if metrics reporting fails
        Logger.warning("Failed to publish metrics for #{proposal.id}: #{inspect(reason)}")
        {:ok, :async_failed}
    end
  end

  @doc """
  Report discovered pattern to Pattern Aggregator.

  Sends pattern discovered during analysis to CentralCloud for cross-instance
  aggregation and consensus validation.

  Returns `{:ok, message_id}` or `{:error, reason}`.
  """
  def report_pattern_to_aggregator(pattern_type, code_pattern, success_rate, agent_type) do
    message = build_pattern_message(pattern_type, code_pattern, success_rate, agent_type)

    case publish_message("patterns_for_aggregator_queue", message) do
      {:ok, message_id} ->
        Logger.debug(
          "Published #{pattern_type} pattern from #{agent_type} (msg_id: #{message_id})"
        )

        :telemetry.execute(
          [:evolution, :quantum_flow, :pattern_published],
          %{},
          %{pattern_type: pattern_type, agent_type: agent_type}
        )

        {:ok, message_id}

      {:error, reason} ->
        Logger.warning("Failed to publish pattern: #{inspect(reason)}")
        {:ok, :async_failed}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp build_proposal_message(proposal) do
    %{
      "type" => "proposal_for_consensus",
      "proposal_id" => proposal.id,
      "instance_id" => instance_id(),
      "agent_type" => proposal.agent_type,
      "code_change" => proposal.code_change,
      "impact_score" => proposal.impact_score,
      "risk_score" => proposal.risk_score,
      "safety_profile" => proposal.safety_profile || %{},
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp build_metrics_message(proposal, metrics_before, metrics_after) do
    %{
      "type" => "execution_metrics",
      "proposal_id" => proposal.id,
      "instance_id" => instance_id(),
      "agent_type" => proposal.agent_type,
      "metrics_before" => metrics_before,
      "metrics_after" => metrics_after,
      "status" => proposal.status,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp build_pattern_message(pattern_type, code_pattern, success_rate, agent_type) do
    %{
      "type" => "pattern_discovered",
      "instance_id" => instance_id(),
      "pattern_type" => pattern_type,
      "code_pattern" => code_pattern,
      "success_rate" => success_rate,
      "agent_type" => agent_type,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp publish_message(queue_name, message) do
    try do
      # Publish via QuantumFlow notifications (PostgreSQL NOTIFY + persistence)
      {:ok, message_id} =
        QuantumFlow.Notifications.send_with_notify(queue_name, message, Singularity.Repo,
          expect_reply: false,
          max_retries: 3,
          retry_delay_ms: 1000
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

  defp instance_id do
    System.get_env("INSTANCE_ID", "singularity_default")
  end
end
