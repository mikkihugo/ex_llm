defmodule Singularity.Learning.Supervisor do
  @moduledoc """
  Learning Supervisor - Manages the learning system including Genesis integration.

  ## Managed Processes

  - ExperimentResultConsumer (GenServer) - Subscribes to Genesis results via NATS
  - Other learning-related services

  ## Restart Strategy

  Uses `:one_for_one` because each service is independent.
  If the result consumer crashes, it restarts independently.

  ## Dependencies

  Depends on:
  - Repo - Database access for storing results
  - NATS.Client - For subscribing to Genesis results
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Learning Supervisor...")

    children = [
      # Genesis integration: consume experiment results via NATS
      Singularity.Learning.ExperimentResultConsumer
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
