defmodule Singularity.Application do
  @moduledoc """
  Application entrypoint bootstrapping clustering, telemetry, and the HTTP control plane.
  """
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Create ETS table for runner executions
    :ets.new(:runner_executions, [:named_table, :public, :set])

    children = [
      # Start the Ecto repository
      Singularity.Repo,
      # Start the Telemetry supervisor (metrics + poller)
      Singularity.Telemetry,
      # Start the main application supervisor
      Singularity.ApplicationSupervisor,
      # Start the Runner for task execution
      Singularity.Runner,
      # Start the unified NATS server (single entry point)
      Singularity.NatsServer,
      # Start the NATS execution router
      Singularity.NatsExecutionRouter,
      # Start the SPARC orchestrator
      Singularity.SPARC.Orchestrator,
      # Start the Template SPARC orchestrator
      Singularity.TemplateSparcOrchestrator,
      # Start the Git tree sync coordinator
      Singularity.Git.GitTreeSyncCoordinator,
      # Start the agent supervisor
      Singularity.AgentSupervisor,
      # Start the autonomy decider
      Singularity.Autonomy.Decider,
      # Start the autonomy planner
      Singularity.Autonomy.Planner,
      # Start the rule engine
      Singularity.Autonomy.RuleEngine,
      # Start the semantic cache
      Singularity.LLM.SemanticCache,
      # Start the template performance tracker
      Singularity.TemplatePerformanceTracker,
      # Start the embedding engine
      Singularity.EmbeddingEngine,
      # Start the quality engine
      Singularity.QualityEngine,
      # Start the source code analyzer
      Singularity.SourceCodeAnalyzer,
      # Start the knowledge artifact store
      Singularity.Knowledge.ArtifactStore,
      # Start the technology template store
      Singularity.TechnologyTemplateStore,
      # Start the framework pattern store
      Singularity.FrameworkPatternStore,
      # Start the semantic code search
      Singularity.Search.SemanticCodeSearch,
      # Start the package registry knowledge
      Singularity.Search.PackageRegistryKnowledge,
      # Start the package and codebase search
      Singularity.Search.PackageAndCodebaseSearch,
      # Start the code store
      Singularity.Code.Storage.CodeStore,
      # Start the code location index
      Singularity.Code.Storage.CodeLocationIndex,
      # Start the pattern indexer
      Singularity.Code.Patterns.PatternIndexer,
      # Start the pattern miner
      Singularity.Code.Patterns.PatternMiner,
      # Start the code quality deduplicator
      Singularity.Code.Quality.CodeDeduplicator,
      # Start the duplication detector
      Singularity.Code.Quality.DuplicationDetector,
      # Start the refactoring agent
      Singularity.Code.Quality.RefactoringAgent,
      # Start the code synthesis pipeline
      Singularity.Code.Generators.CodeSynthesisPipeline,
      # Start the pseudocode generator
      Singularity.Code.Generators.PseudocodeGenerator,
      # Start the quality code generator
      Singularity.Code.Generators.QualityCodeGenerator,
      # Start the RAG code generator
      Singularity.Code.Generators.RAGCodeGenerator,
      # ParserEngine is a NIF module - no need to start it
      # ArchitectureAgent removed - functionality moved to ArchitectureEngine
      # Start the consolidation engine
      Singularity.Code.Analyzers.ConsolidationEngine,
      # Start the coordination analyzer
      Singularity.Code.Analyzers.CoordinationAnalyzer,
      # Start the flow analyzer
      Singularity.Code.Analyzers.FlowAnalyzer,
      # Microservice analyzer removed (feature disabled in this build)
      # Singularity.Code.Analyzers.MicroserviceAnalyzer,
      # Start the Rust tooling analyzer
      Singularity.Code.Analyzers.RustToolingAnalyzer,
      # Start the code trainer
      Singularity.Code.Training.CodeTrainer,
      # Start the domain vocabulary trainer
      Singularity.Code.Training.DomainVocabularyTrainer,
      # Start the flow visualizer
      Singularity.Code.Visualizers.FlowVisualizer,
      # Start the chat conversation agent
      Singularity.Conversation.ChatConversationAgent,
      # Start the Google Chat integration
      Singularity.Conversation.GoogleChat,
      # Start the codebase snapshots
      Singularity.Detection.CodebaseSnapshots,
      # Start the framework detector
      Singularity.Detection.FrameworkDetector,
      # Start the technology agent
      Singularity.Detection.TechnologyAgent,
      # Start the technology pattern adapter
      Singularity.Detection.TechnologyPatternAdapter,
      # Start the technology template loader
      Singularity.Detection.TechnologyTemplateLoader,
      # Start the technology template store
      Singularity.Detection.TechnologyTemplateStore,
      # Start the template matcher
      Singularity.Detection.TemplateMatcher,
      # Start the embedding model loader
      Singularity.EmbeddingModelLoader,
      # Start the codebase store
      Singularity.Engine.CodebaseStore,
      # Start the git tree sync coordinator
      Singularity.Git.GitTreeSyncCoordinator,
      # Start the circuit breaker
      Singularity.Infrastructure.CircuitBreaker,
      # Start the documentation generator
      Singularity.Infrastructure.DocumentationGenerator,
      # Start the error handling
      Singularity.Infrastructure.ErrorHandling,
      # Start the error rate tracker
      Singularity.Infrastructure.ErrorRateTracker,
      # Start the LLM providers
      Singularity.Integration.LLMProviders.Claude,
      Singularity.Integration.LLMProviders.Copilot,
      Singularity.Integration.LLMProviders.Gemini,
      # Start the platform integrations
      Singularity.Integration.Platforms.EngineDatabaseManager,
      # Start the NATS connector
      Singularity.Interfaces.NATS.Connector,
      # Start the template service
      Singularity.Knowledge.TemplateService,
      # Start the LLM rate limiter
      Singularity.LLM.RateLimiter,
      # Start the LLM service
      Singularity.LLM.Service,
      # Start the template aware prompt
      Singularity.LLM.TemplateAwarePrompt,
      # Start the NATS client
      Singularity.NatsClient,
      # Start the NATS execution router
      Singularity.NatsExecutionRouter,
      # Start the package registry collector
      Singularity.Packages.PackageRegistryCollector,
      # Start the HTDAG
      Singularity.Planning.HTDAG,
      # Start the safe work planner
      Singularity.Planning.SafeWorkPlanner,
      # Start the story decomposer
      Singularity.Planning.StoryDecomposer,
      # Start the work plan API
      Singularity.Planning.WorkPlanAPI,
      # Start the embedding quality tracker
      Singularity.Search.EmbeddingQualityTracker,
      # Start the source code analyzer
      Singularity.SourceCodeAnalyzer,
      # Start the source code parser NIF
      Singularity.SourceCodeParserNif,
      # Start the startup warmup
      Singularity.StartupWarmup,
      # Start the store
      Singularity.Store,
      # Start the template performance tracker
      Singularity.TemplatePerformanceTracker,
      # Start the template SPARC orchestrator
      Singularity.TemplateSparcOrchestrator,
      # Start the template store
      Singularity.Templates.TemplateStore,
      # Start the agent guide
      Singularity.Tools.AgentGuide,
      # Start the agent tool selector
      Singularity.Tools.AgentToolSelector,
      # Start the basic tools
      Singularity.Tools.Basic,
      # Start the default tools
      Singularity.Tools.Default,
      # Start the emergency LLM
      Singularity.Tools.EmergencyLLM,
      # Start the enhanced descriptions
      Singularity.Tools.EnhancedDescriptions,
      # Start the quality tools
      Singularity.Tools.Quality,
      # Start the tool selector
      Singularity.Tools.ToolSelector,
      # Start the Phoenix web server
      SingularityWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Singularity.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
