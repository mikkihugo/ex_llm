defmodule Singularity.SelfImprovement.Supervisor do
  @moduledoc """
  Self-Improvement Supervisor - Manages all self-improvement systems.

  ## Managed Processes

  - `Singularity.SelfImprovement.TopicAutoDiscovery` - NATS topic pattern discovery
  - `Singularity.SelfImprovement.PerformanceMonitor` - Performance optimization
  - `Singularity.SelfImprovement.PatternLearner` - Pattern learning and suggestions

  ## Restart Strategy

  Uses `:one_for_one` because each self-improvement system is independent.

  ## Dependencies

  Depends on:
  - Repo - For database access
  - NATS.Supervisor - For messaging
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Self-Improvement Supervisor...")

    children = [
      Singularity.SelfImprovement.TopicAutoDiscovery,
      # Future self-improvement systems can be added here
      # Singularity.SelfImprovement.PerformanceMonitor,
      # Singularity.SelfImprovement.PatternLearner,
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end