defmodule Singularity.Jobs.TemplateFailureReporter do
  @moduledoc """
  Template Failure Reporter - Report template performance failures to CentralCloud

  Replaces pgmq request("centralcloud.template.intelligence", ...)
  Now enqueued as an Oban job that reports failures back via Singularity.Jobs.PgmqClient.

  Triggered when:
  - Template performance degrades
  - Failure patterns detected
  - Agent detects regressions
  """

  use Singularity.JobQueue.Worker,
    queue: :maintenance,
    max_attempts: 3,
    priority: 8

  require Logger

  @doc """
  Report template failure pattern to CentralCloud.

  Args:
    - template_id: Template identifier
    - failure_type: Classification of failure
    - count: Number of failures observed
    - metadata: Additional context
  """
  def report_failure(template_id, failure_type, count \\ 1, metadata \\ %{}) do
    %{
      "template_id" => template_id,
      "failure_type" => failure_type,
      "failure_count" => count,
      "metadata" => metadata,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
    |> new()
    |> Singularity.JobQueue.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "template_id" => template_id,
          "failure_type" => failure_type,
          "failure_count" => count
        }
      }) do
    Logger.debug("Reporting template failure to CentralCloud",
      template_id: template_id,
      failure_type: failure_type,
      count: count
    )

    # Send failure report via QuantumFlow (pgmq + NOTIFY)
    message = %{
      "template_id" => template_id,
      "failure_type" => failure_type,
      "failure_count" => count,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Singularity.Infrastructure.PgFlow.Queue.send_with_notify("centralcloud_failures", message) do
      {:ok, :sent} ->
        Logger.info("Template failure reported to CentralCloud via QuantumFlow",
          template_id: template_id,
          failure_type: failure_type,
          count: count
        )

        :ok

      {:ok, message_id} when is_integer(message_id) ->
        Logger.info("Template failure reported to CentralCloud via QuantumFlow",
          template_id: template_id,
          failure_type: failure_type,
          count: count,
          message_id: message_id
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed to report template failure to CentralCloud",
          template_id: template_id,
          failure_type: failure_type,
          error: inspect(reason)
        )

        {:error, reason}
    end
  end
end
