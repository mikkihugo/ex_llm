defmodule Singularity.Knowledge.Supervisor do
  @moduledoc """
  Knowledge Supervisor - Manages knowledge base and template infrastructure.

  Supervises all knowledge-related processes including templates, performance tracking,
  and code storage.

  ## Managed Processes

  - `Singularity.Knowledge.TemplateService` - GenServer managing template loading/caching
  - `Singularity.TemplatePerformanceTracker` - GenServer tracking template usage/performance
  - `Singularity.CodeStore` - GenServer managing code chunk storage

  ## Living Knowledge Base

  This supervisor manages the "Living Knowledge Base" components:
  - Templates (JSON → PostgreSQL → ETS cache)
  - Performance metrics (usage tracking, success rates)
  - Code storage (parsed code chunks with embeddings)

  ## Dependencies

  Depends on:
  - Repo - For PostgreSQL access (knowledge_artifacts table)
  - EmbeddingModelLoader (Infrastructure.Supervisor) - For generating embeddings
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Knowledge Supervisor...")

    children = [
      Singularity.Knowledge.TemplateService,
      Singularity.TemplatePerformanceTracker,
      Singularity.CodeStore
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
