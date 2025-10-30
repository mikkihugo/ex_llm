defmodule Singularity.ProcessRegistry do
  @moduledoc """
  Central registry of notable processes inside the QuantumFlow-era Singularity runtime.

  Two responsibilities:

    * Provides the actual `Registry` used by agents (`{:via, Registry, {ProcessRegistry, ...}}`).
    * Exposes curated keyword lists so LiveDashboard/search tooling can quickly locate modules.
  """

  @doc """
  Child spec so the registry can be started in the supervision tree.
  """
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {Registry, :start_link, [[keys: :unique, name: __MODULE__]]}
    }
  end

  @process_keywords %{
    # Infrastructure
    "Singularity.Repo" => "PostgreSQL connection pool backing QuantumFlow + embeddings",
    "Singularity.Health.HttpServer" => "HTTP health + readiness endpoint",
    "Singularity.Infrastructure.Overseer" => "Runtime health monitor for QuantumFlow + DB",
    "Singularity.Infrastructure.ErrorRateTracker" => "ETS-backed error rate tracker",
    "Singularity.Infrastructure.CircuitBreakerSupervisor" =>
      "Dynamic supervisor for circuit breakers",

    # QuantumFlow orchestration
    "QuantumFlow.WorkflowSupervisor" => "QuantumFlow workflow orchestrator (demand, ack, retries)",
    "Singularity.Ingestion.Workflows.ExecuteAutoCodeIngestionWorkflow" => "Auto code ingestion workflow (QuantumFlow)",
    "Singularity.Workflows.EmbeddingTrainingWorkflow" => "Embedding training workflow (QuantumFlow)",
    "Singularity.Workflows.ArchitectureLearningWorkflow" =>
      "Architecture learning workflow (QuantumFlow)",
    "Broadway.QuantumFlowProducer" => "Broadway producer (QuantumFlow-backed)",

    # ML pipelines
    "Singularity.ML.PipelineSupervisor" => "Supervisor for ML/Broadway pipelines",
    "Singularity.Embedding.BroadwayEmbeddingPipeline" => "Embedding Broadway pipeline",

    # Knowledge & search
    "Singularity.Knowledge.TemplateService" => "Template registry and learning",
    "Singularity.Search.PackageAndCodebaseSearch" =>
      "Search orchestration across packages/codebases",

    # Agents
    "Singularity.Agents.RuntimeBootstrapper" => "Agent runtime initialisation",
    "Singularity.Agents.Arbiter" => "Agent arbitration and escalation",
    "Singularity.Agents.ChangeTracker" => "Code change tracker feeding QuantumFlow",
    "Singularity.Agents.SelfImprovementAgent" => "Self-improvement orchestration",
    "Singularity.Agents.DocumentationPipelineGitIntegration" =>
      "Documentation pipeline (git sync)",
    "Singularity.Agents.AgentSpawner" => "Dynamic agent supervisor/spawner",

    # Execution / HTDAG
    "Singularity.Ingestion.HTDAG.StartHtdagIngestionSupervisor" => "Hierarchical DAG execution supervisor",
    "Singularity.Execution.TaskGraph.TaskGraphOrchestrator" => "Task graph orchestration",
    "Singularity.Execution.SafeWorkPlanner" => "Work planning + safety rails",

    # Notifications / messaging
    "Singularity.Notifications.PgmqNotify" => "PGMQ + NOTIFY bridge for real-time updates",
    "Singularity.SharedQueueConsumer" => "Shared PostgreSQL queue consumer",

    # Hot reload
    "Singularity.Ingestion.HotReload.TriggerHotReloadOnFileChange" => "Hot reload event processor",
    "Singularity.HotReload.SafeCodeChangeDispatcher" => "Safe code change dispatcher",

    # Monitoring / metrics
    "Singularity.Monitoring.CodeEngineHealthTracker" => "Code engine health tracker",
    "Singularity.Monitoring.AgentTaskTracker" => "Telemetry bridge for agent tasks",
    "Singularity.Metrics.Aggregator" => "Metrics aggregation",

    # LLM / tooling
    "Singularity.LLM.BeamLLMService" => "LLM request orchestration",
    "Singularity.Tools.InstructorAdapter" => "Instructor tool adapter"
  }

  @process_categories %{
    infrastructure: [
      "Singularity.Repo",
      "Singularity.Health.HttpServer",
      "Singularity.Infrastructure.Overseer",
      "Singularity.Infrastructure.ErrorRateTracker",
      "Singularity.Infrastructure.CircuitBreakerSupervisor"
    ],
    QuantumFlow: [
      "QuantumFlow.WorkflowSupervisor",
      "Singularity.Ingestion.Workflows.ExecuteAutoCodeIngestionWorkflow",
      "Singularity.Workflows.EmbeddingTrainingWorkflow",
      "Singularity.Workflows.ArchitectureLearningWorkflow",
      "Broadway.QuantumFlowProducer"
    ],
    pipelines: [
      "Singularity.ML.PipelineSupervisor",
      "Singularity.Embedding.BroadwayEmbeddingPipeline"
    ],
    knowledge: [
      "Singularity.Knowledge.TemplateService",
      "Singularity.Search.PackageAndCodebaseSearch"
    ],
    agents: [
      "Singularity.Agents.RuntimeBootstrapper",
      "Singularity.Agents.Arbiter",
      "Singularity.Agents.ChangeTracker",
      "Singularity.Agents.SelfImprovementAgent",
      "Singularity.Agents.DocumentationPipelineGitIntegration",
      "Singularity.Agents.AgentSpawner"
    ],
    execution: [
      "Singularity.Ingestion.HTDAG.StartHtdagIngestionSupervisor",
      "Singularity.Execution.TaskGraph.TaskGraphOrchestrator",
      "Singularity.Execution.SafeWorkPlanner"
    ],
    messaging: [
      "Singularity.Notifications.PgmqNotify",
      "Singularity.SharedQueueConsumer"
    ],
    hot_reload: [
      "Singularity.Ingestion.HotReload.TriggerHotReloadOnFileChange",
      "Singularity.HotReload.SafeCodeChangeDispatcher"
    ],
    monitoring: [
      "Singularity.Monitoring.CodeEngineHealthTracker",
      "Singularity.Monitoring.AgentTaskTracker",
      "Singularity.Metrics.Aggregator"
    ],
    llm: [
      "Singularity.LLM.BeamLLMService",
      "Singularity.Tools.InstructorAdapter"
    ]
  }

  @quick_searches %{
    "Check QuantumFlow workflows" => "QuantumFlow",
    "See auto-ingestion activity" => "AutoCodeIngestion",
    "Inspect embedding pipeline" => "BroadwayEmbeddingPipeline",
    "Monitor agent orchestration" => "Agent",
    "Watch HTDAG execution" => "HTDAG",
    "Verify PGMQ notifications" => "Pgmq",
    "Track health monitors" => "Overseer",
    "Audit LLM usage" => "BeamLLM"
  }

  @doc """
  Return keyword map for LiveDashboard searches.
  """
  def process_keywords, do: @process_keywords

  @doc """
  Process names grouped by high-level category.
  """
  def process_categories, do: @process_categories

  @doc """
  Handy quick-search hints for LiveDashboard.
  """
  def quick_searches, do: @quick_searches

  @doc """
  Pretty-print registry information to STDOUT for quick reference.
  """
  def print_registry do
    IO.puts("\n=== Singularity Process Registry (QuantumFlow era) ===\n")
    IO.puts("Use these keywords in LiveDashboard Processes tab:")
    IO.puts("  http://localhost:4000/dashboard/processes\n")

    Enum.each(process_categories(), fn {category, processes} ->
      IO.puts("## #{category |> to_string() |> String.upcase()}")

      Enum.each(processes, fn name ->
        IO.puts("  - #{name}")

        if (description = Map.get(process_keywords(), name)) && description != "" do
          IO.puts("    └─ #{description}")
        end
      end)

      IO.puts("")
    end)

    IO.puts("## QUICK SEARCHES")

    Enum.each(quick_searches(), fn {label, query} ->
      IO.puts("  - #{label}: #{query}")
    end)

    IO.puts("")
  end
end
