defmodule Singularity.Jobs.TemplateFailureReporter do
  @moduledoc """
  Template Failure Reporter - Report template performance failures to CentralCloud

  Replaces NATS request("centralcloud.template.intelligence", ...)
  Now enqueued as an Oban job that reports failures back via pgmq.
  
  Triggered when:
  - Template performance degrades
  - Failure patterns detected
  - Agent detects regressions
  """

  use Oban.Worker,
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
    |> Oban.insert()
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

    # TODO: Enqueue to pgmq:centralcloud_failures when consumer ready
    Logger.info("Template failure reported",
      template_id: template_id,
      failure_type: failure_type,
      count: count
    )

    :ok
  end
end
