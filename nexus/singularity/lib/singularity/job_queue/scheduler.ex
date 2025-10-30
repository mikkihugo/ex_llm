defmodule Singularity.JobQueue.Scheduler do
  @moduledoc """
  Scheduling utilities for jobs using QuantumFlow.
  """
  
  @type worker :: module()
  @type args :: map()
  @type opts :: keyword()
  
  @doc """
  Schedule a job to run at a given DateTime.
  """
  @spec schedule_at(worker(), args(), DateTime.t(), opts()) :: {:ok, map()} | {:error, term()}
  def schedule_at(worker_mod, args, %DateTime{} = at, opts \\ []) when is_map(args) do
    job_opts = Keyword.put(opts, :scheduled_at, at)
    Singularity.JobQueue.enqueue(worker_mod, args, job_opts)
  end
  
  @doc """
  Schedule a job to run after the given number of seconds.
  """
  @spec schedule_in(worker(), args(), non_neg_integer(), opts()) :: {:ok, map()} | {:error, term()}
  def schedule_in(worker_mod, args, seconds, opts \\ []) when is_integer(seconds) and seconds >= 0 do
   						at = DateTime.add(DateTime.utc_now(), seconds, :second)
    schedule_at(worker_mod, args, at, opts)
  end
end
