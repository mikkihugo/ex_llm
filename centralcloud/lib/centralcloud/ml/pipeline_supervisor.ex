defmodule CentralCloud.ML.PipelineSupervisor do
  @moduledoc """
  Supervisor for ML Training Pipelines in CentralCloud.
  
  Manages complexity training and model learning pipelines:
  - Model Complexity Training
  - Pattern Learning
  - Framework Intelligence
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("🚀 Starting CentralCloud ML Pipeline Supervisor...")

    children = [
      # Complexity Training Pipeline
      {CentralCloud.ML.Pipelines.ComplexityTrainingPipeline, []},
      
      # Model Ingestion Pipeline
      {CentralCloud.ML.Pipelines.ModelIngestionPipeline, []},
      
      # Pattern Learning Pipeline
      {CentralCloud.ML.Pipelines.PatternLearningPipeline, []},
      
      # ML Services
      {CentralCloud.ML.Services.ModelComplexityService, []},
      {CentralCloud.ML.Services.PatternLearningService, []},
      {CentralCloud.ML.Services.ModelSelectionService, []},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end