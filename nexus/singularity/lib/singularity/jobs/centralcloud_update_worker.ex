defmodule Singularity.Jobs.CentralCloudUpdateWorker do
  @moduledoc """
  CentralCloud Update Worker - Send knowledge updates back to CentralCloud

  Replaces pgmq publish("central.knowledge.update", ...)
  Now enqueued as an Oban job that will eventually write to pgmq queue.

  Architecture:
  - DOWN: CentralCloud data synced to local tables via PostgreSQL replication
  - UP: Knowledge updates enqueued here, then pushed to pgmq:centralcloud_updates
  - Consumer: CentralCloud reads pgmq queue and processes updates

  Triggered by:
  - Singularity.Integrations.CentralCloud.extract_cross_instance_insights/1
  - When new patterns or insights are discovered locally
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 5,
    priority: 5

  require Logger
  alias Singularity.PgFlow

  @doc """
  Enqueue knowledge update to send to CentralCloud via pgflow.

  Args:
    - patterns: List of discovered patterns
    - insights: List of insights
    - instance_id: This Singularity instance ID
    
  Returns: {:ok, job} or {:error, reason}
  """
  def enqueue_knowledge_update(patterns, insights, instance_id \\ nil) do
    instance_id = instance_id || get_instance_id()

    %{
      "patterns" => patterns,
      "insights" => insights,
      "instance_id" => instance_id,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "patterns" => patterns,
          "insights" => insights,
          "instance_id" => instance_id
        }
      }) do
    message = %{
      "instance_id" => instance_id,
      "patterns" => patterns,
      "insights" => insights,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "event_type" => "knowledge_update"
    }

    Logger.debug("Sending knowledge update to CentralCloud via pgmq",
      instance_id: instance_id,
      patterns: length(patterns),
      insights: length(insights)
    )

    case PgFlow.send_with_notify("centralcloud_updates", message) do
      {:ok, :sent} ->
        Logger.info("Knowledge update sent to CentralCloud via pgflow",
          instance_id: instance_id,
          patterns: length(patterns),
          insights: length(insights)
        )

        :ok

      {:ok, message_id} when is_integer(message_id) ->
        Logger.info("Knowledge update sent to CentralCloud via pgflow",
          instance_id: instance_id,
          message_id: message_id,
          patterns: length(patterns),
          insights: length(insights)
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed to send knowledge update to CentralCloud",
          instance_id: instance_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  defp get_instance_id do
    System.get_env("SINGULARITY_INSTANCE_ID") ||
      "#{:inet.gethostname() |> elem(1) |> List.to_string()}-#{System.monotonic_time(:second)}"
  end
end
