defmodule CentralCloud.ML.Supervisor do
  @moduledoc """
  CentralCloud ML Supervisor - Manages all ML pipelines and training processes.

  ## Managed Processes

  - `CentralCloud.ML.Pipelines.ComplexityTrainingPipeline` - Broadway pipeline for model complexity training
  - `CentralCloud.ML.Pipelines.ModelIngestionPipeline` - Broadway pipeline for model data ingestion
  - `CentralCloud.ML.Pipelines.PatternLearningPipeline` - Broadway pipeline for pattern learning

  ## Restart Strategy

  Uses `:one_for_one` because each pipeline is independent and can restart without affecting others.

  ## Dependencies

  Depends on:
  - CentralCloud.Repo - For database access
  - PGMQ - For message queue processing
  - Broadway - For pipeline orchestration
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting CentralCloud ML Supervisor...")

    children = [
      # ML Training Pipelines
      CentralCloud.ML.Pipelines.ComplexityTrainingPipeline,
      CentralCloud.ML.Pipelines.ModelIngestionPipeline,
      CentralCloud.ML.Pipelines.PatternLearningPipeline,

      # ML Services
      CentralCloud.ML.Services.ModelComplexityService,
      CentralCloud.ML.Services.PatternLearningService,
      CentralCloud.ML.Services.ModelSelectionService
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
