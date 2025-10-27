defmodule Genesis.ExperimentRunner do
  @moduledoc """
  DEPRECATED: Genesis Experiment Runner

  This module is deprecated as of October 2025.

  Genesis previously received improvement experiment requests from Singularity instances via NATS.
  This capability is no longer supported as NATS has been removed.

  ## New Architecture

  Genesis now operates as a code execution service via PostgreSQL pgmq:
  - See Genesis.SharedQueueConsumer for current job execution model
  - Reads job_requests from CentralCloud's shared_queue (pgmq)
  - Publishes job_results back to shared_queue
  - No NATS or experiment runner dependencies

  ## Future Enhancement

  Improvement experiments could be re-implemented via:
  1. Dedicated pgmq queues for experiment requests/responses
  2. HTTP API from CentralCloud
  3. Oban background jobs for experiment execution

  This module is retained for backwards compatibility only and is not used.
  It will be removed in a future release.
  """

  require Logger

  def start_link(_opts) do
    Logger.warning(
      "Genesis.ExperimentRunner.start_link called but experiment runner is deprecated. " <>
      "Use Genesis.SharedQueueConsumer for job execution instead."
    )
    :ignore
  end
end
