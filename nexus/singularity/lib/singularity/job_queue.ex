defmodule Singularity.JobQueue do
  @moduledoc """
  App-facing Job Queue API using QuantumFlow (pgmq + notifications).
  
  Replaces Oban completely while maintaining the same API surface.
  """
  
  @type job_spec :: map()
  
  @doc """
  Enqueue a job using the given worker module and args.
  """
  @spec enqueue(module(), map(), keyword()) :: {:ok, job_spec()} | {:error, term()}
  def enqueue(worker_mod, args, opts \\ []) when is_map(args) do
    job_spec = apply(worker_mod, :new, [args, opts])
    insert(job_spec)
  end
  
  @doc """
  Enqueue multiple jobs at once.
  """
  @spec enqueue_all([{module(), map(), keyword()}]) :: {:ok, [job_spec()]} | {:error, term()}
  def enqueue_all(entries) when is_list(entries) do
    job_specs = Enum.map(entries, fn {mod, args, opts} -> apply(mod, :new, [args, opts]) end)
    
    Enum.reduce(job_specs, {:ok, []}, fn spec, acc ->
      case insert(spec) do
        {:ok, job} -> {:ok, [job | elem(acc, 1)]}
        {:error, _} = error -> error
      end
    end)
  end
  
  @doc """
  Insert a job spec into the queue.
  """
  @spec insert(map()) :: {:ok, job_spec()} | {:error, term()}
  def insert(%{worker: worker_mod, args: args, queue: queue} = job_spec) do
    # Store job in pgmq queue (QuantumFlow handles persistence)
    message = %{
      "worker" => to_string(worker_mod),
      "args" => args,
      "queue" => to_string(queue),
      "max_attempts" => Map.get(job_spec, :max_attempts, 5),
      "priority" => Map.get(job_spec, :priority, 0),
      "scheduled_at" => Map.get(job_spec, :scheduled_at, DateTime.utc_now()) |> DateTime.to_iso8601()
    }
    
    case Pgflow.Notifications.send_with_notify(queue, message, Singularity.Repo, expect_reply: false) do
      {:ok, _msg_id} -> {:ok, job_spec}
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Synchronous insert that raises on error.
  """
  @spec insert!(map()) :: job_spec()
  def insert!(job_spec) do
    case insert(job_spec) do
      {:ok, job} -> job
      {:error, reason} -> raise "Job insert failed: #{inspect(reason)}"
    end
  end
end
