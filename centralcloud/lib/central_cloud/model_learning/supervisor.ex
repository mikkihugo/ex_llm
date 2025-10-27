defmodule CentralCloud.ModelLearning.Supervisor do
  @moduledoc """
  Supervision tree for model learning infrastructure.

  Manages:
  - RoutingEventConsumer - Consumes pgmq events from Singularity instances
  - ComplexityScoreLearner - Learns optimal complexity scores from outcomes
  - ModelScoreUpdater - Publishes learned scores back to instances
  """

  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Starting ModelLearning Supervisor...")

    children = [
      # Consume routing events from instances
      CentralCloud.ModelLearning.RoutingEventConsumer,

      # Learn and optimize complexity scores
      {
        CentralCloud.ModelLearning.ComplexityScoreLearner,
        [schedule_interval_ms: 60_000]  # Learn every 60 seconds
      },

      # Publish score updates back to instances
      CentralCloud.ModelLearning.ModelScoreUpdater
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
