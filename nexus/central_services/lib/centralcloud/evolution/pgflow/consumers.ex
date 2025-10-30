defmodule CentralCloud.Evolution.QuantumFlow.Consumers do
  @moduledoc """
  QuantumFlow Consumers - Handle messages from Singularity instance queues.

  Processes incoming messages from Singularity instances via quantum_flow.
  Each message is processed atomically with automatic retry on failure.

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "CentralCloud.Evolution.QuantumFlow.Consumers",
    "purpose": "Process messages from Singularity instances",
    "role": "service",
    "layer": "integration",
    "features": ["proposal_reception", "metrics_aggregation", "pattern_collection"]
  }
  ```

  ### Call Graph (YAML)
  ```yaml
  Consumers:
    calls_from:
      - QuantumFlow.Messaging (proposal, metrics, pattern messages)
    calls_to:
      - Consensus.Engine.propose_change
      - Guardian.RollbackService.report_metrics
      - Patterns.PatternAggregator.record_pattern
      - Telemetry
  ```

  ### Anti-Patterns
  - ❌ DO NOT assume message format is valid
  - ❌ DO NOT skip validation
  - ✅ DO validate every message before processing
  - ✅ DO return error to trigger retry on failure

  ### Search Keywords
  QuantumFlow consumers, proposal reception, metrics aggregation, pattern collection,
  message validation, multi-instance coordination

  ## Message Types Handled

  1. `proposal_for_consensus` - Proposal from instance for voting
  2. `execution_metrics` - Metrics before/after execution
  3. `pattern_discovered` - Pattern found by instance
  """

  require Logger

  alias CentralCloud.Consensus.Engine
  alias CentralCloud.Guardian.RollbackService
  alias CentralCloud.Patterns.PatternAggregator

  @doc """
  Handle proposal for consensus voting.

  Receives proposal from instance and records it for multi-instance consensus.

  Message format:
  ```
  %{
    "type" => "proposal_for_consensus",
    "proposal_id" => "...",
    "instance_id" => "...",
    "agent_type" => "...",
    "code_change" => {...},
    "impact_score" => 8.0,
    "risk_score" => 1.0,
    "safety_profile" => {...},
    "timestamp" => "..."
  }
  ```

  Returns `{:ok, "proposal_recorded"}` or `{:error, reason}` to trigger retry.
  """
  def handle_proposal_for_consensus(
    %{"proposal_id" => proposal_id, "instance_id" => instance_id} = message
  ) do
    Logger.info("Processing proposal #{proposal_id} from #{instance_id}")

    case validate_proposal_message(message) do
      :ok ->
        record_proposal_for_voting(message)

      {:error, reason} ->
        Logger.error("Proposal validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_proposal_for_consensus(message) do
    Logger.error("Invalid proposal_for_consensus message: #{inspect(message)}")
    {:error, :invalid_message}
  end

  @doc """
  Handle execution metrics from instance.

  Receives before/after metrics for Guardian monitoring and anomaly detection.

  Message format:
  ```
  %{
    "type" => "execution_metrics",
    "proposal_id" => "...",
    "instance_id" => "...",
    "agent_type" => "...",
    "metrics_before" => {...},
    "metrics_after" => {...},
    "status" => "executing",
    "timestamp" => "..."
  }
  ```

  Returns `{:ok, "metrics_recorded"}` or `{:error, reason}`.
  """
  def handle_execution_metrics(%{"proposal_id" => proposal_id} = message) do
    Logger.debug("Processing execution metrics for proposal #{proposal_id}")

    case validate_metrics_message(message) do
      :ok ->
        record_execution_metrics(message)

      {:error, reason} ->
        Logger.error("Metrics validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_execution_metrics(message) do
    Logger.error("Invalid execution_metrics message: #{inspect(message)}")
    {:error, :invalid_message}
  end

  @doc """
  Handle pattern discovery from instance.

  Receives pattern discovered during analysis for cross-instance aggregation.

  Message format:
  ```
  %{
    "type" => "pattern_discovered",
    "instance_id" => "...",
    "pattern_type" => "refactoring",
    "code_pattern" => {...},
    "success_rate" => 0.97,
    "agent_type" => "...",
    "timestamp" => "..."
  }
  ```

  Returns `{:ok, "pattern_recorded"}` or `{:error, reason}`.
  """
  def handle_pattern_discovered(%{"pattern_type" => pattern_type} = message) do
    Logger.debug("Processing #{pattern_type} pattern from #{message["instance_id"]}")

    case validate_pattern_message(message) do
      :ok ->
        record_pattern(message)

      {:error, reason} ->
        Logger.error("Pattern validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_pattern_discovered(message) do
    Logger.error("Invalid pattern_discovered message: #{inspect(message)}")
    {:error, :invalid_message}
  end

  # ============================================================================
  # Private Helpers - Message Validation
  # ============================================================================

  defp validate_proposal_message(%{
    "proposal_id" => proposal_id,
    "instance_id" => instance_id,
    "code_change" => code_change
  }) when is_binary(proposal_id) and is_binary(instance_id) and is_map(code_change) do
    :ok
  end

  defp validate_proposal_message(_), do: {:error, :invalid_format}

  defp validate_metrics_message(%{
    "proposal_id" => proposal_id,
    "instance_id" => instance_id,
    "metrics_before" => before,
    "metrics_after" => after_metrics
  })
       when is_binary(proposal_id) and is_binary(instance_id) and is_map(before) and
              is_map(after_metrics) do
    :ok
  end

  defp validate_metrics_message(_), do: {:error, :invalid_format}

  defp validate_pattern_message(%{
    "instance_id" => instance_id,
    "pattern_type" => pattern_type,
    "code_pattern" => pattern,
    "success_rate" => success_rate
  })
       when is_binary(instance_id) and is_binary(pattern_type) and is_map(pattern) and
              is_number(success_rate) and success_rate >= 0.0 and success_rate <= 1.0 do
    :ok
  end

  defp validate_pattern_message(_), do: {:error, :invalid_format}

  # ============================================================================
  # Private Helpers - Message Processing
  # ============================================================================

  defp record_proposal_for_voting(message) do
    try do
      {:ok, _result} = Engine.propose_change(
        message["instance_id"],
        message["proposal_id"],
        message["code_change"],
        %{
          agent_type: message["agent_type"],
          impact_score: message["impact_score"],
          risk_score: message["risk_score"],
          safety_profile: message["safety_profile"]
        }
      )

      Logger.info("Proposal #{message["proposal_id"]} recorded for consensus")

      :telemetry.execute(
        [:evolution, :quantum_flow, :proposal_received],
        %{},
        %{
          proposal_id: message["proposal_id"],
          instance_id: message["instance_id"],
          agent_type: message["agent_type"]
        }
      )

      {:ok, "proposal_recorded"}
    rescue
      e ->
        Logger.error("Exception recording proposal: #{inspect(e)}")
        {:error, {:exception, e}}
    end
  end

  defp record_execution_metrics(message) do
    try do
      {:ok, _result} = RollbackService.report_metrics(
        message["instance_id"],
        message["proposal_id"],
        message["metrics_before"],
        message["metrics_after"],
        message["status"]
      )

      Logger.debug("Metrics recorded for proposal #{message["proposal_id"]}")

      :telemetry.execute(
        [:evolution, :quantum_flow, :metrics_received],
        %{},
        %{
          proposal_id: message["proposal_id"],
          instance_id: message["instance_id"],
          status: message["status"]
        }
      )

      {:ok, "metrics_recorded"}
    rescue
      e ->
        Logger.error("Exception recording metrics: #{inspect(e)}")
        {:error, {:exception, e}}
    end
  end

  defp record_pattern(message) do
    try do
      {:ok, _result} = PatternAggregator.record_pattern(
        message["instance_id"],
        String.to_atom(message["pattern_type"]),
        message["code_pattern"],
        success_rate: message["success_rate"],
        agent_type: message["agent_type"]
      )

      Logger.info(
        "Pattern recorded: #{message["pattern_type"]} from #{message["instance_id"]}"
      )

      :telemetry.execute(
        [:evolution, :quantum_flow, :pattern_received],
        %{success_rate: message["success_rate"]},
        %{
          instance_id: message["instance_id"],
          pattern_type: message["pattern_type"],
          agent_type: message["agent_type"]
        }
      )

      {:ok, "pattern_recorded"}
    rescue
      e ->
        Logger.error("Exception recording pattern: #{inspect(e)}")
        {:error, {:exception, e}}
    end
  end
end
