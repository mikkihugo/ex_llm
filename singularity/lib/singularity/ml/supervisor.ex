defmodule Singularity.ML.Supervisor do
  @moduledoc """
  Singularity ML Supervisor - Manages all ML pipelines and training processes.

  ## Managed Processes

  - `Singularity.ML.Pipelines.EmbeddingTrainingPipeline` - Broadway pipeline for Qodo/Jina embedding training
  - `Singularity.ML.Pipelines.CodeQualityPipeline` - Broadway pipeline for code quality ML training
  - `Singularity.ML.Pipelines.ArchitectureLearningPipeline` - Broadway pipeline for architecture pattern learning

  ## Restart Strategy

  Uses `:one_for_one` because each pipeline is independent and can restart without affecting others.

  ## Dependencies

  Depends on:
  - Singularity.Repo - For database access
  - PGMQ - For message queue processing
  - Broadway - For pipeline orchestration
  - Axon - For deep learning training
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Singularity ML Supervisor...")

    children = [
      # ML Training Pipelines
      Singularity.ML.Pipelines.EmbeddingTrainingPipeline,
      Singularity.ML.Pipelines.CodeQualityPipeline,
      Singularity.ML.Pipelines.ArchitectureLearningPipeline,

      # ML Services
      Singularity.ML.Services.EmbeddingService,
      Singularity.ML.Services.CodeQualityService,
      Singularity.ML.Services.ArchitectureLearningService
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
