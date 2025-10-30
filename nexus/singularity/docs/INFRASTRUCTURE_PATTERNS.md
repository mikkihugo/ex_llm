# Infrastructure Patterns (Cherry-picked from Legacy Branch)

This project keeps the most valuable reliability patterns from the pre-QuantumFlow codebase. The
following modules were ported from the old `master` branch and adapted to the current `nexus`
layout so we can retain the hardening efforts while using PostgreSQL/PGMQ + QuantumFlow:

- `Singularity.Infrastructure.ErrorHandling` – structured execution wrapper with correlation
  IDs, retry helper, and telemetry hooks.
- `Singularity.Infrastructure.ErrorRateTracker` – ETS-backed sliding window metrics to highlight
  error spikes in production.
- `Singularity.Infrastructure.ErrorClassification` – shared vocabulary + telemetry for error
  responses; `ErrorHandling` delegates here when wrapping exceptions.
- `Singularity.Infrastructure.PidManager` – “adopt vs. kill” process management for local
  services such as PostgreSQL and the QuantumFlow notifier.
- `Singularity.Infrastructure.Overseer` – centralized status poller for QuantumFlow workflow
  supervisors, PostgreSQL, and the health HTTP server.
- `Singularity.Infrastructure.Resilience` – retry, timeout, bulkhead, and circuit breaker helpers
  used across QuantumFlow pipelines and integration points.
- `Singularity.Monitoring.AgentTaskTracker` – telemetry-based task lifecycle broadcasts the
  dashboards rely on.
- `Singularity.ProcessRegistry` – LiveDashboard-friendly keywords for QuantumFlow supervision trees
  while still exposing the actual registry used by agents (via `{:via, Registry, ...}` tuples).

QuantumFlow workflows now lean on these primitives: the embedding and architecture training
workflows wrap every critical step (data collection, training, validation, deployment) with
`Resilience.with_retry/with_timeout`, giving consistent backoff and timeout semantics when they
talk to PostgreSQL, QuantumFlow queues, or GPU-backed Axon trainers.

Integration tests in `test/integration/infrastructure_patterns_test.exs` exercise the core
behaviour of these modules to ensure the cherry-picked logic remains healthy as QuantumFlow evolves.
