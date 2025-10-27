defmodule Singularity.ML.PipelineSupervisor do
  @moduledoc """
  Supervisor for ML Training Pipelines using Broadway.

  Manages all ML training pipelines:
  - Embedding Training (Qodo + Jina)
  - Code Generation Training
  - Model Complexity Training
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("🚀 Starting ML Pipeline Supervisor...")

    children = [
      # Embedding Training Pipeline
      {Singularity.ML.Pipelines.EmbeddingTrainingPipeline, []},

      # Code Quality Pipeline
      {Singularity.ML.Pipelines.CodeQualityPipeline, []},

      # Architecture Learning Pipeline
      {Singularity.ML.Pipelines.ArchitectureLearningPipeline, []},

      # ML Services
      {Singularity.ML.Services.EmbeddingService, []},
      {Singularity.ML.Services.CodeQualityService, []},
      {Singularity.ML.Services.ArchitectureLearningService, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
