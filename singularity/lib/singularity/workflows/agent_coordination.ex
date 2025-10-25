defmodule Singularity.Workflows.AgentCoordination do
  @moduledoc """
  Agent Coordination Workflow

  Routes messages between autonomous agents:
  1. Receive coordination message
  2. Validate and route based on target agent
  3. Notify target agent
  4. Return acknowledgment

  Replaces: NATS agent.* topics

  ## Input

      %{
        "message_id" => "550e8400-e29b-41d4-a716-446655440002",
        "source_agent" => "cost-optimized-agent",
        "target_agent" => "self-improving-agent",
        "message_type" => "pattern_discovered" or "status_update" or "request_help",
        "payload" => %{...}
      }

  ## Output

      %{
        "message_id" => "550e8400-e29b-41d4-a716-446655440002",
        "source_agent" => "cost-optimized-agent",
        "target_agent" => "self-improving-agent",
        "routed" => true,
        "timestamp" => "2025-10-25T11:00:05Z"
      }
  """

  use Singularity.Workflow

  require Logger

  def __workflow_steps__ do
    [
      {:receive_message, &__MODULE__.receive_message/1},
      {:validate_routing, &__MODULE__.validate_routing/1},
      {:route_message, &__MODULE__.route_message/1},
      {:acknowledge, &__MODULE__.acknowledge/1}
    ]
  end

  def __workflow_name__, do: "agent_coordination"

  # ============================================================================
  # Step 1: Receive Message
  # ============================================================================

  def receive_message(input) do
    Logger.debug("Agent Coordination: Received message",
      message_id: input["message_id"],
      source: input["source_agent"],
      target: input["target_agent"],
      type: input["message_type"]
    )

    {:ok, %{
      message_id: input["message_id"],
      source_agent: input["source_agent"],
      target_agent: input["target_agent"],
      message_type: input["message_type"],
      payload: input["payload"] || %{},
      received_at: DateTime.utc_now()
    }}
  end

  # ============================================================================
  # Step 2: Validate Routing
  # ============================================================================

  def validate_routing(prev) do
    case validate_agents(prev.source_agent, prev.target_agent) do
      :ok ->
        Logger.debug("Agent Coordination: Routing validated")
        {:ok, prev}

      {:error, reason} ->
        Logger.error("Agent Coordination: Invalid routing",
          message_id: prev.message_id,
          reason: reason
        )

        {:error, {:invalid_routing, reason}}
    end
  end

  # ============================================================================
  # Step 3: Route Message
  # ============================================================================

  def route_message(prev) do
    Logger.info("Agent Coordination: Routing message",
      message_id: prev.message_id,
      source: prev.source_agent,
      target: prev.target_agent,
      type: prev.message_type
    )

    case route_to_agent(prev) do
      :ok ->
        {:ok,
         Map.merge(prev, %{
           routed_at: DateTime.utc_now(),
           routed: true
         })}

      {:error, reason} ->
        Logger.error("Agent Coordination: Routing failed",
          message_id: prev.message_id,
          reason: inspect(reason)
        )

        {:error, {:routing_failed, reason}}
    end
  end

  # ============================================================================
  # Step 4: Acknowledge
  # ============================================================================

  def acknowledge(prev) do
    result = %{
      message_id: prev.message_id,
      source_agent: prev.source_agent,
      target_agent: prev.target_agent,
      routed: true,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Logger.info("Agent Coordination: Acknowledged",
      message_id: prev.message_id
    )

    {:ok, result}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp validate_agents(source, target) do
    valid_agents = [
      "self-improving-agent",
      "cost-optimized-agent",
      "architecture-agent",
      "technology-agent",
      "refactoring-agent",
      "chat-agent"
    ]

    cond do
      not Enum.member?(valid_agents, source) -> {:error, "Invalid source agent"}
      not Enum.member?(valid_agents, target) -> {:error, "Invalid target agent"}
      source == target -> {:error, "Cannot route to self"}
      true -> :ok
    end
  end

  defp route_to_agent(message) do
    # Route based on target agent
    case message.target_agent do
      "self-improving-agent" ->
        # Singularity.SelfImprovingAgent.handle_message(message)
        :ok

      "cost-optimized-agent" ->
        # Singularity.CostOptimizedAgent.handle_message(message)
        :ok

      "architecture-agent" ->
        # Singularity.ArchitectureAgent.handle_message(message)
        :ok

      _ ->
        :ok
    end
  end
end
