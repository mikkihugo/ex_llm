# NATS Migration - Summary & Quick Reference

## Application Status Matrix

### Singularity (Elixir)
- **Current Status:** HYBRID (NATS + pgmq)
- **NATS Dependencies:** 12+ direct, 40+ transitive
- **Critical Operations:** LLM requests, token streaming, agent coordination
- **Can Disable:** Yes (test mode via config)
- **Migration Risk:** MEDIUM (affects agent execution)

**Key Files:**
- `singularity/lib/singularity/nats/` - Core infrastructure
- `singularity/lib/singularity/llm/nats_operation.ex` - LLM request/reply
- `singularity/lib/singularity/shared_queue_*.ex` - New pgmq implementation

**What's Critical:**
```elixir
Singularity.NATS.Client.request("llm.req.<model_id>", ...)
  ↓ Blocks agent execution
  ↓ No fallback if NATS unavailable
  ↓ 30-second timeout default
```

**Migration Approach:**
1. Create `SharedQueueOperation` module (follow Genesis pattern)
2. Replace `llm.request` → `pgmq.llm_requests` table
3. Replace `llm.response` → `pgmq.llm_results` table
4. Update `Singularity.LLM.Service` to use SharedQueue instead of NATS
5. Keep approval/question flow same (Nexus HITL bridge needs NATS or WebSocket)

---

### Genesis (Elixir)
- **Current Status:** DEPRECATED NATS (pgmq only)
- **NATS Dependencies:** 0
- **What Changed:** Switched from NATS to PostgreSQL pgmq
- **Migration Date:** October 2025
- **Result:** Fully functional without NATS

**Key File:**
- `genesis/lib/genesis/shared_queue_consumer.ex` - Model for migration

**How It Works:**
```
pgmq.job_requests  ← Singularity publishes
   ↓
Genesis.SharedQueueConsumer polls every 1000ms
   ↓
Execute job (lint/validate/test)
   ↓
pgmq.job_results  ← Publish result back
```

**Why This Pattern Works:**
- No connection overhead
- Natural batching (poll in bulk)
- Built-in durability (PostgreSQL transaction)
- Survives process restarts (no state in memory)

---

### CentralCloud (Elixir)
- **Current Status:** OPTIONAL NATS (KV cache optimization)
- **NATS Dependencies:** 4-5 direct modules
- **Critical Operations:** None (JetStream KV is optional optimization)
- **Migration Risk:** LOW (can disable without affecting core)

**Key Files:**
- `centralcloud/lib/centralcloud/nats_client.ex` - Connection management
- `centralcloud/lib/centralcloud/knowledge_cache.ex` - Uses NATS KV

**What's Optional:**
- NATS KV bucket for template caching (already have DB)
- Pattern validation subscription (not blocking)
- Intelligence Hub event subscription (not blocking)

**Easy Migration:**
1. Disable NATS in config (no code changes needed)
2. Use PostgreSQL instead of JetStream KV
3. Poll for pattern updates instead of NATS subscribe

---

### Nexus (TypeScript/Bun)
- **Current Status:** CRITICAL NATS USER
- **NATS Dependencies:** 3 major files, 1 npm package
- **Critical Operations:** LLM routing (blocks all AI operations)
- **Migration Risk:** HIGH (must maintain LLM → Provider flow)

**Key Files:**
- `nexus/src/nats-handler.ts` - LLM request handler (150+ lines)
- `nexus/src/approval-websocket-bridge.ts` - HITL approval bridge
- `nexus/src/nats-publisher.ts` - Response publishing

**What's Critical:**
```typescript
// This must work or all agents block
subscription = nc.subscribe('llm.request')
  ↓
Process LLM request
  ↓
publish('llm.response', result)
```

**Migration Strategy:**
- **Option 1:** Keep NATS for LLM routing (simplest - no change)
- **Option 2:** Add pgmq poller alongside NATS
- **Option 3:** Full migration to pgmq (complex - needs handler redesign)

**Recommended:** Option 1 (keep NATS for Nexus, migrate other apps off NATS)

---

### LLM-Server (Deprecated)
- **Status:** MERGED into Nexus
- **NATS Dependencies:** Migrated to Nexus
- **No Action Needed:** Already consolidated

---

## NATS Subject Breakdown

### Singularity Uses (11 subject patterns):
```
1. llm.req.<model_id>           ← Publish LLM request
2. llm.resp.<run_id>.<node_id>  ← Wait for response
3. llm.tokens.<run_id>          ← Subscribe to tokens
4. llm.health                   ← Check health
5. approval.request             ← Code approval (HITL)
6. question.ask                 ← Ask human
7. analysis.meta.naming.*       ← Query naming patterns
8. analysis.meta.architecture.* ← Query arch patterns
9. planning.tasks.*             ← Work planning
10. agent.coordination.*         ← Agent sync
11. system.events.*             ← Event broadcast
```

### Nexus Uses (6 subject patterns):
```
1. llm.request                  ← Receive requests from Singularity
2. llm.response                 ← Send responses back
3. approval.request             ← Code approval requests
4. approval.response            ← Human approval decisions
5. question.ask                 ← Questions for humans
6. question.reply               ← Human responses
```

### CentralCloud Uses (3 subject patterns):
```
1. central.template.search      ← Query template cache
2. central.patterns.update      ← Pattern update broadcast
3. central.health.*             ← Health checks
```

---

## Environment Variables & Config

### Singularity
```bash
# NATS Connection (optional, auto-disabled in tests)
NATS_HOST=127.0.0.1
NATS_PORT=4222

# Shared Queue (new pgmq implementation)
SHARED_QUEUE_ENABLED=true
SHARED_QUEUE_DB_URL=postgresql://...
SHARED_QUEUE_POLL_MS=1000
SHARED_QUEUE_BATCH_SIZE=100
SHARED_QUEUE_LLM_POLL_MS=100
SHARED_QUEUE_LLM_BATCH_SIZE=50
```

### Genesis
```bash
# Shared Queue (pgmq only, no NATS)
SHARED_QUEUE_ENABLED=true
SHARED_QUEUE_DB_URL=postgresql://...
```

### CentralCloud
```bash
# Shared Queue (pgmq)
SHARED_QUEUE_ENABLED=true
SHARED_QUEUE_DB_URL=postgresql://...
```

### Nexus
```bash
# NATS Connection (required for LLM routing)
NATS_URL=nats://localhost:4222
PORT=3000
```

---

## Migration Phases & Effort

### Phase 0: Current State (COMPLETED)
- Genesis: ✅ Fully migrated to pgmq
- Others: 🔄 Hybrid mode

### Phase 1: Singularity LLM Ops (MEDIUM EFFORT)
**Timeline:** 2-3 weeks
**Risk:** MEDIUM

1. Create `SharedQueueOperation` module
2. Create `llm_requests` and `llm_results` pgmq tables
3. Update `Singularity.LLM.NatsOperation` → use SharedQueue
4. Update `Singularity.LLM.Service` → route to SharedQueue
5. Test with all LLM operations
6. Remove NATS dependency

**Deliverable:** Singularity can run without NATS for LLM operations

**Test Commands:**
```bash
mix test singularity/test/singularity/llm/
mix test singularity/test/singularity/agents/
```

---

### Phase 2: HITL Flow (LOW EFFORT)
**Timeline:** 1-2 weeks
**Risk:** LOW

1. Create approval/question pgmq tables
2. Update `Singularity.SharedQueuePublisher` for approvals
3. Update Nexus to read from pgmq instead of NATS (optional)
4. Test approval flow

**Note:** HITL Bridge in Nexus can stay on NATS or move to pgmq (either works)

**Deliverable:** Approval/question flow via pgmq

---

### Phase 3: CentralCloud (LOW EFFORT)
**Timeline:** 1 week
**Risk:** LOW

1. Disable NATS KV caching (fallback to PostgreSQL queries)
2. Replace NATS pattern validation with pgmq polling
3. Test pattern aggregation

**Deliverable:** CentralCloud no longer needs NATS

---

### Phase 4: Nexus Evaluation (2-3 hours)
**Decision Point:** Keep or migrate Nexus NATS?

**Option A: Keep NATS for Nexus (RECOMMENDED)**
- Keep current NATS handler
- Singularity still sends LLM requests via NATS
- Nexus routes to Claude/Gemini/Copilot
- Minimal changes, high stability

**Option B: Migrate Nexus to pgmq**
- More complex (needs polling instead of subscribe)
- Can do later if needed
- Lower priority (Nexus NATS is not a bottleneck)

**Deliverable:** Decision + implementation plan

---

### Phase 5: Cleanup (1 week)
**After all migrations complete:**
1. Remove `gnat` dependency from Singularity
2. Remove NATS supervisor from application.ex
3. Remove NATS-related configuration
4. Archive NATS templates
5. Remove NATS documentation (old)
6. Update CLAUDE.md with new architecture

**Deliverable:** Clean codebase without NATS dependency

---

## Risk Assessment

### High Risk Areas
1. **Agent execution blocking** - Singularity agents will block until LLM response received
   - Mitigation: Use pgmq with polling (Genesis pattern)
   - Test: Run 10+ concurrent agents without NATS

2. **Approval decisions** - HITL flow must not lose requests
   - Mitigation: PostgreSQL transactions guarantee delivery
   - Test: Kill Nexus mid-approval, verify request persists

3. **Token streaming** - Current code expects NATS subscription
   - Mitigation: Token streaming is optional (fallback to non-streaming)
   - Test: Disable token streaming, verify full responses

### Medium Risk Areas
1. **CentralCloud pattern caching** - Small performance regression if no NATS KV
   - Mitigation: Acceptable (PostgreSQL queries are fast)
   - Test: Measure query latency (should be <10ms)

2. **Meta-registry queries** - Some queries use NATS subjects
   - Mitigation: Most are read-only from PostgreSQL already
   - Test: Verify all queries work with config disabled

### Low Risk Areas
1. **Event broadcasting** - Not critical path
   - Mitigation: Batch events via Oban jobs (already done)

---

## Code Size & Complexity

### NATS Code to Remove (1,900 lines)
```
singularity/lib/singularity/nats/              (1,000 lines)
  ├── client.ex                                 (400 lines)
  ├── nats_server.ex                           (200 lines)
  ├── supervisor.ex                            (80 lines)
  ├── jetstream_bootstrap.ex                   (150 lines)
  ├── registry_client.ex                       (100 lines)
  └── engine_discovery_handler.ex              (70 lines)

singularity/lib/singularity/llm/
  └── nats_operation.ex                        (300 lines)

singularity/lib/singularity/tools/
  └── nats.ex                                  (150 lines)

nexus/src/
  └── nats-*.ts                                (400 lines)
```

### NATS Code to Add (1,200 lines)
```
singularity/lib/singularity/shared_queue/
  ├── llm_operation.ex                         (250 lines)
  ├── approval_operation.ex                    (250 lines)
  └── question_operation.ex                    (250 lines)

centralcloud/lib/centralcloud/
  └── shared_queue_patterns.ex                 (200 lines)

Test files:
  └── Tests for above modules                  (250 lines)
```

**Net Change:** -700 lines (cleaner codebase)

---

## Success Criteria

### Phase 1 (LLM Ops)
- [ ] All LLM operations work without NATS
- [ ] Agents don't block waiting for responses
- [ ] Timeout behavior same as NATS (30 seconds)
- [ ] Token streaming optional (not required)
- [ ] Tests pass: `mix test singularity/test/singularity/llm/`

### Phase 2 (HITL Flow)
- [ ] Approvals persisted and delivered
- [ ] No approval requests lost
- [ ] Response time <5 seconds (same as NATS)
- [ ] Tests pass: `mix test singularity/test/singularity/hitl/`

### Phase 3 (CentralCloud)
- [ ] Pattern aggregation works without NATS
- [ ] Query latency <10ms
- [ ] No NATS references in logs

### Phase 4 (Nexus)
- [ ] Decision made: keep or migrate NATS
- [ ] If migrate: LLM routing works via pgmq
- [ ] If keep: document why and when to reconsider

### Phase 5 (Cleanup)
- [ ] No gnat dependency in mix.exs
- [ ] No NATS supervisor in application tree
- [ ] CLAUDE.md updated with new architecture
- [ ] All old NATS documentation archived

---

## Appendix: File Reference

### Singularity NATS Files
| File | Lines | Purpose | Migration |
|------|-------|---------|-----------|
| nats/client.ex | 400 | GenServer pub/sub | Remove |
| nats/supervisor.ex | 80 | Process management | Remove |
| nats/nats_server.ex | 200 | Connection | Remove |
| nats/jetstream_bootstrap.ex | 150 | JetStream setup | Remove |
| llm/nats_operation.ex | 300 | LLM request/reply | Replace |
| tools/nats.ex | 150 | Tool execution | Modify |

### Genesis Pgmq Files (Model Implementation)
| File | Lines | Purpose |
|------|-------|---------|
| shared_queue_consumer.ex | 100 | Polling implementation |
| shared_queue_schemas.ex | 50 | Pgmq table definitions |

### Nexus NATS Files
| File | Lines | Purpose | Migration |
|------|-------|---------|-----------|
| nats-handler.ts | 150 | LLM routing | Keep or migrate later |
| nats-publisher.ts | 80 | Response publishing | Keep or migrate later |
| nats.ts | 100 | JetStream setup | Keep or migrate later |

---

## Next Steps

1. **Review this document** with team
2. **Approve Phase 1 approach** (Genesis pattern for LLM ops)
3. **Create GitHub issue** for Phase 1 work
4. **Assign developer** for 2-3 weeks
5. **Run tests** after each phase
6. **Document lessons learned** after Phase 1

---

**Generated:** October 25, 2025
**Status:** Ready for Phase 1 implementation
**Estimated Total Timeline:** 6-8 weeks for all phases
