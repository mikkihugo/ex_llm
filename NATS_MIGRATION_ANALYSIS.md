# NATS Usage Analysis Across Codebase

## Executive Summary

The codebase is currently in a **transition from NATS to PostgreSQL pgmq** for inter-service messaging. NATS is still used for:
- **Critical LLM operations** (Singularity ↔ Nexus)
- **Meta-registry operations** (Framework detection, pattern matching)
- **Architecture analysis** (NATS subjects for analysis metadata)

However, **Genesis has already deprecated NATS** in favor of pgmq (PostgreSQL message queue).

---

## Application-by-Application NATS Analysis

### 1. SINGULARITY (Elixir Application)

**Status:** HYBRID - Uses NATS heavily, with pgmq for some operations

#### NATS Pub/Sub Patterns Used:
- **Request/Reply Pattern** - LLM operations with timeouts
- **Direct Publish** - Event broadcasting
- **Streaming** - Token streaming for LLM operations
- **JetStream** - Event persistence (planned, not fully implemented)

#### Main NATS Subjects:
```
llm.req.<model_id>              ← Publish LLM requests to Nexus
llm.resp.<run_id>.<node_id>     ← Receive LLM responses from Nexus
llm.tokens.<run_id>.<node_id>   ← Token stream subscription

analysis.meta.*                 ← Meta-registry queries
planning.*                      ← Work planning operations
agent.*                         ← Agent coordination
```

#### Services Publishing to NATS:
1. **Singularity.NATS.Client** - Central pub/sub interface
2. **Singularity.LLM.NatsOperation** - LLM request/reply
3. **Singularity.LLM.Service** - LLM routing layer
4. **Singularity.Control** - System events
5. **Singularity.Execution.Planning** - Task planning
6. **Singularity.Agents.*** - Agent communication

#### Services Subscribing from NATS:
1. **Singularity.NATS.Server** - Connection management
2. **Singularity.Embedding.Service** - Embedding requests
3. **Singularity.Tools.DatabaseToolsExecutor** - Tool execution
4. **Agents** - Event subscriptions

#### Critical Inter-Service Dependencies via NATS:
| Dependency | Direction | Type | Critical? |
|-----------|-----------|------|-----------|
| Singularity → Nexus LLM | Request/Reply | llm.req.* | YES - Blocks agent execution |
| Singularity → Nexus HITL | Request/Reply | approval.request | YES - Code approval |
| Singularity ← Nexus Response | Direct reply | llm.resp.* | YES - Awaited by agents |
| Singularity ← Token stream | Subscribe | llm.tokens.* | NO - Optional streaming |

#### Configuration Controls NATS Enablement:
```elixir
# singularity/config/config.exs (lines 3-16)
config :singularity, :shared_queue,
  enabled: System.get_env("SHARED_QUEUE_ENABLED", "true") == "true",
  database_url: System.get_env("SHARED_QUEUE_DB_URL"),
  poll_interval_ms: String.to_integer(System.get_env("SHARED_QUEUE_POLL_MS", "1000")),
  batch_size: String.to_integer(System.get_env("SHARED_QUEUE_BATCH_SIZE", "100"))

# singularity/lib/singularity/nats/supervisor.ex (lines 204-210)
nats_enabled = Application.get_env(:singularity, :nats, %{})[:enabled] != false
if not nats_enabled do
  Logger.info("NATS Supervisor disabled via configuration (test mode)")
  :ignore
else
  # Start NATS infrastructure
end
```

#### Graceful Degradation Support:
- ✅ **Test Mode** - Can disable NATS in tests by setting config
- ✅ **Connection Retry** - Auto-reconnect every 5 seconds (NATS.Client line 403)
- ✅ **Status Checks** - `Singularity.NATS.Client.connected?()` for health checks
- ⚠️ **Partial Degradation** - If NATS unavailable, LLM operations fail but other work continues
- ❌ **No Fallback Queue** - No queuing mechanism if NATS is down

#### Number of NATS Dependencies:
- **Direct Dependencies:** 12+ modules
- **Transitive Dependencies:** 40+ modules
- **NATS Subject Definitions:** 7 major category hierarchies
- **Configuration Parameters:** 8 environment variables

#### Files Using NATS:
```
singularity/lib/singularity/nats/                  (Core infrastructure)
  - client.ex                                      (GenServer - publish/subscribe)
  - nats_server.ex                                 (Server connection)
  - supervisor.ex                                  (Process management)
  - jetstream_bootstrap.ex                         (JetStream setup)
  - registry_client.ex                             (Registry interface)
  - engine_discovery_handler.ex                    (Engine detection)

singularity/lib/singularity/llm/
  - nats_operation.ex                              (LLM request/reply)
  - service.ex                                     (LLM routing)

singularity/lib/singularity/execution/
  - todos/todo_nats_interface.ex                   (Todo management)
  - planning/work_plan_api.ex                      (Work planning)

singularity/lib/singularity/tools/
  - nats.ex                                        (Tool execution via NATS)
  - database_tools_executor.ex                     (Database operations)

singularity/lib/singularity/interfaces/
  - nats.ex                                        (Interface protocol)
  - nats/connector.ex                              (Connection management)

singularity/lib/singularity/adapters/
  - nats_adapter.ex                                (Adapter pattern)

singularity/lib/singularity/control/
  - agent_improvement_broadcaster.ex               (Event broadcasting)

singularity/lib/singularity/agents/
  - agent.ex                                       (Agent base)
  - supervisor.ex                                  (Agent lifecycle)
```

---

### 2. GENESIS (Elixir Application)

**Status:** DEPRECATED NATS - Now uses PostgreSQL pgmq

#### NATS Status:
- **Status File:** `genesis/lib/genesis/nats_client.ex`
- **Deprecation Date:** October 2025
- **Current Implementation:** Stub that logs warning

```elixir
# genesis/lib/genesis/nats_client.ex
defmodule Genesis.NatsClient do
  @moduledoc """
  DEPRECATED: Genesis NATS Client

  This module is deprecated as of October 2025.
  Genesis now communicates via PostgreSQL pgmq (shared_queue database) instead of NATS.
  """
  
  def start_link(_opts) do
    Logger.warning("Genesis.NatsClient.start_link called but NATS is deprecated...")
    :ignore
  end
end
```

#### New Implementation (pgmq-based):
```elixir
# genesis/lib/genesis/shared_queue_consumer.ex
# Reads from pgmq.job_requests
# Publishes to pgmq.job_results
# No NATS involvement
```

#### Message Flow (Old → New):
```
OLD: Singularity --[NATS]--> Genesis
NEW: Singularity --[pgmq]--> Genesis
```

#### Configuration:
```elixir
# genesis/config/config.exs (lines 37-43)
config :genesis, :shared_queue,
  enabled: true,
  database_url: "postgresql://postgres:@localhost:5432/shared_queue",
  poll_interval_ms: 1000,
  batch_size: 100
```

#### NATS Dependencies: **ZERO** (fully deprecated)
- No NATS imports in application.ex
- No NATS supervisor in supervision tree
- All messaging via PostgreSQL pgmq

---

### 3. CENTRALCLOUD (Elixir Application)

**Status:** HYBRID - Uses NATS for some services, configuration-driven

#### NATS Pub/Sub Patterns:
- **Request/Reply** - Template searches, pattern queries
- **JetStream KV** - Template caching
- **Direct Publish** - Pattern updates

#### NATS Services:
```elixir
# centralcloud/lib/centralcloud/nats_client.ex
def request(subject, payload, opts \\ [])
def publish(subject, payload)
def kv_get(bucket, key)
def kv_put(bucket, key, value)
```

#### NATS Subjects:
```
central.template.search         ← Query templates
central.patterns.update         ← Publish pattern updates
central.health.*                ← Health checks
```

#### Configuration:
```elixir
# centralcloud/config/config.exs (lines 22-28)
config :centralcloud, :shared_queue,
  enabled: System.get_env("SHARED_QUEUE_ENABLED", "true") == "true",
  database_url: System.get_env("SHARED_QUEUE_DB_URL"),
  auto_initialize: true,
  retention_days: String.to_integer(System.get_env("SHARED_QUEUE_RETENTION_DAYS", "90"))
```

#### Critical Dependencies:
| Service | NATS Dependency | Type |
|---------|-----------------|------|
| Template Service | NATS KV cache | Optional |
| Intelligence Hub | NATS pub/sub | Optional |
| Pattern Aggregation | NATS publish | Optional |

#### NATS-Based Services in CentralCloud:
1. **CentralCloud.NatsClient** - Connection management
2. **CentralCloud.IntelligenceHubSubscriber** - Event subscription
3. **CentralCloud.NATS.PatternValidatorSubscriber** - Pattern validation
4. **CentralCloud.Jobs.PatternAggregationJob** - Pattern aggregation via NATS

#### Number of NATS Dependencies:
- **Direct:** 4-5 modules
- **Transitive:** 10-15 modules
- **Status:** Optional (JetStream KV is caching optimization)

---

### 4. NEXUS (TypeScript/Bun Application)

**Status:** CRITICAL NATS USER - LLM routing and HITL bridge

#### NATS Pub/Sub Patterns:
- **Request/Reply** - LLM requests from Singularity
- **Direct Subscribe** - Approval/question requests
- **JetStream Streams** - Event persistence

#### Main NATS Subjects:
```typescript
// Nexus NATS Handler (src/nats-handler.ts)
llm.request                    ← LLM routing requests from Singularity
llm.response                   ← LLM completion responses

// Approval/Question Bridge (src/approval-websocket-bridge.ts)
approval.request               ← Code approval requests
approval.response              ← Human approval decisions
question.ask                   ← Questions to humans
question.reply                 ← Human responses

// Health and Status
system.health.*                ← Health checks
system.events.*                ← System events
```

#### Pub/Sub Implementation:
```typescript
// src/nats-handler.ts (lines 101-140)
class NATSHandler {
  async connect() {
    const natsUrl = process.env.NATS_URL || 'nats://localhost:4222';
    this.nc = await connect({ servers: natsUrl });
    this.publisher = createPublisher(this.nc);
    await this.subscribeToLLMRequests();
  }
  
  async subscribeToLLMRequests() {
    const subscription = this.nc.subscribe('llm.request');
    // Handle stream of requests...
  }
}
```

#### JetStream Configuration:
```typescript
// src/nats.ts (lines 58-85)
// EVENTS stream: All *.events.* subjects (1 hour retention)
// METRICS stream: All *.metrics.* subjects (24 hour retention)
```

#### Critical LLM Operation Flow:
```
1. Singularity publishes to llm.request (topic: llm.req.<model_id>)
2. Nexus receives request via NATS subscription
3. Nexus analyzes task complexity (simple/medium/complex)
4. Nexus selects best model from MODEL_SELECTION_MATRIX
5. Nexus calls AI provider (Claude, Gemini, Copilot, etc.)
6. Nexus publishes response to llm.response
7. Singularity receives response via request/reply wait
```

#### Model Selection Matrix (src/nats-handler.ts):
```typescript
MODEL_SELECTION_MATRIX = {
  general: {
    simple:   [{ provider: 'gemini', model: 'gemini-2.5-flash' }, ...],
    medium:   [{ provider: 'copilot', model: 'gpt-4o' }, ...],
    complex:  [{ provider: 'claude', model: 'opus' }, ...]
  },
  architect: {...},
  coder:     {...},
  qa:        {...}
}
```

#### Critical Dependencies:
| Dependency | Type | Failover |
|-----------|------|----------|
| Singularity → Nexus LLM | Request/Reply | Blocks agent |
| Singularity → Nexus HITL | Request/Reply | Blocks approval |
| NATS Server | Infrastructure | No fallback |

#### Graceful Degradation:
- ✅ **Connection Retry** - Automatic reconnection (src/nats-handler.ts line 132)
- ✅ **Error Logging** - Comprehensive error logging for all operations
- ⚠️ **Partial Failure** - If provider unavailable, fails over to next in matrix
- ❌ **Offline Mode** - No fallback if all providers fail

#### Number of NATS Dependencies:
- **Direct:** 3 major files
- **Transitive:** 1 core dependency (nats package)
- **NATS Subjects:** 10+ (with hierarchical structure)

#### Files Using NATS:
```
nexus/src/
  - nats-handler.ts            (LLM routing - 150+ lines)
  - nats-publisher.ts          (Safe publishing - 80+ lines)
  - nats.ts                    (JetStream setup - 100+ lines)
  - approval-websocket-bridge.ts (HITL bridge - 150+ lines)
  - server.ts                  (Server initialization)
  
nexus/src/tools/
  - nats-tools.ts              (Utility functions)
```

---

### 5. LLM-SERVER (Deprecated, functionality moved to Nexus)

**Status:** DEPRECATED - Functionality merged into Nexus

The original llm-server has been consolidated into Nexus server (src/server.ts), which now handles:
1. LLM routing (nats-handler.ts)
2. HITL bridge (approval-websocket-bridge.ts)
3. PostgreSQL database for HITL history (db.ts + schema.ts)

---

## Summary Table

| Application | NATS Status | Pub/Sub Patterns | Critical Dependencies | Graceful Degradation | Env Variables |
|-------------|------------|------------------|----------------------|----------------------|---------------|
| **Singularity** | HYBRID | Request/Reply, Pub/Sub, Streaming | YES - LLM ops blocked | Partial (can disable) | 8+ |
| **Genesis** | DEPRECATED | None (pgmq only) | NO | N/A | 0 |
| **CentralCloud** | OPTIONAL | Request/Reply, JetStream KV | NO (caching only) | N/A (pgmq fallback) | 5+ |
| **Nexus** | CRITICAL | Request/Reply, Pub/Sub, JetStream | YES - LLM routing | Partial (retry/fallback) | 2+ |
| **LLM-Server** | DEPRECATED | Merged to Nexus | N/A | N/A | 0 |

---

## NATS Subjects Hierarchy

```
llm.*
  ├── llm.request                          ← Singularity sends LLM requests
  ├── llm.response                         ← Nexus sends responses
  ├── llm.tokens.<run_id>.<node_id>       ← Token streaming
  └── llm.health                           ← Health checks

approval.*
  ├── approval.request                     ← Code approval requests
  └── approval.response                    ← Human approval decisions

question.*
  ├── question.ask                         ← Questions to humans
  └── question.reply                       ← Human responses

analysis.meta.*
  ├── analysis.meta.naming.suggestions
  ├── analysis.meta.architecture.patterns
  ├── analysis.meta.quality.checks
  ├── analysis.meta.dependencies.analysis
  ├── analysis.meta.patterns.suggestions
  ├── analysis.meta.templates.suggestions
  └── analysis.meta.refactoring.suggestions

system.events.*
system.metrics.*
system.health.*

agent.*
planning.*
knowledge.*
```

---

## Configuration-Driven NATS Enablement

### Singularity
```elixir
config :singularity, :nats, enabled: true/false
```

### Genesis
```
NO NATS CONFIG (deprecated, uses pgmq only)
```

### CentralCloud
```elixir
config :centralcloud, :shared_queue, enabled: true/false
```

### Nexus
```bash
NATS_URL=nats://localhost:4222  # Default if not set
PORT=3000
```

---

## Critical Migration Path (NATS → pgmq)

### Already Completed:
1. ✅ Genesis - Full migration to pgmq
2. ✅ LLM routing - Consolidated into Nexus

### In Progress:
1. 🔄 Singularity - Hybrid mode (NATS + pgmq)
2. 🔄 CentralCloud - Optional NATS (KV cache optimization)

### Remaining Work:
1. ⏳ Singularity LLM operations - Replace NATS with pgmq
2. ⏳ Singularity approval/question flow - Replace NATS with pgmq
3. ⏳ CentralCloud pattern aggregation - Replace NATS pub/sub with pgmq

---

## Recommendations for Migration

### Phase 1: Low-Risk (Genesis Pattern)
- Genesis successfully uses pgmq for job_requests/job_results
- Copy this pattern for Singularity LLM operations
- Replace `llm.request` → `pgmq.llm_requests` table
- Replace `llm.response` → `pgmq.llm_results` table

### Phase 2: HITL Flow
- Replace `approval.request` → `pgmq.approval_requests`
- Replace `question.ask` → `pgmq.question_requests`
- Maintain WebSocket bridge (Nexus approval-websocket-bridge.ts still needed)

### Phase 3: CentralCloud
- Replace NATS pub/sub with pgmq pattern queries
- Keep Oban jobs for batch aggregation (no NATS needed)

### Cleanup Phase
- Remove NATS.Supervisor from Singularity application.ex
- Remove NATS client library (gnat package)
- Remove NATS-related configuration
- Archive old NATS templates

---

## Code Metrics

### NATS-Related Code (Current):
- **Singularity:** 2,500+ lines (NATS infrastructure + usage)
- **Nexus:** 400+ lines (NATS handler + publisher)
- **CentralCloud:** 300+ lines (NATS client + subscribers)

### Files to Modify in Migration:
- singularity/lib/singularity/nats/ (4 files, ~1000 lines)
- singularity/lib/singularity/llm/ (2 files, ~500 lines)
- singularity/lib/singularity/tools/ (2 files, ~400 lines)
- nexus/src/ (2 files, ~200 lines - just swap pub/sub mechanism)

---

## Testing Recommendations

### For Each Application

**Singularity:**
```bash
# Test LLM operations via pgmq instead of NATS
mix test singularity/test/singularity/llm/shared_queue_operation_test.exs

# Test approval flow via pgmq
mix test singularity/test/singularity/hitl/shared_queue_approval_test.exs
```

**Genesis:**
```bash
# Already working - use as template
mix test genesis/test/genesis/shared_queue_consumer_test.exs
```

**Nexus:**
```bash
# Test NATS → pgmq transition for handlers
bun run test:shared-queue-handler
```

**CentralCloud:**
```bash
# Test pattern aggregation without NATS
mix test centralcloud/test/centralcloud/jobs/pattern_aggregation_test.exs
```

