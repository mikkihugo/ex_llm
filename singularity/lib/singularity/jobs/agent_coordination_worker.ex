defmodule Singularity.Jobs.AgentCoordinationWorker do
  @moduledoc """
  Agent Coordination Worker - Coordinate inter-agent communication

  Replaces NATS publish/subscribe patterns for agent communication.
  Now uses Oban jobs for reliable, ordered message passing between agents.
  
  Patterns replaced:
  - Agent status updates
  - Agent result broadcasting
  - Agent communication requests
  - Agent coordination signals
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    priority: 5

  require Logger

  @doc """
  Enqueue agent coordination message.
  
  Args:
    - source_agent: Sending agent ID
    - target_agent: Receiving agent ID (nil for broadcast)
    - message_type: Type of message (status, result, request, signal)
    - payload: Message data
  """
  def enqueue_message(source_agent, target_agent, message_type, payload \\ %{}) do
    %{
      "source_agent" => source_agent,
      "target_agent" => target_agent,
      "message_type" => message_type,
      "payload" => payload,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "source_agent" => source_agent,
          "message_type" => message_type,
          "payload" => payload
        } = args
      }) do
    target_agent = Map.get(args, "target_agent")

    Logger.debug("Processing agent coordination message",
      source: source_agent,
      target: target_agent,
      type: message_type
    )

    case message_type do
      "status" ->
        handle_status_update(source_agent, payload)

      "result" ->
        handle_result_broadcast(source_agent, target_agent, payload)

      "request" ->
        handle_coordination_request(source_agent, target_agent, payload)

      _ ->
        Logger.warning("Unknown agent message type", type: message_type)
        :ok
    end
  end

  defp handle_status_update(agent_id, payload) do
    Logger.info("Agent status update",
      agent_id: agent_id,
      status: Map.get(payload, "status"),
      progress: Map.get(payload, "progress")
    )
    :ok
  end

  defp handle_result_broadcast(source_agent, target_agent, payload) do
    Logger.info("Agent result broadcast",
      source: source_agent,
      target: target_agent,
      result: Map.get(payload, "result")
    )
    :ok
  end

  defp handle_coordination_request(source_agent, target_agent, payload) do
    Logger.info("Agent coordination request",
      source: source_agent,
      target: target_agent,
      request: Map.get(payload, "request_type")
    )
    :ok
  end
end
