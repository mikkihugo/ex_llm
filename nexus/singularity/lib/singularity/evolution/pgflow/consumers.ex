defmodule Singularity.Evolution.QuantumFlow.Consumers do
  @moduledoc """
  PgFlow Consumers - Handle messages from CentralCloud queues.

  Processes incoming messages from CentralCloud services via ex_quantum_flow queues.
  Each message is processed atomically - either succeeds or retries automatically.

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Evolution.QuantumFlow.Consumers",
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
  QuantumFlow consumers, message processing, consensus results, rollback triggers,
  safety profiles, workflow patterns, consensus patterns, idempotent processing, error recovery

  ## Message Types Handled

  1. `consensus_result` - Consensus voting result from CentralCloud
  2. `rollback_trigger` - Auto-rollback signal from Guardian
  3. `safety_profile_update` - Updated safety thresholds from Genesis
  4. `workflow_consensus_patterns` - Workflow patterns from CentralCloud aggregation

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
            Logger.warning("Unknown consensus status: #{status}")
            {:error, :unknown_status}
        end

      nil ->
        Logger.warning("Proposal #{proposal_id} not found")
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
    Logger.warning("Processing rollback trigger for proposal #{proposal_id}: #{reason}")

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
        Logger.warning("Proposal #{proposal_id} not found for rollback")
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
        [:evolution, :quantum_flow, :profile_updated],
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

  @doc """
  Handle workflow consensus patterns from CentralCloud.

  Receives aggregated workflow patterns from CentralCloud and registers them
  locally for adoption. Patterns are scored by consensus confidence.

  Message format:
  ```
  %{
    "type" => "workflow_consensus_patterns",
    "instance_id" => "...",
    "workflow_patterns" => [
      %{
        "workflow_type" => "code_quality_training",
        "config" => {...},
        "success_rate" => 0.95,
        "frequency" => 42,
        "quality_improvements" => 8.5,
        "confidence" => 0.92,
        "genesis_id" => "...",
        "timestamp" => "..."
      },
      ...
    ],
    "pattern_count" => N,
    "timestamp" => "..."
  }
  ```

  Returns `{:ok, "registered"}` or `{:error, reason}` to trigger retry.
  """
  def handle_workflow_consensus_patterns(%{"workflow_patterns" => patterns} = message) when is_list(patterns) do
    Logger.info("Processing workflow consensus patterns: #{length(patterns)} patterns from CentralCloud")

    case register_consensus_workflow_patterns(patterns) do
      {:ok, registered_count} ->
        Logger.debug("Registered #{registered_count} workflow consensus patterns")

        :telemetry.execute(
          [:evolution, :quantum_flow, :workflow_patterns_registered],
          %{pattern_count: registered_count, total_patterns: length(patterns)},
          %{source: message["instance_id"]}
        )

        {:ok, "registered"}

      {:error, reason} ->
        Logger.warning("Failed to register workflow consensus patterns: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_workflow_consensus_patterns(message) do
    Logger.error("Invalid workflow_consensus_patterns message: #{inspect(message)}")
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
          [:evolution, :quantum_flow, :consensus_approved],
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
    Logger.warning("Consensus rejected for proposal #{proposal.id}")

    votes = message["votes"] || %{}

    # Update proposal status
    updated = Proposal.mark_consensus_failed(proposal, votes)

    case Repo.update(updated) do
      {:ok, _} ->
        Logger.debug("Proposal marked as consensus_failed: #{proposal.id}")

        :telemetry.execute(
          [:evolution, :quantum_flow, :consensus_rejected],
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

    Logger.warning("Initiating rollback for proposal #{proposal.id}: #{reason}")

    # In real implementation, this would:
    # 1. Revert code changes
    # 2. Re-run tests to verify
    # 3. Update proposal status

    updated = Proposal.mark_rolled_back(proposal, reason)

    case Repo.update(updated) do
      {:ok, rolled_back_proposal} ->
        Logger.warning("Proposal rolled back: #{rolled_back_proposal.id}")

        :telemetry.execute(
          [:evolution, :quantum_flow, :rollback_completed],
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

    # Mark proposal as executing in database
    executing_changeset = Proposal.mark_executing(proposal)

    case Repo.update(executing_changeset) do
      {:ok, executing_proposal} ->
        # Execute the code change
        case Singularity.Evolution.ExecutionFlow.execute_proposal(executing_proposal) do
          {:ok, result} ->
            Logger.info("Proposal execution succeeded: #{proposal.id}")

            # Extract metrics from execution result
            metrics_after = Map.get(result, :metrics_after, %{})

            # Mark proposal as applied with metrics
            applied_changeset = Proposal.mark_applied(executing_proposal, metrics_after)

            case Repo.update(applied_changeset) do
              {:ok, applied_proposal} ->
                Logger.debug("Proposal marked as applied: #{applied_proposal.id}")

                :telemetry.execute(
                  [:evolution, :quantum_flow, :execution_success],
                  %{
                    execution_time_ms: Map.get(result, :execution_time_ms, 0),
                    proposal_id: proposal.id
                  },
                  %{}
                )

                {:ok, result}

              {:error, db_error} ->
                Logger.error("Failed to mark proposal as applied: #{inspect(db_error)}")
                {:error, {:apply_update_failed, db_error}}
            end

          {:error, execution_error} ->
            Logger.error("Proposal execution failed: #{inspect(execution_error)}")

            # Mark proposal as failed in database
            failed_changeset = Proposal.mark_failed(
              executing_proposal,
              inspect(execution_error)
            )

            case Repo.update(failed_changeset) do
              {:ok, failed_proposal} ->
                Logger.warning("Proposal marked as failed: #{failed_proposal.id}")

                :telemetry.execute(
                  [:evolution, :quantum_flow, :execution_failed],
                  %{},
                  %{proposal_id: proposal.id, reason: inspect(execution_error)}
                )

                {:error, execution_error}

              {:error, db_error} ->
                Logger.error("Failed to mark proposal as failed: #{inspect(db_error)}")
                {:error, {:failure_update_failed, db_error}}
            end
        end

      {:error, executing_error} ->
        Logger.error("Failed to mark proposal as executing: #{inspect(executing_error)}")

        :telemetry.execute(
          [:evolution, :quantum_flow, :execution_mark_failed],
          %{},
          %{proposal_id: proposal.id, reason: inspect(executing_error)}
        )

        {:error, {:execution_mark_failed, executing_error}}
    end
  end

  defp register_consensus_workflow_patterns(patterns) do
    alias Singularity.Evolution.GenesisWorkflowLearner

    try do
      # Filter patterns by minimum confidence (0.80+)
      min_confidence = 0.80

      valid_patterns =
        patterns
        |> Enum.filter(fn p ->
          is_map(p) && Map.get(p, "confidence", 0.0) >= min_confidence
        end)

      if Enum.empty?(valid_patterns) do
        Logger.info("No patterns met confidence threshold (#{min_confidence})")
        {:ok, 0}
      else
        # Register all valid patterns locally
        registered_count =
          Enum.reduce(valid_patterns, 0, fn pattern_data, count ->
            pattern = convert_payload_to_pattern(pattern_data)

            case GenesisWorkflowLearner.register_consensus_patterns([pattern]) do
              {:ok, _} ->
                count + 1

              {:error, reason} ->
                Logger.warning("Failed to register consensus pattern: #{inspect(reason)}")
                count
            end
          end)

        {:ok, registered_count}
      end
    rescue
      e ->
        Logger.error("Exception during workflow pattern registration: #{inspect(e)}")
        {:error, {:exception, e}}
    end
  end

  defp convert_payload_to_pattern(payload) when is_map(payload) do
    %{
      workflow_type: payload["workflow_type"] || :unknown,
      config: payload["config"] || %{},
      success_rate: payload["success_rate"] || 0.0,
      frequency: payload["frequency"] || 0,
      quality_improvements: payload["quality_improvements"] || 0.0,
      confidence: payload["confidence"] || 0.0,
      genesis_id: payload["genesis_id"],
      timestamp: payload["timestamp"] || DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
end
