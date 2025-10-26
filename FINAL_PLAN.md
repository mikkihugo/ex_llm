# Self-Evolving Context-Aware Generation Pipeline — Reality Plan

**Date:** 2025-10-27  
**Status:** ⚠️ In progress — queue-based Responses pipeline and Observer dashboards are live, but HITL approvals, Genesis publishing, and documentation cleanup remain open.

## Reality Snapshot

- **Data & intelligence foundations are real.** `singularity/lib/singularity/storage/failure_pattern_store.ex` and `singularity/lib/singularity/storage/validation_metrics_store.ex` implement the persistence required for historical validation, and both ship with full query helpers. Likewise, pattern intelligence already lives in CentralCloud (`centralcloud/lib/centralcloud/framework_learning_agent.ex`, `centralcloud/lib/centralcloud/template_intelligence.ex`) with importers that seed all architecture pattern types from `templates_data/architecture_patterns/`.
- **Queue-based LLM requests now run end-to-end.** `Singularity.LLM.Service.dispatch_request/2` routes calls through `Singularity.Jobs.LlmRequestWorker`, the workflow at `singularity/lib/singularity/workflows/llm_request.ex` publishes Responses payloads to `ai_requests`, and `Singularity.Jobs.LlmResultPoller` persists Nexus `ai_results` via `JobResult.record_success/1`. The moduledocs still describe NATS, so documentation cleanup is pending.
- **Observer dashboards render live data but lack approvals.** The LiveViews under `observer/lib/observer_web/live/` use `Observer.Dashboard` to render cards, charts, and pretty JSON with auto-refresh intervals, yet no `Observer.HITL.Approvals` context or persistence exists for human-in-the-loop flows.
- **Genesis publishing and rule evolution are stubbed.** `singularity/lib/singularity/evolution/rule_evolution_system.ex` keeps confident rule data but `publish_rule_to_genesis/2` is still a no-op simulation. `Singularity.Evolution.GenesisPublisher` expects queue wiring that is not yet present.
- **Legacy NATS messaging docs linger.** `singularity/lib/singularity/llm/service.ex`, `singularity/lib/singularity/jobs/pgmq_client.ex`, and `singularity/lib/singularity/storage/knowledge/template_service.ex` have been updated to reflect the pgmq/Nexus flow; remaining cleanup is limited to ancillary comments and older READMEs.

## Active Workstreams

1. **Observer HITL & approvals workflow**  
   Build the approvals context (`Observer.HITL`) with schemas, Oban/pgmq producers, and LiveView screens so humans can approve/override plans. Persist decisions in Observer’s database and expose REST/pgmq hooks Singularity can call.

2. **Genesis publishing & learning telemetry**  
   Replace `publish_rule_to_genesis/2` with a real pgmq producer, persist metrics from `Nexus.Workflows.LLMRequestWorkflow.track_metrics/1`, and surface the data through Rule Evolution and Cost dashboards.

3. **Documentation + helper cleanup for the Responses pipeline**  
   `Singularity.LLM.Service`, `Singularity.Jobs.PgmqClient`, and `Singularity.Knowledge.TemplateService` now describe the queue-first architecture; `await_responses_result/2` ships with unit coverage and `RESPONSES_API_PGMQ_INTEGRATION.md` documents the flow. Remaining work: align secondary docs (CLAUDE.md, README) and ensure callers adopt the new helper.

4. **CentralCloud intelligence alignment**  
   Keep framework/architecture pattern learning centralized in CentralCloud and share it back through pgmq/ex_pgflow so Observer and the pipeline can consume the latest pattern metadata.

## Implementation Plan

### Phase 0 — Baseline & Tooling (✅ Completed)

- Shared pgmq queues are created via `Singularity.Jobs.PgmqClient.ensure_all_queues/0` and run at application boot.
- `observer/moon.yml` exists with dev/test/build tasks so Moon orchestrates the Phoenix app.
- `flake.nix` + devshell continue to pin PostgreSQL 17, pgvector, and the Rust toolchain.

### Phase 1 — Responses API Queue Wiring (✅ Completed)

1. **Payload normalization.** `Singularity.Workflows.LlmRequest.receive_request/1` accepts optional fields (`api_version`, `agent_id`, `max_tokens`, `temperature`, `previous_response_id`, `mcp_servers`, `store`, `tools`) and timestamps each request.
2. **Queue hand-off.** `call_llm_provider/1` publishes to `ai_requests` via `Singularity.Jobs.PgmqClient`, while `Singularity.LLM.Service.dispatch_request/2` now enqueues through `Singularity.Jobs.LlmRequestWorker` (Oban) instead of NATS.
3. **Result ingestion.** `Singularity.Jobs.LlmResultPoller` reads `ai_results`, persists outcomes with `Singularity.Schemas.Execution.JobResult.record_success/1`, and acknowledges the messages. Still pending: expose `await_responses_result/2` for synchronous waits.
4. **Callers aligned.** Agents, planning tools, and PromptEngine continue to invoke `Singularity.LLM.Service`, which now routes through the queue path transparently.
5. **Documentation cleanup complete.** Moduledocs were refreshed and `RESPONSES_API_PGMQ_INTEGRATION.md` now describes the queue flow; secondary guides still need later alignment.

### Phase 2 — Observer / HITL Platform (⚠️ In progress)

1. **Observer dashboards.** `ObserverWeb.DashboardLive` macro, LiveViews (`system_health_live.ex`, `agent_performance_live.ex`, etc.), and shared components are in place with auto-refresh, summary cards, and fallback JSON inspectors.
2. **HITL approvals context (✅ live via UI).** `Observer.HITL` context, schemas, and LiveViews now support approvals. Next step: wire Singularity callbacks through Observer.
3. **Dashboards polish.** Add pagination/search where needed, tighten error messaging, and decide whether raw JSON panels remain or move to a drill-down modal.
4. **Routing & security.** Current router exposes dashboards without auth; add authentication/authorization before exposing Observer in production. Provide pgmq or REST endpoints for approvals once the context ships.

### Phase 3 — Learning & Genesis Integration (Days 7-10)

1. **Validation effectiveness weighting**
   - Wire `Singularity.Storage.ValidationMetricsStore` into Observer dashboards and Adaptive Confidence Gating.
   - Persist metrics emitted from `Nexus.Workflows.LLMRequestWorkflow.track_metrics/1` so cost/latency trends backstop gating decisions.
2. **Historical failure guardrails**
   - Surface failure clusters from `FailurePatternStore` and feed them into `HistoricalValidator` (Phase 3 of the pipeline).
3. **Genesis publishing**
   - Replace the stub in `Singularity.Evolution.RuleEvolutionSystem.publish_rule_to_genesis/2` with a pgmq producer that emits to a `genesis_rule_updates` queue consumed by Genesis.
   - Backfill existing confident rules and record the Genesis IDs when publish succeeds.
4. **CentralCloud sync**
   - Schedule `FailurePatternStore.sync_with_centralcloud/1` and ensure CentralCloud rebroadcasts aggregated patterns.

### Phase 4 — Testing, CI, and Ops (Days 10-12)

- Add integration tests covering the queue loop: enqueue request → Nexus workflow → ai_results → result poller.
- Write LiveView tests for Observer pages with stubbed data.
- Regression-test TaskGraph plans that depend on LLM assistance after switching to queue-based calls.
- Update deployment docs to include Observer (Phoenix) service, its database, and required environment variables (shared pgmq credentials, OpenAI keys).

## Tooling & Environments

- **Nix-first workflow:** `nix develop .#dev` continues to provide Erlang/Elixir, Rust, PostgreSQL, pgvector, and CLI tooling. No bespoke setup scripts are needed beyond `just setup`.
- **Moon tasks:** `observer/moon.yml` already defines `deps`, `compile`, `test`, `format`, and `server`; keep workspace-level Moon config aligned if cross-project dependencies change.
- **Databases:**
  - Observer uses its own Postgres schema (via `Observer.Repo`) for approvals and cached snapshots so the UI can remain responsive even if upstream services are slow.
  - Shared artefacts (pgmq queues, ex_pgflow tables) remain in the shared “queue” database so Singularity, Nexus, Genesis, and CentralCloud can collaborate without tight coupling.

## Appendix — Verified Components

| Area | Status | Notes |
|------|--------|-------|
| Failure patterns | ✅ Implemented | `singularity/lib/singularity/storage/failure_pattern_store.ex` handles upsert, similarity queries, and CentralCloud sync. |
| Validation metrics | ✅ Implemented | `singularity/lib/singularity/storage/validation_metrics_store.ex` provides precision/recall + cost tracking. |
| Pattern intelligence | ✅ Implemented | CentralCloud pattern importer & learners live under `centralcloud/lib/centralcloud/`. |
| Queue worker | ✅ Implemented | `Singularity.LLM.Service` → `Singularity.Jobs.LlmRequestWorker` → `singularity/lib/singularity/workflows/llm_request.ex` enqueue to pgmq; `LlmResultPoller` stores Nexus results (helper for synchronous waits still pending). |
| Nexus workflow | ✅ Implemented | `nexus/lib/nexus/workflows/llm_request_workflow.ex` executes validate → route → publish → metrics using Responses API payloads. |
| Observer app | ⚠️ Approvals TODO | Live dashboards render metrics via `Observer.Dashboard`; need HITL context + auth before production exposure. |
| Genesis publisher | ⚠️ Stub | `Singularity.Evolution.RuleEvolutionSystem.publish_rule_to_genesis/2` logs instead of emitting to Genesis. |

### Short Checklist

- [x] Responses API enqueuing & result polling (Singularity ↔ Nexus) via `LlmRequestWorker`, `LlmRequest`, and `LlmResultPoller`
- [ ] Build Observer HITL/approvals + dashboard polish
- [ ] Replace Genesis publishing stub with real pgmq producer and persist Nexus metrics
- [x] Update `Singularity.LLM.Service`/`PgmqClient` docs, add `await_responses_result/2`, refresh `RESPONSES_API_PGMQ_INTEGRATION.md`
- [ ] Add integration + LiveView tests, wire tasks into Moon/Nix pipelines

This plan keeps the existing intelligence modules intact (FailurePatternStore, ValidationMetricsStore, CentralCloud pattern catalogues, framework learners, Adaptive Confidence Gating) while focusing current effort on Observer HITL approvals, documentation cleanup, and Genesis publishing.
