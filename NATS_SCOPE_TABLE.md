# NATS Migration Scope - Consolidated View

## At-a-Glance Summary

```
┌─────────────────┬──────────────┬──────────┬───────────────────┬─────────────┬──────────────┐
│   Application   │ Status       │ Patterns │ Dependencies      │ Risk Level  │ Effort       │
├─────────────────┼──────────────┼──────────┼───────────────────┼─────────────┼──────────────┤
│ Singularity     │ HYBRID       │ 11       │ 12 direct, 40 T   │ MEDIUM      │ 2-3 weeks    │
│ Genesis         │ DEPRECATED   │ 0        │ 0                 │ NONE        │ DONE         │
│ CentralCloud    │ OPTIONAL     │ 3        │ 4-5 direct        │ LOW         │ 1 week       │
│ Nexus           │ CRITICAL     │ 6        │ 3 files, 1 pkg    │ HIGH*       │ KEEP NATS    │
│ LLM-Server      │ DEPRECATED   │ N/A      │ Merged to Nexus   │ NONE        │ DONE         │
└─────────────────┴──────────────┴──────────┴───────────────────┴─────────────┴──────────────┘
* Recommended to keep NATS for Nexus (simplest, highest stability)
```

---

## Detailed Metrics Per Application

### SINGULARITY (Elixir)

| Metric | Value | Notes |
|--------|-------|-------|
| **Current NATS Usage** | HYBRID | Also using pgmq (shared_queue) |
| **Files with NATS imports** | 12+ | See file list below |
| **Lines of NATS code** | 2,500+ | client, supervisor, nats_operation, etc. |
| **NATS Subject Patterns** | 11 | llm.*, approval.*, planning.*, agent.*, etc. |
| **Critical Dependencies** | 3 | LLM ops, token streaming, approval flow |
| **Can Disable** | Yes | Test mode sets config `nats.enabled: false` |
| **Auto-reconnect** | Yes | Every 5 seconds (line 403 nats/client.ex) |
| **Timeout (seconds)** | 30 | Default for request/reply (NatsOperation) |
| **Polling Interval (ms)** | 1000 | For new pgmq messages |
| **Batch Size** | 50-100 | LLM requests: 50, other: 100 |

**Files Using NATS:**
```
singularity/lib/singularity/nats/
  ├── client.ex                   (GenServer - publish/subscribe)
  ├── supervisor.ex               (Process management)
  ├── nats_server.ex              (Connection handling)
  ├── jetstream_bootstrap.ex       (JetStream setup)
  ├── registry_client.ex           (Registry interface)
  └── engine_discovery_handler.ex  (Engine detection)

singularity/lib/singularity/llm/
  ├── nats_operation.ex            (LLM request/reply - 984 lines total)
  └── service.ex                   (LLM routing - calls nats_operation)

singularity/lib/singularity/execution/
  ├── todos/todo_nats_interface.ex (Todo management)
  └── planning/work_plan_api.ex     (Work planning)

singularity/lib/singularity/tools/
  ├── nats.ex                      (Tool execution via NATS)
  └── database_tools_executor.ex   (Database operations)

singularity/lib/singularity/interfaces/
  ├── nats.ex                      (Interface protocol)
  └── nats/connector.ex            (Connection management)

singularity/lib/singularity/control/
  └── agent_improvement_broadcaster.ex (Event broadcasting)

singularity/lib/singularity/adapters/
  └── nats_adapter.ex              (Adapter pattern)

singularity/lib/singularity/agents/
  ├── agent.ex                     (Agent base)
  └── supervisor.ex                (Agent lifecycle)
```

**Primary Migration Target:** Replace `llm.request` → `pgmq.llm_requests`

---

### GENESIS (Elixir)

| Metric | Value | Notes |
|--------|-------|-------|
| **Current NATS Usage** | DEPRECATED | Fully switched to pgmq Oct 2025 |
| **Files with NATS imports** | 1 | nats_client.ex (stub only, returns :ignore) |
| **Lines of NATS code** | 25 | Just deprecation warning |
| **NATS Subject Patterns** | 0 | No NATS subjects |
| **Critical Dependencies** | 0 | All via PostgreSQL pgmq |
| **Status** | ✅ COMPLETE | Fully functional without NATS |
| **Polling Interval (ms)** | 1000 | Genesis.SharedQueueConsumer |
| **Batch Size** | 100 | Per polling cycle |
| **Database Tables** | 2 | pgmq.job_requests, pgmq.job_results |

**Model Implementation (Copy This Pattern):**
```elixir
# genesis/lib/genesis/shared_queue_consumer.ex
# - GenServer with periodic polling
# - Reads from pgmq.job_requests
# - Processes jobs (lint/validate/test)
# - Writes to pgmq.job_results
# - No NATS involvement
```

**Why This Works:**
- Natural batching (poll bulk)
- Built-in durability (PostgreSQL)
- Survives restarts (no in-memory state)
- Simple error handling (just log and continue)

---

### CENTRALCLOUD (Elixir)

| Metric | Value | Notes |
|--------|-------|-------|
| **Current NATS Usage** | OPTIONAL | JetStream KV is caching optimization |
| **Files with NATS imports** | 4-5 | nats_client, intelligence_hub, subscribers |
| **Lines of NATS code** | 300 | Limited, mostly optional |
| **NATS Subject Patterns** | 3 | central.*, intelligence.*, health.* |
| **Critical Dependencies** | 0 | All optional (fallback: PostgreSQL queries) |
| **Can Disable** | Yes | Would just query PostgreSQL instead |
| **JetStream Features** | 2 | KV bucket (templates), Streams (events/metrics) |
| **Status** | Low priority | Can migrate after Singularity |

**Optional Services:**
1. **NATS KV Template Cache** - Optimization only (DB fallback exists)
2. **Pattern Aggregation** - Via NATS or Oban jobs (either works)
3. **Intelligence Hub Events** - Fire-and-forget (not critical)

**Easy Migration:**
- Config flag: disable NATS
- Fall back to PostgreSQL queries (already exist)
- Query latency acceptable (<10ms)

---

### NEXUS (TypeScript/Bun)

| Metric | Value | Notes |
|--------|-------|-------|
| **Current NATS Usage** | CRITICAL | Blocks all LLM operations |
| **Files with NATS imports** | 3 major | nats-handler, nats-publisher, nats.ts |
| **Lines of NATS code** | 400+ | Handler + publisher + setup |
| **NATS Subject Patterns** | 6 | llm.*, approval.*, question.* |
| **Critical Dependencies** | 1 | llm.request subscription (blocks agents) |
| **npm Package** | nats | ~100KB library |
| **Connection** | Persistent | Auto-reconnect on failure |
| **Model Selection Matrix** | 4 task types | general, architect, coder, qa |
| **Providers Supported** | 8+ | Claude, Gemini, Copilot, OpenRouter, etc. |

**Critical Flow:**
```
Singularity.NATS.Client.request("llm.req.<model>", payload)
                    ↓ NATS
Nexus listens on "llm.request"
    ├── Analyze task complexity
    ├── Select best model from MODEL_SELECTION_MATRIX
    ├── Call AI provider
    └── Publish response
                    ↓ NATS
Singularity receives response (blocking)
    ↓ Agents continue execution
```

**If Nexus NATS fails:**
- All Singularity agents block (timeout 30s)
- No fallback mechanism
- Complete system stall

**Recommendation:** KEEP NATS for Nexus (simplest, safest option)

**Why not migrate to pgmq:**
- Would need polling instead of subscribe
- Slower than NATS request/reply
- More complex handler redesign
- Can be deferred (lower priority)

---

### LLM-SERVER (Deprecated)

| Metric | Value | Notes |
|--------|-------|-------|
| **Status** | DEPRECATED | Merged into Nexus (Oct 2025) |
| **Files** | 0 | All code consolidated to nexus/ |
| **NATS Dependencies** | 0 | Moved to Nexus files |
| **Action** | None | Already completed |

---

## Consolidated NATS Subjects Matrix

```
┌──────────────────────┬─────────────────────┬──────────────────────────┬──────────┐
│ Subject Pattern      │ Publisher           │ Subscriber               │ Priority │
├──────────────────────┼─────────────────────┼──────────────────────────┼──────────┤
│ llm.req.<model_id>   │ Singularity         │ Nexus                    │ CRITICAL │
│ llm.response         │ Nexus               │ Singularity              │ CRITICAL │
│ llm.tokens.*         │ Nexus               │ Singularity (optional)   │ LOW      │
│ approval.request     │ Singularity         │ Nexus                    │ HIGH     │
│ approval.response    │ Nexus/Browser       │ Singularity              │ HIGH     │
│ question.ask         │ Singularity         │ Nexus                    │ HIGH     │
│ question.reply       │ Nexus/Browser       │ Singularity              │ HIGH     │
│ central.template.*   │ CentralCloud        │ Singularity (optional)   │ LOW      │
│ analysis.meta.*      │ CentralCloud        │ Singularity              │ MEDIUM   │
│ planning.*           │ Singularity         │ Singularity agents       │ MEDIUM   │
│ agent.*              │ Singularity agents  │ Singularity              │ MEDIUM   │
│ system.events.*      │ Singularity         │ Monitoring               │ LOW      │
└──────────────────────┴─────────────────────┴──────────────────────────┴──────────┘
```

---

## Configuration Parameters

### Singularity (singularity/config/config.exs)
```elixir
config :singularity, :nats,
  enabled: true/false                                # Can disable for tests

config :singularity, :shared_queue,
  enabled: true/false
  database_url: System.get_env("SHARED_QUEUE_DB_URL")
  poll_interval_ms: 1000                             # Default
  batch_size: 100                                    # Default
  llm_request_poll_ms: 100                           # Faster for LLM
  llm_batch_size: 50                                 # Smaller batch
```

### Genesis (genesis/config/config.exs)
```elixir
config :genesis, :shared_queue,
  enabled: true                                      # Always on
  database_url: "postgresql://..."
  poll_interval_ms: 1000
  batch_size: 100
```

### CentralCloud (centralcloud/config/config.exs)
```elixir
config :centralcloud, :shared_queue,
  enabled: System.get_env("SHARED_QUEUE_ENABLED", "true") == "true"
  database_url: System.get_env("SHARED_QUEUE_DB_URL")
  auto_initialize: true
  retention_days: 90
```

### Nexus (nexus environment)
```bash
NATS_URL=nats://localhost:4222                      # Default
PORT=3000
```

---

## Migration Impact Summary

### Code Changes Required
```
Singularity:   650 lines changed (remove NATS, add SharedQueue LLM ops)
Genesis:       ✅ DONE
CentralCloud:  200 lines (remove NATS KV, use PostgreSQL queries)
Nexus:         0 lines (RECOMMENDED: Keep NATS)
─────────────────────────────────
Total:         ~850 lines across 4 applications
```

### Testing Requirements
```
Singularity LLM:      200 test lines (request/reply cycles)
Singularity HITL:     150 test lines (approval flow)
CentralCloud:         100 test lines (pattern queries)
Nexus:                0 lines (no change if keeping NATS)
─────────────────────────────────
Total:                ~450 test lines
```

### Dependencies to Remove
```
Singularity:
  - gnat library (NATS client)
  - nats config
  - Connection pool for NATS

Genesis:         (already removed)
CentralCloud:    (optional - can keep as optimization)
Nexus:           (RECOMMENDED: keep if not migrating)
```

---

## Timeline & Resources

```
Phase 1 (Singularity LLM):  2-3 weeks,  1 developer  (Medium risk)
Phase 2 (HITL):             1-2 weeks,  1 developer  (Low risk)
Phase 3 (CentralCloud):     1 week,     1 developer  (Low risk)
Phase 4 (Nexus decision):   2-3 hours,  1 developer  (Decision point)
Phase 5 (Cleanup):          1 week,     1 developer  (Cleanup)
────────────────────────────────────────────────────
Total:                      6-8 weeks for full migration
```

---

## Success Metrics

### Phase 1 Complete
- [ ] LLM operations work via pgmq (no NATS)
- [ ] Agents don't block on NATS unavailability
- [ ] All tests pass: `mix test singularity/test/singularity/llm/`
- [ ] Timeout behavior identical to NATS (30 seconds)

### Phase 2 Complete
- [ ] Approval requests persisted and delivered
- [ ] No approvals lost (ACID guarantees)
- [ ] Response time <5 seconds
- [ ] Tests pass: `mix test singularity/test/singularity/hitl/`

### Phase 3 Complete
- [ ] CentralCloud works without NATS KV
- [ ] Pattern queries < 10ms latency
- [ ] No NATS errors in logs

### Phase 4 Decision
- [ ] Documented: Keep NATS for Nexus OR Migrate to pgmq
- [ ] Implementation plan if migrating

### Phase 5 Cleanup
- [ ] No gnat dependency in mix.exs
- [ ] No NATS supervisor in supervision tree
- [ ] CLAUDE.md updated

---

**Analysis Generated:** October 25, 2025
**Ready for:** Phase 1 Implementation
**Recommendation:** Proceed with Genesis pattern for Singularity LLM ops
