defmodule Singularity.Jobs.AgentCoordinationWorker do
  @moduledoc """
  Agent Coordination Worker - Coordinate inter-agent communication

  Replaces pgmq publish/subscribe patterns for agent communication.
  Now uses Oban jobs for reliable, ordered message passing between agents.
  
  Patterns replaced:
  - Agent status updates
  - Agent result broadcasting
  - Agent communication requests
  - Agent coordination signals
  """

  use Pgflow.Worker, queue: :default, max_attempts: 3

  require Logger
  alias Singularity.Workflows.AgentCoordination

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
  def perform(%Oban.Job{args: args, id: job_id}) do
    message_id = args["message_id"] || Ecto.UUID.generate()
    start_time = System.monotonic_time(:millisecond)

    Logger.debug("Processing agent coordination message via workflow",
      source: args["source_agent"],
      target: args["target_agent"],
      type: args["message_type"]
    )

    input = %{
      "message_id" => message_id,
      "source_agent" => args["source_agent"],
      "target_agent" => args["target_agent"],
      "message_type" => args["message_type"],
      "payload" => args["payload"] || %{}
    }

    case Pgflow.Executor.execute(AgentCoordination, input, timeout: 30000) do
      {:ok, result} ->
        duration_ms = System.monotonic_time(:millisecond) - start_time

        Logger.info("Agent coordination workflow completed",
          message_id: result["message_id"],
          source: result["source_agent"],
          target: result["target_agent"],
          duration_ms: duration_ms
        )

        # Record result for tracking
        Singularity.Schemas.Execution.JobResult.record_success(
          workflow: "Singularity.Workflows.AgentCoordination",
          instance_id: Pgflow.Instance.Registry.instance_id(),
          job_id: job_id,
          input: input,
          output: result,
          duration_ms: duration_ms
        )

        :ok

      {:error, reason} ->
        duration_ms = System.monotonic_time(:millisecond) - start_time

        Logger.error("Agent coordination workflow failed",
          message_id: message_id,
          reason: inspect(reason),
          duration_ms: duration_ms
        )

        # Record failure for tracking
        Singularity.Schemas.Execution.JobResult.record_failure(
          workflow: "Singularity.Workflows.AgentCoordination",
          instance_id: Pgflow.Instance.Registry.instance_id(),
          job_id: job_id,
          input: input,
          error: inspect(reason),
          duration_ms: duration_ms
        )

        # Oban will retry automatically (max_attempts: 3)
        {:error, reason}
    end
  end
end
