defmodule Singularity.Metrics.Supervisor do
  @moduledoc """
  Metrics Supervisor - Manages unified metrics system infrastructure.

  OTP supervisor for metrics-related processes:
  - QueryCache (GenServer) - ETS-backed caching with TTL
  - AggregationJob (Oban Worker) - Periodic aggregation of events

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Metrics.Supervisor",
    "purpose": "OTP supervisor for metrics infrastructure (cache, aggregation job)",
    "layer": "metrics",
    "status": "production"
  }
  ```

  ## Managed Processes

  1. **Metrics.QueryCache** (GenServer)
     - ETS-backed cache for query results
     - Automatic TTL cleanup (5 second default)
     - Eliminates repeated database queries

  2. **Metrics.AggregationJob** (Oban Worker)
     - Hourly background job
     - Aggregates metrics_events → metrics_aggregated
     - Idempotent (safe to re-run)

  ## Restart Strategy

  Uses `:one_for_one` because each child is independent:
  - QueryCache failure doesn't require job restart (cache is optional, degrades gracefully)
  - AggregationJob failure doesn't affect query cache
  - Each restarts independently on failure

  ## Dependencies

  Depends on:
  - Repo - Database for Event and AggregatedData queries
  - EventCollector - Produces raw events for aggregation
  - Oban - Background job queue
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Metrics Supervisor...")

    children = [
      # Query result cache (ETS with TTL)
      {Singularity.Metrics.QueryCache, []},

      # Hourly metrics aggregation job
      Singularity.Metrics.AggregationJob
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
