# Task Execution Systems - Complete File Reference

**All absolute paths for task, job, and adapter implementations**

---

## Oban Jobs (18 files, 2,902 lines)

### Singularity Jobs (15 files)

| Module | File Path | Lines | Purpose |
|--------|-----------|-------|---------|
| JobOrchestrator | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/job_orchestrator.ex` | 298 | Config-driven job discovery and enqueue |
| JobType | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/job_type.ex` | 215 | Behavior contract for all jobs |
| MetricsAggregationWorker | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/metrics_aggregation_worker.ex` | 59 | Aggregate agent metrics (5 min) |
| PatternSyncWorker | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/pattern_sync_worker.ex` | ~70 | Sync framework patterns (5 min) |
| FeedbackAnalysisWorker | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/feedback_analysis_worker.ex` | ~70 | Analyze feedback (30 min) |
| AgentEvolutionWorker | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/agent_evolution_worker.ex` | ~70 | Apply agent improvements (1 hour) |
| CacheRefreshWorker | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/cache_refresh_worker.ex` | ~70 | Refresh hot cache (1 hour) |
| CachePrewarmWorker | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/cache_prewarm_worker.ex` | ~70 | Prewarm cache (6 hours) |
| CacheCleanupWorker | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/cache_cleanup_worker.ex` | ~70 | Cleanup cache (on-demand) |
| CacheMaintenanceJob | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/cache_maintenance_job.ex` | ~70 | General cache maintenance |
| KnowledgeExportWorker | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/knowledge_export_worker.ex` | ~70 | Export patterns to Git |
| PatternMinerJob | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/pattern_miner_job.ex` | ~200 | Mine code patterns from codebase |
| DomainVocabularyTrainerJob | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/domain_vocabulary_trainer_job.ex` | ~200 | Train domain vocabulary models |
| TrainT5ModelJob | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/train_t5_model_job.ex` | ~200 | Fine-tune T5 embeddings |
| EmbeddingFinetuneJob | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/embedding_finetune_job.ex` | ~150 | Fine-tune embedding model |
| DeadCodeDailyCheck | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/dead_code_daily_check.ex` | ~100 | Daily dead code detection |
| DeadCodeWeeklySummary | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/dead_code_weekly_summary.ex` | ~100 | Weekly dead code summary |

### CentralCloud Jobs (3 files)

| Module | File Path | Lines | Purpose |
|--------|-----------|-------|---------|
| PatternAggregationJob | `/Users/mhugo/code/singularity-incubation/centralcloud/lib/centralcloud/jobs/pattern_aggregation_job.ex` | ~200 | Aggregate patterns from all instances (1 hour) |
| PackageSyncJob | `/Users/mhugo/code/singularity-incubation/centralcloud/lib/centralcloud/jobs/package_sync_job.ex` | ~200 | Sync package registry |
| StatisticsJob | `/Users/mhugo/code/singularity-incubation/centralcloud/lib/centralcloud/jobs/statistics_job.ex` | ~150 | Compute statistics |

---

## NATS Infrastructure (5+ files, ~1,400 lines)

### Main NATS Files

| Module | File Path | Lines | Purpose |
|--------|-----------|-------|---------|
| NatsExecutionRouter | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/nats/nats_execution_router.ex` | 245 | Route execution requests (DEPRECATED) |
| NatsServer | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/nats/nats_server.ex` | ~500 | NATS connection management |
| NatsClient | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/nats/nats_client.ex` | ~300 | NATS client library |
| NatsEngineDiscoveryHandler | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/nats/engine_discovery_handler.ex` | ~100 | Engine discovery via NATS |
| NatsSupervisor | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/nats/supervisor.ex` | ~100 | NATS supervision tree |

### CentralCloud NATS Subscribers

| Module | File Path | Lines | Purpose |
|--------|-----------|-------|---------|
| IntelligenceHubSubscriber | `/Users/mhugo/code/singularity-incubation/centralcloud/lib/centralcloud/intelligence_hub_subscriber.ex` | ~100 | Receive intelligence hub data |
| PatternValidatorSubscriber | `/Users/mhugo/code/singularity-incubation/centralcloud/lib/centralcloud/nats/pattern_validator_subscriber.ex` | ~100 | Validate patterns via NATS |

---

## Task Graph / Execution System (90 files, 13,114 lines)

### Core Task Graph Components

| Module | File Path | Lines | Purpose |
|--------|-----------|-------|---------|
| TaskGraph.Orchestrator | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/task_graph/orchestrator.ex` | 200+ | High-level enqueue API with dependencies |
| TaskGraph.WorkerPool | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/task_graph/worker_pool.ex` | 250+ | Poll-based worker spawning |
| TaskGraph.Worker | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/task_graph/worker.ex` | 300+ | Individual worker process |
| TaskGraph.Toolkit | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/task_graph/toolkit.ex` | 300+ | Policy-enforced tool execution |
| TaskGraph.Policy | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/task_graph/policy.ex` | 150+ | Role-based security policies |

### Execution Adapters

| Module | File Path | Lines | Purpose |
|--------|-----------|-------|---------|
| Shell | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/task_graph/adapters/shell.ex` | 200+ | Safe shell command execution |
| Docker | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/task_graph/adapters/docker.ex` | 250+ | Sandboxed Docker execution |
| Lua | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/task_graph/adapters/lua.ex` | 200+ | Luerl Lua sandbox execution |
| Http | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/task_graph/adapters/http.ex` | 150+ | HTTP request execution |

### Todos Storage

| Module | File Path | Lines | Purpose |
|--------|-----------|-------|---------|
| TodoStore | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/todos/todo_store.ex` | 300+ | PostgreSQL todo persistence |
| Todo (Schema) | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/todos/todo.ex` | ~100 | Todo schema definition |
| TodoNatsInterface | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/todos/todo_nats_interface.ex` | 150+ | NATS query interface for todos |
| TodoSwarmCoordinator | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/todos/todo_swarm_coordinator.ex` | 200+ | Legacy swarm coordinator |
| TodoWorkerAgent | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/todos/todo_worker_agent.ex` | 200+ | Individual todo worker agent |
| TodoSupervisor | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/todos/supervisor.ex` | 100+ | Todos supervision tree |

### Execution Planning

| Module | File Path | Lines | Purpose |
|--------|-----------|-------|---------|
| TaskGraphCore | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/planning/task_graph_core.ex` | 300+ | Dependency resolution logic |
| TaskGraphExecutor | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/planning/task_graph_executor.ex` | 200+ | Execute task DAGs |
| LuaStrategyExecutor | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/planning/lua_strategy_executor.ex` | 250+ | Execute Lua strategies |
| SafeWorkPlanner | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/planning/safe_work_planner.ex` | 300+ | Plan work safely with constraints |
| TaskExecutionStrategy | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/planning/task_execution_strategy.ex` | 200+ | Strategy definitions and selection |
| StoryDecomposer | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/planning/story_decomposer.ex` | 250+ | Decompose stories into tasks |

### Planning Support Modules

- **Schema Files:** `capability.ex`, `capability_dependency.ex`, `epic.ex`, `feature.ex`, `strategic_theme.ex`
- **Strategy Files:** `strategy_loader.ex`, `task_graph.ex`, `task_graph_evolution.ex`
- **Support Files:** `vision.ex`, `code_file_watcher.ex`, `execution_tracer.ex`, `work_plan_api.ex`

---

## GenServer Agents (7+ files, ~2,500 lines)

| Module | File Path | Lines | Purpose |
|--------|-----------|-------|---------|
| Agent | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/agent.ex` | 400+ | Base GenServer for all agents |
| CostOptimizedAgent | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/cost_optimized_agent.ex` | 300+ | Cost-aware LLM model selection |
| SelfImprovingAgent | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/self_improving_agent.ex` | 250+ | Self-optimizing agent |
| RuntimeBootstrapper | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/runtime_bootstrapper.ex` | 200+ | Bootstrap agents at startup |
| AgentSupervisor | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/agent_supervisor.ex` | 150+ | Agent process supervision |
| QualityEnforcer | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/quality_enforcer.ex` | 200+ | Enforce code quality |
| MetricsFeeder | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/metrics_feeder.ex` | 150+ | Feed metrics to agents |
| DocumentationUpgrader | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/documentation_upgrader.ex` | 200+ | Auto-upgrade documentation |
| DocumentationPipeline | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/documentation_pipeline.ex` | 250+ | Documentation generation pipeline |
| DeadCodeMonitor | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/dead_code_monitor.ex` | 150+ | Monitor and report dead code |
| RealWorkloadFeeder | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/real_workload_feeder.ex` | 150+ | Feed real workloads to agents |

---

## Execution Orchestrators (5 files, ~1,500 lines)

| Module | File Path | Lines | Purpose |
|--------|-----------|-------|---------|
| ExecutionOrchestrator | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/execution_orchestrator.ex` | 126 | Unified orchestrator (auto-detect strategy) |
| SPARC.Orchestrator | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/execution/sparc/orchestrator.ex` | 400+ | Template-based execution |
| MethodologyExecutor | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/quality/methodology_executor.ex` | 200+ | Execute SAFe methodology |
| DatabaseToolsExecutor | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/tools/database_tools_executor.ex` | 150+ | Execute database tools |
| StartupCodeIngestion | `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/code/startup_code_ingestion.ex` | 200+ | Load code at startup |

---

## Configuration Files

| Location | Purpose |
|----------|---------|
| `/Users/mhugo/code/singularity-incubation/singularity/config/config.exs` | Main Elixir config (job_types, oban) |
| `/Users/mhugo/code/singularity-incubation/centralcloud/config/config.exs` | CentralCloud config |

---

## Summary Statistics

```
Total Execution/Job Files:     120+
Total Execution Code Lines:    ~20,000

Breakdown:
  - Oban Jobs:               18 files    2,902 lines
  - NATS Infrastructure:      5 files   ~1,400 lines
  - Task Graph/Execution:    90 files   13,114 lines
  - GenServer Agents:        7+ files   ~2,500 lines
  - Orchestrators:            5 files   ~1,500 lines
```

---

## Quick Navigation

**By Pattern:**
- **Background Jobs:** Oban Jobs section
- **Message-Based:** NATS Infrastructure section
- **Dependency Workflows:** Task Graph / Execution System section
- **Direct Execution:** GenServer Agents section
- **Unified Entry Points:** Execution Orchestrators section

**By File Type:**
- **Configuration:** `/config/config.exs`
- **Infrastructure:** `supervisor.ex`, `orchestrator.ex`
- **Workers:** `*_worker.ex`, `*_job.ex`
- **Storage:** `*_store.ex`
- **Adapters:** `/adapters/*.ex`

---

**Last Updated:** 2025-10-24
**Maintained By:** Claude Code
