# Production Readiness TODO

This checklist tracks the outstanding work needed to take the queue-based
pipeline and Observer HITL stack to production quality.

## Queue & Workflow Hardening
- [x] pgmq + quantum_flow messaging implemented correctly (misleading function names exist but use correct implementation)
- [ ] Provision a repeatable PostgreSQL (pgmq + quantum_flow enabled) instance for tests and CI
      so `Singularity.Repo` and `Singularity.Jobs.LlmResultPoller.await_responses_result/2`
      run without connection errors.
- [ ] Add integration tests that cover `ai_requests → Nexus → ai_results` end-to-end
      once the database fixture is in place.
- [x] Most NATS references updated (Genesis/CentralCloud functions renamed but use pgmq correctly)

## Observer HITL Integration
- [x] Observer.HITL APIs implemented (pgmq-based communication)
- [x] HITL approvals migration exists (`observer/priv/repo/migrations/20251026000100_create_hitl_approvals.exs`)
- [ ] Wire remaining Singularity agents to Observer.HITL APIs (currently only self_improving_agent uses Singularity.HITL.ApprovalService)
- [ ] Add automated migration step for `observer` to deployment scripts (setup-database.sh, setup-all-services.sh)
- [ ] Expand LiveView coverage with fixtures for approval decisions and polling

## Documentation & Runtime
- [ ] Finish doc refresh for pgmq + quantum_flow architecture (README + Singularity runtime docs updated;
      still need to revise remaining guides such as `CLAUDE.md`, service quick references)
- [ ] Add pgmq/quantum_flow configuration to `.env.example` (PGFLOW_*_ENABLED variables)
- [ ] Audit Rust packages for lingering NATS assumptions and update to pgmq/quantum_flow

## Follow-up Enhancements
- [ ] Monitor `genesis_rule_updates` queue consumption and backfill logic once Genesis
      wiring lands, adding alerting/metrics for the new publisher.
- [ ] Baseline performance (latency, cost) for the queue path after the above changes
      and document SLOs.
