# Production Readiness TODO

This checklist tracks the outstanding work needed to take the queue-based
pipeline and Observer HITL stack to production quality.

## Queue & Workflow Hardening
- [ ] Provision a repeatable PostgreSQL (pgmq-enabled) instance for tests and CI
      so `Singularity.Repo` and `Singularity.Jobs.LlmResultPoller.await_responses_result/2`
      run without connection errors.
- [ ] Add integration tests that cover `ai_requests → Nexus → ai_results` end-to-end
      once the database fixture is in place.
- [ ] Replace the remaining NATS-dependent helpers (`Singularity.Messaging.Client`,
      `Singularity.NATS.RegistryClient`) with pgmq or direct database access, or remove
      callers entirely if obsolete.

## Observer HITL Integration
- [ ] Wire Singularity agents to call the new `Observer.HITL` APIs (pgmq/HTTP) so
      human decisions flow back into the pipeline.
- [ ] Add an automated migration step for `observer` (e.g. `mix ecto.migrate`) to the
      deployment scripts so the `hitl_approvals` table is present everywhere.
- [ ] Expand LiveView coverage with fixtures for approval decisions and polling.

## Documentation & Runtime
- [ ] Update top-level docs (`CLAUDE.md`, README files, centralcloud guides) to reflect
      the queue-first architecture and removal of NATS listeners.
- [ ] Ship env templates (e.g. `.env.example`, Docker Compose) capturing required
      settings for pgmq, Observer, and Nexus so operators can bootstrap consistently.
- [ ] Audit Rust packages (`prompt_engine`, `architecture_engine`, etc.) for lingering
      NATS assumptions and either update to pgmq or mark them deprecated.

## Follow-up Enhancements
- [ ] Monitor `genesis_rule_updates` queue consumption and backfill logic once Genesis
      wiring lands, adding alerting/metrics for the new publisher.
- [ ] Baseline performance (latency, cost) for the queue path after the above changes
      and document SLOs.
