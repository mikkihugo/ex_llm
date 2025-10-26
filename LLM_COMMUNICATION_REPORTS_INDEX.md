# LLM Communication Architecture Reports Index

## Overview

Three comprehensive reports analyzing LLM communication in Singularity after NATS removal.

**Status:** 🔴 BROKEN - LLM.Service returns `{:error, :unavailable}`. New pgmq + Pgflow architecture is 60% complete with 5 critical gaps.

---

## Reports

### 1. LLM_COMMUNICATION_ANALYSIS.md (16 KB)

**Purpose:** Comprehensive analysis with all technical details  
**Length:** 400+ lines across 9 sections  
**Audience:** Developers implementing fixes

**Contents:**
- Executive summary
- LLM.Service usage map (where it's called, by whom)
- New communication architecture (pgmq + Pgflow)
- Key components breakdown (8 components detailed)
- Current internal communication patterns (4 patterns)
- Broken references after NATS removal (5 critical issues)
- Dependencies & integrations (ex_pgflow, ex_llm, pgmq, Oban)
- Recommendations for cleanup & fix (10 recommendations, prioritized)
- Communication pattern summary (matrix view)

**Read This If:** You need to understand the complete architecture and implement fixes

---

### 2. LLM_COMMUNICATION_QUICK_REFERENCE.md (3.8 KB)

**Purpose:** Quick 2-page summary for rapid understanding  
**Length:** 200 lines  
**Audience:** Developers, architects, managers

**Contents:**
- Status summary
- 5 critical issues (what, where, why, impact)
- Architecture diagram (Singularity/Nexus/PostgreSQL)
- Working vs incomplete components
- Fix priority list
- Dependencies table
- File location table
- Quick assessment

**Read This If:** You need to understand the situation quickly (5-10 min read)

---

### 3. INTERNAL_COMMUNICATION_MAP.md (13 KB)

**Purpose:** Detailed line-by-line flow diagrams for all communication patterns  
**Length:** 300+ lines  
**Audience:** Developers implementing/debugging communication

**Contents:**
- 4 Communication patterns detailed:
  1. Direct function calls (LLM.Service) - BROKEN
  2. Oban background jobs - PARTIALLY WORKING
  3. PostgreSQL message queue (pgmq) - INCOMPLETE
  4. Execution result tracking - COMPLETE
- Request flow diagram (9 steps, what works, what's broken)
- Component status matrix
- Key insights
- File-by-file change requirements

**Read This If:** You need to implement specific fixes or debug communication flow

---

## Quick Navigation

### If You Have 5 Minutes
Read: **LLM_COMMUNICATION_QUICK_REFERENCE.md**

### If You Have 15 Minutes
Read: **LLM_COMMUNICATION_QUICK_REFERENCE.md** + first 3 sections of **LLM_COMMUNICATION_ANALYSIS.md**

### If You Have 30+ Minutes
Read all three reports in order:
1. Quick Reference (5 min) - understand the problem
2. Analysis (15 min) - understand all components
3. Communication Map (10 min) - understand the flows

### If You Need to Implement Fixes
Read: **INTERNAL_COMMUNICATION_MAP.md** + relevant sections from **LLM_COMMUNICATION_ANALYSIS.md**

---

## Key Findings Summary

### 5 Critical Issues

1. **LLM.Service.dispatch_request** (BROKEN)
   - File: `/singularity/lib/singularity/llm/service.ex:817`
   - Returns: `{:error, :unavailable}`
   - Impact: All LLM calls fail

2. **Nexus.QueueConsumer** (MISSING)
   - Should be: `/nexus/lib/nexus/queue_consumer.ex`
   - Impact: Requests enqueued but never processed

3. **Nexus.Workflows.publish_result** (TODO)
   - File: `/nexus/lib/nexus/workflows/llm_request_workflow.ex:207`
   - Impact: Results never reach response queue

4. **LlmResultPoller.store_result** (TODO)
   - File: `/singularity/lib/singularity/jobs/llm_result_poller.ex:111`
   - Impact: Results lost, can't be consumed

5. **Singularity.Workflows.LlmRequest** (BROKEN)
   - File: `/singularity/lib/singularity/workflows/llm_request.ex:100`
   - Issue: Calls broken LLM.Service
   - Impact: Pgflow workflow fails

### Priority Fix Order

1. Implement Nexus.QueueConsumer (2-3 hours)
2. Complete publish_result (30 min)
3. Complete store_result (1 hour)
4. Fix LLM.Service.dispatch_request (2-4 hours)
5. Fix Singularity.Workflows (1 hour)

**Total: 6.5 - 10 hours to working LLM communication**

---

## Architecture Assessment

**Status:** Sound design, incomplete implementation (60% done)

**Working:**
- pgmq for inter-app communication ✅
- Pgflow for workflow orchestration ✅
- Nexus.LLMRouter for provider routing ✅
- ExLLM for actual LLM calls ✅
- Oban for job scheduling ✅

**Broken:**
- LLM.Service entry point ❌
- Nexus queue consumer ❌
- Result publishing ❌
- Result storage ❌

---

## File Locations Quick Reference

| Component | File | Status |
|-----------|------|--------|
| LLM.Service | `/singularity/lib/singularity/llm/service.ex` | BROKEN |
| LlmRequestWorker | `/singularity/lib/singularity/jobs/llm_request_worker.ex` | ✅ |
| LlmResultPoller | `/singularity/lib/singularity/jobs/llm_result_poller.ex` | ⚠️ |
| PgmqClient | `/singularity/lib/singularity/jobs/pgmq_client.ex` | ✅ |
| JobResult | `/singularity/lib/singularity/schemas/execution/job_result.ex` | ✅ |
| Singularity.Workflows.LlmRequest | `/singularity/lib/singularity/workflows/llm_request.ex` | BROKEN |
| Nexus.LLMRouter | `/nexus/lib/nexus/llm_router.ex` | ✅ |
| Nexus.Workflows | `/nexus/lib/nexus/workflows/llm_request_workflow.ex` | ⚠️ |
| Nexus.QueueConsumer | MISSING | ❌ |

---

## Dependencies

- **ex_pgflow** - Workflow orchestration (in both Singularity and Nexus) ✅
- **ex_llm** - LLM client (in Nexus only) ✅
- **pgmq** - PostgreSQL message queue (in Nexus, works in Singularity) ✅
- **Oban** - Job scheduling (in Singularity) ✅

---

## Next Steps

1. Read the appropriate report(s) based on your available time
2. Decide on sync vs async approach for LLM calls
3. Implement Nexus.QueueConsumer (critical blocker)
4. Complete TODO items
5. Test end-to-end
6. Add monitoring

---

## Questions Answered by These Reports

- "What's broken after NATS removal?" → Quick Reference
- "How should LLM requests flow?" → Communication Map
- "Where exactly do I need to make changes?" → Communication Map + Analysis
- "What's the current architecture?" → Analysis section 2
- "What components are working?" → Quick Reference + Analysis section 7
- "What needs to be implemented?" → Quick Reference or Analysis section 6
- "What are the dependencies?" → Analysis section 5 or Quick Reference
- "How long will fixes take?" → Analysis section 6

---

Generated: October 26, 2025
Codebase: singularity-incubation
Analysis Time: ~2 hours
Report Format: Markdown
Total Content: ~32 KB across 3 files
