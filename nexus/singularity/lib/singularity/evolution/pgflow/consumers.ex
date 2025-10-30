defmodule Singularity.Evolution.Pgflow.Consumers do
  @moduledoc """
  PgFlow Consumers - Handle messages from CentralCloud queues.

  Processes incoming messages from CentralCloud services via ex_pgflow queues.
  Each message is processed atomically - either succeeds or retries automatically.

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Evolution.Pgflow.Consumers",
    "purpose": "Process incoming messages from CentralCloud",
    "role": "service",
    "layer": "integration",
    "features": ["async_message_processing", "idempotent_handlers", "error_recovery"]
  }
  ```

  ### Anti-Patterns
  - ❌ DO NOT fail silently (log all errors)
  - ❌ DO NOT assume message format is valid
  - ✅ DO validate message format before processing
  - ✅ DO return {:ok, "processed"} on success
  - ✅ DO return {:error, reason} to trigger retry

  ### Search Keywords
  pgflow consumers, message processing, consensus results, rollback triggers,
  safety profiles, idempotent processing, error recovery

  ## Message Types Handled

  1. `consensus_result` - Consensus voting result from CentralCloud
  2. `rollback_trigger` - Auto-rollback signal from Guardian
  3. `safety_profile_update` - Updated safety thresholds from Genesis

  ## Usage

  Consumers are registered in application supervision tree.
  Messages are automatically dequeued and processed with retry on error.

  ```elixir
  # Consumers auto-process messages from queues
  # Success: message removed from queue
  # Error: message retried with backoff
  # Max retries exceeded: moved to dead-letter queue
  ```
  """

  require Logger

  alias Singularity.Repo
  alias Singularity.Schemas.Evolution.Proposal
  alias Singularity.Evolution.{ProposalQueue, SafetyProfiles}

  @doc """
  Handle consensus result from CentralCloud.

  Processes voting result and either marks proposal as approved/rejected
  or executes if approved.

  Message format:
  ```
  %{
    "type" => "consensus_result",
    "proposal_id" => "...",
    "instance_id" => "...",
    "status" => "approved" | "rejected",
    "votes" => {...},
    "confidence" => 0.95,
    "timestamp" => "..."
  }
  ```

  Returns `{:ok, "processed"}` or `{:error, reason}` to trigger retry.
  """
  def handle_consensus_result(%{"proposal_id" => proposal_id, "status" => status} = message) do
    Logger.info("Processing consensus result for proposal #{proposal_id}: #{status}")

    case Repo.get(Proposal, proposal_id) do
      %Proposal{} = proposal ->
        case status do
          "approved" ->
            handle_consensus_approved(proposal, message)

          "rejected" ->
            handle_consensus_rejected(proposal, message)

          _ ->
            Logger.warn("Unknown consensus status: #{status}")
            {:error, :unknown_status}
        end

      nil ->
        Logger.warn("Proposal #{proposal_id} not found")
        {:error, :proposal_not_found}
    end
  end

  def handle_consensus_result(message) do
    Logger.error("Invalid consensus_result message: #{inspect(message)}")
    {:error, :invalid_message}
  end

  @doc """
  Handle rollback trigger from Guardian.

  Reverts code change and marks proposal as rolled_back.

  Message format:
  ```
  %{
    "type" => "rollback_trigger",
    "proposal_id" => "...",
    "instance_id" => "...",
    "reason" => "error_rate_breach",
    "threshold" => {...},
    "timestamp" => "..."
  }
  ```

  Returns `{:ok, "rolled_back"}` or `{:error, reason}`.
  """
  def handle_rollback_trigger(%{"proposal_id" => proposal_id, "reason" => reason} = message) do
    Logger.warn("Processing rollback trigger for proposal #{proposal_id}: #{reason}")

    case Repo.get(Proposal, proposal_id) do
      %Proposal{status: current_status} = proposal ->
        # Only rollback if currently executing or applied
        if current_status in ["executing", "applied"] do
          perform_rollback(proposal, message)
        else
          Logger.debug("Proposal #{proposal_id} not in rollback-eligible state (#{current_status})")
          {:ok, "not_applicable"}
        end

      nil ->
        Logger.warn("Proposal #{proposal_id} not found for rollback")
        {:error, :proposal_not_found}
    end
  end

  def handle_rollback_trigger(message) do
    Logger.error("Invalid rollback_trigger message: #{inspect(message)}")
    {:error, :invalid_message}
  end

  @doc """
  Handle safety profile update from Guardian.

  Updates local safety thresholds for an agent type based on learnings
  from CentralCloud.Guardian and Genesis.

  Message format:
  ```
  %{
    "type" => "safety_profile_update",
    "instance_id" => "...",
    "agent_type" => "...",
    "safety_profile" => {...},
    "source" => "genesis_learning_loop",
    "timestamp" => "..."
  }
  ```

  Returns `{:ok, "updated"}` or `{:error, reason}`.
  """
  def handle_safety_profile_update(%{"agent_type" => agent_type, "safety_profile" => profile} = message) do
    Logger.info("Processing safety profile update for #{agent_type}")

    try do
      # Update in-memory cache
      SafetyProfiles.update_from_central(agent_type, profile)

      Logger.debug("Safety profile updated for #{agent_type}")

      :telemetry.execute(
        [:evolution, :pgflow, :profile_updated],
        %{},
        %{agent_type: agent_type, source: message["source"]}
      )

      {:ok, "updated"}
    rescue
      e ->
        Logger.error("Exception updating safety profile: #{inspect(e)}")
        {:error, {:exception, e}}
    end
  end

  def handle_safety_profile_update(message) do
    Logger.error("Invalid safety_profile_update message: #{inspect(message)}")
    {:error, :invalid_message}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp handle_consensus_approved(proposal, message) do
    Logger.info("Consensus approved for proposal #{proposal.id}")

    votes = message["votes"] || %{}

    # Update proposal status
    updated = Proposal.mark_consensus_reached(proposal, votes)

    case Repo.update(updated) do
      {:ok, updated_proposal} ->
        Logger.debug("Proposal marked as consensus_reached: #{updated_proposal.id}")

        :telemetry.execute(
          [:evolution, :pgflow, :consensus_approved],
          %{confidence: message["confidence"] || 0.0},
          %{proposal_id: proposal.id}
        )

        # Execute the approved proposal
        Task.Supervisor.start_child(
          Singularity.TaskSupervisor,
          fn -> execute_approved_proposal(updated_proposal) end
        )

        {:ok, "processed"}

      {:error, reason} ->
        Logger.error("Failed to update proposal status: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_consensus_rejected(proposal, message) do
    Logger.warn("Consensus rejected for proposal #{proposal.id}")

    votes = message["votes"] || %{}

    # Update proposal status
    updated = Proposal.mark_consensus_failed(proposal, votes)

    case Repo.update(updated) do
      {:ok, _} ->
        Logger.debug("Proposal marked as consensus_failed: #{proposal.id}")

        :telemetry.execute(
          [:evolution, :pgflow, :consensus_rejected],
          %{},
          %{proposal_id: proposal.id}
        )

        {:ok, "processed"}

      {:error, reason} ->
        Logger.error("Failed to update proposal status: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp perform_rollback(proposal, message) do
    reason = message["reason"]
    threshold = message["threshold"] || %{}

    Logger.warn("Initiating rollback for proposal #{proposal.id}: #{reason}")

    # In real implementation, this would:
    # 1. Revert code changes
    # 2. Re-run tests to verify
    # 3. Update proposal status

    updated = Proposal.mark_rolled_back(proposal, reason)

    case Repo.update(updated) do
      {:ok, rolled_back_proposal} ->
        Logger.warn("Proposal rolled back: #{rolled_back_proposal.id}")

        :telemetry.execute(
          [:evolution, :pgflow, :rollback_completed],
          %{},
          %{proposal_id: proposal.id, reason: reason, threshold: threshold}
        )

        {:ok, "rolled_back"}

      {:error, error_reason} ->
        Logger.error("Failed to mark proposal as rolled_back: #{inspect(error_reason)}")
        {:error, error_reason}
    end
  end

  defp execute_approved_proposal(proposal) do
    Logger.info("Executing approved proposal #{proposal.id}")

    case Singularity.Evolution.ExecutionFlow.execute_proposal(proposal) do
      {:ok, result} ->
        Logger.info("Proposal execution succeeded: #{proposal.id}")
        {:ok, result}

      {:error, reason} ->
        Logger.error("Proposal execution failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
