# NATS Migration Analysis - Complete Documentation Index

## Overview

This analysis documents NATS usage across the entire codebase and provides a structured migration plan from NATS to PostgreSQL pgmq for inter-service messaging.

**Status:** Genesis has already completed migration to pgmq. Singularity, CentralCloud, and Nexus remain on NATS (hybrid or optional usage).

---

## Document Guide

### For Quick Understanding
Start here if you want a fast overview:

1. **NATS_SCOPE_TABLE.md** (14 KB, 336 lines)
   - At-a-glance summary table
   - Application status matrix
   - Detailed metrics per application
   - Success criteria checklist
   - **Best for:** Executive summary, quick reference

2. **NATS_MIGRATION_SUMMARY.md** (13 KB, 426 lines)
   - Migration phases (5 phases total)
   - Risk assessment
   - Timeline & effort estimation
   - Success criteria with checkboxes
   - **Best for:** Planning and prioritization

### For Deep Analysis
Read these for comprehensive understanding:

3. **NATS_MIGRATION_ANALYSIS.md** (17 KB, 523 lines)
   - Complete application-by-application breakdown
   - NATS pub/sub patterns by application
   - Critical inter-service dependencies
   - Configuration controls & graceful degradation
   - **Best for:** Understanding current state, architectural decisions

### For Reference
Use these for specific lookups:

4. **NATS_SCOPE_TABLE.md** → Consolidated metrics table
   - All applications at a glance
   - Files, lines of code, dependencies
   - Configuration parameters
   - Success metrics

5. **NATS_REGISTRY.md** → Historical NATS subject registry
   - NATS subject definitions
   - Framework patterns
   - Legacy reference

---

## Reading Sequence by Role

### Project Manager / Tech Lead
1. Read: NATS_SCOPE_TABLE.md (15 min)
2. Review: Timeline & Resources section
3. Decide: Phase 1 approval
4. Outcome: Clear scope, effort, risk

### Backend Developer
1. Read: NATS_MIGRATION_ANALYSIS.md (30 min)
2. Reference: NATS_SCOPE_TABLE.md for specifics
3. Study: Genesis implementation in shared_queue_consumer.ex
4. Outcome: Ready to implement Phase 1

### DevOps / Infrastructure
1. Read: Configuration Parameters section (10 min)
2. Check: Environment variables per application
3. Verify: NATS server setup (can stay for Nexus)
4. Outcome: Understand infrastructure changes

### QA / Testing
1. Read: Testing Recommendations section
2. Review: Success Criteria
3. Plan: Test cases for each phase
4. Outcome: Test plan for migration

---

## Key Findings Summary

### Current State (October 2025)

| Application | NATS Status | Risk | Effort | Phase |
|------------|------------|------|--------|-------|
| **Genesis** | ✅ Migrated to pgmq | None | DONE | 0 |
| **Singularity** | 🔄 HYBRID (NATS + pgmq) | MEDIUM | 2-3 weeks | 1 |
| **CentralCloud** | ⚠️ OPTIONAL (KV cache) | LOW | 1 week | 3 |
| **Nexus** | 🔴 CRITICAL (LLM routing) | HIGH | Keep NATS | 4 |
| **LLM-Server** | ✅ Merged to Nexus | None | DONE | 0 |

### Critical Findings

1. **Genesis Success Pattern**
   - Successfully migrated to PostgreSQL pgmq
   - GenServer + periodic polling (1000ms)
   - Durable message delivery via transactions
   - ✅ Copy this pattern for Singularity LLM ops

2. **Singularity NATS Dependency**
   - 12+ direct modules, 40+ transitive
   - 2,500+ lines of NATS code
   - 11 NATS subject patterns
   - **Critical**: LLM operations block agents until response received
   - **Timeout**: 30 seconds (agents block waiting for LLM response)

3. **Nexus LLM Routing**
   - Absolutely critical (blocks all agent execution)
   - Only 3 files, 400 lines (contained)
   - **Recommendation**: KEEP NATS for Nexus (simplest, safest)
   - Can be migrated later if needed

4. **CentralCloud Optional**
   - NATS KV is optimization only (DB fallback exists)
   - Can be disabled without affecting core functionality
   - Easy migration (just flip config flag)

---

## Migration Phases

### Phase 0: Completed
- ✅ Genesis: Full migration to pgmq (Oct 2025)
- ✅ LLM-Server: Merged into Nexus

### Phase 1: Singularity LLM Operations
- **Timeline**: 2-3 weeks
- **Risk**: MEDIUM (affects agent execution)
- **Approach**: Follow Genesis pattern
  - Create SharedQueueOperation module
  - Create llm_requests/llm_results pgmq tables
  - Replace NATS request/reply with pgmq poll
  - Update LLM.Service to use SharedQueue

### Phase 2: HITL Flow (Approvals/Questions)
- **Timeline**: 1-2 weeks
- **Risk**: LOW (approval flow is async)
- **Approach**: pgmq tables for approval/question requests

### Phase 3: CentralCloud
- **Timeline**: 1 week
- **Risk**: LOW (all optional)
- **Approach**: Disable NATS KV, use PostgreSQL queries

### Phase 4: Nexus Decision Point
- **Timeline**: 2-3 hours (decision only)
- **Decision**: Keep NATS or migrate to pgmq?
- **Recommendation**: Keep NATS (minimal changes, maximum stability)

### Phase 5: Cleanup
- **Timeline**: 1 week
- **After**: All migrations complete
- **Action**: Remove NATS dependencies, update docs

**Total Timeline**: 6-8 weeks for full migration

---

## What This Analysis Covers

### Per Application
- Current NATS usage pattern
- All pub/sub subjects
- Direct and transitive dependencies
- Critical inter-service dependencies
- Configuration controls
- Graceful degradation support
- Number of NATS dependencies
- Files using NATS
- Migration approach
- Risk assessment

### Architecture
- NATS subject hierarchy
- Pub/sub patterns used (request/reply, streaming, direct)
- JetStream usage
- Configuration parameters per app
- Environment variables

### Migration Plan
- 5 phases with timelines
- Risk assessment per phase
- Success criteria with checkboxes
- Code metrics (lines to change)
- Testing requirements
- Resource allocation

### Decision Support
- Tables for quick comparison
- Risk vs effort assessment
- Recommendation for Nexus (keep NATS)
- Lessons from Genesis migration

---

## Files You Need

### To Understand Migration Scope
- ✅ NATS_SCOPE_TABLE.md (this is your goto reference)
- ✅ NATS_MIGRATION_SUMMARY.md (executive summary + timelines)

### To Understand Current Architecture
- ✅ NATS_MIGRATION_ANALYSIS.md (comprehensive breakdown)

### To Implement Phase 1
- ✅ genesis/lib/genesis/shared_queue_consumer.ex (copy this pattern)
- ✅ singularity/lib/singularity/llm/nats_operation.ex (what to replace)
- ✅ singularity/lib/singularity/shared_queue_publisher.ex (existing pgmq code)

### For Reference
- ✅ NATS_REGISTRY.md (historical subject definitions)
- ✅ All 3 new NATS_*.md files created by this analysis

---

## Recommendations

### Immediate Actions (Week 1)
1. **Review** this analysis with team
2. **Approve** Phase 1 approach (Genesis pattern)
3. **Decide** on Nexus (keep NATS)
4. **Assign** developer for Phase 1 implementation

### Phase 1 Priorities
1. Create `SharedQueueOperation` module
2. Create pgmq tables for llm_requests/llm_results
3. Update LLM.Service to use SharedQueue
4. Test with agents (no NATS required)
5. Measure performance (ensure no regression)

### Success Criteria
- [ ] LLM operations work without NATS
- [ ] Agent execution not blocked on NATS unavailability
- [ ] All tests pass (singularity/test/singularity/llm/)
- [ ] Timeout behavior identical (30 seconds default)
- [ ] No performance regression

### After Phase 1
- Document lessons learned
- Plan Phase 2 (HITL flow)
- Decision on Nexus migration (likely: keep NATS)

---

## Quick Access Tables

### Application Status
```
┌─────────────────┬──────────────┬──────────┬───────────────────┬─────────────┐
│   Application   │ Status       │ Patterns │ Dependencies      │ Risk Level  │
├─────────────────┼──────────────┼──────────┼───────────────────┼─────────────┤
│ Singularity     │ HYBRID       │ 11       │ 12 direct, 40 T   │ MEDIUM      │
│ Genesis         │ DEPRECATED   │ 0        │ 0                 │ NONE        │
│ CentralCloud    │ OPTIONAL     │ 3        │ 4-5 direct        │ LOW         │
│ Nexus           │ CRITICAL     │ 6        │ 3 files, 1 pkg    │ HIGH*       │
│ LLM-Server      │ DEPRECATED   │ N/A      │ Merged to Nexus   │ NONE        │
└─────────────────┴──────────────┴──────────┴───────────────────┴─────────────┘
* Recommended to keep NATS for Nexus
```

### NATS Subjects by Application
```
Singularity:  11 patterns (llm.*, approval.*, question.*, analysis.meta.*, etc.)
Genesis:      0 patterns  (all pgmq)
CentralCloud: 3 patterns  (central.*, intelligence.*, health.*)
Nexus:        6 patterns  (llm.request, llm.response, approval.*, question.*, etc.)
```

### Timeline & Resources
```
Phase 1: 2-3 weeks,  1 developer  (Singularity LLM ops)
Phase 2: 1-2 weeks,  1 developer  (HITL flow)
Phase 3: 1 week,     1 developer  (CentralCloud)
Phase 4: 2-3 hours,  1 developer  (Nexus decision)
Phase 5: 1 week,     1 developer  (Cleanup)
────────────────────────────────────────────
Total:   6-8 weeks for full migration
```

---

## Document Dates & Status

| Document | Size | Lines | Created | Status |
|----------|------|-------|---------|--------|
| NATS_SCOPE_TABLE.md | 14 KB | 336 | Oct 25, 2025 | ✅ Complete |
| NATS_MIGRATION_SUMMARY.md | 13 KB | 426 | Oct 25, 2025 | ✅ Complete |
| NATS_MIGRATION_ANALYSIS.md | 17 KB | 523 | Oct 25, 2025 | ✅ Complete |
| NATS_REGISTRY.md | 11 KB | 323 | Historical | Reference |

---

## Questions Answered by This Analysis

1. **What NATS pub/sub patterns are used?**
   → Request/Reply (LLM ops), Direct Publish (events), Streaming (tokens), JetStream (optional)

2. **What are the main NATS subjects/topics?**
   → 11 patterns for Singularity, 6 for Nexus, 3 for CentralCloud (see tables)

3. **What services publish vs subscribe?**
   → Documented per app with full module names

4. **Are there critical inter-service dependencies?**
   → YES: Singularity → Nexus LLM routing (blocks agents)

5. **What configuration controls NATS enablement?**
   → Per-app config flags documented (singularity.nats.enabled, etc.)

6. **Are there graceful degradation patterns?**
   → Partial: Test mode disable, auto-reconnect; NO: Full fallback queue

7. **What's the migration scope?**
   → Genesis: ✅ Done; Singularity: 2-3 weeks; CentralCloud: 1 week; Nexus: Keep NATS

8. **Why not migrate Nexus?**
   → Risk is high, current NATS is stable, pgmq would require polling (slower)

---

## Next Steps

1. **Share** these documents with team
2. **Discuss** Phase 1 approach in meeting
3. **Approve** timeline and resources
4. **Create** GitHub issue for Phase 1
5. **Assign** developer
6. **Execute** Phase 1 (2-3 weeks)

---

**Analysis Complete**
- Date: October 25, 2025
- Scope: Full NATS migration assessment
- Status: Ready for Phase 1 implementation
- Recommendation: Proceed with Genesis pattern for Singularity LLM ops
- Decision Point: Keep NATS for Nexus (recommended)

See **NATS_SCOPE_TABLE.md** for quick reference.
See **NATS_MIGRATION_ANALYSIS.md** for comprehensive details.
