# Self-Evolving Context-Aware Generation Pipeline — Reality Plan

**Date:** 2025-10-27  
**Status:** ⚠️ In progress — data stores, analyzers, and learning primitives exist, but Responses API integration, Observer HITL flows, and Genesis publishing remain open.

## Reality Snapshot

- **Data & intelligence foundations are real.** `singularity/lib/singularity/storage/failure_pattern_store.ex` and `singularity/lib/singularity/storage/validation_metrics_store.ex` implement the persistence required for historical validation, and both ship with full query helpers. Likewise, pattern intelligence already lives in CentralCloud (`centralcloud/lib/centralcloud/framework_learning_agent.ex`, `centralcloud/lib/centralcloud/template_intelligence.ex`) with importers that seed all architecture pattern types from `templates_data/architecture_patterns/`.
- **Queue-based LLM requests are only partially wired.** `singularity/lib/singularity/jobs/llm_request_worker.ex` enqueues jobs with `api_version: "responses"`, and Nexus executes them via `nexus/lib/nexus/workflows/llm_request_workflow.ex`. However, `singularity/lib/singularity/workflows/llm_request.ex` still simulates synchronous results and the legacy `Singularity.LLM.Service` module references NATS/ai-server paths that no longer exist.
- **Observer exists but is skeletal.** The new Phoenix LiveView app under `observer/` (see `observer/mix.exs`) boots with Oban, pgmq, ex_pgflow, heroicons, ecto_psql_extras, etc., yet its LiveViews still render placeholder JSON and lack HITL/approvals contexts. Navigation helpers and Moon tasks were missing.
- **Genesis publishing and rule evolution are stubbed.** `singularity/lib/singularity/evolution/rule_evolution_system.ex` keeps confident rule data but `publish_rule_to_genesis/2` is still a no-op simulation. `Singularity.Evolution.GenesisPublisher` expects queue wiring that is not yet present.
- **No ai-server / NATS dependency.** The TypeScript ai-server and NATS references are historical. All new work must rely on `pgmq` + `ex_pgflow` with OpenAI Responses API payloads routed through Nexus. Any lingering docs or code that suggest NATS usage need to be cleaned up.

## Active Workstreams

1. **Responses API queue integration (critical path)**  
   Align Singularity enqueue → Nexus workflow → pgmq result polling on Responses payloads. Update docs and callers so `api_version: "responses"` is the default, and kill the NATS narrative.

2. **Observer (Phoenix LiveView) as the single HITL & telemetry surface**  
   Build the Observer contexts that proxy existing dashboards (Agent, Validation, Rule Evolution, Cost) and introduce the human-in-the-loop approvals UI. Ensure Observer has its own database while reading shared telemetry from Singularity/Nexus.

3. **CentralCloud intelligence alignment**  
   Keep framework/architecture pattern learning centralized in CentralCloud and share it back through pgmq/ex_pgflow so Observer and the pipeline can consume the latest pattern metadata.

4. **Post-execution learning & Genesis exchange**  
   Finish the feedback loop: store failure/success outcomes, evolve validation rules, and publish confident rules to Genesis via pgmq rather than the ai-server.

## Implementation Plan

### Phase 0 — Baseline & Tooling (Day 0)

- Ensure shared pgmq queues exist (`Singularity.Jobs.PgmqClient.ensure_all_queues/0`).
- Add Moon project metadata for the Observer app (`observer/moon.yml`) so Nix + moon tasks cover `mix deps`, `mix compile`, `mix test`, `mix phx.server`.
- Keep development inside the Nix devshell (`flake.nix`) to guarantee uniform tooling (PostgreSQL 17, pgvector, Rust toolchain for NIFs).

### Phase 1 — Responses API Queue Wiring (Days 1-3)

1. **Normalize the workflow payload** (`singularity/lib/singularity/workflows/llm_request.ex`)
   - Capture optional fields (`api_version`, `agent_id`, `max_tokens`, `temperature`, `previous_response_id`, `mcp_servers`, `store`, `tools`).
   - Respect user-supplied `complexity`/`model` hints; otherwise fall back to `get_complexity_for_task/1` and `select_best_model/1`.
2. **Enqueue Responses payloads**
   - Replace the `Singularity.LLM.Service.call_with_prompt/3` usage with `Singularity.Jobs.PgmqClient.send_message("ai_requests", payload)` so every request hits Nexus.
   - Persist the generated `request_id` + `msg_id` for downstream tracking.
3. **Poll Responses results** (`singularity/lib/singularity/jobs/llm_result_poller.ex`)
   - Parse Responses envelopes and store them via `Singularity.Schemas.Execution.JobResult.record_success/1`.
   - Surface helpers like `await_responses_result/2` for synchronous callers.
4. **Update callers** (Chat agents, planning tools, PromptEngine) to queue requests instead of invoking NATS. Each path should forward tool specifications (`tools`, `store`) untouched.
5. **Document the queue flow** (in this plan and in `RESPONSES_API_PGMQ_INTEGRATION.md`).

### Phase 2 — Observer / HITL Platform (Days 3-7)

1. **Observer core components**
   - Finalize navigation helper in `observer/lib/observer_web/components/core_components.ex` and clean up LiveView assigns to avoid HEEx warnings.
   - Flesh out `Observer.Dashboard` to normalise, cache, and paginate large payloads from Singularity dashboards.
2. **HITL approvals context**
   - Create `Observer.HITL.Approvals` with CRUD APIs backed by Observer’s own Postgres database (Ecto schemas + migrations).
   - Replace legacy human-in-the-loop calls in Singularity with REST/pgmq calls to Observer.
3. **Dashboards**
   - For each LiveView (`system_health_live.ex`, `validation_metrics_live.ex`, `agent_performance_live.ex`, …) convert raw JSON dumps into summary cards and tables fed by `Observer.Dashboard`.
   - Add streaming/refresh controls with sensible intervals.
4. **Routing & security**
   - Wire LiveView routes (`observer/lib/observer_web/router.ex`) with authentication hooks if required.
   - Expose Observer endpoints to Singularity/Genesis/Nexus via pgmq or HTTP for approvals and manual overrides.

### Phase 3 — Learning & Genesis Integration (Days 7-10)

1. **Validation effectiveness weighting**
   - Wire `Singularity.Storage.ValidationMetricsStore` into Observer dashboards and Adaptive Confidence Gating.
   - Compute precision/recall + latency to drive `should_run_check/2` thresholds.
2. **Historical failure guardrails**
   - Surface failure clusters from `FailurePatternStore` and feed them into `HistoricalValidator` (Phase 3 of the pipeline).
3. **Genesis publishing**
   - Replace the stub in `Singularity.Evolution.RuleEvolutionSystem.publish_rule_to_genesis/2` with a pgmq producer that emits to a `genesis_rule_updates` queue consumed by Genesis.
   - Backfill existing confident rules.
4. **CentralCloud sync**
   - Schedule `FailurePatternStore.sync_with_centralcloud/1` and ensure CentralCloud rebroadcasts aggregated patterns.

### Phase 4 — Testing, CI, and Ops (Days 10-12)

- Add integration tests covering the queue loop: enqueue request → Nexus workflow → ai_results → result poller.
- Write LiveView tests for Observer pages with stubbed data.
- Regression-test TaskGraph plans that depend on LLM assistance after switching to queue-based calls.
- Update deployment docs to include Observer (Phoenix) service, its database, and required environment variables (shared pgmq credentials, OpenAI keys).

## Tooling & Environments

- **Nix-first workflow:** `nix develop .#dev` continues to provide Erlang/Elixir, Rust, PostgreSQL, pgvector, and CLI tooling. No bespoke setup scripts are needed beyond `just setup`.
- **Moon tasks:** Add `observer/moon.yml` with `deps`, `compile`, `test`, `format`, `server` tasks. Update workspace-level Moon config if cross-project dependencies are needed.
- **Databases:**
  - Observer uses its own Postgres schema (via `Observer.Repo`) for approvals and cached snapshots so the UI can remain responsive even if upstream services are slow.
  - Shared artefacts (pgmq queues, ex_pgflow tables) remain in the shared “queue” database so Singularity, Nexus, Genesis, and CentralCloud can collaborate without tight coupling.

## Appendix — Verified Components

| Area | Status | Notes |
|------|--------|-------|
| Failure patterns | ✅ Implemented | `singularity/lib/singularity/storage/failure_pattern_store.ex` handles upsert, similarity queries, and CentralCloud sync. |
| Validation metrics | ✅ Implemented | `singularity/lib/singularity/storage/validation_metrics_store.ex` provides precision/recall + cost tracking. |
| Pattern intelligence | ✅ Implemented | CentralCloud pattern importer & learners live under `centralcloud/lib/centralcloud/`. |
| Queue worker | ⚠️ Partial | `singularity/lib/singularity/workflows/llm_request.ex` still simulates synchronous results; needs pure pgmq handoff. |
| Nexus workflow | ✅ Implemented | `nexus/lib/nexus/workflows/llm_request_workflow.ex` executes validate → route → publish → metrics using Responses API payloads. |
| Observer app | ⚠️ Partial | `observer/` scaffolding exists; contexts/routes/UI remain TODO. |
| Genesis publisher | ⚠️ Stub | `Singularity.Evolution.RuleEvolutionSystem.publish_rule_to_genesis/2` logs instead of emitting to Genesis. |

### Short Checklist

- [ ] Finish Responses API enqueuing & result polling (Singularity ↔ Nexus)
- [ ] Build Observer HITL/approvals + dashboard polish
- [ ] Replace Genesis publishing stub with real pgmq producer
- [ ] Update/retire `Singularity.LLM.Service` NATS references once new queue path is stable
- [ ] Add integration + LiveView tests, wire tasks into Moon/Nix pipelines

This plan keeps the existing intelligence modules intact (FailurePatternStore, ValidationMetricsStore, CentralCloud pattern catalogues, framework learners, Adaptive Confidence Gating) while focusing current effort on the missing glue: Responses API queue wiring, Observer HITL experience, and Genesis publishing.
