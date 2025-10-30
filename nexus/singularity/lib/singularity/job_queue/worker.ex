defmodule Singularity.JobQueue.Worker do
  @moduledoc """
  Worker macro for background jobs using QuantumFlow job queue.
  
  Provides the same interface as Oban.Worker but delegates to QuantumFlow.
  """
  
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      # QuantumFlow job workers implement perform/1 with a map
      @behaviour Singularity.JobQueue.WorkerBehaviour
      
      @doc false
      def new(args, job_opts \\ []) when is_map(args) do
        queue = Keyword.get(opts, :queue, :default)
        max_attempts = Keyword.get(opts, :max_attempts, 5)
        priority = Keyword.get(opts, :priority, 0)
        scheduled_at = Keyword.get(job_opts, :scheduled_at)
        
        %{
          worker: __MODULE__,
          args: args,
          queue: queue,
          max_attempts: max_attempts,
          priority: priority,
          scheduled_at: scheduled_at || DateTime.utc_now()
        }
      end
    end
  end
end

defmodule Singularity.JobQueue.WorkerBehaviour do
  @moduledoc false
  @callback perform(job :: map()) :: :ok | {:error, term()}
end
