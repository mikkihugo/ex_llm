# NATS Integration Map - Who Needs What

## Apps That NEED NATS ✅

### 1. **ai-server** (TypeScript) ✅ DONE
- **Role**: API Gateway / LLM Proxy
- **Uses NATS for**:
  - Stream LLM tokens to clients
  - Query facts from fact system
  - Execute distributed tools
  - Broadcast agent events
- **Install**: `bun add nats` ✅

### 2. **singularity_app** (Elixir) ⚠️ TODO
- **Role**: Agent Orchestration
- **Uses NATS for**:
  - Subscribe to agent events
  - Query facts from Rust
  - Publish code analysis requests
  - Coordinate multi-agent workflows
- **Install**: Add to `mix.exs`:
  ```elixir
  {:gnat, "~> 1.8"}  # NATS client
  {:jason, "~> 1.4"} # Already have
  ```

### 3. **rust/db_service** (Rust) ⚠️ TODO
- **Role**: PostgreSQL Gateway (ONLY service with DB access)
- **Uses NATS for**:
  - Handle DB queries ← `db.query` (request/reply)
  - Handle DB mutations ← `db.execute` (request/reply)
  - Publish all data changes → JetStream
- **Database**: Owns `facts_db` PostgreSQL database
- **Install**: Already done ✅

### 4. **rust/tool_doc_index** (Rust) ⚠️ TODO
- **Role**: Framework Detection (NO database access)
- **Uses NATS for**:
  - Query DB via NATS ← `db.query`
  - Store facts via NATS ← `db.execute`
  - Publish detections → `facts.framework_detected.*`
  - NO direct PostgreSQL or redb storage
- **Install**: Already done ✅

### 5. **rust/prompt_engine** (Rust) ⚠️ TODO
- **Role**: SPARC Template System
- **Uses NATS for**:
  - Provide templates on request ← `sparc.template.*`
  - Track prompt usage stats
  - Publish optimization results
- **Install**: Same as tool_doc_index

---

## Apps That DON'T Need NATS ❌

### ❌ **rust/analysis_suite**
- Self-contained analysis
- Called directly via CLI
- No pub/sub needed

### ❌ **rust/universal_parser**
- Pure parsing logic
- Library, not service
- No messaging needed

### ❌ **rust/linting_engine**
- CLI tool
- Direct invocation
- No distribution needed

---

## NATS Subject Schema

```
db.query                 → SQL SELECT queries (request/reply)
db.execute               → SQL INSERT/UPDATE/DELETE (request/reply)

facts.framework_detected.{name}   → Framework detected (pub/sub)
facts.tech_stack.{repo}           → Tech stack discovered (pub/sub)
facts.tool_doc.{tool}             → Tool documentation updated (pub/sub)

sparc.template.{stage}   → Get SPARC template (request/reply)
sparc.pseudocode         → Generate pseudocode (request/reply)
sparc.architecture       → Generate architecture (request/reply)

agent.{id}.status        → Agent status updates (pub/sub)
agent.{id}.task          → Task assignment (pub/sub)
agent.{id}.result        → Task result (pub/sub)

code.generated           → Code generated event (pub/sub)
code.analyzed            → Analysis complete (pub/sub)
code.indexed             → Indexed in vector DB (pub/sub)

llm.stream.{session}     → LLM token stream (pub/sub)
llm.request.{provider}   → LLM request (request/reply)

tools.{name}             → Execute tool (request/reply)
```

---

## JetStream Streams

```yaml
FACTS:
  subjects: ["facts.>"]
  retention: limits
  max_age: 30d
  storage: file
  use_case: Long-term fact storage, replay for analysis

SPARC:
  subjects: ["sparc.>"]
  retention: limits
  max_age: 7d
  storage: file
  use_case: Template requests, SPARC workflow events

AGENTS:
  subjects: ["agent.>"]
  retention: limits
  max_age: 1d
  storage: memory
  use_case: Real-time agent coordination

CODE_EVENTS:
  subjects: ["code.>"]
  retention: limits
  max_age: 1d
  storage: memory
  use_case: Code generation/analysis events

LLM_STREAMS:
  subjects: ["llm.>"]
  retention: limits
  max_age: 1h
  storage: memory
  use_case: Temporary LLM streaming
```

---

## Installation Priority

### Phase 1: Core Integration (Now)
1. ✅ ai-server (TypeScript) - DONE
2. ⚠️ singularity_app (Elixir) - Add `gnat`
3. ⚠️ tool_doc_index (Rust) - Add `async-nats`

### Phase 2: SPARC Integration (Later)
4. prompt_engine (Rust) - Add `async-nats`

### Phase 3: Optional (If needed)
5. Python workers (if we add them)

---

## Next Steps

1. Add NATS to singularity_app/mix.exs
2. Add NATS to tool_doc_index/Cargo.toml
3. Create NATS connection modules for each
4. Wire up the pub/sub subjects

**Ready to add NATS to Elixir and Rust apps?**
