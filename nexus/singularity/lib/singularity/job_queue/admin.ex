defmodule Singularity.JobQueue.Admin do
  @moduledoc """
  Administrative helpers for the job queue. Thin delegates to Oban so the
  rest of the app doesn't depend on Oban directly.
  """

  @spec cancel(job_id :: integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def cancel(job_id), do: Oban.cancel_job(job_id)

  @spec retry(job_id :: integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def retry(job_id), do: Oban.retry_job(job_id)
end
