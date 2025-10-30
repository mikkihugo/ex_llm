# Singularity Ecosystem - Quick Reference
## Component Relationships at a Glance

### Products Ready to Ship
| Product | Status | What | Key Integration |
|---------|--------|------|-----------------|
| **GitHub App** | 90% | Auto PR analysis + quality checks | → Webhook driven |
| **Scanner CLI** | 95% | Portable code quality binary | → Offline-first |
| **CentralCloud** | 85% | Learning hub + pattern sync | → REST API |

### What Each Product Produces/Consumes

```
GitHub App & Scanner
    ↓ Produces: metrics, patterns, issue fingerprints
    ↓
CentralCloud API (/scanner/runs, /scanner/events)
    ↓ Consumes + Aggregates
    ↓ Learns patterns → Genesis evolves rules
    ↓
GET /patterns/snapshot (evolved patterns)
    ↓ Consumed by both products
    ↓ Better detection next run
```

### Core System Not Yet Productized

| System | Status | Purpose | Could Become |
|--------|--------|---------|--------------|
| **Agents (SelfImproving)** | 85% | Autonomous code evolution | Agent-as-a-Service |
| **Pipeline (5-phase)** | 95% | Self-improvement loop | Workflow-as-a-Service |
| **Hot Reload** | 95% | Live code updates | Infrastructure only |
| **Embeddings (Nx)** | 90% | Semantic search | Semantic search service |

### Data Flow: Products → Core System

```
Scanner finds issues
    ↓
POST /scanner/events → CentralCloud
    ↓
Parse patterns, failures, success rates
    ↓
Genesis evolves rules (validates, scores improvements)
    ↓
Updated patterns stored in PostgreSQL
    ↓
Serve via GET /patterns/snapshot (with ETag caching)
    ↓
Products use evolved patterns next run
    ↓
ALSO feeds core Singularity pipeline (agent training)
```

### Network Effects Unlocked

1. **Pattern Consensus** - More users = better rules (15% found this pattern)
2. **Template Evolution** - Failed templates improved (40% fail rate → fix → retest)
3. **Quality Standards** - Emerge from corpus (95% of top teams enforce X)
4. **Failure Prevention** - Learn from others (we prevented this bug before)

### Missing Pieces (To Close Loop)

| Gap | Impact | Fix |
|-----|--------|-----|
| **Products don't visibly use evolved patterns** | No customer awareness of network effect | Show "learned from 10k repos" |
| **No team personalization** | Rules are global, not personalized | Add team-specific variants |
| **No acceptance/rejection tracking** | Genesis doesn't know if customers liked suggestions | Collect "ignored" signals |
| **Cross-product learning weak** | GitHub App & Scanner learn separately | Share CentralCloud patterns |

### How to Pitch "Auto-Fix" Upgrade

```
Stage 1: "Scanner found 50 issues"
Stage 2: "We can auto-fix 80% using community patterns"
Stage 3: "Hot-reload applies fixes safely (with automatic rollback)"
Stage 4: "Self-improving agents learn YOUR code style"
Stage 5: "Predict issues before you write them"
```

### Relationship Between Products & packages/code_quality_engine

```
packages/code_quality_engine (Rust NIF + CLI binaries)
    ├─→ Used by Scanner product (via CLI feature)
    ├─→ Used by GitHub App (via NIF binding)
    ├─→ Analyzers: metrics, complexity, quality, security
    └─→ Binaries: singularity-scanner, scanner, formatter, api_client
```

### Why ex_quantum_flow is Important

`packages/ex_quantum_flow` is the messaging backbone:
- Scanner → CentralCloud communication
- GitHub App async workflow orchestration
- Internal pgmq queues (learning, checks, patterns_sync)
- **Status:** 100% complete, already published to Hex

### CentralCloud API Endpoints (3 only)

```
1. POST /scanner/runs
   Request: {local_run_id, repo, commit, etag}
   Response: {server_run_id, patterns_etag, policies}
   
2. POST /scanner/events
   Request: {server_run_id, results, metrics}
   Response: {status: "ok"}
   
3. GET /patterns/snapshot
   Response: encrypted patterns + ETag
   (304 if unchanged, client uses Cache-Control/ETag)
```

### Why Patterns/Rules Don't Change Often

1. **ETag caching** - Clients cache patterns locally
2. **Evolved rules stabilize** - After 100+ instances, consensus emerges
3. **No continuous retraining** - Genesis runs periodically (daily/weekly)
4. **Benefits accumulate** - Small improvements compound over time

### Product Lock-In Timeline

```
Month 1-3: Data collection phase
  - Products gather patterns from 100+ repos
  - CentralCloud sees patterns emerging

Month 3-6: Consensus phase
  - Enough data to trust evolved rules
  - Genesis produces first improvements
  - Products start using evolved patterns

Month 6-12: Network effects phase
  - Team-specific personalizations emerge
  - Failure prevention measurable
  - Switching cost rises (would lose personalized rules)

Month 12+: Expansion phase
  - Add Team Dashboard (see personalized rules)
  - Add IDE plugins (integration)
  - Add SaaS upgrade (agent-as-a-service)
```

### Quick Facts

- **GitHub App:** Webhook-driven (background), continuous collection
- **Scanner:** On-demand (foreground), CI/CD friendly, offline-capable
- **CentralCloud:** Hub (central), no database access from clients (REST only)
- **Agents:** Local (internal), improve your own codebase continuously
- **Patterns:** Encrypted, distributed via HTTP, cached with ETag
- **Feedback:** Not yet closed (Genesis sees results, not customer intent)

### Key Metrics to Watch

| Metric | Target | Unlocks |
|--------|--------|---------|
| **CentralCloud instances online** | 100+ | Pattern consensus |
| **Pattern hit ratio** | 70%+ customers benefit | Network effect proof |
| **Template success improvement** | +5% per quarter | Compounding value |
| **Failure prevention rate** | Measurable | Lock-in begins |

---

**Status:** CentralCloud is the linchpin - once live, network effects begin.
**Next:** Complete CentralCloud implementation (API, PostgreSQL schema, Genesis integration).
